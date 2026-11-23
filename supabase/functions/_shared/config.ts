// ============================================================================
//  CONFIGURATION MÉTIER — e-booklive (La Boutique + Studio Live)
//  Source unique de vérité partagée par toutes les Edge Functions.
//
//  • 8 secteurs + « Autre métier » (alias des anciens codes conservés).
//  • Tous les pays du monde : 23 pays SasPay + Paddle pour le reste.
//  • Tarifs kits en XOF, Studio Live 10 USD / 30 jours (voir pricing.ts).
// ============================================================================

import type { TypeProduit } from "./pricing.ts";
import {
  PRIX_KITS_XOF,
  PRIX_STUDIO_USD,
  PRIX_STUDIO_XOF,
  DUREE_STUDIO_JOURS,
  formaterMontant,
} from "./pricing.ts";
import {
  type PaysMonde,
  type RoutePaiement,
  PAYS_MONDE,
  PAYS_SASPAY,
  deviseFacturation,
  deviseLocale,
  paysMonde,
} from "./countries.ts";

export type { TypeProduit } from "./pricing.ts";
export type { TypeAchat } from "./pricing.ts";

// ----------------------------------------------------------------------------
//  1. OFFRES (tarifs en XOF, catalogue inchangé pour la livraison)
// ----------------------------------------------------------------------------

export interface Offre {
  type: TypeProduit;
  productId: string;
  titre: string;
  description: string;
  prixFcfa: number;
  credits: number;
  populaire: boolean;
}

/** Tarifs officiels en FCFA — plus aucun prix en dirham. */
export const OFFRES: Record<TypeProduit, Offre> = {
  prompt: {
    type: "prompt",
    productId: "8cbddad5-7747-424e-8ed1-a1829ae46914",
    titre: "Prompts IA",
    description: "10 prompts IA prêts à copier pour vendre et produire votre contenu.",
    prixFcfa: PRIX_KITS_XOF.prompt,
    credits: 1,
    populaire: false,
  },
  sheet: {
    type: "sheet",
    productId: "d4b7a69e-1720-4038-8da8-cf782fed24e9",
    titre: "Sheet Automatisé",
    description: "Votre Google Sheet de ventes, stocks, marges et point mort.",
    prixFcfa: PRIX_KITS_XOF.sheet,
    credits: 1,
    populaire: false,
  },
  livre: {
    type: "livre",
    productId: "f8a7dd07-d155-4b83-8289-286f2e44ee6b",
    titre: "Livre Stratégique",
    description: "Votre plan d'action complet, écrit pour votre métier et votre pays.",
    prixFcfa: PRIX_KITS_XOF.livre,
    credits: 1,
    populaire: false,
  },
  pack: {
    type: "pack",
    productId: "54e2150a-1648-4119-a4df-208bcb121c27",
    titre: "Pack Complet",
    description: "Livre + Prompts IA + Google Sheet : tout votre kit en une fois.",
    prixFcfa: PRIX_KITS_XOF.pack,
    credits: 3,
    populaire: true,
  },
};

// ----------------------------------------------------------------------------
//  2. SECTEURS ET KITS MÉTIERS (8 secteurs + Autre métier)
// ----------------------------------------------------------------------------

export interface Secteur {
  code: string;
  label: string;
  description: string;
  emoji: string;
}

/** Les 8 secteurs proposés à l'étape 1 de La Boutique. */
export const SECTEURS: Secteur[] = [
  {
    code: "ecommerce",
    label: "E-commerce & Mode",
    description: "Vêtements, accessoires, cosmétiques, livraison à domicile.",
    emoji: "🛍️",
  },
  {
    code: "immobilier",
    label: "Immobilier",
    description: "Vente, location, promotion immobilière et gestion locative.",
    emoji: "🏠",
  },
  {
    code: "restauration",
    label: "Restauration",
    description: "Restaurant, maquis, fast-food, traiteur et livraison.",
    emoji: "🍲",
  },
  {
    code: "beaute",
    label: "Beauté & Bien-être",
    description: "Salon, spa, coiffure, onglerie, soins et cosmétiques.",
    emoji: "💅",
  },
  {
    code: "formation",
    label: "Formation & Éducation",
    description: "Cours, coaching, écoles, ateliers et contenus payants.",
    emoji: "🎓",
  },
  {
    code: "transport",
    label: "Transport & Logistique",
    description: "VTC, livraison, fret, location de véhicules et tournées.",
    emoji: "🚚",
  },
  {
    code: "services_b2b",
    label: "Services B2B",
    description: "Agence, conseil, freelance, marketing et sous-traitance.",
    emoji: "💼",
  },
  {
    code: "sante",
    label: "Santé",
    description: "Clinique, pharmacie, laboratoire, cabinet et bien-être.",
    emoji: "🩺",
  },
];

/** Secteur libre : le client écrit lui-même son activité. */
export const SECTEUR_AUTRE: Secteur = {
  code: "autre",
  label: "Autre métier",
  description: "Écrivez votre activité en quelques mots.",
  emoji: "✍️",
};

export const TOUS_SECTEURS: Secteur[] = [...SECTEURS, SECTEUR_AUTRE];

export interface KitMetier extends Secteur {
  promesse: string;
  motsCles: string[];
}

const PROMESSES: Record<string, string> = {
  ecommerce: "Vendre sur WhatsApp et les réseaux, livrer sans perdre d'argent.",
  immobilier: "Vendre, louer et gérer des biens sans laisser filer vos commissions.",
  restauration: "Remplir votre salle, maîtriser vos coûts et fidéliser vos clients.",
  beaute: "Remplir votre agenda, vendre vos prestations et vos produits.",
  formation: "Vendre vos formations et remplir vos sessions sans y passer vos nuits.",
  transport: "Rentabiliser chaque trajet, chaque véhicule et chaque tournée.",
  services_b2b: "Vendre vos prestations au juste prix et livrer sans dépassement.",
  sante: "Remplir votre cabinet, structurer vos soins et fidéliser vos patients.",
  autre: "Un kit écrit pour votre activité exacte, sans case préformatée.",
};

const MOTS_CLES: Record<string, string[]> = {
  ecommerce: [
    "whatsapp business",
    "catalogue",
    "livraison",
    "paiement mobile",
    "stock",
    "mode",
    "accessoires",
    "cosmétiques",
  ],
  immobilier: [
    "mandat",
    "visite",
    "commission",
    "gestion locative",
    "promotion immobilière",
    "terrain",
    "bail",
  ],
  restauration: [
    "menu",
    "food cost",
    "livraison",
    "réservation",
    "hygiène",
    "maquis",
    "traiteur",
  ],
  beaute: [
    "agenda",
    "prestations",
    "fidélisation",
    "forfaits",
    "instagram",
    "soins",
    "onglerie",
  ],
  formation: [
    "cours",
    "coaching",
    "école",
    "atelier",
    "contenu payant",
    "certificat",
    "session",
  ],
  transport: [
    "vtc",
    "livraison",
    "fret",
    "tournées",
    "carburant",
    "chauffeur",
    "véhicule",
  ],
  services_b2b: [
    "offres",
    "devis",
    "prospection",
    "contrats",
    "tarification",
    "agence",
    "freelance",
  ],
  sante: [
    "consultation",
    "rendez-vous",
    "pharmacie",
    "laboratoire",
    "suivi patient",
    "ordonnance",
    "cabinet",
  ],
  autre: ["activité personnalisée", "projet libre", "métier spécifique"],
};

/** Les kits métiers clés en main (8 secteurs + Autre métier). */
export const KITS_METIERS: KitMetier[] = TOUS_SECTEURS.map((secteur) => ({
  ...secteur,
  promesse: PROMESSES[secteur.code] ?? SECTEUR_AUTRE.description,
  motsCles: MOTS_CLES[secteur.code] ?? MOTS_CLES.autre,
}));

/**
 * Anciens codes utilisés par les commandes existantes → secteur actuel.
 * Ils ne cassent ni `kitParCode` ni la génération des anciens kits.
 */
export const ALIAS_METIER: Record<string, string> = {
  restaurant: "restauration",
  elevage: "autre",
  agence: "services_b2b",
  financement: "autre",
};

/** Libellés historiques conservés pour l'affichage et la génération. */
export const LIBELLES_LEGACY: Record<string, string> = {
  restaurant: "Restaurant / Maquis rentable",
  elevage: "Élevage / Agriculture",
  agence: "Agence de Services",
  financement: "Dossier de Financement",
};

/** Un kit métier par son code (alias legacy inclus), ou undefined. */
export function kitParCode(code: string | null | undefined): KitMetier | undefined {
  const normalise = (code ?? "").trim().toLowerCase();
  if (!normalise) return undefined;

  const direct = KITS_METIERS.find((kit) => kit.code === normalise);
  if (direct) return direct;

  const alias = ALIAS_METIER[normalise];
  if (!alias) return undefined;

  const cible = KITS_METIERS.find((kit) => kit.code === alias);
  if (!cible) return undefined;

  const label = LIBELLES_LEGACY[normalise];
  return label ? { ...cible, label } : cible;
}

/** Libellé d'un secteur (ou le code brut si inconnu). */
export function libelleSecteur(code: string | null | undefined): string {
  return kitParCode(code)?.label ?? (code ?? "").trim();
}

// ----------------------------------------------------------------------------
//  3. PAYS ET ROUTAGE (tous les pays via countries.ts)
// ----------------------------------------------------------------------------

export interface PaysRoutage {
  code: string;
  nom: string;
  drapeau: string;
  indicatif: string;
  /** Devise locale réelle (ex. MAD, NGN, XOF). */
  devise: string;
  /** Devise réellement facturée : locale (SasPay) ou EUR/USD (Paddle). */
  deviseFacturation: string;
  route: RoutePaiement;
}

/** Tous les pays connus, avec leur route de paiement. */
export function paysParCode(code: string | null | undefined): PaysRoutage | undefined {
  const pays: PaysMonde | undefined = paysMonde(code);
  if (!pays) return undefined;
  return {
    code: pays.code,
    nom: pays.nom,
    drapeau: pays.drapeau,
    indicatif: pays.indicatif,
    devise: pays.devise,
    deviseFacturation: deviseFacturation(pays.code),
    route: pays.sasPay ? "saspay" : "paddle",
  };
}

/** Les 23 pays SasPay, sous forme de routes prêtes à l'emploi. */
export const PAYS_SASPAY_ROUTES: PaysRoutage[] = PAYS_SASPAY.map((pays) => ({
  code: pays.code,
  nom: pays.nom,
  drapeau: pays.drapeau,
  indicatif: pays.indicatif,
  devise: deviseLocale(pays.code),
  deviseFacturation: deviseFacturation(pays.code),
  route: "saspay" as const,
}));

// ----------------------------------------------------------------------------
//  4. LIENS DU SITE (URL strategy : path, plus de hash)
// ----------------------------------------------------------------------------

/** URL publique du site (sans slash final). */
export const SITE_URL = (Deno.env.get("SITE_URL") ?? "https://e-booklive.offboard-hub.com")
  .replace(/\/+$/, "");

/** Boutique : kits métiers (paiement unique). */
export function lienAchat(): string {
  return `${SITE_URL}/boutique`;
}

/** Studio Live : abonnement 10 USD / 30 jours. */
export function lienStudio(): string {
  return `${SITE_URL}/studio-live`;
}

/** Guide & Tutoriel public. */
export function lienGuide(): string {
  return `${SITE_URL}/guide`;
}

/** Page de l'assistant (plein écran). */
export function lienAssistant(): string {
  return `${SITE_URL}/assistant`;
}

/** Numéro d'aide WhatsApp (format international sans +, ex. 22670123456). */
export function numeroAide(): string {
  return (Deno.env.get("WHATSAPP_AIDE_NUMBER") ?? "").replace(/\D/g, "");
}

export function lienAideWhatsApp(): string {
  const num = numeroAide();
  return num ? `https://wa.me/${num}` : SITE_URL;
}

// ----------------------------------------------------------------------------
//  5. HELPERS DE FORMATAGE
// ----------------------------------------------------------------------------

/** Le montant SasPay est toujours une chaîne décimale ("9000.00"). */
export function montantSaspay(montantFcfa: number): string {
  return Number(montantFcfa || 0).toFixed(2);
}

/** Compose un numéro E.164 à partir de l'indicatif pays et du numéro saisi. */
export function telephoneE164(indicatif: string, numero: string): string {
  const chiffres = (numero ?? "").replace(/\D/g, "").replace(/^0+/, "");
  const prefixe = (indicatif ?? "").replace(/\D/g, "");
  return `+${prefixe}${chiffres}`;
}

/** Montant formaté pour l'affichage : "9 000 FCFA". */
export function formaterFcfa(montant: number): string {
  return formaterMontant(montant, "XOF");
}

// ----------------------------------------------------------------------------
//  6. TEXTES POUR L'ASSISTANT IA (Awa)
// ----------------------------------------------------------------------------

/** Récapitulatif texte des offres (utilisé par l'assistant IA). */
export function catalogueTexte(): string {
  return Object.values(OFFRES)
    .map(
      (o) =>
        `- ${o.titre} : ${formaterFcfa(o.prixFcfa)}${o.populaire ? " (le plus choisi)" : ""} — ${o.description}`,
    )
    .join("\n");
}

export function kitsTexte(): string {
  return KITS_METIERS.map((k) => `- ${k.emoji} ${k.label} : ${k.promesse}`).join("\n");
}

/** Les 8 secteurs (sans « Autre métier »). */
export function secteursTexte(): string {
  return SECTEURS.map((s) => `- ${s.emoji} ${s.label} : ${s.description}`).join("\n");
}

/** Studio Live : offre, prix et bénéfice. */
export function studioTexte(): string {
  return [
    `- Studio Live : abonnement ${PRIX_STUDIO_USD} USD / ${DUREE_STUDIO_JOURS} jours`,
    `  (≈ ${formaterMontant(PRIX_STUDIO_XOF, "XOF")} pour les pays FCFA, converti dans la devise locale).`,
    "  Il donne accès à la régie live (3 onglets), au chat IA commercial en direct,",
    "  à une salle de live pour les co-animateurs invités et au Livre Guide Live personnalisé.",
  ].join("\n");
}

/** Les 23 pays SasPay, avec devise locale et indicatif. */
export function paysSasPayTexte(): string {
  return PAYS_SASPAY_ROUTES.map(
    (p) => `${p.drapeau} ${p.nom} (${p.indicatif}, ${p.deviseFacturation})`,
  ).join(" • ");
}

/** Le reste du monde : Paddle en EUR (Europe + Maghreb) ou USD. */
export function paysPaddleTexte(): string {
  return (
    "Tous les autres pays passent par Paddle : EUR pour l'Europe et le Maghreb " +
    "(Maroc, Algérie, Tunisie, Libye, Égypte, Soudan), USD partout ailleurs " +
    "(Canada, États-Unis, Émirats arabes unis, Royaume-Uni, etc.). " +
    "Le montant local affiché est indicatif."
  );
}

export function paysTexte(): string {
  return `PAYS SASPAY (23) : ${paysSasPayTexte()}\nPAYS PADDLE : ${paysPaddleTexte()}`;
}

/** Routes du site à connaître par l'assistant. */
export function routesTexte(): string {
  return [
    `- /boutique : choisir un kit métier et payer (${lienAchat()})`,
    `- /studio-live : abonnement Studio Live ${PRIX_STUDIO_USD} USD / 30 jours (${lienStudio()})`,
    `- /studio/regie : régie du live, réservée aux abonnés`,
    `- /guide : guide & tutoriel public (${lienGuide()})`,
    `- /assistant : l'assistant en plein écran (${lienAssistant()})`,
  ].join("\n");
}

/** Nombre total de pays connus (les 23 SasPay + le reste du monde). */
export const NOMBRE_PAYS_MONDE = PAYS_MONDE.length;
