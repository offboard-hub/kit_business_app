// ============================================================================
//  verify-payment — VÉRIFICATION SASPAY + LIVRAISON AUTOMATIQUE DU KIT
//  Appelée par l'application après le retour du client depuis SasPay.
//  Seul un statut SUCCESS (GET /payments/{id}/verify/) autorise la livraison.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { OFFRES } from "../_shared/config.ts";
import {
  paiementDepuisRequete,
  sessionDepuisRequete,
  statutSession,
  verifierPaiement,
} from "../_shared/saspay.ts";
import { adminClient } from "../_shared/supabase.ts";
import {
  chargerCommande,
  chargerCommandeParSession,
  livrerCommande,
  type Commande,
} from "../_shared/fulfillment.ts";

const STATUTS_PAYES = new Set(["SUCCESS", "PAID", "PAYE", "COMPLETED", "SUCCEEDED"]);

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST" && req.method !== "GET") return erreur("Méthode non autorisée.", 405);

  try {
    const url = new URL(req.url);
    let corps: Record<string, unknown> = {};

    if (req.method === "POST") {
      try {
        corps = (await req.json()) as Record<string, unknown>;
      } catch {
        corps = {};
      }
    }

    const orderId = (corps.order_id ?? corps.orderId ?? url.searchParams.get("order_id")) as string | null;
    const sessionId = sessionDepuisRequete(url, corps);
    const paymentIdParam = paiementDepuisRequete(url, corps);

    const admin = adminClient();

    // ------------------------------------------------------------------
    // 1. RETROUVER LA COMMANDE
    // ------------------------------------------------------------------
    let commande: Commande | null = null;

    if (orderId) {
      commande = await chargerCommande(String(orderId));
    } else if (sessionId) {
      commande = await chargerCommandeParSession(sessionId);
    } else if (paymentIdParam) {
      const { data } = await admin
        .from("orders")
        .select("*")
        .eq("saspay_payment_id", String(paymentIdParam))
        .maybeSingle();
      commande = (data as Commande | null) ?? null;
    }

    if (!commande) {
      return erreur("Commande introuvable. Vérifiez votre lien de paiement.", 404);
    }

    // ------------------------------------------------------------------
    // 2. DÉJÀ LIVRÉE : ON RENVOIE LES LIENS (page de confirmation rechargée)
    // ------------------------------------------------------------------
    if (commande.statut === "LIVRE" && commande.kit_id) {
      const resultat = await livrerCommande(commande.id);
      return json({ success: true, paid: true, ...resultat });
    }

    // ------------------------------------------------------------------
    // 3. VÉRIFICATION AUPRÈS DE SASPAY
    // ------------------------------------------------------------------
    let paymentId = paymentIdParam ?? commande.saspay_payment_id ?? null;
    let statutSaspay = "";
    let montantVerifie: number | null = null;
    let source = "payment_verify";

    if (!paymentId && commande.saspay_session_id) {
      const session = await statutSession(commande.saspay_session_id);
      paymentId = session.paymentId;
      statutSaspay = session.statut;
      montantVerifie = session.montant;
      source = "session_status";
    }

    let paye = false;

    if (paymentId) {
      const verification = await verifierPaiement(paymentId);
      statutSaspay = verification.statut;
      montantVerifie = verification.montant;
      paye = verification.paye;
      source = "payment_verify";
    } else {
      // Repli : certains réseaux ne renvoient pas d'identifiant de paiement
      // avant la confirmation finale. Le webhook reste la source fiable.
      paye = STATUTS_PAYES.has(statutSaspay);
      source = "session_status";
    }

    if (!paye) {
      return json({
        success: true,
        paid: false,
        order_id: commande.id,
        statut: commande.statut,
        saspay_status: statutSaspay || "EN_ATTENTE",
        source,
        message: "Paiement en attente de confirmation. Validez la demande sur votre téléphone.",
      });
    }

    // Contrôle du montant : jamais de livraison sous-payée.
    if (montantVerifie !== null && montantVerifie + 1 < commande.montant_fcfa) {
      return erreur(
        `Montant reçu insuffisant (${montantVerifie} ${commande.devise} pour ${commande.montant_fcfa} FCFA attendus). Contactez le support.`,
        402,
      );
    }

    // ------------------------------------------------------------------
    // 4. MARQUER PAYÉE (une seule fois) + JOURNALISER LA TRANSACTION
    // ------------------------------------------------------------------
    const { data: passagePaye } = await admin
      .from("orders")
      .update({
        statut: "PAYE",
        paid_at: new Date().toISOString(),
        saspay_payment_id: paymentId,
      })
      .eq("id", commande.id)
      .in("statut", ["EN_ATTENTE", "ECHEC"])
      .select("id")
      .maybeSingle();

    if (passagePaye) {
      await admin.from("transactions").insert({
        user_id: commande.user_id,
        provider: "saspay",
        transaction_token: paymentId ?? commande.saspay_session_id,
        product_id: OFFRES[commande.produit_type]?.productId ?? null,
        amount_paid: commande.montant_fcfa,
        currency: commande.devise,
        status: "success",
      });
    }

    // ------------------------------------------------------------------
    // 5. GÉNÉRATION + LIVRAISON PAR EMAIL (Resend)
    // ------------------------------------------------------------------
    try {
      const resultat = await livrerCommande(commande.id);
      return json({ success: true, paid: true, source, ...resultat });
    } catch (erreurLivraison) {
      const message = erreurLivraison instanceof Error ? erreurLivraison.message : String(erreurLivraison);
      return json(
        {
          success: false,
          paid: true,
          order_id: commande.id,
          error: `Paiement confirmé, mais la génération a échoué : ${message}`,
          retry: true,
        },
        502,
      );
    }
  } catch (erreurInterne) {
    console.error("verify-payment :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Vérification du paiement impossible.",
      500,
    );
  }
});
