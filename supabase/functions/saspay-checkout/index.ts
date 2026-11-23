// ============================================================================
//  saspay-checkout — Commande (kit) ou abonnement (Studio Live) + session SasPay.
//
//  23 pays SasPay uniquement : les autres pays sont facturés via Paddle
//  (`create-paddle-checkout`). Le montant est TOUJOURS recalculé côté serveur
//  par pricing.ts dans la devise locale — aucun montant client n'est accepté.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import {
  OFFRES,
  SITE_URL,
  kitParCode,
  paysParCode,
  telephoneE164,
  type TypeProduit,
} from "../_shared/config.ts";
import {
  DUREE_STUDIO_JOURS,
  estTypeProduit,
  libelleOffre,
  montantSasPay,
  prixReferenceXof,
  type TypeAchat,
} from "../_shared/pricing.ts";
import { creerSessionCheckout } from "../_shared/saspay.ts";
import { adminClient, utilisateurCourant } from "../_shared/supabase.ts";

interface CorpsRequete {
  kind?: string;
  metier_code?: string;
  metier_label?: string;
  nom_projet?: string;
  pays_code?: string;
  whatsapp?: string;
  precisions?: string;
  email?: string;
  produit_type?: string;
}

function emailValide(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email);
}

function nettoyer(valeur: unknown, max: number): string {
  return String(valeur ?? "").trim().slice(0, max);
}

function texteJson(valeur: unknown): string {
  return JSON.stringify(valeur);
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  try {
    const corps = (await req.json().catch(() => ({}))) as CorpsRequete;

    // ------------------------------------------------------------------
    // 1. VALIDATION COMMUNE
    // ------------------------------------------------------------------
    const kind: TypeAchat = nettoyer(corps.kind, 10).toLowerCase() === "studio"
      ? "studio"
      : "kit";

    const pays = paysParCode(nettoyer(corps.pays_code, 2));
    if (!pays) return erreur("Choisissez votre pays dans la liste.");
    if (pays.route !== "saspay") {
      return erreur(
        "Ce pays est facturé via Paddle. Utilisez le paiement international (EUR/USD).",
        400,
      );
    }

    const codeMetier = nettoyer(corps.metier_code, 40).toLowerCase();
    const metier = kitParCode(codeMetier);
    if (!metier) return erreur("Choisissez un secteur valide.");

    const labelSaisi = nettoyer(corps.metier_label, 80);
    if (codeMetier === "autre" && labelSaisi.length < 2) {
      return erreur("Précisez votre métier en quelques mots (2 caractères minimum).");
    }
    const metierLabel = labelSaisi.length >= 2 ? labelSaisi : metier.label;

    const nomProjet = nettoyer(corps.nom_projet, 120);
    if (nomProjet.length < 3) {
      return erreur("Renseignez le nom de votre projet (3 caractères minimum).");
    }

    const whatsappChiffres = nettoyer(corps.whatsapp, 20).replace(/\D/g, "");
    if (whatsappChiffres.length < 6 || whatsappChiffres.length > 15) {
      return erreur("Renseignez un numéro WhatsApp valide.");
    }

    const email = nettoyer(corps.email, 160).toLowerCase();
    if (!emailValide(email)) return erreur("Renseignez un email valide pour recevoir vos liens.");

    const precisions = nettoyer(corps.precisions, 1000);
    const telephone = telephoneE164(pays.indicatif, whatsappChiffres);

    let produit: TypeProduit | null = null;
    if (kind === "kit") {
      const brutProduit = nettoyer(corps.produit_type, 10).toLowerCase();
      if (!estTypeProduit(brutProduit)) return erreur("Choisissez une offre valide.");
      produit = brutProduit;
    }

    const tarif = montantSasPay(kind, produit, pays.code);
    const referenceXof = prixReferenceXof(kind, produit);

    const utilisateur = await utilisateurCourant(req);
    const admin = adminClient();

    // ------------------------------------------------------------------
    // 2. KIT : COMMANDE EN_ATTENTE (montant local recalculé)
    // ------------------------------------------------------------------
    if (kind === "kit") {
      const offre = OFFRES[produit as TypeProduit];
      const { data: commande, error: erreurCommande } = await admin
        .from("orders")
        .insert({
          user_id: utilisateur?.id ?? null,
          email,
          nom_projet: nomProjet,
          metier_code: metier.code,
          metier_label: metierLabel,
          produit_type: offre.type,
          montant_fcfa: offre.prixFcfa,
          devise: "XOF",
          montant_local: tarif.montant,
          devise_locale: tarif.devise,
          pays_code: pays.code,
          pays_label: pays.nom,
          indicatif: pays.indicatif,
          whatsapp: telephone,
          precisions: precisions || null,
          statut: "EN_ATTENTE",
          provider: "saspay",
          kind: "kit",
        })
        .select("id")
        .single();

      if (erreurCommande || !commande) {
        throw new Error(`Création de la commande impossible : ${erreurCommande?.message ?? "inconnu"}`);
      }

      const session = await creerSessionCheckout({
        montant: tarif.montant,
        devise: tarif.devise,
        description: `Kit ${metierLabel} — ${offre.titre} (${nomProjet})`,
        email,
        nom: nomProjet,
        telephone,
        pays: pays.code,
        returnUrl: `${SITE_URL}/?commande=${commande.id}`,
        metadata: {
          order_id: commande.id,
          kind: "kit",
          pays_code: pays.code,
        },
      });

      await admin
        .from("orders")
        .update({
          saspay_session_id: session.id,
          saspay_checkout_url: session.checkoutUrl,
        })
        .eq("id", commande.id);

      return json({
        success: true,
        provider: "saspay",
        kind: "kit",
        order_id: commande.id,
        subscription_id: null,
        session_id: session.id,
        checkout_url: session.checkoutUrl,
        montant: tarif.montant,
        devise: tarif.devise,
        montant_fcfa: referenceXof,
        offre: offre.titre,
        metier: metierLabel,
        pays: pays.nom,
      });
    }

    // ------------------------------------------------------------------
    // 3. STUDIO LIVE : ABONNEMENT EN_ATTENTE (10 USD / 30 jours)
    // ------------------------------------------------------------------
    const { data: abonnement, error: erreurAbonnement } = await admin
      .from("studio_subscriptions")
      .insert({
        user_id: utilisateur?.id ?? null,
        email,
        nom_activite: nomProjet,
        metier_code: metier.code,
        metier_label: metierLabel,
        pays_code: pays.code,
        pays_label: pays.nom,
        devise: tarif.devise,
        montant_local: tarif.montant,
        montant_usd: 10,
        provider: "saspay",
        status: "EN_ATTENTE",
        guide_status: "EN_ATTENTE",
      })
      .select("id")
      .single();

    if (erreurAbonnement || !abonnement) {
      throw new Error(
        `Création de l'abonnement impossible : ${erreurAbonnement?.message ?? "inconnu"}`,
      );
    }

    const session = await creerSessionCheckout({
      montant: tarif.montant,
      devise: tarif.devise,
      description: `Studio Live ${DUREE_STUDIO_JOURS} jours — ${nomProjet}`,
      email,
      nom: nomProjet,
      telephone,
      pays: pays.code,
      returnUrl: `${SITE_URL}/studio-live?abonnement=${abonnement.id}`,
      metadata: {
        subscription_id: abonnement.id,
        kind: "studio",
        pays_code: pays.code,
      },
    });

    await admin
      .from("studio_subscriptions")
      .update({ saspay_session_id: session.id })
      .eq("id", abonnement.id);

    console.log("saspay-checkout studio :", texteJson({
      subscription_id: abonnement.id,
      pays: pays.code,
      devise: tarif.devise,
    }));

    return json({
      success: true,
      provider: "saspay",
      kind: "studio",
      order_id: null,
      subscription_id: abonnement.id,
      session_id: session.id,
      checkout_url: session.checkoutUrl,
      montant: tarif.montant,
      devise: tarif.devise,
      montant_fcfa: referenceXof,
      offre: libelleOffre("studio"),
      metier: metierLabel,
      pays: pays.nom,
    });
  } catch (erreurInterne) {
    console.error("saspay-checkout :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Paiement indisponible pour le moment.",
      500,
    );
  }
});
