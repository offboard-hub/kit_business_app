// ============================================================================
//  PRIX ET CONVERSIONS — source de vérité des montants facturés.
//
//  • Kits métiers : prix de référence en XOF / FCFA (3 000 / 3 500 / 5 000 / 9 000).
//  • Studio Live  : 10 USD pour 30 jours (source de vérité).
//  • SasPay       : montant converti dans la devise locale du pays.
//  • Paddle       : montant en EUR (Europe + Maghreb) ou USD, avec une
//                   conversion locale purement indicative.
//
//  Les arrondis reproduisent exactement ceux de `lib/core/pricing.dart`
//  (`Prix.arrondir`) : le montant affiché par le frontend et celui facturé par
//  le serveur doivent être identiques.
//
//  ⚠️ Aucun montant envoyé par le client n'est utilisé : tout est recalculé ici.
// ============================================================================

import {
  DEVISES_ENTIERES,
  SYMBOLES_DEVISES,
  convertirDepuisXof,
  deviseLocale,
  devisePaddle,
  taux,
} from "./countries.ts";

export type TypeProduit = "prompt" | "sheet" | "livre" | "pack";
export type TypeAchat = "kit" | "studio";

/** Tarifs de référence des kits, en XOF (FCFA). */
export const PRIX_KITS_XOF: Record<TypeProduit, number> = {
  prompt: 3000,
  sheet: 3500,
  livre: 5000,
  pack: 9000,
};

/** Studio Live : prix de référence en USD pour 30 jours. */
export const PRIX_STUDIO_USD = 10;

/** Équivalent XOF de 10 USD au taux de référence (10 / 0,00165 ≈ 6061). */
export const PRIX_STUDIO_XOF = 6061;

/** Durée d'un abonnement Studio Live. */
export const DUREE_STUDIO_JOURS = 30;

export const LIBELLES_OFFRES: Record<TypeProduit, string> = {
  prompt: "Prompts IA",
  sheet: "Sheet Automatisé",
  livre: "Livre Stratégique",
  pack: "Pack Complet",
};

export const LIBELLE_STUDIO = "Studio Live";

/** Libellé commercial d'une offre (ou du Studio Live). */
export function libelleOffre(produit: TypeProduit | string | null | undefined): string {
  if (produit === "studio") return LIBELLE_STUDIO;
  if (produit && produit in LIBELLES_OFFRES) {
    return LIBELLES_OFFRES[produit as TypeProduit];
  }
  return LIBELLE_STUDIO;
}

/** Vrai si la chaîne est un type de kit valide. */
export function estTypeProduit(valeur: string | null | undefined): valeur is TypeProduit {
  return valeur === "prompt" || valeur === "sheet" || valeur === "livre" || valeur === "pack";
}

/**
 * Prix de référence en XOF d'un achat.
 * Studio Live : 6061 XOF (équivalent de 10 USD).
 */
export function prixReferenceXof(
  kind: TypeAchat,
  produit: TypeProduit | string | null | undefined,
): number {
  if (kind === "studio") return PRIX_STUDIO_XOF;
  if (!estTypeProduit(produit)) {
    throw new Error("Offre inconnue : impossible de calculer le prix.");
  }
  return PRIX_KITS_XOF[produit];
}

/**
 * Arrondi commercial — copie conforme de `Prix.arrondir` (frontend) :
 *  - devises « entières » : 500 si ≥ 10 000, 100 si ≥ 1 000, sinon entier ;
 *  - autres devises : deux décimales.
 */
export function arrondirPrix(montant: number, devise: string): number {
  const valeur = Number.isFinite(montant) ? montant : 0;
  const code = (devise ?? "").toUpperCase();
  if (DEVISES_ENTIERES.has(code)) {
    if (valeur >= 10_000) return Math.round(valeur / 500) * 500;
    if (valeur >= 1_000) return Math.round(valeur / 100) * 100;
    return Math.round(valeur);
  }
  return Math.round(valeur * 100) / 100;
}

function grouper(chiffres: string): string {
  let resultat = "";
  for (let i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 === 0) resultat += " ";
    resultat += chiffres[i];
  }
  return resultat;
}

/**
 * Formate un montant en français : « 9 000 FCFA », « 13,72 € », « 14,85 $ »,
 * « 23 000 NGN ». Reproduit `Prix.formater` (frontend).
 */
export function formaterMontant(montant: number, devise: string): string {
  const code = (devise ?? "").toUpperCase();
  const valeur = Number.isFinite(montant) ? montant : 0;
  const entier = DEVISES_ENTIERES.has(code);
  const texte = entier ? String(Math.round(valeur)) : valeur.toFixed(2);
  const morceaux = texte.split(".");
  const decimales = morceaux.length > 1 ? `,${morceaux[1]}` : "";
  const symbole = SYMBOLES_DEVISES[code] ?? code;
  return `${grouper(morceaux[0])}${decimales} ${symbole}`;
}

export interface MontantSasPay {
  montant: number;
  devise: string;
}

/**
 * Montant à facturer via SasPay, dans la devise locale du pays.
 * Le pays doit être un pays SasPay (validé en amont par l'appelant).
 */
export function montantSasPay(
  kind: TypeAchat,
  produit: TypeProduit | string | null | undefined,
  paysCode: string,
): MontantSasPay {
  const devise = deviseLocale(paysCode);
  const reference = prixReferenceXof(kind, produit);
  return {
    montant: arrondirPrix(convertirDepuisXof(reference, devise), devise),
    devise,
  };
}

export interface MontantPaddle {
  /** Montant réellement facturé par Paddle (EUR ou USD). */
  montant: number;
  /** Devise de facturation Paddle. */
  devise: string;
  /** Conversion locale indicative (null si la devise locale est identique). */
  montantIndicatif: number | null;
  deviseIndicative: string | null;
}

/**
 * Montant à facturer via Paddle : EUR (Europe + Maghreb) ou USD.
 * Pour le Studio Live, la conversion part de 10 USD ; la conversion locale
 * indicative reste calculée sur l'équivalent XOF (6061) comme le frontend.
 */
export function montantPaddle(
  kind: TypeAchat,
  produit: TypeProduit | string | null | undefined,
  paysCode: string,
): MontantPaddle {
  const devise = devisePaddle(paysCode);
  const local = deviseLocale(paysCode);

  const montant = kind === "studio"
    ? arrondirPrix((PRIX_STUDIO_USD / taux("USD")) * taux(devise), devise)
    : arrondirPrix(convertirDepuisXof(prixReferenceXof("kit", produit), devise), devise);

  const referenceLocale = kind === "studio"
    ? PRIX_STUDIO_XOF
    : prixReferenceXof("kit", produit);
  const indicatif = local === devise
    ? null
    : arrondirPrix(convertirDepuisXof(referenceLocale, local), local);

  return {
    montant,
    devise,
    montantIndicatif: indicatif,
    deviseIndicative: indicatif === null ? null : local,
  };
}

/** Libellé du produit pour les emails et les descriptions de paiement. */
export function descriptionAchat(
  kind: TypeAchat,
  produit: TypeProduit | string | null | undefined,
  metier: string,
  nomProjet: string,
): string {
  if (kind === "studio") {
    return `Studio Live ${DUREE_STUDIO_JOURS} jours — ${nomProjet}`;
  }
  return `Kit ${metier} — ${libelleOffre(produit)} (${nomProjet})`;
}
