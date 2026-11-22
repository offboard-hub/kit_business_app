// ============================================================================
//  tiktok-auth — Connexion TikTok OAuth 2.0 depuis /admin-videos.
//
//  Actions (POST JSON, réservées à l'administrateur) :
//    { action: "start" }                 → renvoie l'URL d'autorisation TikTok
//    { action: "callback", code, state } → échange le code et stocke les jetons
//    { action: "status" }                → état de la connexion (sans jetons)
//    { action: "disconnect" }            → supprime les jetons
//
//  Les jetons ne quittent jamais le serveur : ils sont écrits dans
//  public.tiktok_credentials (service_role uniquement).
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { adminClient, estAdminUtilisateur, utilisateurCourant } from "../_shared/supabase.ts";
import {
  echangerCodeTiktok,
  effacerIdentifiantsTiktok,
  enregistrerIdentifiantsTiktok,
  lireIdentifiantsTiktok,
  redirectUriTiktok,
  scopesTiktok,
  urlAutorisationTiktok,
  type IdentifiantsTiktok,
} from "../_shared/tiktok.ts";

const VALIDITE_ETAT_MS = 15 * 60 * 1000;

function resumeTiktok(identifiants: IdentifiantsTiktok | null) {
  return {
    connected: !!identifiants?.accessToken,
    open_id: identifiants?.openId ?? null,
    scope: identifiants?.scope ?? null,
    expires_at: identifiants?.expiresAt ?? null,
    refresh_expires_at: identifiants?.refreshExpiresAt ?? null,
    connected_at: identifiants?.connectedAt ?? null,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  try {
    const utilisateur = await utilisateurCourant(req);
    if (!utilisateur) {
      return erreur(
        "Connectez-vous avec le compte administrateur, puis relancez la connexion TikTok.",
        401,
      );
    }

    if (!(await estAdminUtilisateur(utilisateur))) {
      return erreur("Accès réservé à l'administrateur.", 403);
    }

    const corps = (await req.json().catch(() => ({}))) as {
      action?: string;
      code?: string;
      state?: string;
    };
    const action = String(corps.action ?? "status");
    const admin = adminClient();

    // ------------------------------------------------------------------
    //  DÉMARRAGE : on génère un state, on le stocke, on renvoie l'URL
    // ------------------------------------------------------------------
    if (action === "start") {
      // Nettoyage des états périmés (1 heure).
      await admin
        .from("tiktok_oauth_states")
        .delete()
        .lt("created_at", new Date(Date.now() - 60 * 60 * 1000).toISOString());

      const state = `${crypto.randomUUID().replace(/-/g, "")}${crypto.randomUUID().replace(/-/g, "")}`;

      const { error } = await admin
        .from("tiktok_oauth_states")
        .insert({ state, user_id: utilisateur.id });

      if (error) {
        throw new Error(`Préparation de la connexion TikTok impossible : ${error.message}`);
      }

      return json({
        success: true,
        auth_url: urlAutorisationTiktok(state),
        state,
        redirect_uri: redirectUriTiktok(),
        scopes: scopesTiktok(),
      });
    }

    // ------------------------------------------------------------------
    //  RETOUR DE TIKTOK : échange du code contre les jetons
    // ------------------------------------------------------------------
    if (action === "callback") {
      const code = String(corps.code ?? "").trim();
      const state = String(corps.state ?? "").trim();

      if (!code) return erreur("Code d'autorisation TikTok manquant.", 400);
      if (!state) return erreur("Paramètre state manquant : relancez la connexion depuis /admin-videos.", 400);

      const { data: etat } = await admin
        .from("tiktok_oauth_states")
        .select("state, user_id, created_at")
        .eq("state", state)
        .maybeSingle();

      if (!etat) {
        // Lien déjà consommé (rafraîchissement de la page) : on répond succès
        // si une connexion vient d'aboutir, pour éviter une erreur trompeuse.
        const identifiants = await lireIdentifiantsTiktok();
        const connecteRecemment =
          identifiants?.accessToken &&
          identifiants.connectedAt &&
          Date.now() - new Date(identifiants.connectedAt).getTime() < VALIDITE_ETAT_MS;

        if (connecteRecemment) {
          return json({
            success: true,
            already_connected: true,
            ...resumeTiktok(identifiants),
          });
        }

        return erreur(
          "Lien de connexion expiré ou déjà utilisé. Relancez « Connecter TikTok » depuis /admin-videos.",
          410,
        );
      }

      if (String(etat.user_id) !== utilisateur.id) {
        return erreur(
          "Cette connexion a été initiée par un autre administrateur. Relancez-la depuis votre session.",
          403,
        );
      }

      const age = Date.now() - new Date(String(etat.created_at)).getTime();
      if (age > VALIDITE_ETAT_MS) {
        await admin.from("tiktok_oauth_states").delete().eq("state", state);
        return erreur("Lien de connexion expiré (15 minutes). Relancez « Connecter TikTok ».", 410);
      }

      // Usage unique.
      await admin.from("tiktok_oauth_states").delete().eq("state", state);

      const jetons = await echangerCodeTiktok(code, redirectUriTiktok());
      const identifiants = await enregistrerIdentifiantsTiktok({
        jetons,
        connectedBy: utilisateur.id,
      });

      return json({
        success: true,
        ...resumeTiktok(identifiants),
      });
    }

    // ------------------------------------------------------------------
    //  ÉTAT DE LA CONNEXION (sans jamais renvoyer les jetons)
    // ------------------------------------------------------------------
    if (action === "status") {
      const identifiants = await lireIdentifiantsTiktok();
      return json({
        success: true,
        ...resumeTiktok(identifiants),
        redirect_uri: redirectUriTiktok(),
        scopes: scopesTiktok(),
      });
    }

    // ------------------------------------------------------------------
    //  DÉCONNEXION
    // ------------------------------------------------------------------
    if (action === "disconnect") {
      await effacerIdentifiantsTiktok();
      return json({ success: true, connected: false });
    }

    return erreur(`Action inconnue : ${action}`, 400);
  } catch (erreurInterne) {
    console.error("tiktok-auth :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Connexion TikTok impossible.",
      502,
    );
  }
});
