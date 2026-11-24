// ============================================================================
//  STUDIO LIVE — activation d'abonnement et Livre Guide Live.
//
//  • `activerAbonnementStudio` : verrou atomique EN_ATTENTE|PAYE → ACTIF,
//    début + expiration à 30 jours, puis génération du guide et email Resend.
//  • `genererGuidePourAbonnement` : plan structuré DeepSeek + rédaction HTML
//    Gemini, avec repli statique complet si l'IA est indisponible. Idempotent.
//
//  Toutes les écritures passent par la clé service_role : la RLS interdit au
//  client toute écriture sur les tables Studio.
// ============================================================================

import { adminClient, utilisateurCourant } from "./supabase.ts";
import { SITE_URL, lienAideWhatsApp } from "./config.ts";
import { DUREE_STUDIO_JOURS, formaterMontant } from "./pricing.ts";
import { appelDeepSeek, appelGemini, extraireJson, nettoyerHtml } from "./ia.ts";
import { envoyerEmail, type ResultatEnvoi } from "./delivery.ts";
import { enArrierePlan } from "./background.ts";

// ----------------------------------------------------------------------------
//  TYPES
// ----------------------------------------------------------------------------

export interface StudioAbonnement {
  id: string;
  user_id: string | null;
  email: string;
  nom_activite: string;
  metier_code: string;
  metier_label: string | null;
  pays_code: string;
  pays_label: string | null;
  devise: string;
  montant_local: number;
  montant_usd: number;
  provider: string;
  status: string;
  saspay_session_id: string | null;
  saspay_payment_id: string | null;
  paddle_transaction_id: string | null;
  guide_status: string;
  guide_error: string | null;
  started_at: string | null;
  expires_at: string | null;
  paid_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface StudioGuide {
  id: string;
  subscription_id: string;
  user_id: string | null;
  email: string | null;
  metier_code: string | null;
  metier_label: string | null;
  pays_code: string | null;
  titre: string;
  contenu_html: string;
  contenu_markdown: string;
  statut: string;
  created_at: string;
  updated_at: string;
}

export interface StudioSessionLive {
  id: string;
  subscription_id: string | null;
  user_id: string | null;
  room_id: string;
  invite_token: string;
  titre: string | null;
  plateformes: string[] | null;
  format: string;
  mode_visuel: string;
  fiche_produit: Record<string, unknown> | null;
  statut: string;
  started_at: string | null;
  ended_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ResultatActivation {
  abonnement: StudioAbonnement;
  guide: StudioGuide | null;
  dejaActif: boolean;
}

interface SessionContexte {
  mode_visuel: string;
  format: string;
  plateformes: string[];
  fiche_produit: Record<string, unknown>;
  titre: string | null;
}

interface PlanGuide {
  titre?: string;
  accroche?: string[];
  sequences?: Array<{
    titre?: string;
    duree_minutes?: number;
    objectif?: string;
    script?: string;
    actions?: string[];
  }>;
  conseils_camera?: string[];
  conseils_ecran?: string[];
  techniques_vente?: string[];
  objections?: Array<{ objection?: string; reponse?: string }>;
  modeles_reponses?: Array<{ question?: string; reponse?: string }>;
  plan_action_7_jours?: Array<{ jour?: number; theme?: string; actions?: string[] }>;
}

// ----------------------------------------------------------------------------
//  LECTURES
// ----------------------------------------------------------------------------

export async function chargerAbonnement(id: string | null): Promise<StudioAbonnement | null> {
  if (!id) return null;
  const admin = adminClient();
  const { data, error } = await admin
    .from("studio_subscriptions")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) throw new Error(`Lecture de l'abonnement impossible : ${error.message}`);
  return (data as StudioAbonnement | null) ?? null;
}

export async function chargerAbonnementParSession(
  sessionId: string,
): Promise<StudioAbonnement | null> {
  if (!sessionId) return null;
  const admin = adminClient();
  const { data, error } = await admin
    .from("studio_subscriptions")
    .select("*")
    .eq("saspay_session_id", sessionId)
    .maybeSingle();
  if (error) throw new Error(`Lecture de l'abonnement impossible : ${error.message}`);
  return (data as StudioAbonnement | null) ?? null;
}

export async function chargerAbonnementParTransaction(
  transactionId: string,
): Promise<StudioAbonnement | null> {
  if (!transactionId) return null;
  const admin = adminClient();
  const { data, error } = await admin
    .from("studio_subscriptions")
    .select("*")
    .eq("paddle_transaction_id", transactionId)
    .maybeSingle();
  if (error) throw new Error(`Lecture de l'abonnement impossible : ${error.message}`);
  return (data as StudioAbonnement | null) ?? null;
}

export async function chargerGuide(subscriptionId: string): Promise<StudioGuide | null> {
  if (!subscriptionId) return null;
  const admin = adminClient();
  const { data, error } = await admin
    .from("studio_guides")
    .select("*")
    .eq("subscription_id", subscriptionId)
    .maybeSingle();
  if (error) throw new Error(`Lecture du guide impossible : ${error.message}`);
  return (data as StudioGuide | null) ?? null;
}

/** L'utilisateur connecté est-il propriétaire de l'abonnement ? */
export function abonnementAppartient(
  abonnement: StudioAbonnement,
  utilisateur: { id: string; email: string | null },
): boolean {
  if (abonnement.user_id && abonnement.user_id === utilisateur.id) return true;
  const emailAbonnement = (abonnement.email ?? "").trim().toLowerCase();
  const emailUtilisateur = (utilisateur.email ?? "").trim().toLowerCase();
  return !!emailAbonnement && emailAbonnement === emailUtilisateur;
}

/** Comparaison de chaînes à temps constant (jetons d'invitation). */
export function comparaisonConstante(a: string, b: string): boolean {
  const premier = a ?? "";
  const second = b ?? "";
  if (premier.length !== second.length) return false;
  let difference = 0;
  for (let i = 0; i < premier.length; i++) {
    difference |= premier.charCodeAt(i) ^ second.charCodeAt(i);
  }
  return difference === 0;
}

export async function chargerSessionParRoom(
  roomId: string,
): Promise<StudioSessionLive | null> {
  if (!roomId) return null;
  const admin = adminClient();
  const { data, error } = await admin
    .from("studio_live_sessions")
    .select("*")
    .eq("room_id", roomId)
    .maybeSingle();
  if (error) throw new Error(`Lecture de la session live impossible : ${error.message}`);
  return (data as StudioSessionLive | null) ?? null;
}

export interface AccesSession {
  autorise: boolean;
  proprietaire: boolean;
  tokenValide: boolean;
  abonnement: StudioAbonnement | null;
}

export interface StudioEssai {
  user_id: string;
  trial_started_at: string;
  trial_ends_at: string;
  created_at: string;
}

/** Charge l'essai gratuit d'un utilisateur (ou null s'il n'en a jamais eu). */
export async function chargerEssai(userId: string | null): Promise<StudioEssai | null> {
  if (!userId) return null;
  const admin = adminClient();
  const { data, error } = await admin
    .from("live_subscriptions")
    .select("user_id, trial_started_at, trial_ends_at, created_at")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new Error(`Lecture de l'essai Studio impossible : ${error.message}`);
  return (data as StudioEssai | null) ?? null;
}

export function essaiActif(essai: StudioEssai | null): boolean {
  if (!essai) return false;
  return new Date(essai.trial_ends_at).getTime() > Date.now();
}

/** L'accès à une salle est-il actif (abonnement payé ou essai non expiré) ? */
export async function sessionAccesActif(session: StudioSessionLive): Promise<boolean> {
  if (session.subscription_id) {
    const abonnement = await chargerAbonnement(session.subscription_id);
    if (!abonnement || abonnement.status !== "ACTIF") return false;
    if (!abonnement.expires_at) return true;
    return new Date(abonnement.expires_at).getTime() > Date.now();
  }
  if (!session.user_id) return false;
  return essaiActif(await chargerEssai(session.user_id));
}

/** Nombre de réponses IA générées aujourd'hui pour un essai (limite 20/j). */
export async function compterReponsesIaEssai(userId: string): Promise<number> {
  if (!userId) return 0;
  const admin = adminClient();
  const { data, error } = await admin.rpc("compter_reponses_ia_essai", {
    p_user: userId,
  });
  if (error) {
    console.error("Compter les réponses IA d'essai impossible :", error.message);
    return 0;
  }
  return Number(data ?? 0);
}

/**
 * Accès à une salle live : jeton d'invitation (comparaison constante) OU
 * propriétaire connecté (JWT Supabase + abonnement).
 */
export async function verifierAccesSession(
  req: Request,
  session: StudioSessionLive,
  inviteToken: string,
): Promise<AccesSession> {
  const tokenValide = !!inviteToken &&
    comparaisonConstante(inviteToken.trim(), session.invite_token ?? "");

  const abonnement = session.subscription_id
    ? await chargerAbonnement(session.subscription_id)
    : null;
  let proprietaire = false;

  if (!tokenValide) {
    const utilisateur = await utilisateurCourant(req);
    if (utilisateur) {
      if (session.user_id && session.user_id === utilisateur.id) {
        proprietaire = true;
      } else if (abonnement) {
        proprietaire = abonnementAppartient(abonnement, utilisateur);
      }
    }
  }

  return {
    autorise: tokenValide || proprietaire,
    proprietaire,
    tokenValide,
    abonnement,
  };
}

// ----------------------------------------------------------------------------
//  CONTEXTE DE GÉNÉRATION
// ----------------------------------------------------------------------------

async function chargerContexteSession(subscriptionId: string): Promise<SessionContexte> {
  const admin = adminClient();
  const { data } = await admin
    .from("studio_live_sessions")
    .select("titre, mode_visuel, format, plateformes, fiche_produit")
    .eq("subscription_id", subscriptionId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  const ligne = (data ?? {}) as Record<string, unknown>;
  const plateformes = Array.isArray(ligne.plateformes)
    ? ligne.plateformes.map((p) => String(p)).slice(0, 6)
    : [];
  const fiche = ligne.fiche_produit && typeof ligne.fiche_produit === "object"
    ? (ligne.fiche_produit as Record<string, unknown>)
    : {};

  return {
    mode_visuel: String(ligne.mode_visuel ?? "CAMERA").toUpperCase() === "ECRAN" ? "ECRAN" : "CAMERA",
    format: String(ligne.format ?? "SOLO").toUpperCase() === "DUO" ? "DUO" : "SOLO",
    plateformes,
    fiche_produit: fiche,
    titre: ligne.titre ? String(ligne.titre) : null,
  };
}

function contexteAbonnement(
  abonnement: StudioAbonnement,
  session: SessionContexte,
): string {
  const fiche = JSON.stringify(session.fiche_produit ?? {}).slice(0, 1400);
  return [
    `Activité : "${abonnement.nom_activite}".`,
    `Secteur : ${abonnement.metier_label ?? abonnement.metier_code}.`,
    `Pays : ${abonnement.pays_label ?? abonnement.pays_code} — devise locale : ${abonnement.devise}.`,
    `Mode visuel principal : ${session.mode_visuel === "ECRAN" ? "partage d'écran" : "caméra produits"}.`,
    `Format : ${session.format === "DUO" ? "duo avec un co-animateur" : "solo"}.`,
    session.plateformes.length
      ? `Plateformes visées : ${session.plateformes.join(", ")}.`
      : "Plateformes visées : salle interne, TikTok, YouTube, Instagram.",
    fiche !== "{}" ? `Fiche produit fournie : ${fiche}.` : "Aucune fiche produit fournie.",
    `Montant de l'abonnement : ${formaterMontant(abonnement.montant_local, abonnement.devise)} pour ${DUREE_STUDIO_JOURS} jours.`,
  ].join("\n");
}

// ----------------------------------------------------------------------------
//  PLAN DE SECOURS (IA indisponible) — volontairement complet
// ----------------------------------------------------------------------------

function planDeSecours(
  abonnement: StudioAbonnement,
  session: SessionContexte,
): PlanGuide {
  const activite = abonnement.nom_activite;
  const metier = abonnement.metier_label ?? abonnement.metier_code;
  const pays = abonnement.pays_label ?? abonnement.pays_code;
  const devise = abonnement.devise;

  return {
    titre: `Guide Live — ${activite}`,
    accroche: [
      `« Vous êtes en direct pour ${activite}. En 20 minutes, je vous montre comment ${metier.toLowerCase()} peut gagner plus en ${pays}, sans publicité et sans stock supplémentaire. »`,
      `« Restez jusqu'à la fin : les 10 premières personnes qui posent une question repartent avec le lien de l'offre et un bonus. »`,
      `« Si vous êtes sur mobile, tapez “MOI” dans le chat : je vous réponds personnellement. »`,
    ],
    sequences: [
      {
        titre: "1. Accroche et promesse (0–2 min)",
        duree_minutes: 2,
        objectif: "Retenir les 30 premières secondes et annoncer la promesse.",
        script: "Bonjour, je suis votre hôte. Aujourd'hui : une méthode simple, chiffrée, applicable dès ce soir. Promesse : 3 actions concrètes, aucun blabla.",
        actions: ["Afficher le titre à l'écran", "Annoncer le programme en 3 points", "Demander une réaction (cœur, commentaire)"],
      },
      {
        titre: "2. Le problème réel (2–6 min)",
        duree_minutes: 4,
        objectif: "Faire reconnaître le problème par le spectateur.",
        script: `Le vrai problème de ${metier.toLowerCase()} en ${pays}, ce n'est pas le manque de clients : c'est de ne pas savoir combien rapporte chaque client et combien coûte chaque vente.`,
        actions: ["Donner 2 exemples concrets et chiffrés", "Faire un sondage « ça vous arrive ? »"],
      },
      {
        titre: "3. La démonstration (6–14 min)",
        duree_minutes: 8,
        objectif: "Montrer le produit/service en action, preuve à l'appui.",
        script: `Je vous montre exactement comment je fais : étape 1, étape 2, étape 3. Voici le résultat, en ${devise}.`,
        actions: [
          session.mode_visuel === "ECRAN"
            ? "Partager l'écran sur le tableau de suivi ou la boutique en ligne"
            : "Présenter le produit sous 3 angles (face, détail, utilisation)",
          "Zoomer sur un détail qui rassure (qualité, provenance, garantie)",
        ],
      },
      {
        titre: "4. La preuve sociale (14–19 min)",
        duree_minutes: 5,
        objectif: "Lever le doute avec des avis et des résultats réels.",
        script: "Voici ce que disent les clients : trois avis, deux résultats chiffrés, une capture d'écran. Rien d'inventé.",
        actions: ["Afficher 2 à 3 témoignages", "Raconter une histoire client en 45 secondes"],
      },
      {
        titre: "5. L'offre et le prix (19–25 min)",
        duree_minutes: 6,
        objectif: "Rendre l'offre évidente et le prix justifiable.",
        script: `Voici ce que vous obtenez pour ${formaterMontant(abonnement.montant_local, devise)} : le contenu, l'accompagnement, et le bonus du jour. Le prix ne bougera pas après le live.`,
        actions: ["Détailler la valeur avant le prix", "Annoncer clairement la durée de l'offre", "Afficher le lien à l'écran"],
      },
      {
        titre: "6. Questions / objections (25–35 min)",
        duree_minutes: 10,
        objectif: "Traiter les 8 objections classiques sans agressivité.",
        script: "Question fréquente : « est-ce que ça marche pour moi ? » Réponse courte, preuve, puis invitation à poser LA question qui bloque.",
        actions: ["Lire les questions à voix haute", "Répondre en 30 secondes maximum", "Noter les objections récurrentes"],
      },
      {
        titre: "7. Clôture et rappel (35–45 min)",
        duree_minutes: 10,
        objectif: "Conclure sans pression, avec une dernière raison d'agir.",
        script: "On ferme dans 5 minutes. Si vous hésitez, écrivez-moi « AIDE » : je vous dis honnêtement si c'est fait pour vous. Merci d'être restés.",
        actions: ["Rappeler le lien une dernière fois", "Annoncer le prochain live", "Remercier et remercier encore"],
      },
    ],
    conseils_camera: [
      "Placez la caméra à hauteur des yeux, à 1,2 m : le visage occupe le tiers supérieur de l'écran.",
      "Éclairez le visage avec une source douce devant vous (fenêtre ou ring light), jamais derrière.",
      "Fond sombre et propre : un mur uni, le logo e-booklive, aucun désordre visible.",
      "Ayez le produit à portée de main : le passer devant l'objectif crée de la texture et de la preuve.",
      "Regardez l'objectif, pas l'écran : c'est le contact visuel qui retient.",
    ],
    conseils_ecran: [
      "Préparez un onglet unique par démonstration : tableau de bord, boutique, résultats.",
      "Masquez tout ce qui contient des données clients (noms, numéros, adresses complètes).",
      "Agrandissez la police à 125 % avant de démarrer : le texte doit être lisible sur téléphone.",
      "Déplacez la souris lentement et commentez chaque clic à voix haute.",
      "Gardez votre visage en vignette pour humaniser le partage d'écran.",
    ],
    techniques_vente: [
      "La règle des 3 preuves : un chiffre, un témoignage, une démonstration.",
      "Le prix se donne après la valeur, jamais avant la démonstration.",
      "Créer une raison d'agir maintenant : bonus du live, places limitées réellement.",
      "Répondre aux objections par une question, pas par une contradiction.",
      "Proposer une seule action claire (le lien), pas trois.",
      "Faire participer : sondages, « tapez 1 », appels à l'action toutes les 5 minutes.",
      "Répéter l'offre 3 fois dans le live (ouverture, milieu, clôture).",
      "Terminer par une preuve sociale fraîche : un client qui vient d'acheter.",
    ],
    objections: [
      {
        objection: "C'est trop cher.",
        reponse: "Je comprends. Comparez avec ce que vous coûte le problème chaque mois. Si l'offre ne se rembourse pas en une seule vente, ne la prenez pas — mais regardez le calcul ensemble.",
      },
      {
        objection: "Je n'ai pas le temps.",
        reponse: "C'est justement pour ça que le guide est en 7 jours, 20 minutes par jour. Pas de théorie : une action par jour.",
      },
      {
        objection: "Je ne suis pas sûr que ça marche pour mon activité.",
        reponse: "Dites-moi en une phrase votre activité et votre pays : je vous réponds honnêtement. Le guide s'adapte à votre métier, pas l'inverse.",
      },
      {
        objection: "Je préfère en parler à mon conjoint / associé.",
        reponse: "Bien sûr. Je vais vous donner le résumé en 3 lignes à lui montrer, et vous décidez après. Le lien reste ouvert 24 h.",
      },
      {
        objection: "Je ne fais pas confiance aux paiements en ligne.",
        reponse: "Le paiement passe par un prestataire sécurisé (SasPay ou Paddle), pas par nos serveurs. Nous ne voyons jamais vos données bancaires.",
      },
      {
        objection: "Je peux trouver ça gratuitement sur Internet.",
        reponse: "Oui, et vous passerez des semaines à trier. Ici, tout est déjà adapté à votre métier et à votre pays, avec des montants dans votre devise.",
      },
      {
        objection: "Je veux d'abord voir un résultat.",
        reponse: "Regardez la démonstration de maintenant : c'est exactement ce que vous ferez demain. Je vous montre le résultat avant que vous payiez.",
      },
      {
        objection: "Et si ça ne me plaît pas ?",
        reponse: "Écrivez-nous sur WhatsApp dans les 7 jours : nous regardons ensemble. Nous préférons un client satisfait à une vente forcée.",
      },
    ],
    modeles_reponses: [
      {
        question: "Comment je reçois le guide ?",
        reponse: `Après le paiement, le guide est généré automatiquement et envoyé par email. Il est aussi disponible dans votre régie : ${SITE_URL}/studio/regie.`,
      },
      {
        question: "Est-ce que le guide est personnalisé ?",
        reponse: "Oui : il est écrit pour votre activité, votre pays et votre devise. Le script d'accroche et les objections sont adaptés à votre métier.",
      },
      {
        question: "Puis-je inviter un co-animateur ?",
        reponse: "Oui, le format DUO génère un lien d'invitation à partager. Votre co-animateur rejoint la salle sans accéder à votre compte.",
      },
      {
        question: "Combien de temps dure l'abonnement ?",
        reponse: `30 jours à partir de l'activation, pour ${formaterMontant(abonnement.montant_local, devise)}.`,
      },
    ],
    plan_action_7_jours: [
      { jour: 1, theme: "Préparer l'offre", actions: ["Choisir un seul produit à pousser", "Calculer la marge et le prix", "Remplir la fiche produit de la régie"] },
      { jour: 2, theme: "Écrire l'accroche", actions: ["Rédiger 3 accroches de 20 secondes", "Tester à voix haute", "Choisir celle qui donne envie"] },
      { jour: 3, theme: "Préparer le décor", actions: ["Installer la lumière et le fond", "Tester le son", "Préparer les produits à montrer"] },
      { jour: 4, theme: "Répéter le live", actions: ["Dérouler les 7 séquences à blanc", "Chronométrer", "Noter les questions probables"] },
      { jour: 5, theme: "Lancer le premier live", actions: ["Annoncer le live 2 h avant", "Ouvrir la salle et inviter", "Suivre le script sans lire"] },
      { jour: 6, theme: "Analyser", actions: ["Revoir les moments de pic", "Noter les 3 questions récurrentes", "Corriger l'accroche"] },
      { jour: 7, theme: "Vendre et relancer", actions: ["Relancer les indécis en message privé", "Publier un extrait du live", "Planifier le live suivant"] },
    ],
  };
}

// ----------------------------------------------------------------------------
//  NORMALISATION DU PLAN (garantit 7 séquences et 8 objections)
// ----------------------------------------------------------------------------

function completerListe<T>(
  fourni: T[] | undefined,
  secours: T[] | undefined,
  minimum: number,
): T[] {
  const liste = [...(fourni ?? [])];
  for (const element of secours ?? []) {
    if (liste.length >= minimum) break;
    liste.push(element);
  }
  return liste;
}

/** Complète un plan IA partiel avec le plan de secours (guide toujours complet). */
function completerPlan(plan: PlanGuide, secours: PlanGuide): PlanGuide {
  return {
    ...plan,
    titre: plan.titre?.trim() || secours.titre,
    accroche: completerListe(plan.accroche, secours.accroche, 3),
    sequences: completerListe(plan.sequences, secours.sequences, 7).slice(0, 7),
    conseils_camera: completerListe(plan.conseils_camera, secours.conseils_camera, 5),
    conseils_ecran: completerListe(plan.conseils_ecran, secours.conseils_ecran, 5),
    techniques_vente: completerListe(plan.techniques_vente, secours.techniques_vente, 6),
    objections: completerListe(plan.objections, secours.objections, 8).slice(0, 8),
    modeles_reponses: completerListe(
      plan.modeles_reponses,
      secours.modeles_reponses,
      4,
    ),
    plan_action_7_jours: completerListe(
      plan.plan_action_7_jours,
      secours.plan_action_7_jours,
      7,
    ).slice(0, 7),
  };
}

// ----------------------------------------------------------------------------
//  RENDU MARKDOWN / HTML STATIQUE
// ----------------------------------------------------------------------------

function liste(items: string[] | undefined, prefixe = "- "): string {
  return (items ?? []).filter(Boolean).map((item) => `${prefixe}${item}`).join("\n");
}

function planEnMarkdown(plan: PlanGuide, abonnement: StudioAbonnement): string {
  const lignes: string[] = [];
  lignes.push(`# ${plan.titre ?? `Guide Live — ${abonnement.nom_activite}`}`);
  lignes.push("");
  lignes.push(`**Activité :** ${abonnement.nom_activite}  `);
  lignes.push(`**Secteur :** ${abonnement.metier_label ?? abonnement.metier_code}  `);
  lignes.push(`**Pays :** ${abonnement.pays_label ?? abonnement.pays_code} — ${abonnement.devise}`);
  lignes.push("");

  lignes.push("## 1. Script d'accroche");
  lignes.push(liste(plan.accroche, "- "));
  lignes.push("");

  lignes.push("## 2. Structure du live (7 séquences)");
  for (const sequence of plan.sequences ?? []) {
    lignes.push(`### ${sequence.titre ?? "Séquence"}`);
    if (sequence.duree_minutes !== undefined) lignes.push(`*Durée : ${sequence.duree_minutes} min*`);
    if (sequence.objectif) lignes.push(`**Objectif :** ${sequence.objectif}`);
    if (sequence.script) lignes.push(`**Script :** ${sequence.script}`);
    if (sequence.actions?.length) lignes.push(liste(sequence.actions));
    lignes.push("");
  }

  lignes.push("## 3. Conseils caméra");
  lignes.push(liste(plan.conseils_camera));
  lignes.push("");
  lignes.push("### Partage d'écran");
  lignes.push(liste(plan.conseils_ecran));
  lignes.push("");

  lignes.push("## 4. Techniques de vente live");
  lignes.push(liste(plan.techniques_vente));
  lignes.push("");

  lignes.push("## 5. Réponses aux objections");
  for (const objection of plan.objections ?? []) {
    lignes.push(`### « ${objection.objection ?? "Objection"} »`);
    lignes.push(objection.reponse ?? "");
    lignes.push("");
  }

  lignes.push("## 6. Modèles de réponses");
  for (const modele of plan.modeles_reponses ?? []) {
    lignes.push(`**${modele.question ?? "Question"}**`);
    lignes.push(modele.reponse ?? "");
    lignes.push("");
  }

  lignes.push("## 7. Plan d'action 7 jours");
  for (const jour of plan.plan_action_7_jours ?? []) {
    lignes.push(`### Jour ${jour.jour ?? "?"} — ${jour.theme ?? ""}`);
    lignes.push(liste(jour.actions));
    lignes.push("");
  }

  return lignes.join("\n").trim();
}

function echapper(valeur: string): string {
  return (valeur ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/**
 * Nettoyage défensif du HTML produit par l'IA : aucun script, iframe, objet
 * embarqué ni gestionnaire d'événement inline (le guide est affiché en régie).
 */
function assainirHtml(html: string): string {
  return (html ?? "")
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<iframe[\s\S]*?<\/iframe>/gi, "")
    .replace(/<(object|embed|link|meta)[^>]*>/gi, "")
    .replace(/\son\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, "")
    .replace(/javascript:/gi, "");
}

function guideHtmlStatique(
  plan: PlanGuide,
  abonnement: StudioAbonnement,
  session: SessionContexte,
): string {
  const or = "#F7D488";
  const emeraude = "#34D399";
  const sequences = (plan.sequences ?? [])
    .map(
      (sequence) => `
      <section class="carte">
        <h3>${echapper(sequence.titre ?? "Séquence")}</h3>
        <p class="meta">${sequence.duree_minutes ? `${sequence.duree_minutes} min` : ""}${sequence.objectif ? ` · ${echapper(sequence.objectif)}` : ""}</p>
        ${sequence.script ? `<p class="script">« ${echapper(sequence.script)} »</p>` : ""}
        ${sequence.actions?.length ? `<ul>${sequence.actions.map((a) => `<li>${echapper(a)}</li>`).join("")}</ul>` : ""}
      </section>`,
    )
    .join("");

  const objections = (plan.objections ?? [])
    .map(
      (objection) => `
      <div class="objection">
        <p class="question">« ${echapper(objection.objection ?? "")} »</p>
        <p>${echapper(objection.reponse ?? "")}</p>
      </div>`,
    )
    .join("");

  const jours = (plan.plan_action_7_jours ?? [])
    .map(
      (jour) => `
      <div class="jour">
        <p class="jour-titre">Jour ${jour.jour ?? "?"} — ${echapper(jour.theme ?? "")}</p>
        <ul>${(jour.actions ?? []).map((a) => `<li>${echapper(a)}</li>`).join("")}</ul>
      </div>`,
    )
    .join("");

  const modeles = (plan.modeles_reponses ?? [])
    .map(
      (modele) => `
      <div class="objection">
        <p class="question">${echapper(modele.question ?? "")}</p>
        <p>${echapper(modele.reponse ?? "")}</p>
      </div>`,
    )
    .join("");

  return `<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${echapper(plan.titre ?? `Guide Live — ${abonnement.nom_activite}`)}</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin:0; background:#090D16; color:#E2E8F0; font-family:'Segoe UI',Arial,sans-serif; line-height:1.65; }
  .page { max-width:820px; margin:0 auto; padding:40px 22px 72px; }
  .badge { display:inline-block; color:${or}; border:1px solid rgba(247,212,136,.45); border-radius:999px; padding:6px 14px; font-size:12px; letter-spacing:.14em; text-transform:uppercase; }
  h1 { font-size:34px; line-height:1.2; margin:18px 0 10px; background:linear-gradient(90deg,${or},#E7B84B,${emeraude}); -webkit-background-clip:text; background-clip:text; color:transparent; }
  h2 { font-size:22px; margin:38px 0 14px; color:${or}; border-bottom:1px solid #1E293B; padding-bottom:8px; }
  h3 { font-size:17px; margin:18px 0 6px; color:#F8FAFC; }
  .meta { color:#94A3B8; font-size:13px; margin:0 0 8px; }
  .carte, .objection, .jour { background:#111827; border:1px solid #1E293B; border-radius:16px; padding:16px 18px; margin:12px 0; }
  .script { color:${emeraude}; font-style:italic; }
  .question { color:${or}; font-weight:600; margin:0 0 6px; }
  .jour-titre { color:${emeraude}; font-weight:600; margin:0 0 6px; }
  ul { margin:8px 0 0; padding-left:20px; }
  li { margin:4px 0; }
  .hero { background:linear-gradient(135deg,rgba(247,212,136,.12),rgba(52,211,153,.10)); border:1px solid rgba(247,212,136,.3); border-radius:20px; padding:22px; }
  .pied { margin-top:40px; color:#64748B; font-size:12px; text-align:center; }
  a { color:${or}; }
</style></head>
<body><div class="page">
  <span class="badge">Studio Live · Guide offert</span>
  <h1>${echapper(plan.titre ?? `Guide Live — ${abonnement.nom_activite}`)}</h1>
  <p class="meta">${echapper(abonnement.nom_activite)} · ${echapper(abonnement.metier_label ?? abonnement.metier_code)} · ${echapper(abonnement.pays_label ?? abonnement.pays_code)} · ${echapper(abonnement.devise)}</p>

  <div class="hero">
    <h2 style="margin-top:0">1. Script d'accroche</h2>
    <ul>${(plan.accroche ?? []).map((a) => `<li>${echapper(a)}</li>`).join("")}</ul>
  </div>

  <h2>2. Structure du live en 7 séquences</h2>
  ${sequences}

  <h2>3. Conseils ${session.mode_visuel === "ECRAN" ? "partage d'écran" : "caméra"}</h2>
  <div class="carte"><ul>${(plan.conseils_camera ?? []).map((c) => `<li>${echapper(c)}</li>`).join("")}</ul></div>
  <div class="carte"><h3>Partage d'écran</h3><ul>${(plan.conseils_ecran ?? []).map((c) => `<li>${echapper(c)}</li>`).join("")}</ul></div>

  <h2>4. Techniques de vente live</h2>
  <div class="carte"><ul>${(plan.techniques_vente ?? []).map((t) => `<li>${echapper(t)}</li>`).join("")}</ul></div>

  <h2>5. Réponses aux 8 objections</h2>
  ${objections}

  <h2>6. Modèles de réponses</h2>
  ${modeles}

  <h2>7. Plan d'action 7 jours</h2>
  ${jours}

  <div class="pied">
    Guide généré pour ${echapper(abonnement.email)} — e-booklive<br>
    Régie : <a href="${SITE_URL}/studio/regie">${SITE_URL}/studio/regie</a> ·
    Aide : <a href="${lienAideWhatsApp()}">WhatsApp</a>
  </div>
</div></body></html>`;
}

// ----------------------------------------------------------------------------
//  GÉNÉRATION IA
// ----------------------------------------------------------------------------

async function produirePlan(
  abonnement: StudioAbonnement,
  session: SessionContexte,
): Promise<PlanGuide> {
  const prompt = `Rôle : coach de vente live et directeur artistique, spécialiste des marchés d'Afrique francophone et du commerce sur mobile.
${contexteAbonnement(abonnement, session)}

Prépare un GUIDE DE LIVE complet, en français, immédiatement utilisable par le dirigeant.
Contraintes :
- Un script d'accroche en 3 variantes de 20 à 30 secondes.
- Une structure de live en EXACTEMENT 7 séquences, avec durée en minutes et script mot à mot.
- Des conseils caméra ET des conseils partage d'écran adaptés au mode ${session.mode_visuel}.
- Des techniques de vente live concrètes (preuve, urgence honnête, appel à l'action).
- EXACTEMENT 8 objections clients avec une réponse courte et honnête.
- 4 modèles de réponses aux questions fréquentes.
- Un plan d'action sur 7 jours, une action par jour.
- Les montants doivent être dans la devise ${abonnement.devise}, réalistes pour ${abonnement.pays_label ?? abonnement.pays_code}.
- Aucune promesse de gain magique, aucun chiffre inventé présenté comme garanti.

Réponds UNIQUEMENT avec ce JSON valide :
{
  "titre": "...",
  "accroche": ["...", "...", "..."],
  "sequences": [{"titre":"...","duree_minutes":2,"objectif":"...","script":"...","actions":["..."]}],
  "conseils_camera": ["..."],
  "conseils_ecran": ["..."],
  "techniques_vente": ["..."],
  "objections": [{"objection":"...","reponse":"..."}],
  "modeles_reponses": [{"question":"...","reponse":"..."}],
  "plan_action_7_jours": [{"jour":1,"theme":"...","actions":["..."]}]
}`;

  const brut = await appelDeepSeek(prompt, {
    json: true,
    temperature: 0.75,
    maxTokens: 4096,
    timeoutMs: 45_000,
  });
  const plan = extraireJson<PlanGuide>(brut);

  // Garde-fous : la structure minimale doit être présente.
  if (!Array.isArray(plan.sequences) || plan.sequences.length < 5) {
    throw new Error("Plan IA incomplet (séquences manquantes).");
  }
  if (!Array.isArray(plan.objections) || plan.objections.length < 5) {
    throw new Error("Plan IA incomplet (objections manquantes).");
  }
  return plan;
}

async function produireHtmlGuide(
  plan: PlanGuide,
  abonnement: StudioAbonnement,
  session: SessionContexte,
): Promise<string> {
  const prompt = `Rôle : rédacteur web senior et designer HTML.
${contexteAbonnement(abonnement, session)}

Transforme ce plan en un LIVRE GUIDE LIVE complet, en HTML autonome (un seul fichier),
en français, prêt à lire sur mobile.

Plan source : ${JSON.stringify(plan).slice(0, 9000)}

Exigences :
- Document HTML complet avec <!DOCTYPE html>, <head>, styles inline dans <style>, aucun script, aucune ressource externe.
- Design sombre (fond #090D16, surfaces #111827, bordures #1E293B) avec accents or (#F7D488 → #E7B84B) et émeraude (#34D399).
- Titre principal, rappel de l'activité, du secteur, du pays et de la devise.
- Toutes les sections du plan : accroche, 7 séquences avec timings, conseils caméra/partage d'écran, techniques de vente, 8 objections, modèles de réponses, plan d'action 7 jours.
- Texte aéré, lisible sur téléphone, aucune donnée personnelle inventée.
- Termine par un rappel de la régie ${SITE_URL}/studio/regie.

Réponds UNIQUEMENT avec le code HTML, sans commentaire ni balise Markdown.`;

  return nettoyerHtml(
    await appelGemini(prompt, { temperature: 0.8, maxTokens: 8192, timeoutMs: 75_000 }),
  );
}

// ----------------------------------------------------------------------------
//  GÉNÉRATION ET PERSISTANCE DU GUIDE
// ----------------------------------------------------------------------------

function illustrationGuide(index: number): string {
  const svg = [
    `<svg viewBox="0 0 760 110" aria-hidden="true"><rect x="10" y="12" width="220" height="86" rx="14" fill="#0B1B33" stroke="#E7B84B" stroke-opacity=".45"/><rect x="34" y="34" width="145" height="9" rx="4" fill="#E7B84B" opacity=".8"/><rect x="34" y="56" width="110" height="7" rx="3" fill="#34D399" opacity=".6"/><rect x="34" y="76" width="128" height="7" rx="3" fill="#94A3B8" opacity=".45"/><path d="M260 55 H340" stroke="#E7B84B" stroke-dasharray="6 6"/><circle cx="372" cy="55" r="22" fill="#0B1B33" stroke="#34D399" stroke-width="2"/><path d="M363 55 l7 7 l14 -16" fill="none" stroke="#34D399" stroke-width="4"/><rect x="425" y="16" width="310" height="80" rx="14" fill="#0B1B33" stroke="#34D399" stroke-opacity=".35"/><path d="M450 78 L510 42 L560 62 L630 26 L700 38" fill="none" stroke="#E7B84B" stroke-width="3"/></svg>`,
    `<svg viewBox="0 0 760 110" aria-hidden="true"><rect x="30" y="16" width="200" height="78" rx="16" fill="#0B1B33" stroke="#E7B84B" stroke-opacity=".4"/><circle cx="130" cy="55" r="25" fill="none" stroke="#34D399" stroke-width="3"/><circle cx="130" cy="55" r="9" fill="#E7B84B"/><circle cx="255" cy="30" r="6" fill="#F87171"/><rect x="270" y="22" width="85" height="16" rx="8" fill="#111827" stroke="#F87171" stroke-opacity=".4"/><text x="280" y="33" fill="#F87171" font-size="9" font-family="Arial" font-weight="bold">LIVE</text><rect x="390" y="14" width="345" height="84" rx="14" fill="#0B1B33" stroke="#34D399" stroke-opacity=".35"/><rect x="412" y="34" width="170" height="9" rx="4" fill="#34D399" opacity=".75"/><rect x="412" y="56" width="130" height="7" rx="3" fill="#94A3B8" opacity=".5"/><rect x="412" y="74" width="155" height="7" rx="3" fill="#E7B84B" opacity=".55"/></svg>`,
  ];
  return `<figure class="guide-illu">${svg[index % svg.length]}</figure>`;
}

function habillerGuideEditorial(html: string, abonnement: StudioAbonnement): string {
  if (!html.includes("<body") || !html.includes("</head>")) return html;
  const couverture = `<section class="guide-cover">
    <p class="guide-kicker">Édition premium · Studio Live</p>
    <h1>Votre Livre Guide Live</h1>
    <p class="guide-sous-titre">${echapper(abonnement.nom_activite)} · ${echapper(abonnement.metier_label ?? abonnement.metier_code)}</p>
    <div class="guide-badges">
      <span>${echapper(abonnement.metier_label ?? abonnement.metier_code)}</span>
      <span>${echapper(abonnement.pays_label ?? abonnement.pays_code)}</span>
      <span>${echapper(abonnement.devise)}</span>
    </div>
  </section>`;
  const conseils = [
    "Préparez votre fiche produit avant d'ouvrir la salle : prix, stock, taille et lien de commande.",
    "Les 10 premières secondes décident du départ : annoncez le produit et l'offre immédiatement.",
    "Une seule action à la fois : montrez, expliquez, prouvez, puis donnez le lien.",
  ];
  let index = 0;
  let conseilIndex = 0;
  const css = `<style>
    .guide-cover{margin:0 0 28px;padding:30px 24px;border-radius:20px;color:#F3E9D2;background:
      radial-gradient(circle at 12% 18%,rgba(52,211,153,.2),transparent 38%),
      radial-gradient(circle at 88% 12%,rgba(231,184,75,.24),transparent 40%),
      linear-gradient(145deg,#07101F,#0B1B33 55%,#0D2A27);border:1px solid rgba(231,184,75,.28)}
    .guide-kicker{margin:0;color:#34D399;font-size:10px;letter-spacing:.24em;text-transform:uppercase;font-weight:800}
    .guide-cover h1{font-family:Georgia,serif;font-size:34px;line-height:1.1;margin:14px 0 8px;color:#fff}
    .guide-sous-titre{margin:0 0 14px;color:#A7B0C0;font-size:14px}
    .guide-badges{display:flex;gap:7px;flex-wrap:wrap}
    .guide-badges span{border:1px solid rgba(231,184,75,.35);background:rgba(231,184,75,.08);color:#F6D98A;border-radius:999px;padding:5px 10px;font-size:10px;font-weight:700}
    .guide-illu{display:block;margin:22px 0 2px;padding:0;border-radius:14px;overflow:hidden;background:#0B1B33;border:1px solid rgba(231,184,75,.2)}
    .guide-illu svg{display:block;width:100%;height:auto}
    .guide-conseil{margin:12px 0 20px;padding:13px 15px;border-left:3px solid #E7B84B;background:rgba(231,184,75,.08);border-radius:0 10px 10px 0;color:#D8C9AA;font-size:13px;line-height:1.6}
    .guide-conseil strong{display:block;color:#E7B84B;font-size:9.5px;letter-spacing:.1em;text-transform:uppercase;margin-bottom:4px}
    @media print{.guide-cover{background:#fff!important;color:#111!important}.guide-cover h1{color:#111}.guide-illu{page-break-inside:avoid}}
  </style>`;
  let resultat = html.replace("</head>", `${css}</head>`);
  resultat = resultat.replace(/(<body[^>]*>)/i, `$1${couverture}`);
  resultat = resultat.replace(/<h2(\s|>)/gi, (correspondance) => {
    const tip = conseils[conseilIndex++ % conseils.length];
    const bloc = `${illustrationGuide(index++)}<aside class="guide-conseil"><strong>Conseil Pro</strong>${echapper(tip)}</aside>`;
    return `${bloc}${correspondance}`;
  });
  return resultat;
}


export async function genererGuidePourAbonnement(
  subscriptionId: string,
): Promise<StudioGuide | null> {
  const admin = adminClient();
  const abonnement = await chargerAbonnement(subscriptionId);
  if (!abonnement) throw new Error("Abonnement Studio introuvable.");

  const existant = await chargerGuide(subscriptionId);
  if (existant && existant.statut === "PRET" && existant.contenu_html.trim()) {
    return existant;
  }

  // Verrou atomique : un seul processus génère le guide.
  const { data: verrou } = await admin
    .from("studio_subscriptions")
    .update({ guide_status: "EN_COURS", guide_error: null })
    .eq("id", subscriptionId)
    .in("guide_status", ["EN_ATTENTE", "ERREUR"])
    .select("id")
    .maybeSingle();

  if (!verrou) {
    const actuel = await chargerAbonnement(subscriptionId);
    if (actuel?.guide_status === "EN_COURS") {
      // Une autre exécution est en cours : on attend un peu le résultat.
      for (let essai = 0; essai < 6; essai++) {
        await new Promise((resolve) => setTimeout(resolve, 4000));
        const guide = await chargerGuide(subscriptionId);
        if (guide?.statut === "PRET" && guide.contenu_html.trim()) return guide;
      }
      return null;
    }
    const guide = await chargerGuide(subscriptionId);
    return guide?.statut === "PRET" && guide.contenu_html.trim() ? guide : null;
  }

  const session = await chargerContexteSession(subscriptionId);

  try {
    const secours = planDeSecours(abonnement, session);
    let plan: PlanGuide;
    try {
      plan = completerPlan(await produirePlan(abonnement, session), secours);
    } catch (erreur) {
      console.error("Plan DeepSeek indisponible, plan de secours :", erreur);
      plan = secours;
    }

    let html: string;
    try {
      html = await produireHtmlGuide(plan, abonnement, session);
    } catch (erreur) {
      console.error("Rédaction Gemini indisponible, HTML statique :", erreur);
      html = guideHtmlStatique(plan, abonnement, session);
    }
    if (!html || html.length < 800) {
      html = guideHtmlStatique(plan, abonnement, session);
    }
    html = assainirHtml(html);
    html = habillerGuideEditorial(html, abonnement);

    const titre = (plan.titre ?? `Guide Live — ${abonnement.nom_activite}`).slice(0, 160);
    const markdown = planEnMarkdown(plan, abonnement);

    const { data: guideEnregistre, error: erreurGuide } = await admin
      .from("studio_guides")
      .upsert(
        {
          subscription_id: subscriptionId,
          user_id: abonnement.user_id,
          email: abonnement.email,
          metier_code: abonnement.metier_code,
          metier_label: abonnement.metier_label,
          pays_code: abonnement.pays_code,
          titre,
          contenu_html: html,
          contenu_markdown: markdown,
          statut: "PRET",
        },
        { onConflict: "subscription_id" },
      )
      .select("*")
      .single();

    if (erreurGuide || !guideEnregistre) {
      throw new Error(`Enregistrement du guide impossible : ${erreurGuide?.message ?? "inconnu"}`);
    }

    await admin
      .from("studio_subscriptions")
      .update({ guide_status: "PRET", guide_error: null })
      .eq("id", subscriptionId);

    // Email envoyé une seule fois : uniquement lors du passage à PRET.
    const envoi: ResultatEnvoi = await envoyerEmail({
      to: abonnement.email,
      subject: `Votre Livre Guide Live est prêt — ${abonnement.nom_activite}`,
      html: emailGuideHtml({
        nomActivite: abonnement.nom_activite,
        metierLabel: abonnement.metier_label ?? abonnement.metier_code,
        paysLabel: abonnement.pays_label ?? abonnement.pays_code,
        montant: abonnement.montant_local,
        devise: abonnement.devise,
        titre,
      }),
    });
    if (!envoi.ok) {
      console.error("Email du guide non envoyé :", envoi.error);
    }

    return guideEnregistre as StudioGuide;
  } catch (erreur) {
    const message = erreur instanceof Error ? erreur.message : String(erreur);
    await admin
      .from("studio_subscriptions")
      .update({ guide_status: "ERREUR", guide_error: message.slice(0, 900) })
      .eq("id", subscriptionId);
    throw erreur;
  }
}

// ----------------------------------------------------------------------------
//  ACTIVATION DE L'ABONNEMENT
// ----------------------------------------------------------------------------

/**
 * Active un abonnement payé : ACTIF + 30 jours, puis génération du guide.
 * Idempotent : un abonnement déjà actif n'est pas reprolongé.
 *
 * @param options.attendreGuide false pour rendre la main immédiatement et
 *        générer le guide en tâche de fond (webhooks, retour de paiement).
 */
export async function activerAbonnementStudio(
  subscriptionId: string,
  options: { attendreGuide?: boolean } = {},
): Promise<ResultatActivation> {
  const admin = adminClient();
  const attendreGuide = options.attendreGuide !== false;

  const existant = await chargerAbonnement(subscriptionId);
  if (!existant) throw new Error("Abonnement Studio introuvable.");

  if (existant.status === "ACTIF") {
    const guide = await chargerGuide(subscriptionId);
    if (guide?.statut === "PRET" && guide.contenu_html.trim()) {
      return { abonnement: existant, guide, dejaActif: true };
    }
    if (attendreGuide) {
      const genere = await genererGuidePourAbonnement(subscriptionId).catch((erreur) => {
        console.error("Génération du guide en échec :", erreur);
        return null;
      });
      const rafraichi = (await chargerAbonnement(subscriptionId)) ?? existant;
      return { abonnement: rafraichi, guide: genere, dejaActif: true };
    }
    enArrierePlan(genererGuidePourAbonnement(subscriptionId));
    return { abonnement: existant, guide: null, dejaActif: true };
  }

  const maintenant = new Date();
  const expiration = new Date(maintenant.getTime() + DUREE_STUDIO_JOURS * 24 * 60 * 60 * 1000);

  const { data: verrou } = await admin
    .from("studio_subscriptions")
    .update({
      status: "ACTIF",
      started_at: maintenant.toISOString(),
      expires_at: expiration.toISOString(),
      paid_at: maintenant.toISOString(),
    })
    .eq("id", subscriptionId)
    .in("status", ["EN_ATTENTE", "PAYE", "ECHEC"])
    .select("*")
    .maybeSingle();

  if (!verrou) {
    const actuel = await chargerAbonnement(subscriptionId);
    if (actuel?.status === "ACTIF") {
      const guide = await chargerGuide(subscriptionId);
      return { abonnement: actuel, guide, dejaActif: true };
    }
    throw new Error(
      `Activation impossible : l'abonnement est au statut ${actuel?.status ?? "inconnu"}.`,
    );
  }

  const abonnement = verrou as StudioAbonnement;

  if (!attendreGuide) {
    enArrierePlan(genererGuidePourAbonnement(subscriptionId));
    return { abonnement, guide: null, dejaActif: false };
  }

  let guide: StudioGuide | null = null;
  try {
    guide = await genererGuidePourAbonnement(subscriptionId);
  } catch (erreur) {
    // L'abonnement reste ACTIF : le guide pourra être régénéré depuis la régie.
    console.error("Guide non généré à l'activation :", erreur);
  }

  const rafraichi = (await chargerAbonnement(subscriptionId)) ?? abonnement;
  return { abonnement: rafraichi, guide, dejaActif: false };
}

// ----------------------------------------------------------------------------
//  EMAIL DU GUIDE
// ----------------------------------------------------------------------------

/**
 * Email « Livre Guide Live » : design sombre / or-émeraude, bouton vers la régie,
 * mention du guide offert.
 */
export function emailGuideHtml(params: {
  nomActivite: string;
  metierLabel: string;
  paysLabel: string;
  montant: number;
  devise: string;
  titre: string;
}): string {
  const or = "#F7D488";
  const emeraude = "#34D399";
  const bouton =
    `<a href="${SITE_URL}/studio/regie" style="display:inline-block;background:linear-gradient(90deg,${or},#E7B84B);color:#090D16;font-weight:800;text-decoration:none;padding:15px 26px;border-radius:14px;">🎬 Ouvrir ma régie Studio Live</a>`;

  return `<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#090D16;font-family:'Segoe UI',Arial,sans-serif;color:#E2E8F0;">
  <div style="max-width:600px;margin:0 auto;padding:34px 20px;">
    <p style="font-size:13px;letter-spacing:.16em;text-transform:uppercase;color:${or};margin:0 0 20px 0;">e-booklive · Studio Live</p>
    <h1 style="font-size:28px;line-height:1.25;margin:0 0 12px 0;color:#F8FAFC;">Votre Livre Guide Live est prêt 🎁</h1>
    <p style="font-size:16px;line-height:1.7;color:#94A3B8;margin:0 0 22px 0;">
      Bonjour, votre guide <strong style="color:${or};">${echapper(params.titre)}</strong> pour
      <strong style="color:#F8FAFC;">${echapper(params.nomActivite)}</strong>
      (${echapper(params.metierLabel)} — ${echapper(params.paysLabel)}) vient d'être généré.
      Il est <strong style="color:${emeraude};">offert</strong> avec votre abonnement Studio Live.
    </p>

    <div style="background:#111827;border:1px solid #1E293B;border-radius:18px;padding:22px;margin:0 0 22px 0;">
      <p style="margin:0 0 14px 0;font-size:15px;color:#F8FAFC;"><strong>Ce que contient votre guide</strong></p>
      <p style="margin:0;line-height:1.9;font-size:14px;color:#94A3B8;">
        🎯 Script d'accroche en 3 variantes<br>
        🗺️ Structure du live en 7 séquences chronométrées<br>
        🎥 Conseils caméra et partage d'écran<br>
        💬 8 objections clients et leurs réponses<br>
        🚀 Plan d'action sur 7 jours, une action par jour
      </p>
    </div>

    <p style="margin:0 0 26px 0;">${bouton}</p>

    <p style="font-size:14px;line-height:1.7;color:#94A3B8;margin:0 0 10px 0;">
      Votre abonnement est actif pour <strong style="color:#F8FAFC;">30 jours</strong>,
      soit ${echapper(formaterMontant(params.montant, params.devise))}. Le guide reste accessible
      dans votre régie pendant toute la durée de l'abonnement.
    </p>
    <p style="font-size:14px;line-height:1.7;color:#94A3B8;margin:0 0 24px 0;">
      Un doute avant votre premier live ?
      <a href="${lienAideWhatsApp()}" style="color:${or};">Écrivez-nous sur WhatsApp</a>,
      nous répondons avant chaque direct.
    </p>
    <p style="font-size:12px;color:#64748B;">
      © e-booklive — ${SITE_URL}<br>
      Vous recevez cet email parce que votre abonnement Studio Live est actif.
    </p>
  </div>
</body></html>`;
}
