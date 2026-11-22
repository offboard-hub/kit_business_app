// ============================================================================
//  MOTEUR DE GÉNÉRATION DU KIT — Gemini + DeepSeek + Google Sheets
//  Contexte : Afrique francophone, montants en FCFA, mobile money, WhatsApp.
//  Aucun fichier n'est stocké : tout est du texte en base + lien Google Sheet.
// ============================================================================

import { google } from "npm:googleapis@126.0.1";
import { formaterFcfa, type TypeProduit } from "./config.ts";
import { appelDeepSeek, appelGemini, extraireJson, nettoyerHtml } from "./ia.ts";

export interface KitInput {
  metierCode: string;
  metierLabel: string;
  nomProjet: string;
  paysCode: string;
  paysLabel: string;
  devise: string;
  precisions?: string | null;
  emailClient?: string | null;
}

export interface ContenuKit {
  livreHtml: string;
  promptsTexte: string;
  sheetUrl: string;
  strategie: Record<string, unknown>;
  avertissements: string[];
}

export interface LiensKit {
  livre: string | null;
  prompts: string | null;
  sheet: string | null;
  principal: string | null;
}

// ----------------------------------------------------------------------------
//  APPELS IA
// ----------------------------------------------------------------------------

// Les appels modèles sont mutualisés dans `ia.ts` (également utilisé par
// l'agence vidéo et l'assistant IA).
export { extraireJson, nettoyerHtml };
export { appelDeepSeek, appelGemini };

// ----------------------------------------------------------------------------
//  PROMPTS — contextualisés Afrique francophone
// ----------------------------------------------------------------------------

function contexte(input: KitInput): string {
  const precision = input.precisions?.trim()
    ? `Précisions du client : "${input.precisions.trim()}".`
    : "Aucune précision supplémentaire.";

  return `Marché : ${input.paysLabel} (zone FCFA, devise ${input.devise}).
Projet : "${input.nomProjet}" — secteur : ${input.metierLabel}.
${precision}
Réalité locale à intégrer : mobile money (Orange Money, Wave, MTN MoMo, Moov Money), WhatsApp Business,
livraison à moto et à domicile, pouvoir d'achat local, saisonnalité, méfiance envers les promesses,
concurrence du marché informel. Tous les montants doivent être exprimés en FCFA.`;
}

async function produireStrategie(input: KitInput): Promise<Record<string, unknown>> {
  const prompt = `Rôle : stratège d'affaires d'élite, spécialiste des marchés d'Afrique francophone.
${contexte(input)}

Interdiction : aucune généralité, aucun conseil copié-collé. Tu identifies l'hémorragie invisible,
les leviers asymétriques réellement applicables avec peu de trésorerie, et l'architecture d'un
tableau de gestion adapté.

Réponds UNIQUEMENT avec un JSON valide :
{
  "diagnostic_brutal": "3 phrases maximum, sans complaisance",
  "hemorragie_invisible": "la fuite de cash ou de clients la plus coûteuse",
  "leviers_secret": [
    {"nom_levier": "...", "mecanisme": "...", "action_immediate": "...", "gain_estime_fcfa": 250000}
  ],
  "chiffres_cles": [
    {"indicateur": "...", "valeur_fcfa": 150000, "commentaire": "..."}
  ],
  "plan_livre_anti_blabla": "plan de 3 semaines, orienté exécution",
  "architecture_sheet_intelligent": "colonnes, formules et ratios à automatiser",
  "accroche_whatsapp": "message WhatsApp de 2 phrases pour vendre l'offre dès aujourd'hui"
}`;

  const brut = await appelDeepSeek(prompt, { json: true });
  return extraireJson<Record<string, unknown>>(brut);
}

async function produireLivre(input: KitInput, strategie: Record<string, unknown>): Promise<string> {
  const prompt = `Rôle : rédacteur opérationnel senior (français d'Afrique de l'Ouest et du Centre).
${contexte(input)}

Source stratégique à respecter : ${JSON.stringify(strategie)}

Rédige un LIVRE STRATÉGIQUE complet et actionnable (2 000 à 2 500 mots) en HTML propre,
sans Markdown, sans commentaire, avec uniquement : <h1>, <h2>, <h3>, <p>, <ul>, <li>, <strong>, <table>, <tr>, <td>.
Structure imposée :
1. Le diagnostic sans filtre de "${input.nomProjet}".
2. Le modèle économique chiffré en FCFA (coûts fixes, coût de revient, prix de vente, marge, point mort).
3. Les 5 leviers de croissance, chacun avec une action à faire dans les 48 heures.
4. Les scripts exacts : message WhatsApp de prospection, relance, demande d'avis client.
5. Le tableau de bord à tenir (indicateurs + fréquence).
6. Les erreurs qui tuent l'entreprise (avec le coût en FCFA).
7. Le plan d'action jour par jour sur 21 jours.

Chaque chiffre doit sembler réaliste pour le pays indiqué. Aucune promesse magique.`;

  try {
    return nettoyerHtml(await appelGemini(prompt, { temperature: 0.8 }));
  } catch (erreur) {
    console.error("Repli DeepSeek pour le livre :", erreur);
    return nettoyerHtml(await appelDeepSeek(prompt));
  }
}

async function produirePrompts(input: KitInput, strategie: Record<string, unknown>): Promise<string> {
  const prompt = `Rôle : ingénieur en systèmes IA. ${contexte(input)}
Leviers identifiés : ${JSON.stringify(strategie.leviers_secret ?? strategie)}

Crée 10 prompts d'élite, prêts à copier dans ChatGPT, Gemini ou DeepSeek, pour le dirigeant de
"${input.nomProjet}". Chaque prompt doit être spécifique au métier et au pays, et produire un livrable
utilisable immédiatement (post WhatsApp, script d'appel, calcul de marge, plan de tournée, réponse client...).

Format HTML brut (pas de Markdown) :
<h2>1. Nom du prompt</h2>
<p><strong>Problème résolu :</strong> ...</p>
<p><strong>Prompt à copier :</strong></p>
<pre>le prompt complet avec le contexte et le format de sortie attendu</pre>
... jusqu'à 10.`;

  try {
    return nettoyerHtml(await appelGemini(prompt, { temperature: 0.75 }));
  } catch (erreur) {
    console.error("Repli DeepSeek pour les prompts :", erreur);
    return nettoyerHtml(await appelDeepSeek(prompt));
  }
}

async function produireDonneesSheet(
  input: KitInput,
  strategie: Record<string, unknown>,
): Promise<string[][] | null> {
  const prompt = `Rôle : CFO / architecte Google Sheets. ${contexte(input)}
Architecture voulue : ${String(strategie.architecture_sheet_intelligent ?? "")}

Renvoie UNIQUEMENT un objet JSON pur :
{"values": [["ligne d'en-têtes"], ["données avec formules"], ...]}

Contraintes :
- 4 à 8 colonnes maximum, 15 à 25 lignes de données réalistes.
- Formules Google Sheets en anglais (=IF, =SUM, =AVERAGE, =IFERROR) et références de cellules valides.
- Inclure un bloc "Point mort" calculé avec les prix en FCFA.
- Aucun texte hors du JSON.`;

  try {
    const brut = await appelGemini(prompt, { json: true, temperature: 0.4 });
    const objet = extraireJson<{ values?: string[][] }>(brut);
    const values = objet?.values;
    if (Array.isArray(values) && values.length > 1) return values;
    return null;
  } catch (erreur) {
    console.error("Sheet Gemini indisponible :", erreur);
    return null;
  }
}

// ----------------------------------------------------------------------------
//  GOOGLE SHEETS
// ----------------------------------------------------------------------------

async function creerGoogleSheet(titre: string, values: string[][]): Promise<string> {
  const brut = Deno.env.get("GOOGLE_WORKSPACE_CREDENTIALS");
  if (!brut) throw new Error("GOOGLE_WORKSPACE_CREDENTIALS n'est pas configurée.");

  const identifiants = JSON.parse(brut);
  const auth = new google.auth.JWT({
    email: identifiants.client_email,
    key: identifiants.private_key,
    scopes: [
      "https://www.googleapis.com/auth/spreadsheets",
      "https://www.googleapis.com/auth/drive",
    ],
  });

  const sheets = google.sheets({ version: "v4", auth });
  const drive = google.drive({ version: "v3", auth });

  const creation = await sheets.spreadsheets.create({
    requestBody: { properties: { title: titre.slice(0, 100) } },
  });
  const spreadsheetId = creation.data.spreadsheetId;
  if (!spreadsheetId) throw new Error("Création Google Sheet impossible (identifiant vide).");

  await sheets.spreadsheets.values.update({
    spreadsheetId,
    range: "A1",
    valueInputOption: "USER_ENTERED",
    requestBody: { values },
  });

  await drive.permissions.create({
    fileId: spreadsheetId,
    requestBody: { role: "writer", type: "anyone" },
  });

  return `https://docs.google.com/spreadsheets/d/${spreadsheetId}/edit`;
}

// ----------------------------------------------------------------------------
//  ORCHESTRATION
// ----------------------------------------------------------------------------

/** Génère tout ou partie du kit selon le produit acheté. */
export async function genererContenu(input: KitInput, typeProduit: TypeProduit): Promise<ContenuKit> {
  const avertissements: string[] = [];

  let strategie: Record<string, unknown> = {};
  try {
    strategie = await produireStrategie(input);
  } catch (erreur) {
    console.error("Stratégie DeepSeek indisponible :", erreur);
    avertissements.push("Analyse stratégique générée en mode dégradé.");
    strategie = {
      diagnostic_brutal: `Activité ${input.metierLabel} à structurer sur le marché ${input.paysLabel}.`,
      leviers_secret: [],
      architecture_sheet_intelligent: "Ventes, coûts, marge, point mort.",
    };
  }

  let livreHtml = "";
  let promptsTexte = "";
  let sheetUrl = "";
  let sheetData: string[][] | null = null;

  const taches: Promise<void>[] = [];

  if (typeProduit === "livre" || typeProduit === "pack") {
    taches.push(produireLivre(input, strategie).then((valeur) => {
      livreHtml = valeur;
    }));
  }

  if (typeProduit === "prompt" || typeProduit === "pack") {
    taches.push(produirePrompts(input, strategie).then((valeur) => {
      promptsTexte = valeur;
    }));
  }

  if (typeProduit === "sheet" || typeProduit === "pack") {
    taches.push(produireDonneesSheet(input, strategie).then((valeur) => {
      sheetData = valeur;
    }));
  }

  // Les trois rédactions sont indépendantes : on les lance en parallèle pour
  // rester sous la limite de 150 secondes des Edge Functions.
  await Promise.all(taches);

  if (sheetData) {
    try {
      sheetUrl = await creerGoogleSheet(`Business - ${input.nomProjet}`, sheetData);
    } catch (erreur) {
      console.error("Création Google Sheet impossible :", erreur);
      avertissements.push(
        `Le Google Sheet n'a pas pu être créé automatiquement (${erreur instanceof Error ? erreur.message : String(erreur)}).`,
      );
    }
  } else if (typeProduit === "sheet" || typeProduit === "pack") {
    avertissements.push("Les données du Google Sheet n'ont pas pu être générées.");
  }

  return { livreHtml, promptsTexte, sheetUrl, strategie, avertissements };
}

/**
 * Construit les liens directs de consultation / téléchargement.
 * Les documents restent en base (texte) et sont rendus par `view-kit`.
 */
export function construireLiens(
  kitId: string,
  accessToken: string,
  sheetUrl: string,
  typeProduit: TypeProduit,
): LiensKit {
  const base = Deno.env.get("SUPABASE_URL") ?? "";
  const url = (type: string) =>
    `${base}/functions/v1/view-kit?id=${encodeURIComponent(kitId)}&token=${encodeURIComponent(accessToken)}&type=${type}`;

  const livre = typeProduit === "livre" || typeProduit === "pack" ? url("livre") : null;
  const prompts = typeProduit === "prompt" || typeProduit === "pack" ? url("prompt") : null;
  const sheet = sheetUrl && sheetUrl.startsWith("http") ? sheetUrl : null;

  return {
    livre,
    prompts,
    sheet,
    principal: livre ?? prompts ?? sheet,
  };
}

/** Récapitulatif texte des liens (WhatsApp, email, console). */
export function liensEnTexte(liens: LiensKit): string {
  const lignes: string[] = [];
  if (liens.livre) lignes.push(`📘 Livre stratégique : ${liens.livre}`);
  if (liens.prompts) lignes.push(`🤖 Prompts IA : ${liens.prompts}`);
  if (liens.sheet) lignes.push(`📊 Google Sheet : ${liens.sheet}`);
  return lignes.join("\n");
}

/** Résumé du kit pour l'email de livraison. */
export function montantLisible(montant: number): string {
  return formaterFcfa(montant);
}
