// ============================================================================
//  saspay-webhook — confirmation fiable du paiement (signature HMAC vérifiée).
//  Sécurité : X-Webhook-Signature + X-Webhook-Timestamp (fenêtre de 300 s).
//
//  Traite les kits (`orders`) ET les abonnements Studio Live
//  (`studio_subscriptions`) : SasPay renvoie l'objet ciblé dans `metadata`.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { signatureWebhookValide } from "../_shared/saspay.ts";
import { adminClient } from "../_shared/supabase.ts";
import { chargerCommandeParSession, livrerCommande, type Commande } from "../_shared/fulfillment.ts";
import { enArrierePlan } from "../_shared/background.ts";
import { OFFRES } from "../_shared/config.ts";
import {
  activerAbonnementStudio,
  chargerAbonnement,
  chargerAbonnementParSession,
  type StudioAbonnement,
} from "../_shared/studio.ts";

interface WebhookSaspay {
  event?: string;
  data?: Record<string, unknown>;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  const corpsBrut = await req.text();
  const signature = req.headers.get("X-Webhook-Signature") ?? req.headers.get("x-webhook-signature");
  const timestamp = req.headers.get("X-Webhook-Timestamp") ?? req.headers.get("x-webhook-timestamp");

  if (!(await signatureWebhookValide(corpsBrut, signature, timestamp))) {
    return erreur("Signature de webhook invalide.", 401);
  }

  let payload: WebhookSaspay;
  try {
    payload = JSON.parse(corpsBrut) as WebhookSaspay;
  } catch {
    return erreur("Corps JSON invalide.", 400);
  }

  const evenement = payload.event ?? req.headers.get("X-Webhook-Event") ?? "";
  if (!evenement.startsWith("transaction.")) {
    return json({ received: true, ignored: evenement || "événement inconnu" });
  }

  try {
    const admin = adminClient();
    const data = payload.data ?? {};
    const metadata = (data.metadata ?? {}) as Record<string, unknown>;
    const sessionBrute = data.checkout_session_id ?? data.session_id ?? data.session;
    const sessionId = typeof sessionBrute === "string" ? sessionBrute : undefined;

    // ------------------------------------------------------------------
    // 1. STUDIO LIVE (abonnement)
    // ------------------------------------------------------------------
    const subscriptionIdBrut = metadata.subscription_id ?? data.subscription_id;
    const subscriptionId = typeof subscriptionIdBrut === "string" ? subscriptionIdBrut : undefined;
    let abonnement: StudioAbonnement | null = null;

    if (subscriptionId && UUID.test(subscriptionId)) {
      abonnement = await chargerAbonnement(subscriptionId);
    }
    if (!abonnement && sessionId) abonnement = await chargerAbonnementParSession(sessionId);

    if (abonnement) {
      if (evenement === "transaction.failed" || evenement === "transaction.cancelled") {
        if (abonnement.status === "EN_ATTENTE") {
          await admin
            .from("studio_subscriptions")
            .update({ status: "ECHEC" })
            .eq("id", abonnement.id);
        }
        return json({ received: true, statut: "ECHEC", subscription_id: abonnement.id });
      }

      if (evenement !== "transaction.success") {
        return json({ received: true, ignored: evenement, subscription_id: abonnement.id });
      }

      if (abonnement.status === "ACTIF" || abonnement.status === "EXPIRE") {
        return json({
          received: true,
          ignored: "abonnement déjà activé",
          subscription_id: abonnement.id,
        });
      }

      const paymentId = (data.payment_id ?? data.id ?? data.transaction_id) as string | undefined;
      if (paymentId) {
        await admin
          .from("studio_subscriptions")
          .update({ saspay_payment_id: paymentId })
          .eq("id", abonnement.id);
      }

      // Le client reçoit sa réponse 2xx tout de suite : l'activation et la
      // génération du guide (30-90 s) continuent en tâche de fond.
      enArrierePlan(activerAbonnementStudio(abonnement.id, { attendreGuide: false }));

      return json(
        { received: true, subscription_id: abonnement.id, statut: "ACTIF" },
        202,
      );
    }

    // ------------------------------------------------------------------
    // 2. KITS (commandes)
    // ------------------------------------------------------------------
    let commande: Commande | null = null;

    const orderIdBrut = metadata.order_id ?? data.order_id;
    const orderId = typeof orderIdBrut === "string" && UUID.test(orderIdBrut) ? orderIdBrut : undefined;
    if (orderId) {
      const { data: ligne } = await admin.from("orders").select("*").eq("id", orderId).maybeSingle();
      commande = (ligne as Commande | null) ?? null;
    }

    if (!commande && sessionId) commande = await chargerCommandeParSession(sessionId);

    if (!commande) {
      console.warn("Webhook SasPay : commande ou abonnement introuvable.", { evenement, data });
      return json({ received: true, ignored: "commande introuvable" });
    }

    if (evenement === "transaction.failed" || evenement === "transaction.cancelled") {
      if (commande.statut === "EN_ATTENTE") {
        await admin.from("orders").update({ statut: "ECHEC" }).eq("id", commande.id);
      }
      return json({ received: true, statut: "ECHEC", order_id: commande.id });
    }

    if (evenement !== "transaction.success") {
      return json({ received: true, ignored: evenement });
    }

    const paymentId = (data.payment_id ?? data.id ?? data.transaction_id) as string | undefined;

    const { data: passagePaye } = await admin
      .from("orders")
      .update({
        statut: "PAYE",
        paid_at: new Date().toISOString(),
        saspay_payment_id: paymentId ?? commande.saspay_payment_id,
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
        amount_paid: commande.montant_local ?? commande.montant_fcfa,
        currency: commande.devise_locale ?? commande.devise,
        status: "success",
      });
    }

    // Le client reçoit sa réponse 2xx tout de suite : la génération (30-90 s)
    // continue en tâche de fond.
    enArrierePlan(livrerCommande(commande.id));

    return json({ received: true, order_id: commande.id, statut: "EN_COURS" }, 202);
  } catch (erreurInterne) {
    console.error("saspay-webhook :", erreurInterne);
    return erreur("Traitement du webhook impossible.", 500);
  }
});
