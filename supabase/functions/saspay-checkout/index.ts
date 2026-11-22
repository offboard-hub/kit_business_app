// ============================================================================
//  saspay-checkout — Création de la commande + session de paiement SasPay.
//  ⚠️ Le montant est TOUJOURS calculé côté serveur (jamais envoyé par le client).
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
import { creerSessionCheckout } from "../_shared/saspay.ts";
import { adminClient, utilisateurCourant } from "../_shared/supabase.ts";

interface CorpsRequete {
  metier_code?: string;
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

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  try {
    const corps = (await req.json()) as CorpsRequete;

    // ------------------------------------------------------------------
    // 1. VALIDATION
    // ------------------------------------------------------------------
    const metier = kitParCode(nettoyer(corps.metier_code, 40));
    if (!metier) return erreur("Choisissez un kit métier valide.");

    const pays = paysParCode(nettoyer(corps.pays_code, 2));
    if (!pays) return erreur("Choisissez votre pays africain.");

    const offre = OFFRES[nettoyer(corps.produit_type, 10) as TypeProduit];
    if (!offre) return erreur("Choisissez une offre valide.");

    const nomProjet = nettoyer(corps.nom_projet, 120);
    if (nomProjet.length < 3) return erreur("Renseignez le nom de votre projet (3 caractères minimum).");

    const whatsappChiffres = nettoyer(corps.whatsapp, 20).replace(/\D/g, "");
    if (whatsappChiffres.length < 6 || whatsappChiffres.length > 15) {
      return erreur("Renseignez un numéro WhatsApp valide.");
    }

    const email = nettoyer(corps.email, 160).toLowerCase();
    if (!emailValide(email)) return erreur("Renseignez un email valide pour recevoir vos liens.");

    const precisions = nettoyer(corps.precisions, 1000);
    const telephone = telephoneE164(pays.indicatif, whatsappChiffres);
    const utilisateur = await utilisateurCourant(req);
    const admin = adminClient();

    // ------------------------------------------------------------------
    // 2. COMMANDE (statut EN_ATTENTE, montant serveur)
    // ------------------------------------------------------------------
    const { data: commande, error: erreurCommande } = await admin
      .from("orders")
      .insert({
        user_id: utilisateur?.id ?? null,
        email,
        nom_projet: nomProjet,
        metier_code: metier.code,
        metier_label: metier.label,
        produit_type: offre.type,
        montant_fcfa: offre.prixFcfa,
        devise: pays.devise,
        pays_code: pays.code,
        pays_label: pays.nom,
        indicatif: pays.indicatif,
        whatsapp: telephone,
        precisions: precisions || null,
        statut: "EN_ATTENTE",
      })
      .select("id")
      .single();

    if (erreurCommande || !commande) {
      throw new Error(`Création de la commande impossible : ${erreurCommande?.message ?? "inconnu"}`);
    }

    // ------------------------------------------------------------------
    // 3. SESSION SASPAY (le client revient sur le site avec ?commande=<id>)
    // ------------------------------------------------------------------
    const returnUrl = `${SITE_URL}/?commande=${commande.id}`;

    const session = await creerSessionCheckout({
      montantFcfa: offre.prixFcfa,
      devise: pays.devise,
      description: `Kit ${metier.label} — ${offre.titre} (${nomProjet})`,
      email,
      nom: nomProjet,
      telephone,
      pays: pays.code,
      returnUrl,
      metadata: {
        order_id: commande.id,
        produit_type: offre.type,
        metier_code: metier.code,
        pays_code: pays.code,
        site: SITE_URL,
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
      order_id: commande.id,
      session_id: session.id,
      checkout_url: session.checkoutUrl,
      montant_fcfa: offre.prixFcfa,
      devise: pays.devise,
      offre: offre.titre,
      metier: metier.label,
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
