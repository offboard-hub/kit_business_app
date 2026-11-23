// ============================================================================
//  generate-live-guide — (Re)génération du Livre Guide Live d'un abonné Studio.
//
//  JWT Supabase obligatoire. Seul le propriétaire de l'abonnement (user_id ou
//  email du JWT) peut générer / récupérer son guide.
//  Idempotent : si le guide est déjà PRET, il est renvoyé sans régénération.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { utilisateurCourant } from "../_shared/supabase.ts";
import {
  abonnementAppartient,
  chargerAbonnement,
  chargerGuide,
  genererGuidePourAbonnement,
} from "../_shared/studio.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  try {
    const utilisateur = await utilisateurCourant(req);
    if (!utilisateur) {
      return erreur("Connectez-vous pour accéder à votre guide Studio Live.", 401);
    }

    const corps = (await req.json().catch(() => ({}))) as { subscription_id?: string };
    const subscriptionId = String(corps.subscription_id ?? "").trim();
    if (!UUID.test(subscriptionId)) {
      return erreur("Abonnement Studio Live invalide.", 400);
    }

    const abonnement = await chargerAbonnement(subscriptionId);
    if (!abonnement) return erreur("Abonnement Studio Live introuvable.", 404);

    if (!abonnementAppartient(abonnement, utilisateur)) {
      return erreur("Ce guide appartient à un autre compte.", 403);
    }

    if (abonnement.status === "EN_ATTENTE") {
      return erreur("Votre paiement n'est pas encore confirmé. Le guide sera disponible juste après.", 409);
    }
    if (abonnement.status === "ECHEC") {
      return erreur("Le paiement de cet abonnement a échoué. Relancez une commande.", 409);
    }
    if (abonnement.status === "EXPIRE") {
      return erreur("Cet abonnement est expiré. Renouvelez le Studio Live pour régénérer le guide.", 403);
    }

    const existant = await chargerGuide(subscriptionId);
    if (existant?.statut === "PRET" && existant.contenu_html.trim()) {
      return json({ success: true, guide: existant, deja_genere: true });
    }

    let guide;
    try {
      guide = await genererGuidePourAbonnement(subscriptionId);
    } catch (erreurGeneration) {
      const message = erreurGeneration instanceof Error
        ? erreurGeneration.message
        : "Génération du guide impossible.";
      console.error("generate-live-guide :", message);
      return json({ success: false, error: message, guide: null }, 502);
    }

    if (!guide) {
      return json(
        {
          success: false,
          error: "Le guide est en cours de génération. Réessayez dans quelques instants.",
          guide: null,
        },
        202,
      );
    }

    return json({ success: true, guide });
  } catch (erreurInterne) {
    console.error("generate-live-guide :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Génération du guide impossible.",
      500,
    );
  }
});
