// ============================================================================
//  ASSISTANTE IA DU SITE — « Awa » connaît les deux univers e-booklive :
//  La Boutique (kits métiers) et le Studio Live (10 USD / 30 jours).
//  Elle redirige vers /boutique, /studio-live ou /guide.
// ============================================================================

import {
  KITS_METIERS,
  OFFRES,
  SECTEURS,
  SITE_URL,
  catalogueTexte,
  formaterFcfa,
  lienAchat,
  lienAideWhatsApp,
  lienGuide,
  lienStudio,
  paysPaddleTexte,
  paysSasPayTexte,
  routesTexte,
  secteursTexte,
  studioTexte,
} from "./config.ts";
import {
  DUREE_STUDIO_JOURS,
  PRIX_STUDIO_USD,
  PRIX_STUDIO_XOF,
  formaterMontant,
  libelleOffre,
} from "./pricing.ts";
import { paysMonde } from "./countries.ts";

export interface MessageHistorique {
  role: "user" | "assistant";
  content: string;
}

export interface ReponseAssistant {
  reply: string;
  ctaUrl: string;
  suggestions: string[];
}

export const SUGGESTIONS = [
  "Quel kit pour mon métier ?",
  "Combien coûte le Pack Complet ?",
  "C'est quoi le Studio Live à 10 USD ?",
  "Comment lancer mon premier live ?",
  "Quels pays sont acceptés ?",
  "Comment je reçois mon guide ?",
];

/** CTA le plus pertinent selon la question (boutique, studio ou guide). */
function choisirCta(question: string): string {
  const q = (question ?? "").toLowerCase();
  if (/studio|live|direct|régie|regie|abonnement|co-animateur|coanimateur/.test(q)) {
    return lienStudio();
  }
  if (/guide|tutoriel/.test(q)) {
    return lienGuide();
  }
  return lienAchat();
}

function systemPrompt(): string {
  return `Tu es "Awa", l'assistante commerciale de e-booklive, une marque d'Afrique francophone
et internationale. Tu réponds aux visiteurs du site et aux spectateurs des lives.

DEUX UNIVERS BIEN DISTINCTS :
1. LA BOUTIQUE — des kits métiers clés en main, en paiement unique :
${catalogueTexte()}
   Chaque kit est un livre stratégique, des prompts IA et/ou un Google Sheet,
   rédigé pour le métier, le pays et la devise du client.
2. LE STUDIO LIVE — un abonnement de ${PRIX_STUDIO_USD} USD pour ${DUREE_STUDIO_JOURS} jours
   (≈ ${formaterMontant(PRIX_STUDIO_XOF, "XOF")} pour les pays FCFA, converti dans la devise locale) :
${studioTexte()}
   Il inclut la régie live, le chat IA commercial en direct, la salle pour un
   co-animateur invité et un Livre Guide Live personnalisé OFFERT.
   La page publique est ${lienStudio()} ; la régie (abonnés) est ${SITE_URL}/studio/regie.

LES 8 SECTEURS + « AUTRE MÉTIER » (le client choisit en 1 clic, ou écrit son activité) :
${secteursTexte()}
- ✍️ Autre métier : le client écrit son activité en quelques mots.

PAYS ET DEVISES :
- 23 pays encaissés par SasPay dans leur devise locale : ${paysSasPayTexte()}
- ${paysPaddleTexte()}

ROUTES DU SITE :
${routesTexte()}
Le Guide & Tutoriel public (gratuit) est ici : ${lienGuide()}.

COMMENT ÇA MARCHE :
1. Le client choisit son secteur, puis son offre (La Boutique) ou le Studio Live.
2. Il renseigne le nom de son projet, son pays, son numéro WhatsApp et son email.
3. Le montant est calculé côté serveur dans la devise locale : SasPay (mobile money
   ou carte) dans les 23 pays, Paddle (EUR/USD) partout ailleurs.
4. Dès le paiement confirmé, le kit est généré (DeepSeek + Gemini) et les liens sont
   envoyés immédiatement par email, puis affichés sur la page de confirmation.
   Pour le Studio Live, le guide est généré et envoyé par email, et la régie s'ouvre.

RÈGLES DE RÉPONSE :
- Français simple, chaleureux, direct. 3 à 6 lignes maximum, pas de jargon.
- Si on demande un prix, donne le montant exact : kits en FCFA, Studio Live en USD
  (et l'équivalent FCFA si la personne est dans un pays FCFA).
- Distingue toujours clairement La Boutique (paiement unique) et le Studio Live (abonnement).
- Termine TOUJOURS par une phrase qui invite à agir (boutique, studio ou guide).
- N'invente jamais un produit, un prix, une réduction, une garantie ou un remboursement.
- Si la question sort du cadre (santé, politique, technique externe), redirige
  poliment vers WhatsApp.
- Ne demande jamais de données de carte bancaire ni de mot de passe.

LIEN BOUTIQUE : ${lienAchat()}
LIEN STUDIO LIVE : ${lienStudio()}
GUIDE & TUTORIEL : ${lienGuide()}
SITE : ${SITE_URL}
AIDE WHATSAPP : ${lienAideWhatsApp()}`;
}

async function appelDeepSeek(
  message: string,
  historique: MessageHistorique[],
): Promise<{ texte: string; suggestions: string[] }> {
  const cle = Deno.env.get("DEEPSEEK_API_KEY");
  if (!cle) throw new Error("DEEPSEEK_API_KEY manquante.");

  const messages = [
    { role: "system", content: systemPrompt() },
    ...historique.slice(-8).map((m) => ({ role: m.role, content: m.content })),
    { role: "user", content: message },
  ];

  const reponse = await fetch("https://api.deepseek.com/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${cle}` },
    body: JSON.stringify({
      model: Deno.env.get("DEEPSEEK_MODEL") ?? "deepseek-chat",
      temperature: 0.6,
      max_tokens: 380,
      messages,
    }),
    signal: AbortSignal.timeout(45_000),
  });

  if (!reponse.ok) {
    throw new Error(`DeepSeek a renvoyé HTTP ${reponse.status}`);
  }

  const donnees = await reponse.json();
  const texte = String(donnees?.choices?.[0]?.message?.content ?? "").trim();
  if (!texte) throw new Error("Réponse vide de DeepSeek.");

  return { texte, suggestions: SUGGESTIONS.slice(0, 4) };
}

/** Réponse de secours si l'IA est indisponible : l'offre reste toujours visible. */
function reponseDeSecours(question: string): ReponseAssistant {
  const message = [
    "Je suis momentanément très sollicitée 🙏",
    "",
    "Voici l'essentiel :",
    `• Prompts IA : ${formaterFcfa(OFFRES.prompt.prixFcfa)}`,
    `• Sheet Automatisé : ${formaterFcfa(OFFRES.sheet.prixFcfa)}`,
    `• Livre Stratégique : ${formaterFcfa(OFFRES.livre.prixFcfa)}`,
    `• Pack Complet : ${formaterFcfa(OFFRES.pack.prixFcfa)}`,
    `• Studio Live : ${PRIX_STUDIO_USD} USD / ${DUREE_STUDIO_JOURS} jours (régie + guide offert)`,
    "",
    `La Boutique : ${lienAchat()}`,
    `Le Studio Live : ${lienStudio()}`,
    `Le Guide & Tutoriel : ${lienGuide()}`,
    `Ou écrivez-nous : ${lienAideWhatsApp()}`,
  ].join("\n");

  return {
    reply: message,
    ctaUrl: choisirCta(question),
    suggestions: SUGGESTIONS,
  };
}

export async function repondreAssistant(
  message: string,
  historique: MessageHistorique[] = [],
): Promise<ReponseAssistant> {
  const question = (message ?? "").trim();
  if (!question) {
    return {
      reply:
        "Bonjour 👋 Je suis Awa, l'assistante e-booklive. Vous cherchez un kit métier pour votre activité, ou le Studio Live pour vendre en direct ?",
      ctaUrl: lienAchat(),
      suggestions: SUGGESTIONS,
    };
  }

  // Salutation / remerciement : réponse instantanée, zéro appel IA facturé.
  if (/^(bonjour|salut|hello|hi|coucou|bonsoir)\b/i.test(question) && question.length < 25) {
    return {
      reply:
        "Bonjour 👋 Je suis Awa. Je vous aide à choisir : un kit métier (e-commerce, immobilier, " +
        "restauration, beauté, formation, transport, services B2B, santé, ou votre propre métier) " +
        "ou bien le Studio Live pour vendre en direct. Que voulez-vous faire ?",
      ctaUrl: lienAchat(),
      suggestions: SUGGESTIONS,
    };
  }

  try {
    const { texte, suggestions } = await appelDeepSeek(question, historique);
    return { reply: texte, ctaUrl: choisirCta(question), suggestions };
  } catch (erreur) {
    console.error("Assistant IA indisponible :", erreur);
    return reponseDeSecours(question);
  }
}

/** Réponse courte utilisée dans le chat YouTube (contraintes de longueur). */
export function messageYouTube(reponse: string): string {
  const propre = reponse.replace(/\s+/g, " ").trim();
  const court = propre.length > 190 ? `${propre.slice(0, 187)}...` : propre;
  return `${court} 👉 ${lienAchat()}`;
}

/** Vérifie qu'un code pays est connu (23 SasPay + reste du monde). */
export function paysExiste(code: string): boolean {
  return paysMonde(code) !== undefined;
}

/** Texte marketing court des deux univers (utilisé par les emails). */
export function deuxUniversTexte(): string {
  return [
    `La Boutique : ${KITS_METIERS.length} kits métiers (dont Autre métier), paiement unique en FCFA.`,
    `Le Studio Live : ${PRIX_STUDIO_USD} USD / ${DUREE_STUDIO_JOURS} jours, régie + chat IA + guide offert.`,
    `Secteurs : ${SECTEURS.map((s) => s.label).join(", ")}.`,
    `Offre la plus choisie : ${libelleOffre("pack")} à ${formaterFcfa(OFFRES.pack.prixFcfa)}.`,
  ].join("\n");
}
