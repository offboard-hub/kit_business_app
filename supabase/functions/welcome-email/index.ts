// ============================================================================
//  welcome-email — Email d'accueil informatif via Resend.
//  AUCUN lien de confirmation : le compte est déjà actif. Simple information.
//  Anti-spam : un seul email par adresse toutes les 24 heures.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { emailBienvenueHtml, envoyerEmail } from "../_shared/delivery.ts";
import { adminClient } from "../_shared/supabase.ts";

const FENETRE_MS = 24 * 60 * 60 * 1000;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  try {
    const corps = (await req.json().catch(() => ({}))) as {
      email?: string;
      prenom?: string;
      source?: string;
    };

    const email = String(corps.email ?? "").trim().toLowerCase().slice(0, 160);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      return erreur("Adresse email invalide.");
    }

    const prenom = String(corps.prenom ?? "").trim().slice(0, 60);
    const source = String(corps.source ?? "site").trim().slice(0, 40);
    const admin = adminClient();

    // Anti-doublon : 1 email d'accueil par adresse et par 24 h.
    const { data: existant } = await admin
      .from("welcome_emails")
      .select("email, envois, last_sent_at")
      .eq("email", email)
      .maybeSingle();

    if (existant?.last_sent_at) {
      const ecoule = Date.now() - new Date(String(existant.last_sent_at)).getTime();
      if (ecoule < FENETRE_MS) {
        return json({ success: true, sent: false, already_sent: true });
      }
    }

    const envoi = await envoyerEmail({
      to: email,
      subject: "Bienvenue chez Kit Business — votre kit business en FCFA",
      html: emailBienvenueHtml({ email, prenom }),
    });

    if (!envoi.ok) {
      return json({ success: false, sent: false, error: envoi.error }, 502);
    }

    if (existant) {
      await admin
        .from("welcome_emails")
        .update({ envois: Number(existant.envois ?? 0) + 1, last_sent_at: new Date().toISOString(), source })
        .eq("email", email);
    } else {
      await admin.from("welcome_emails").insert({ email, source });
    }

    // Trace côté profil si un compte existe déjà avec cet email.
    await admin
      .from("profiles")
      .update({ welcome_email_sent_at: new Date().toISOString() })
      .eq("email", email);

    return json({ success: true, sent: true });
  } catch (erreurInterne) {
    console.error("welcome-email :", erreurInterne);
    return erreur("Envoi de l'email d'accueil impossible.", 500);
  }
});
