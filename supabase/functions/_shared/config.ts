// ============================================================================
//  CONFIGURATION MÉTIER — Kit Business (Afrique francophone, 100 % FCFA)
//  Source unique de vérité partagée par toutes les Edge Functions.
// ============================================================================

export type TypeProduit = "prompt" | "sheet" | "livre" | "pack";

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
    prixFcfa: 3000,
    credits: 1,
    populaire: false,
  },
  sheet: {
    type: "sheet",
    productId: "d4b7a69e-1720-4038-8da8-cf782fed24e9",
    titre: "Sheet Automatisé",
    description: "Votre Google Sheet de ventes, stocks, marges et point mort.",
    prixFcfa: 3500,
    credits: 1,
    populaire: false,
  },
  livre: {
    type: "livre",
    productId: "f8a7dd07-d155-4b83-8289-286f2e44ee6b",
    titre: "Livre Stratégique",
    description: "Votre plan d'action complet, écrit pour votre métier et votre pays.",
    prixFcfa: 5000,
    credits: 1,
    populaire: false,
  },
  pack: {
    type: "pack",
    productId: "54e2150a-1648-4119-a4df-208bcb121c27",
    titre: "Pack Complet",
    description: "Livre + Prompts IA + Google Sheet : tout votre kit en une fois.",
    prixFcfa: 9000,
    credits: 3,
    populaire: true,
  },
};

export interface KitMetier {
  code: string;
  label: string;
  emoji: string;
  promesse: string;
  motsCles: string[];
}

/** Les 6 kits métiers clés en main (sélection visuelle en 1 clic). */
export const KITS_METIERS: KitMetier[] = [
  {
    code: "restaurant",
    label: "Restaurant / Maquis rentable",
    emoji: "🍲",
    promesse: "Remplir votre salle, maîtriser vos coûts et fidéliser vos clients.",
    motsCles: ["menu", "food cost", "livraison", "réservation", "hygiène"],
  },
  {
    code: "ecommerce",
    label: "Boutique E-commerce + livraison",
    emoji: "🛍️",
    promesse: "Vendre sur WhatsApp et les réseaux, livrer sans perdre d'argent.",
    motsCles: ["whatsapp business", "catalogue", "livraison", "paiement mobile", "stock"],
  },
  {
    code: "elevage",
    label: "Élevage / Agriculture",
    emoji: "🌾",
    promesse: "Produire plus, vendre mieux, sécuriser vos marges saisonnières.",
    motsCles: ["alimentation", "mortalité", "cycle de production", "coopérative", "marché"],
  },
  {
    code: "beaute",
    label: "Salon de Beauté",
    emoji: "💅",
    promesse: "Remplir votre agenda, vendre vos prestations et vos produits.",
    motsCles: ["agenda", "prestations", "fidélisation", "forfaits", "instagram"],
  },
  {
    code: "agence",
    label: "Agence de Services",
    emoji: "💼",
    promesse: "Vendre vos prestations au juste prix et livrer sans dépassement.",
    motsCles: ["offres", "devis", "prospection", "contrats", "tarification"],
  },
  {
    code: "financement",
    label: "Dossier de Financement",
    emoji: "🏦",
    promesse: "Préparer un dossier bancaire ou microfinance solide et crédible.",
    motsCles: ["business plan", "prévisionnel", "garanties", "banque", "subvention"],
  },
];

export interface PaysAfricain {
  code: string; // ISO 3166-1 alpha-2
  nom: string;
  indicatif: string; // ex. +225
  devise: "XOF" | "XAF";
  drapeau: string;
}

/** Pays couverts — uniquement des devises FCFA (XOF / XAF). */
export const PAYS: PaysAfricain[] = [
  { code: "CI", nom: "Côte d'Ivoire", indicatif: "+225", devise: "XOF", drapeau: "🇨🇮" },
  { code: "SN", nom: "Sénégal", indicatif: "+221", devise: "XOF", drapeau: "🇸🇳" },
  { code: "ML", nom: "Mali", indicatif: "+223", devise: "XOF", drapeau: "🇲🇱" },
  { code: "CM", nom: "Cameroun", indicatif: "+237", devise: "XAF", drapeau: "🇨🇲" },
  { code: "BF", nom: "Burkina Faso", indicatif: "+226", devise: "XOF", drapeau: "🇧🇫" },
  { code: "BJ", nom: "Bénin", indicatif: "+229", devise: "XOF", drapeau: "🇧🇯" },
  { code: "TG", nom: "Togo", indicatif: "+228", devise: "XOF", drapeau: "🇹🇬" },
  { code: "GA", nom: "Gabon", indicatif: "+241", devise: "XAF", drapeau: "🇬🇦" },
  { code: "NE", nom: "Niger", indicatif: "+227", devise: "XOF", drapeau: "🇳🇪" },
  { code: "TD", nom: "Tchad", indicatif: "+235", devise: "XAF", drapeau: "🇹🇩" },
  { code: "CG", nom: "Congo-Brazzaville", indicatif: "+242", devise: "XAF", drapeau: "🇨🇬" },
  { code: "CF", nom: "République Centrafricaine", indicatif: "+236", devise: "XAF", drapeau: "🇨🇫" },
  { code: "GW", nom: "Guinée-Bissau", indicatif: "+245", devise: "XOF", drapeau: "🇬🇼" },
  { code: "GQ", nom: "Guinée Équatoriale", indicatif: "+240", devise: "XAF", drapeau: "🇬🇶" },
];

/** URL publique du site (sans slash final). */
export const SITE_URL = (Deno.env.get("SITE_URL") ?? "https://e-booklive.offboard-hub.com")
  .replace(/\/+$/, "");

/** Lien d'achat Saspay (page de paiement réutilisable) ou, à défaut, tunnel du site. */
export function lienAchat(): string {
  const lien = Deno.env.get("SASPAY_PAYMENT_LINK");
  if (lien && lien.startsWith("http")) return lien;
  return `${SITE_URL}/#/commande`;
}

/** Numéro d'aide WhatsApp (format international sans +, ex. 22670123456). */
export function numeroAide(): string {
  return (Deno.env.get("WHATSAPP_AIDE_NUMBER") ?? "").replace(/\D/g, "");
}

export function lienAideWhatsApp(): string {
  const num = numeroAide();
  return num ? `https://wa.me/${num}` : SITE_URL;
}

export function paysParCode(code: string): PaysAfricain | undefined {
  return PAYS.find((p) => p.code === code.toUpperCase());
}

export function kitParCode(code: string): KitMetier | undefined {
  return KITS_METIERS.find((k) => k.code === code.toLowerCase());
}

/** Le montant Saspay est toujours une chaîne décimale ("9000.00"). */
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
  return `${Math.round(montant).toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ")} FCFA`;
}

/** Récapitulatif texte de l'offre (utilisé par l'assistant IA). */
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

export function paysTexte(): string {
  return PAYS.map((p) => `${p.drapeau} ${p.nom} (${p.indicatif})`).join(" • ");
}
