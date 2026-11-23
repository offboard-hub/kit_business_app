// ============================================================================
//  create-paddle-checkout — Paiement international (hors 23 pays SasPay).
//
//  • Paddle Billing : POST /transactions (price_id configuré côté Paddle).
//  • Crée la ligne orders / studio_subscriptions AVANT l'appel, puis stocke
//    paddle_transaction_id, le montant local facturé et sa devise.
//  • La devise de facturation est EUR (Europe + Maghreb) ou USD (reste du
//    monde) ; la conversion locale renvoyée est indicative.
//  • Aucun montant client n'est accepté : tout est recalculé par pricing.ts.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import {
  OFFRES,
  kitParCode,
  paysParCode,
  telephoneE164,
  type TypeProduit,
} from "../_shared/config.ts";
import {
  DUREE_STUDIO_JOURS,
  arrondirPrix,
  estTypeProduit,
  libelleOffre,
  montantPaddle,
  prixReferenceXof,
  type TypeAchat,
} from "../_shared/pricing.ts";
import { taux } from "../_shared/countries.ts";
import {
  clientTokenPaddle,
  creerTransactionPaddle,
  environnementPaddle,
  priceIdPaddle,
  type TransactionPaddle,
} from "../_shared/paddle.ts";
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

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  try {
    const corps = (await req.json().catch(() => ({}))) as CorpsRequete;

    // ------------------------------------------------------------------
    // 1. VALIDATION
    // ------------------------------------------------------------------
    const kind: TypeAchat = nettoyer(corps.kind, 10).toLowerCase() === "studio"
      ? "studio"
      : "kit";

    const pays = paysParCode(nettoyer(corps.pays_code, 2));
    if (!pays) return erreur("Choisissez votre pays dans la liste.");
    if (pays.route !== "paddle") {
      return erreur(
        "Ce pays est encaissé par SasPay dans sa devise locale. Utilisez le paiement SasPay.",
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

    const tarif = montantPaddle(kind, produit, pays.code);
    const referenceXof = prixReferenceXof(kind, produit);
    const priceId = priceIdPaddle(kind, produit, tarif.devise);
    const offre = kind === "kit"
      ? OFFRES[produit as TypeProduit].titre
      : libelleOffre("studio");

    const utilisateur = await utilisateurCourant(req);
    const admin = adminClient();

    // ------------------------------------------------------------------
    // 2. LIGNE MÉTIER AVANT L'APPEL PADDLE
    // ------------------------------------------------------------------
    let orderId: string | null = null;
    let subscriptionId: string | null = null;

    if (kind === "kit") {
      const { data, error } = await admin
        .from("orders")
        .insert({
          user_id: utilisateur?.id ?? null,
          email,
          nom_projet: nomProjet,
          metier_code: metier.code,
          metier_label: metierLabel,
          produit_type: produit,
          montant_fcfa: referenceXof,
          devise: "XOF",
          montant_local: tarif.montant,
          devise_locale: tarif.devise,
          pays_code: pays.code,
          pays_label: pays.nom,
          indicatif: pays.indicatif,
          whatsapp: telephone,
          precisions: precisions || null,
          statut: "EN_ATTENTE",
          provider: "paddle",
          kind: "kit",
        })
        .select("id")
        .single();
      if (error || !data) {
        throw new Error(`Création de la commande impossible : ${error?.message ?? "inconnu"}`);
      }
      orderId = String(data.id);
    } else {
      const { data, error } = await admin
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
          provider: "paddle",
          status: "EN_ATTENTE",
          guide_status: "EN_ATTENTE",
        })
        .select("id")
        .single();
      if (error || !data) {
        throw new Error(`Création de l'abonnement impossible : ${error?.message ?? "inconnu"}`);
      }
      subscriptionId = String(data.id);
    }

    // ------------------------------------------------------------------
    // 3. TRANSACTION PADDLE
    // ------------------------------------------------------------------
    let transaction: TransactionPaddle;
    try {
      transaction = await creerTransactionPaddle({
        priceId,
        customData: {
          ...(orderId ? { order_id: orderId } : {}),
          ...(subscriptionId ? { subscription_id: subscriptionId } : {}),
          kind,
          pays_code: pays.code,
        },
      });
    } catch (erreurPaddle) {
      const message = erreurPaddle instanceof Error
        ? erreurPaddle.message
        : "Paddle est indisponible pour le moment.";
      const table = kind === "kit" ? "orders" : "studio_subscriptions";
      const id = orderId ?? subscriptionId;
      if (id) {
        await admin
          .from(table)
          .update(kind === "kit" ? { statut: "ECHEC" } : { status: "ECHEC" })
          .eq("id", id);
      }
      console.error("create-paddle-checkout :", message);
      return erreur(`Paiement international indisponible : ${message}`, 502);
    }

    // Les price IDs EUR sont optionnels : si la variante EUR n'existe pas,
    // priceIdPaddle() retombe sur le prix USD. Paddle fait foi sur la devise
    // réellement facturée, et la ligne est alignée sur cette devise.
    const deviseFacturee = (transaction.devise ?? tarif.devise).toUpperCase();
    const montantFacture = transaction.montantTotal ?? tarif.montant;
    if (deviseFacturee !== tarif.devise) {
      console.warn("create-paddle-checkout : repli de devise Paddle.", {
        attendu: tarif.devise,
        facture: deviseFacturee,
        price_id: priceId,
      });
    }

    const deviseIndicative = deviseFacturee === pays.devise ? null : pays.devise;
    const montantIndicatif = deviseIndicative === null
      ? null
      : arrondirPrix(
        (montantFacture / Math.max(taux(deviseFacturee), 0.0000001)) * taux(pays.devise),
        pays.devise,
      );

    const table = kind === "kit" ? "orders" : "studio_subscriptions";
    const id = orderId ?? subscriptionId;
    if (id) {
      await admin
        .from(table)
        .update(
          kind === "kit"
            ? {
              paddle_transaction_id: transaction.id,
              montant_local: montantFacture,
              devise_locale: deviseFacturee,
            }
            : {
              paddle_transaction_id: transaction.id,
              montant_local: montantFacture,
              devise: deviseFacturee,
            },
        )
        .eq("id", id);
    }

    const clientToken = clientTokenPaddle();
    if (!clientToken && !transaction.checkoutUrl) {
      const tableEchec = kind === "kit" ? "orders" : "studio_subscriptions";
      const idEchec = orderId ?? subscriptionId;
      if (idEchec) {
        await admin
          .from(tableEchec)
          .update(kind === "kit" ? { statut: "ECHEC" } : { status: "ECHEC" })
          .eq("id", idEchec);
      }
      return erreur(
        "Le paiement international n'est pas disponible pour le moment. Réessayez dans un instant ou contactez le support.",
        503,
      );
    }

    return json({
      success: true,
      provider: "paddle",
      kind,
      order_id: orderId,
      subscription_id: subscriptionId,
      transaction_id: transaction.id,
      checkout_url: transaction.checkoutUrl,
      client_token: clientToken,
      environment: environnementPaddle(),
      montant: montantFacture,
      devise: deviseFacturee,
      montant_indicatif: montantIndicatif,
      devise_indicative: deviseIndicative,
      montant_fcfa: referenceXof,
      offre,
      metier: metierLabel,
      pays: pays.nom,
      duree_jours: kind === "studio" ? DUREE_STUDIO_JOURS : null,
    });
  } catch (erreurInterne) {
    console.error("create-paddle-checkout :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error
        ? erreurInterne.message
        : "Paiement international indisponible pour le moment.",
      500,
    );
  }
});
