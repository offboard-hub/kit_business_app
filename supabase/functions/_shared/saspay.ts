// ============================================================================
//  SasPay — SEUL prestataire de paiement de l'application (YouCan Pay désactivé).
//  Documentation : https://docs.saspay.me — base https://api.saspay.me/api/v1
//  Montants : chaînes décimales ("9000.00"), jamais de flottants.
//  Devises : XOF (UEMOA) et XAF (CEMAC), c'est-à-dire 100 % FCFA.
// ============================================================================

const BASE = (Deno.env.get("SASPAY_BASE_URL") ?? "https://api.saspay.me/api/v1").replace(/\/+$/, "");

function cleApi(): string {
  const cle = Deno.env.get("SASPAY_API_KEY");
  if (!cle) throw new Error("SASPAY_API_KEY n'est pas configurée dans les secrets Supabase.");
  return cle;
}

interface ReponseSaspay {
  success?: boolean;
  code?: number;
  data?: Record<string, unknown>;
  error?: { message?: string; code?: string } | string;
  [key: string]: unknown;
}

async function appelSaspay(
  chemin: string,
  init: RequestInit = {},
): Promise<ReponseSaspay> {
  const reponse = await fetch(`${BASE}${chemin}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${cleApi()}`,
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(init.headers ?? {}),
    },
    signal: AbortSignal.timeout(30_000),
  });

  const brut = await reponse.text();
  let donnees: ReponseSaspay = {};
  try {
    donnees = brut ? (JSON.parse(brut) as ReponseSaspay) : {};
  } catch {
    donnees = { raw: brut };
  }

  if (!reponse.ok) {
    const messageErreur = typeof donnees.error === "string"
      ? donnees.error
      : donnees.error?.message ?? `Erreur SasPay (HTTP ${reponse.status})`;
    throw new Error(messageErreur);
  }

  return donnees;
}

/** Extrait l'objet utile de l'enveloppe { success, data, code }. */
function donneesUtiles(reponse: ReponseSaspay): Record<string, unknown> {
  return (reponse.data ?? reponse) as Record<string, unknown>;
}

export interface SessionCheckout {
  id: string;
  slug?: string;
  checkoutUrl: string;
  reference?: string;
  brut: Record<string, unknown>;
}

/**
 * Crée une session de paiement hébergée (mobile money + carte).
 * Le client est redirigé vers `checkout_url`.
 */
export async function creerSessionCheckout(params: {
  montantFcfa: number;
  devise: "XOF" | "XAF";
  description: string;
  email: string;
  nom: string;
  telephone: string;
  pays: string;
  returnUrl: string;
  metadata?: Record<string, unknown>;
}): Promise<SessionCheckout> {
  const corps = {
    amount: params.montantFcfa.toFixed(2),
    currency: params.devise,
    description: params.description,
    customer_email: params.email,
    customer_name: params.nom,
    customer_phone: params.telephone,
    country: params.pays,
    return_url: params.returnUrl,
    metadata: params.metadata ?? {},
  };

  const reponse = await appelSaspay("/checkout-sessions/", {
    method: "POST",
    body: JSON.stringify(corps),
  });

  const data = donneesUtiles(reponse);
  const id = String(data.id ?? data.session_id ?? "");
  const checkoutUrl = String(data.checkout_url ?? data.url ?? "");

  if (!id || !checkoutUrl) {
    throw new Error("SasPay n'a pas renvoyé de lien de paiement exploitable.");
  }

  return {
    id,
    slug: data.slug ? String(data.slug) : undefined,
    checkoutUrl,
    reference: data.reference ? String(data.reference) : undefined,
    brut: data,
  };
}

export interface StatutSession {
  statut: string;
  paymentId: string | null;
  montant: number | null;
  devise: string | null;
  brut: Record<string, unknown>;
}

/** Statut d'une session de checkout (utilisé au retour du client). */
export async function statutSession(sessionId: string): Promise<StatutSession> {
  const reponse = await appelSaspay(`/checkout-sessions/${encodeURIComponent(sessionId)}/status/`);
  const data = donneesUtiles(reponse);

  const paiement = (data.payment ?? data.transaction ?? {}) as Record<string, unknown>;
  const paymentId =
    (data.payment_id as string) ??
    (paiement.id as string) ??
    (data.transaction_id as string) ??
    null;

  return {
    statut: String(data.status ?? data.payment_status ?? "").toUpperCase(),
    paymentId: paymentId ? String(paymentId) : null,
    montant: nombreOuNull(data.amount ?? paiement.amount),
    devise: (data.currency as string) ?? (paiement.currency as string) ?? null,
    brut: data,
  };
}

export interface VerificationPaiement {
  statut: string;
  paye: boolean;
  montant: number | null;
  montantNet: number | null;
  devise: string | null;
  brut: Record<string, unknown>;
}

/**
 * Vérification officielle : seul un statut SUCCESS autorise la livraison.
 * GET /payments/{payment_id}/verify/
 */
export async function verifierPaiement(paymentId: string): Promise<VerificationPaiement> {
  const reponse = await appelSaspay(`/payments/${encodeURIComponent(paymentId)}/verify/`);
  const data = donneesUtiles(reponse);
  const statut = String(data.status ?? data.payment_status ?? "").toUpperCase();

  return {
    statut,
    paye: statut === "SUCCESS",
    montant: nombreOuNull(data.amount ?? data.charged),
    montantNet: nombreOuNull(data.net_amount),
    devise: (data.currency as string) ?? null,
    brut: data,
  };
}

function nombreOuNull(valeur: unknown): number | null {
  if (valeur === null || valeur === undefined) return null;
  const n = Number(valeur);
  return Number.isFinite(n) ? n : null;
}

/** Normalise un identifiant de session renvoyé dans l'URL de retour. */
export function sessionDepuisRequete(url: URL, corps?: Record<string, unknown>): string | null {
  return (
    url.searchParams.get("session_id") ??
    url.searchParams.get("checkout_session_id") ??
    url.searchParams.get("saspay_session") ??
    (corps?.session_id as string) ??
    (corps?.sessionId as string) ??
    null
  );
}

/** Normalise un identifiant de paiement renvoyé dans l'URL de retour. */
export function paiementDepuisRequete(url: URL, corps?: Record<string, unknown>): string | null {
  return (
    url.searchParams.get("payment_id") ??
    url.searchParams.get("transaction_id") ??
    (corps?.payment_id as string) ??
    (corps?.paymentId as string) ??
    null
  );
}

// ----------------------------------------------------------------------------
//  WEBHOOKS — signature HMAC SHA-256 sur le corps brut
// ----------------------------------------------------------------------------

function comparaisonConstante(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let i = 0; i < a.length; i++) {
    difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return difference === 0;
}

/**
 * Vérifie `X-Webhook-Signature` = HMAC_SHA256(secret, `${timestamp}.${corps brut}`)
 * et rejette un horodatage de plus de 300 secondes.
 */
export async function signatureWebhookValide(
  corpsBrut: string,
  signature: string | null,
  timestamp: string | null,
): Promise<boolean> {
  const secret = Deno.env.get("SASPAY_WEBHOOK_SECRET");
  if (!secret || !signature || !timestamp) return false;

  const horodatage = Number(timestamp);
  if (!Number.isFinite(horodatage)) return false;
  if (Math.abs(Date.now() / 1000 - horodatage) > 300) return false;

  const cle = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signatureCalculee = await crypto.subtle.sign(
    "HMAC",
    cle,
    new TextEncoder().encode(`${timestamp}.${corpsBrut}`),
  );
  const hex = Array.from(new Uint8Array(signatureCalculee))
    .map((octet) => octet.toString(16).padStart(2, "0"))
    .join("");

  return comparaisonConstante(hex, signature.toLowerCase());
}
