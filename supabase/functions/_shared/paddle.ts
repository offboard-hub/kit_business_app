// ============================================================================
//  PADDLE BILLING — client API + vérification des webhooks.
//  Documentation : https://developer.paddle.com
//  Base : https://api.paddle.com (production) ou
//         https://sandbox-api.paddle.com (sandbox), selon PADDLE_ENVIRONMENT.
//
//  ⚠️ Aucun montant n'est envoyé par le client : le prix est porté par les
//  price_id configurés dans Paddle (PADDLE_PRICE_*), et le montant affiché est
//  recalculé par pricing.ts (source de vérité = XOF / USD).
// ============================================================================

import type { TypeProduit } from "./pricing.ts";
import { estTypeProduit } from "./pricing.ts";

export type EnvironnementPaddle = "sandbox" | "production";

/** Environnement Paddle actif (sandbox par défaut en développement). */
export function environnementPaddle(): EnvironnementPaddle {
  const brut = (Deno.env.get("PADDLE_ENVIRONMENT") ?? "production").trim().toLowerCase();
  return brut === "sandbox" ? "sandbox" : "production";
}

/** URL de base de l'API Paddle selon l'environnement. */
export function baseUrlPaddle(): string {
  return environnementPaddle() === "sandbox"
    ? "https://sandbox-api.paddle.com"
    : "https://api.paddle.com";
}

function cleApiPaddle(): string {
  const cle = Deno.env.get("PADDLE_API_KEY");
  if (!cle) {
    throw new Error("PADDLE_API_KEY n'est pas configurée dans les secrets Supabase.");
  }
  return cle;
}

/** Jeton public utilisé par Paddle.js pour ouvrir le checkout. */
export function clientTokenPaddle(): string {
  return (Deno.env.get("PADDLE_CLIENT_TOKEN") ?? "").trim();
}

interface ReponsePaddle {
  data?: Record<string, unknown>;
  error?: {
    code?: string;
    detail?: string;
    documentation_url?: string;
    errors?: Array<{ field?: string; message?: string }>;
  };
  meta?: Record<string, unknown>;
}

/** Appel générique à l'API Paddle (JSON, timeout 30 s, erreurs lisibles). */
async function appelPaddle<T = Record<string, unknown>>(
  chemin: string,
  init: RequestInit = {},
): Promise<T> {
  let reponse: Response;
  try {
    reponse = await fetch(`${baseUrlPaddle()}${chemin}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${cleApiPaddle()}`,
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(init.headers ?? {}),
      },
      signal: AbortSignal.timeout(30_000),
    });
  } catch (erreur) {
    const message = erreur instanceof Error ? erreur.message : String(erreur);
    throw new Error(`Paddle est injoignable (${message}). Réessayez dans un instant.`);
  }

  const brut = await reponse.text();
  let donnees: ReponsePaddle = {};
  try {
    donnees = brut ? (JSON.parse(brut) as ReponsePaddle) : {};
  } catch {
    donnees = {};
  }

  if (!reponse.ok) {
    const detail = donnees.error?.detail ??
      donnees.error?.errors?.map((e) => e.message ?? e.field).filter(Boolean).join(", ") ??
      `HTTP ${reponse.status}`;
    throw new Error(`Paddle a refusé la requête : ${detail}`);
  }

  return (donnees.data ?? donnees) as T;
}

export interface TransactionPaddle {
  id: string;
  statut: string;
  checkoutUrl: string | null;
  devise: string | null;
  montantTotal: number | null;
  clientToken: string | null;
  brut: Record<string, unknown>;
}

function lireTransaction(data: Record<string, unknown>): TransactionPaddle {
  const checkout = (data.checkout ?? {}) as Record<string, unknown>;
  const details = (data.details ?? {}) as Record<string, unknown>;
  const totaux = (details.totals ?? {}) as Record<string, unknown>;
  const total = totaux.total === undefined || totaux.total === null ? null : Number(totaux.total);

  return {
    id: String(data.id ?? ""),
    statut: String(data.status ?? "").toLowerCase(),
    checkoutUrl: checkout.url ? String(checkout.url) : null,
    devise: data.currency_code ? String(data.currency_code).toUpperCase() : null,
    montantTotal: Number.isFinite(total) ? (total as number) / 100 : null,
    clientToken: clientTokenPaddle() || null,
    brut: data,
  };
}

/**
 * Crée une transaction Paddle prête pour Paddle.js / le checkout hébergé.
 * `custom_data` transporte order_id / subscription_id pour le webhook.
 *
 * La devise n'est pas imposée : Paddle utilise celle du price_id. Cela évite
 * un échec « currency mismatch » quand seule une variante USD existe.
 */
export async function creerTransactionPaddle(params: {
  priceId: string;
  customData: Record<string, unknown>;
}): Promise<TransactionPaddle> {
  if (!params.priceId || !params.priceId.startsWith("pri_")) {
    throw new Error("Identifiant de prix Paddle invalide.");
  }

  const data = await appelPaddle<Record<string, unknown>>("/transactions", {
    method: "POST",
    body: JSON.stringify({
      items: [{ price_id: params.priceId, quantity: 1 }],
      custom_data: params.customData,
    }),
  });

  const transaction = lireTransaction(data);
  if (!transaction.id) {
    throw new Error("Paddle n'a pas renvoyé d'identifiant de transaction.");
  }
  return transaction;
}

/** Récupère une transaction existante (vérification de retour client). */
export async function recupererTransactionPaddle(
  transactionId: string,
): Promise<TransactionPaddle> {
  if (!/^txn_[a-z0-9]{26}$/i.test(transactionId)) {
    throw new Error("Identifiant de transaction Paddle invalide.");
  }
  const data = await appelPaddle<Record<string, unknown>>(
    `/transactions/${encodeURIComponent(transactionId)}`,
  );
  return lireTransaction(data);
}

/** Statuts Paddle considérés comme payés (webhook et vérification directe). */
export function transactionPaddlePayee(statut: string): boolean {
  return ["completed", "paid", "billed"].includes((statut ?? "").toLowerCase());
}

/** Statuts Paddle d'échec. */
export function transactionPaddleEchouee(statut: string): boolean {
  return ["canceled", "cancelled", "payment_failed", "past_due"].includes(
    (statut ?? "").toLowerCase(),
  );
}

// ----------------------------------------------------------------------------
//  PRICE IDS — PADDLE_PRICE_KIT_<TYPE> (+ variante _EUR), PADDLE_PRICE_STUDIO
// ----------------------------------------------------------------------------

function lireVariable(nom: string): string {
  return (Deno.env.get(nom) ?? "").trim();
}

/**
 * Résout le price_id Paddle à utiliser.
 * Base USD (sans suffixe) ; variante EUR via le suffixe `_EUR`.
 */
export function priceIdPaddle(
  kind: "kit" | "studio",
  produit: TypeProduit | string | null | undefined,
  devise: string,
): string {
  const eur = (devise ?? "").toUpperCase() === "EUR";

  if (kind === "studio") {
    if (eur) {
      const variante = lireVariable("PADDLE_PRICE_STUDIO_EUR");
      if (variante) return variante;
      // Les price IDs EUR sont optionnels : repli sur le prix USD.
    }
    const base = lireVariable("PADDLE_PRICE_STUDIO");
    if (base) return base;
    throw new Error(
      "Prix Paddle du Studio Live manquant : renseignez PADDLE_PRICE_STUDIO " +
        "(et PADDLE_PRICE_STUDIO_EUR pour l'Europe/Maghreb).",
    );
  }

  if (!estTypeProduit(produit)) {
    throw new Error("Offre inconnue : impossible de choisir un prix Paddle.");
  }
  const suffixe = produit.toUpperCase();
  if (eur) {
    const variante = lireVariable(`PADDLE_PRICE_KIT_${suffixe}_EUR`);
    if (variante) return variante;
    // Les price IDs EUR sont optionnels : repli sur le prix USD.
  }
  const base = lireVariable(`PADDLE_PRICE_KIT_${suffixe}`);
  if (base) return base;
  throw new Error(
    `Prix Paddle manquant pour l'offre ${produit} : renseignez PADDLE_PRICE_KIT_${suffixe} ` +
      `(et PADDLE_PRICE_KIT_${suffixe}_EUR pour l'Europe/Maghreb).`,
  );
}

// ----------------------------------------------------------------------------
//  WEBHOOKS — Paddle-Signature: ts=…;h1=… (HMAC SHA-256 sur `${ts}:${body}`)
// ----------------------------------------------------------------------------

function comparaisonConstante(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let i = 0; i < a.length; i++) {
    difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return difference === 0;
}

interface EnteteSignature {
  horodatage: number;
  signatures: string[];
}

function analyserSignature(entete: string | null): EnteteSignature | null {
  if (!entete) return null;
  let horodatage: number | null = null;
  const signatures: string[] = [];

  for (const morceau of entete.split(";")) {
    const [cle, valeur] = morceau.split("=");
    if (!cle || !valeur) continue;
    if (cle.trim() === "ts") {
      const valeurNumerique = Number(valeur.trim());
      if (Number.isFinite(valeurNumerique)) horodatage = valeurNumerique;
    } else if (cle.trim() === "h1") {
      for (const candidate of valeur.split(",")) {
        const propre = candidate.trim().toLowerCase();
        if (propre) signatures.push(propre);
      }
    }
  }

  if (horodatage === null || signatures.length === 0) return null;
  return { horodatage, signatures };
}

/**
 * Vérifie la signature Paddle : HMAC-SHA256(secret, `${ts}:${corps brut}`),
 * fenêtre de 300 secondes, comparaison à temps constant.
 */
export async function signaturePaddleValide(
  corpsBrut: string,
  entete: string | null,
): Promise<boolean> {
  const secret = Deno.env.get("PADDLE_WEBHOOK_SECRET");
  if (!secret) {
    console.error("PADDLE_WEBHOOK_SECRET n'est pas configurée : webhook refusé.");
    return false;
  }

  const analyse = analyserSignature(entete);
  if (!analyse) return false;

  const maintenant = Math.floor(Date.now() / 1000);
  if (Math.abs(maintenant - analyse.horodatage) > 300) return false;

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
    new TextEncoder().encode(`${analyse.horodatage}:${corpsBrut}`),
  );
  const hex = Array.from(new Uint8Array(signatureCalculee))
    .map((octet) => octet.toString(16).padStart(2, "0"))
    .join("");

  return analyse.signatures.some((signature) => comparaisonConstante(hex, signature));
}
