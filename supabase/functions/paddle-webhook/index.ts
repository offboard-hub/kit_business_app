// ============================================================================
//  paddle-webhook — confirmation fiable des paiements Paddle Billing.
//
//  Sécurité : en-tête `Paddle-Signature: ts=…;h1=…` = HMAC-SHA256(secret,
//  `${ts}:${corps brut}`), fenêtre de 300 s, comparaison à temps constant.
//
//  Événements traités :
//    • transaction.completed / transaction.paid → payé + livraison en fond
//    • transaction.payment_failed / transaction.canceled → ECHEC
//
//  Idempotent : une commande LIVRE ou un abonnement ACTIF n'est jamais relivré.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { signaturePaddleValide } from "../_shared/paddle.ts";
import { adminClient } from "../_shared/supabase.ts";
import { chargerCommande, livrerCommande, type Commande } from "../_shared/fulfillment.ts";
import {
  activerAbonnementStudio,
  chargerAbonnement,
  chargerAbonnementParTransaction,
  type StudioAbonnement,
} from "../_shared/studio.ts";
import { enArrierePlan } from "../_shared/background.ts";
import { OFFRES } from "../_shared/config.ts";

interface WebhookPaddle {
  event_id?: string;
  event_type?: string;
  notification_id?: string;
  data?: Record<string, unknown>;
}

const EVENEMENTS_PAYES = new Set(["transaction.completed", "transaction.paid"]);
const EVENEMENTS_ECHEC = new Set([
  "transaction.payment_failed",
  "transaction.canceled",
  "transaction.cancelled",
]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function montantDepuisTransaction(data: Record<string, unknown>): number | null {
  const details = (data.details ?? {}) as Record<string, unknown>;
  const totaux = (details.totals ?? {}) as Record<string, unknown>;
  const valeur = Number(totaux.total);
  return Number.isFinite(valeur) ? valeur / 100 : null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  const corpsBrut = await req.text();
  const signature = req.headers.get("Paddle-Signature") ?? req.headers.get("paddle-signature");

  if (!(await signaturePaddleValide(corpsBrut, signature))) {
    return erreur("Signature de webhook Paddle invalide.", 401);
  }

  let payload: WebhookPaddle;
  try {
    payload = JSON.parse(corpsBrut) as WebhookPaddle;
  } catch {
    return erreur("Corps JSON invalide.", 400);
  }

  const evenement = String(payload.event_type ?? "");
  const data = payload.data ?? {};

  const paye = EVENEMENTS_PAYES.has(evenement);
  const echec = EVENEMENTS_ECHEC.has(evenement);
  if (!paye && !echec) {
    return json({ received: true, ignored: evenement || "événement inconnu" });
  }

  try {
    const admin = adminClient();
    const transactionId = String(data.id ?? "");
    const montantPaddle = montantDepuisTransaction(data);
    const devisePaddle = data.currency_code
      ? String(data.currency_code).toUpperCase()
      : null;
    const customData = (data.custom_data ?? {}) as Record<string, unknown>;

    let commande: Commande | null = null;
    let abonnement: StudioAbonnement | null = null;

    const orderId = customData.order_id ? String(customData.order_id) : "";
    const subscriptionId = customData.subscription_id
      ? String(customData.subscription_id)
      : "";

    if (UUID.test(orderId)) commande = await chargerCommande(orderId);
    if (!commande && UUID.test(subscriptionId)) {
      abonnement = await chargerAbonnement(subscriptionId);
    }

    // Repli : retrouver la ligne par l'identifiant de transaction Paddle.
    if (!commande && !abonnement && transactionId) {
      const { data: ligne } = await admin
        .from("orders")
        .select("*")
        .eq("paddle_transaction_id", transactionId)
        .maybeSingle();
      commande = (ligne as Commande | null) ?? null;
      if (!commande) abonnement = await chargerAbonnementParTransaction(transactionId);
    }

    if (!commande && !abonnement) {
      console.warn("Webhook Paddle : aucune ligne métier trouvée.", {
        evenement,
        transactionId,
        customData,
      });
      return json({ received: true, ignored: "commande introuvable" });
    }

    // ------------------------------------------------------------------
    // 1. ÉCHEC DE PAIEMENT
    // ------------------------------------------------------------------
    if (echec) {
      if (commande && commande.statut === "EN_ATTENTE") {
        await admin.from("orders").update({ statut: "ECHEC" }).eq("id", commande.id);
      }
      if (abonnement && abonnement.status === "EN_ATTENTE") {
        await admin
          .from("studio_subscriptions")
          .update({ status: "ECHEC" })
          .eq("id", abonnement.id);
      }
      return json({ received: true, statut: "ECHEC", evenement });
    }

    // ------------------------------------------------------------------
    // 2. PAIEMENT CONFIRMÉ — KIT
    // ------------------------------------------------------------------
    if (commande) {
      if (commande.statut === "LIVRE") {
        return json({ received: true, ignored: "commande déjà livrée", order_id: commande.id });
      }

      const { data: passagePaye } = await admin
        .from("orders")
        .update({
          statut: "PAYE",
          paid_at: new Date().toISOString(),
          ...(transactionId ? { paddle_transaction_id: transactionId } : {}),
          ...(montantPaddle !== null ? { montant_local: montantPaddle } : {}),
          ...(devisePaddle ? { devise_locale: devisePaddle } : {}),
        })
        .eq("id", commande.id)
        .in("statut", ["EN_ATTENTE", "ECHEC"])
        .select("id")
        .maybeSingle();

      if (passagePaye) {
        await admin.from("transactions").insert({
          user_id: commande.user_id,
          provider: "paddle",
          transaction_token: transactionId || commande.paddle_transaction_id,
          product_id: OFFRES[commande.produit_type]?.productId ?? null,
          amount_paid: montantPaddle ?? commande.montant_local ?? commande.montant_fcfa,
          currency: devisePaddle ?? commande.devise_locale ?? commande.devise,
          status: "success",
        });
      }

      // Le client Paddle reçoit un 200 immédiat : la livraison continue en fond.
      enArrierePlan(livrerCommande(commande.id));

      return json(
        { received: true, kind: "kit", order_id: commande.id, statut: "EN_COURS" },
        202,
      );
    }

    // ------------------------------------------------------------------
    // 3. PAIEMENT CONFIRMÉ — STUDIO LIVE
    // ------------------------------------------------------------------
    if (abonnement) {
      if (abonnement.status === "ACTIF" || abonnement.status === "EXPIRE") {
        return json({
          received: true,
          ignored: "abonnement déjà activé",
          subscription_id: abonnement.id,
        });
      }

      await admin
        .from("studio_subscriptions")
        .update({
          ...(transactionId ? { paddle_transaction_id: transactionId } : {}),
          ...(montantPaddle !== null ? { montant_local: montantPaddle } : {}),
          ...(devisePaddle ? { devise: devisePaddle } : {}),
        })
        .eq("id", abonnement.id);

      enArrierePlan(activerAbonnementStudio(abonnement.id, { attendreGuide: false }));

      return json(
        {
          received: true,
          kind: "studio",
          subscription_id: abonnement.id,
          statut: "ACTIF",
        },
        202,
      );
    }

    return json({ received: true, ignored: "aucune action" });
  } catch (erreurInterne) {
    console.error("paddle-webhook :", erreurInterne);
    return erreur("Traitement du webhook Paddle impossible.", 500);
  }
});
