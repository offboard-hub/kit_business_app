// ============================================================================
//  ASSISTANT IA DU SITE — connaît toute l'offre et redirige vers le paiement.
//  Utilisé par la bulle de chat Flutter.
// ============================================================================

import {
  KITS_METIERS,
  OFFRES,
  PAYS,
  SITE_URL,
  catalogueTexte,
  formaterFcfa,
  lienAchat,
  lienAideWhatsApp,
  paysTexte,
} from "./config.ts";

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
  "Quel kit pour un maquis ?",
  "Combien coûte le Pack Complet ?",
  "Comment je reçois mon kit ?",
  "Quels pays sont acceptés ?",
];

function systemPrompt(): string {
  return `Tu es "Awa", l'assistante commerciale de Kit Business, une entreprise d'Afrique francophone
qui vend des kits business clés en main générés par IA (livre stratégique, prompts IA, Google Sheet).

CE QUE VEND KIT BUSINESS (prix en FCFA uniquement, jamais en dirham ni en dollar) :
${catalogueTexte()}

LES 6 KITS MÉTIERS (le client choisit son secteur en 1 clic) :
${KITS_METIERS.map((k) => `- ${k.emoji} ${k.label} : ${k.promesse}`).join("\n")}

PAYS ET INDICATIFS : ${paysTexte()}

COMMENT ÇA MARCHE :
1. Le client choisit son kit métier et son offre.
2. Il renseigne le nom de son projet, son pays, son numéro WhatsApp (contact) et son email.
3. Il paie en mobile money ou par carte avec SasPay (Orange Money, Wave, MTN MoMo, Moov, Djamo, carte bancaire).
4. Dès le paiement confirmé, le kit est généré (Gemini + DeepSeek) et les liens sont envoyés
   immédiatement par email, et affichés sur la page de confirmation.
5. Le livre se télécharge en PDF depuis le lien de consultation. Le Google Sheet est privé mais ouvert en écriture.

FORFAITS : Prompts IA ${formaterFcfa(OFFRES.prompt.prixFcfa)} • Sheet Automatisé ${formaterFcfa(OFFRES.sheet.prixFcfa)} •
Livre Stratégique ${formaterFcfa(OFFRES.livre.prixFcfa)} • Pack Complet ${formaterFcfa(OFFRES.pack.prixFcfa)} (le plus choisi).

RÈGLES DE RÉPONSE :
- Français simple, chaleureux, direct. 3 à 6 lignes maximum, pas de jargon.
- Tu réponds aux questions des spectateurs pendant nos Lives OBS.
- Si on demande un prix, donne le montant exact en FCFA.
- Termine TOUJOURS par une phrase qui invite à commander.
- N'invente jamais un produit, un prix, une réduction ou une promesse de remboursement.
- Si la question sort du cadre (sujet technique externe, politique, santé), redirige poliment vers WhatsApp.
- Ne demande jamais de données de carte bancaire.

LIEN D'ACHAT OFFICIEL : ${lienAchat()}
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
      max_tokens: 350,
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

  return { texte, suggestions: SUGGESTIONS.slice(0, 3) };
}

/** Réponse de secours si l'IA est indisponible : l'offre reste toujours visible. */
function reponseDeSecours(): ReponseAssistant {
  const message = [
    "Je suis momentanément très sollicitée 🙏",
    "",
    "Voici l'essentiel :",
    `• Prompts IA : ${formaterFcfa(OFFRES.prompt.prixFcfa)}`,
    `• Sheet Automatisé : ${formaterFcfa(OFFRES.sheet.prixFcfa)}`,
    `• Livre Stratégique : ${formaterFcfa(OFFRES.livre.prixFcfa)}`,
    `• Pack Complet : ${formaterFcfa(OFFRES.pack.prixFcfa)}`,
    "",
    `Choisissez votre kit ici : ${lienAchat()}`,
    `Ou écrivez-nous : ${lienAideWhatsApp()}`,
  ].join("\n");

  return {
    reply: message,
    ctaUrl: lienAchat(),
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
      reply: "Bonjour 👋 Je suis Awa, l'assistante Kit Business. Quel est votre métier ?",
      ctaUrl: lienAchat(),
      suggestions: SUGGESTIONS,
    };
  }

  // Salutation / remerciement : réponse instantanée, zéro appel IA facturé.
  if (/^(bonjour|salut|hello|hi|coucou|bonsoir)\b/i.test(question) && question.length < 25) {
    return {
      reply:
        "Bonjour 👋 Je suis Awa. Je vous aide à choisir le bon kit pour votre activité. " +
        "Quel est votre secteur : restaurant, boutique en ligne, élevage, beauté, services ou financement ?",
      ctaUrl: lienAchat(),
      suggestions: SUGGESTIONS,
    };
  }

  try {
    const { texte, suggestions } = await appelDeepSeek(question, historique);
    return { reply: texte, ctaUrl: lienAchat(), suggestions };
  } catch (erreur) {
    console.error("Assistant IA indisponible :", erreur);
    return reponseDeSecours();
  }
}

/** Réponse courte utilisée dans le chat YouTube (contraintes de longueur). */
export function messageYouTube(reponse: string): string {
  const propre = reponse.replace(/\s+/g, " ").trim();
  const court = propre.length > 190 ? `${propre.slice(0, 187)}...` : propre;
  return `${court} 👉 ${lienAchat()}`;
}

export function paysExiste(code: string): boolean {
  return PAYS.some((p) => p.code === code.toUpperCase());
}
