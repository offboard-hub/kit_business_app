// ============================================================================
//  auth-signup — création de compte confirmé côté serveur.
//
//  Supabase Auth envoie sinon un email de confirmation via son SMTP, qui peut
//  échouer (500 « Error sending confirmation email »). Ici, le compte est créé
//  avec email_confirm = true ; l'email d'accueil / d'activation est envoyé
//  séparément via Resend (welcome-email), puis le client se connecte.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { adminClient } from "../_shared/supabase.ts";

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  try {
    const corps = (await req.json().catch(() => ({}))) as {
      email?: string;
      password?: string;
      nom?: string;
    };
    const email = String(corps.email ?? "").trim().toLowerCase().slice(0, 160);
    const password = String(corps.password ?? "");
    const nom = String(corps.nom ?? "").trim().slice(0, 80);

    if (!EMAIL.test(email)) return erreur("Adresse email invalide.", 400);
    if (password.length < 6) {
      return erreur("Le mot de passe doit contenir au moins 6 caractères.", 400);
    }
    if (nom.length < 2) return erreur("Le nom est obligatoire (2 caractères minimum).", 400);

    const admin = adminClient();
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: nom },
      app_metadata: { provider: "email", providers: ["email"] },
    });

    if (error) {
      const message = error.message.toLowerCase();
      const existe = message.includes("already") || message.includes("registered");
      return json(
        {
          success: false,
          code: existe ? "compte_existant" : "creation_impossible",
          error: existe
            ? "Un compte existe déjà avec cet email. Connectez-vous."
            : "Création du compte impossible. Réessayez dans un instant.",
        },
        existe ? 409 : 500,
      );
    }

    return json({ success: true, user_id: data.user?.id ?? null });
  } catch (erreurInterne) {
    console.error("auth-signup :", erreurInterne);
    return erreur("Création du compte impossible.", 500);
  }
});
