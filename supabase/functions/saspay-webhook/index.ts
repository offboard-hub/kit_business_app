// ============================================================================
//  saspay-webhook — confirmation fiable du paiement (signature HMAC vérifiée).
//  Sécurité : X-Webhook-Signature + X-Webhook-Timestamp (fenêtre de 300 s).
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { signatureWebhookValide } from "../_shared/saspay.ts";
import { adminClient } from "../_shared/supabase.ts";
import { chargerCommandeParSession, livrerCommande, type Commande } from "../_shared/fulfillment.ts";
import { enArrierePlan } from "../_shared/background.ts";
import { OFFRES } from "../_shared/config.ts";

interface WebhookSaspay {
  event?: string;
  data?: Record<string, unknown>;
}

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

    let commande: Commande | null = null;

    const orderId = (metadata.order_id ?? data.order_id) as string | undefined;
    if (orderId) {
      const { data: ligne } = await admin.from("orders").select("*").eq("id", orderId).maybeSingle();
      commande = (ligne as Commande | null) ?? null;
    }

    if (!commande) {
      const sessionId = (data.checkout_session_id ?? data.session_id ?? data.session) as string | undefined;
      if (sessionId) commande = await chargerCommandeParSession(sessionId);
    }

    if (!commande) {
      console.warn("Webhook SasPay : commande introuvable.", { evenement, data });
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
        amount_paid: commande.montant_fcfa,
        currency: commande.devise,
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
