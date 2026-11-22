// ============================================================================
//  TikTok OAuth 2.0 — échange du code, rafraîchissement et stockage des jetons.
//  Les jetons vivent uniquement dans public.tiktok_credentials (service_role).
//  Le client ne reçoit jamais l'access_token ni le refresh_token.
// ============================================================================

import { SITE_URL } from "./config.ts";
import { adminClient } from "./supabase.ts";

const URL_JETON = "https://open.tiktokapis.com/v2/oauth/token/";
const URL_AUTORISATION = "https://www.tiktok.com/v2/auth/authorize/";

export interface JetonTiktok {
  access_token: string;
  expires_in?: number;
  refresh_token?: string;
  refresh_expires_in?: number;
  open_id?: string;
  scope?: string;
  token_type?: string;
}

export interface IdentifiantsTiktok {
  accessToken: string | null;
  refreshToken: string | null;
  openId: string | null;
  scope: string | null;
  expiresAt: string | null;
  refreshExpiresAt: string | null;
  connectedAt: string | null;
  connectedBy: string | null;
}

// ----------------------------------------------------------------------------
//  CONFIGURATION
// ----------------------------------------------------------------------------

export function cleClientTiktok(): string {
  const cle = Deno.env.get("TIKTOK_CLIENT_KEY");
  if (!cle) throw new Error("TIKTOK_CLIENT_KEY n'est pas configurée dans les secrets Supabase.");
  return cle;
}

function secretClientTiktok(): string {
  const secret = Deno.env.get("TIKTOK_CLIENT_SECRET");
  if (!secret) throw new Error("TIKTOK_CLIENT_SECRET n'est pas configurée dans les secrets Supabase.");
  return secret;
}

/** Portées demandées (Content Posting API : envoi en brouillon via video.upload). */
export function scopesTiktok(): string {
  return Deno.env.get("TIKTOK_SCOPES") ?? "video.upload";
}

/**
 * URL de retour enregistrée dans l'application TikTok.
 * Par défaut la racine du site : TikTok y ajoute ?code=...&state=...
 */
export function redirectUriTiktok(): string {
  const explicite = (Deno.env.get("TIKTOK_REDIRECT_URI") ?? "").trim();
  if (explicite) return explicite;
  return `${SITE_URL}/`;
}

/** Construit l'URL d'autorisation TikTok (le state est généré par l'appelant). */
export function urlAutorisationTiktok(state: string): string {
  const url = new URL(URL_AUTORISATION);
  url.searchParams.set("client_key", cleClientTiktok());
  url.searchParams.set("scope", scopesTiktok());
  url.searchParams.set("response_type", "code");
  url.searchParams.set("redirect_uri", redirectUriTiktok());
  url.searchParams.set("state", state);
  return url.toString();
}

// ----------------------------------------------------------------------------
//  APPELS TIKTOK
// ----------------------------------------------------------------------------

function messageErreur(donnees: Record<string, unknown>, statut: number): string {
  const erreur = donnees?.error;
  if (typeof erreur === "string" && erreur.trim()) {
    const description = donnees?.error_description;
    return description ? `${erreur} — ${description}` : erreur;
  }
  if (erreur && typeof erreur === "object") {
    const objet = erreur as Record<string, unknown>;
    return String(objet.description ?? objet.message ?? objet.code ?? `Erreur TikTok (${statut})`);
  }
  const description = donnees?.error_description;
  return description ? String(description) : `TikTok a renvoyé HTTP ${statut}`;
}

async function posterJeton(corps: URLSearchParams): Promise<JetonTiktok> {
  const reponse = await fetch(URL_JETON, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: corps,
    signal: AbortSignal.timeout(30_000),
  });

  const brut = await reponse.text();
  let donnees: Record<string, unknown> = {};
  try {
    donnees = brut ? (JSON.parse(brut) as Record<string, unknown>) : {};
  } catch {
    donnees = {};
  }

  // Certaines réponses sont enveloppées dans { data: {...} }.
  const utile = (donnees.data && typeof donnees.data === "object"
    ? donnees.data
    : donnees) as Record<string, unknown>;

  const accessToken = utile?.access_token;
  if (!reponse.ok || !accessToken) {
    throw new Error(messageErreur(donnees, reponse.status));
  }

  return {
    access_token: String(accessToken),
    expires_in: Number(utile.expires_in ?? 0) || undefined,
    refresh_token: utile.refresh_token ? String(utile.refresh_token) : undefined,
    refresh_expires_in: Number(utile.refresh_expires_in ?? 0) || undefined,
    open_id: utile.open_id ? String(utile.open_id) : undefined,
    scope: utile.scope ? String(utile.scope) : undefined,
    token_type: utile.token_type ? String(utile.token_type) : undefined,
  };
}

/** Échange le code d'autorisation contre un access_token. */
export async function echangerCodeTiktok(code: string, redirectUri: string): Promise<JetonTiktok> {
  return await posterJeton(
    new URLSearchParams({
      client_key: cleClientTiktok(),
      client_secret: secretClientTiktok(),
      code,
      grant_type: "authorization_code",
      redirect_uri: redirectUri,
    }),
  );
}

/** Rafraîchit un access_token expiré (le refresh token peut être renouvelé). */
export async function rafraichirJetonTiktok(refreshToken: string): Promise<JetonTiktok> {
  return await posterJeton(
    new URLSearchParams({
      client_key: cleClientTiktok(),
      client_secret: secretClientTiktok(),
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    }),
  );
}

// ----------------------------------------------------------------------------
//  STOCKAGE (service_role uniquement)
// ----------------------------------------------------------------------------

function isoDepuisMaintenant(secondes: number | undefined): string | null {
  if (!secondes || !Number.isFinite(secondes) || secondes <= 0) return null;
  return new Date(Date.now() + secondes * 1000).toISOString();
}

export async function lireIdentifiantsTiktok(): Promise<IdentifiantsTiktok | null> {
  try {
    const admin = adminClient();
    const { data, error } = await admin
      .from("tiktok_credentials")
      .select("*")
      .eq("id", "default")
      .maybeSingle();

    if (error || !data) return null;

    return {
      accessToken: data.access_token ? String(data.access_token) : null,
      refreshToken: data.refresh_token ? String(data.refresh_token) : null,
      openId: data.open_id ? String(data.open_id) : null,
      scope: data.scope ? String(data.scope) : null,
      expiresAt: data.expires_at ? String(data.expires_at) : null,
      refreshExpiresAt: data.refresh_expires_at ? String(data.refresh_expires_at) : null,
      connectedAt: data.connected_at ? String(data.connected_at) : null,
      connectedBy: data.connected_by ? String(data.connected_by) : null,
    };
  } catch (erreur) {
    console.error("Lecture des identifiants TikTok impossible :", erreur);
    return null;
  }
}

export async function enregistrerIdentifiantsTiktok(params: {
  jetons: JetonTiktok;
  connectedBy?: string | null;
  openId?: string | null;
}): Promise<IdentifiantsTiktok | null> {
  const admin = adminClient();
  const existants = await lireIdentifiantsTiktok();

  const { error } = await admin.from("tiktok_credentials").upsert(
    {
      id: "default",
      access_token: params.jetons.access_token,
      refresh_token: params.jetons.refresh_token ?? existants?.refreshToken ?? null,
      open_id: params.jetons.open_id ?? params.openId ?? existants?.openId ?? null,
      scope: params.jetons.scope ?? existants?.scope ?? scopesTiktok(),
      expires_at: isoDepuisMaintenant(params.jetons.expires_in) ?? existants?.expiresAt ?? null,
      refresh_expires_at:
        isoDepuisMaintenant(params.jetons.refresh_expires_in) ?? existants?.refreshExpiresAt ?? null,
      connected_by: params.connectedBy ?? existants?.connectedBy ?? null,
      connected_at: new Date().toISOString(),
    },
    { onConflict: "id" },
  );

  if (error) {
    throw new Error(`Enregistrement des jetons TikTok impossible : ${error.message}`);
  }

  return await lireIdentifiantsTiktok();
}

/** Supprime les jetons (déconnexion depuis /admin-videos). */
export async function effacerIdentifiantsTiktok(): Promise<void> {
  const admin = adminClient();
  const { error } = await admin
    .from("tiktok_credentials")
    .update({
      access_token: null,
      refresh_token: null,
      open_id: null,
      scope: null,
      expires_at: null,
      refresh_expires_at: null,
      connected_at: null,
      connected_by: null,
    })
    .eq("id", "default");

  if (error) throw new Error(`Déconnexion TikTok impossible : ${error.message}`);
}

// ----------------------------------------------------------------------------
//  JETON VALIDE POUR LA PUBLICATION
// ----------------------------------------------------------------------------

/**
 * Renvoie un access_token utilisable :
 *   1. TIKTOK_ACCESS_TOKEN (test manuel) ;
 *   2. jeton stocké en base, rafraîchi automatiquement s'il expire ;
 *   3. TIKTOK_REFRESH_TOKEN (ancienne configuration, optionnelle).
 */
export async function jetonTiktokValide(): Promise<string> {
  const direct = Deno.env.get("TIKTOK_ACCESS_TOKEN");
  if (direct) return direct;

  const identifiants = await lireIdentifiantsTiktok();
  const maintenant = Date.now();

  const expiration = identifiants?.expiresAt ? new Date(identifiants.expiresAt).getTime() : 0;
  if (identifiants?.accessToken && expiration > maintenant + 60_000) {
    return identifiants.accessToken;
  }

  if (identifiants?.refreshToken) {
    try {
      const jetons = await rafraichirJetonTiktok(identifiants.refreshToken);
      await enregistrerIdentifiantsTiktok({ jetons, connectedBy: identifiants.connectedBy });
      return jetons.access_token;
    } catch (erreur) {
      console.error("Rafraîchissement TikTok impossible :", erreur);
    }
  }

  const refreshEnv = Deno.env.get("TIKTOK_REFRESH_TOKEN");
  if (refreshEnv) {
    const jetons = await rafraichirJetonTiktok(refreshEnv);
    try {
      await enregistrerIdentifiantsTiktok({
        jetons,
        openId: null,
      });
    } catch (_) {
      // La base n'est pas indispensable ici : le jeton reste utilisable.
    }
    return jetons.access_token;
  }

  throw new Error(
    "TikTok n'est pas connecté. Ouvrez /admin-videos et cliquez sur « Connecter TikTok ».",
  );
}
