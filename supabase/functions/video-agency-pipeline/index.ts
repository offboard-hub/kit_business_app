// ============================================================================
//  video-agency-pipeline — AGENCE VIDÉO IA (4 agents) + DISTRIBUTION
//
//  ⚠️ RÈGLE ZÉRO STOCKAGE SUPABASE (plan gratuit 1 Go) :
//     le fichier .mp4 n'est JAMAIS écrit dans Supabase Storage. On ne stocke
//     que du texte (scripts, sous-titres, copy) et le flux vidéo part
//     directement vers YouTube / TikTok depuis la mémoire de la fonction.
//
//  Actions :
//    POST {action:"analyze"}  → agents 1, 2 et 3
//    POST {action:"update"}   → enregistre les corrections manuelles
//    POST {action:"publish"}  → agent 4 (YouTube privé + TikTok brouillon)
//    GET  ?action=srt&id=...  → télécharge le fichier .srt
//    GET  ?action=list        → 20 derniers projets
//    GET  ?action=status&id=  → état de la distribution
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { adminClient, estAdmin, estAdminJeton } from "../_shared/supabase.ts";
import { jetonTiktokValide } from "../_shared/tiktok.ts";
import { appelDeepSeek, appelGemini, extraireJson } from "../_shared/ia.ts";
import { lienAchat } from "../_shared/config.ts";

const MAX_OCTETS = Math.max(5, Number(Deno.env.get("MAX_VIDEO_MB") ?? 90)) * 1024 * 1024;

interface ProjetVideo {
  id: string;
  theme: string;
  transcript: string | null;
  video_filename: string | null;
  video_url: string | null;
  video_size_bytes: number | null;
  statut: string;
  decorticage: Record<string, unknown> | null;
  srt: string | null;
  hooks: Record<string, unknown> | null;
  copy: Record<string, unknown> | null;
  youtube_video_id: string | null;
  tiktok_publish_id: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
}

// ============================================================================
//  UTILITAIRES
// ============================================================================

function tronquer(valeur: unknown, max: number): string {
  return String(valeur ?? "").trim().slice(0, max);
}

function normaliserTags(valeur: unknown): string[] {
  const liste = Array.isArray(valeur) ? valeur : String(valeur ?? "").split(/[,\s]+/);
  return liste
    .map((tag) => String(tag).replace(/^#+/, "").trim())
    .filter((tag) => tag.length > 1)
    .slice(0, 15);
}

function timecode(secondes: number): string {
  const s = Math.max(0, Math.floor(secondes));
  const h = Math.floor(s / 3600).toString().padStart(2, "0");
  const m = Math.floor((s % 3600) / 60).toString().padStart(2, "0");
  const sec = (s % 60).toString().padStart(2, "0");
  return `${h}:${m}:${sec},000`;
}

function srtDepuisLignes(lignes: string[]): string {
  const blocs: string[] = [];
  let temps = 0;
  let numero = 0;

  for (const ligne of lignes.slice(0, 80)) {
    const propre = ligne.replace(/\s+/g, " ").trim();
    if (!propre) continue;
    const duree = Math.min(7, Math.max(2, Math.ceil(propre.length / 14)));
    numero += 1;
    blocs.push(`${numero}\n${timecode(temps)} --> ${timecode(temps + duree)}\n${propre}`);
    temps += duree;
  }

  return blocs.join("\n\n");
}

function normaliserSrt(srt: unknown, theme: string, hooks: unknown): string {
  const brut = String(srt ?? "").replace(/\r\n/g, "\n").trim();
  if (/^\s*1\s*\n/.test(brut) && brut.includes("-->")) {
    return brut;
  }

  const lignes = brut
    .split("\n")
    .map((ligne) => ligne.trim())
    .filter((ligne) => ligne && !/^\d+$/.test(ligne) && !ligne.includes("-->"));

  const secours: string[] = [];
  if (Array.isArray(hooks)) {
    for (const hook of hooks) {
      const texte = typeof hook === "string" ? hook : (hook as Record<string, unknown>)?.texte;
      if (texte) secours.push(String(texte));
    }
  }

  const base = lignes.length > 0 ? lignes : secours.length > 0 ? secours : [theme];
  return srtDepuisLignes(base);
}

// ============================================================================
//  AGENT 1 — DÉCORTIQUEUR (DeepSeek + Gemini)
// ============================================================================

async function agentDecortiqueur(theme: string, transcript: string): Promise<Record<string, unknown>> {
  const contexte = transcript
    ? `Transcription fournie (extrait) :\n"""${transcript.slice(0, 6000)}"""`
    : "Aucune transcription fournie : travaille à partir du thème et de l'offre Kit Business.";

  const promptDeepSeek = `Rôle : analyste vidéo senior, spécialiste des contenus courts qui vendent en Afrique francophone.
Thème de la vidéo : "${theme}"
${contexte}

Notre offre : kits business clés en main (livre stratégique, prompts IA, Google Sheet), de 3 000 à 9 000 FCFA,
vendus sur WhatsApp et par email. Nos Lives OBS tournent sur YouTube.

Décortique la vidéo sans complaisance et réponds UNIQUEMENT avec ce JSON :
{
  "sujet": "le vrai sujet en une phrase",
  "accroche_3_secondes": {
    "texte": "la phrase exacte des 3 premières secondes",
    "pourquoi_ca_marche": "mécanisme psychologique",
    "alternative_plus_forte": "une autre accroche, encore plus directe"
  },
  "arguments_chiffres": [
    {"argument": "...", "chiffre_fcfa": 250000, "preuve": "comment le rendre crédible"}
  ],
  "structure": [
    {"temps": "0-3 s", "objectif": "...", "visuel": "..."}
  ],
  "forces": ["..."],
  "faiblesses": ["..."],
  "idees_suites": [
    {"titre": "...", "angle": "...", "accroche": "...", "format": "Live OBS 10 min"}
  ],
  "appel_a_action": "la phrase de fin qui pousse vers le lien d'achat"
}`;

  const decorticage = extraireJson<Record<string, unknown>>(
    await appelDeepSeek(promptDeepSeek, { json: true, temperature: 0.6 }),
  );

  let analyseGemini = "";
  try {
    analyseGemini = await appelGemini(
      `Rôle : directeur artistique et scénariste.
Voici l'analyse d'une vidéo sur "${theme}" : ${JSON.stringify(decorticage)}.
Donne en 6 puces courtes (texte brut, pas de Markdown) :
1) le plan d'ouverture idéal (cadrage + texte à l'écran),
2) le rythme de montage seconde par seconde,
3) les 2 erreurs de forme à éviter,
4) comment adapter ce contenu à un Live OBS,
5) le moment exact où afficher le lien d'achat (${lienAchat()}),
6) le titre le plus clivant possible.`,
      { temperature: 0.9 },
    );
  } catch (erreurGemini) {
    console.error("Agent 1 (Gemini) :", erreurGemini);
  }

  return {
    ...decorticage,
    idees_suites: Array.isArray(decorticage.idees_suites) ? decorticage.idees_suites.slice(0, 3) : [],
    analyse_gemini: analyseGemini,
  };
}

// ============================================================================
//  AGENT 2 — SOUS-TITRES & HOOKS (DeepSeek)
// ============================================================================

async function agentSousTitres(
  theme: string,
  decorticage: Record<string, unknown>,
): Promise<{ srt: string; hooks: Record<string, unknown> }> {
  const prompt = `Rôle : sous-titreur professionnel et expert en hooks pour TikTok, Reels et Shorts.
Thème : "${theme}"
Analyse disponible : ${JSON.stringify(decorticage)}

Produis :
1. Un fichier SRT complet et valide (numérotation, timecodes HH:MM:SS,mmm, 2 lignes maximum par sous-titre)
   pour une vidéo de 45 à 60 secondes, en français, découpé par groupes de 3 à 7 mots.
2. Les textes à incruster à l'écran (hooks) avec leur moment d'apparition.

Réponds UNIQUEMENT avec ce JSON :
{
  "srt": "1\\n00:00:00,000 --> 00:00:02,500\\nTexte du sous-titre\\n\\n2\\n...",
  "hooks_ecran": [
    {"moment": "0-3 s", "texte": "...", "style": "gros et jaune, centré"}
  ],
  "duree_estimee": "50 secondes",
  "conseils_incrustation": "police, taille, position, contraste"
}`;

  const resultat = extraireJson<Record<string, unknown>>(
    await appelDeepSeek(prompt, { json: true, temperature: 0.5, maxTokens: 4096 }),
  );

  const hooks = {
    hooks_ecran: Array.isArray(resultat.hooks_ecran) ? resultat.hooks_ecran : [],
    duree_estimee: tronquer(resultat.duree_estimee, 40),
    conseils_incrustation: tronquer(resultat.conseils_incrustation, 400),
  };

  return {
    srt: normaliserSrt(resultat.srt, theme, hooks.hooks_ecran),
    hooks,
  };
}

// ============================================================================
//  AGENT 3 — COPYWRITER MULTI-RÉSEAUX (DeepSeek)
// ============================================================================

async function agentCopywriter(
  theme: string,
  decorticage: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const prompt = `Rôle : copywriter de direct response, spécialiste des réseaux sociaux en Afrique francophone.
Thème : "${theme}"
Analyse : ${JSON.stringify(decorticage)}
Offre : kits business clés en main de 3 000 à 9 000 FCFA. Lien d'achat : ${lienAchat()}

Rédige un contenu NATIVEMENT différent pour chaque réseau (pas de simple copier-coller).
Tous les prix doivent être en FCFA. Réponds UNIQUEMENT avec ce JSON :
{
  "youtube": {
    "titre": "moins de 90 caractères, avec un chiffre en FCFA",
    "description": "3 paragraphes + le lien d'achat en fin",
    "hashtags": ["#...", "#..."],
    "tags": ["mot-clé", "mot-clé"]
  },
  "tiktok": {
    "caption": "moins de 150 caractères, ton direct, 1 emoji",
    "hashtags": ["#...", "#..."],
    "hook_oral": "la première phrase dite face caméra"
  },
  "instagram": {
    "caption": "150 à 300 caractères, storytelling court",
    "hashtags": ["#...", "#..."],
    "premiere_ligne": "l'accroche visible avant le 'plus'"
  },
  "facebook": {
    "post": "texte de 300 à 600 caractères, orienté communauté",
    "hashtags": ["#...", "#..."],
    "question_finale": "..."
  },
  "pinterest": {
    "titre": "moins de 100 caractères",
    "description": "150 à 300 caractères, riches en mots-clés de recherche",
    "hashtags": ["#...", "#..."]
  }
}`;

  const copy = extraireJson<Record<string, unknown>>(
    await appelDeepSeek(prompt, { json: true, temperature: 0.8, maxTokens: 4096 }),
  );

  return {
    youtube: copy.youtube ?? {},
    tiktok: copy.tiktok ?? {},
    instagram: copy.instagram ?? {},
    facebook: copy.facebook ?? {},
    pinterest: copy.pinterest ?? {},
  };
}

// ============================================================================
//  AGENT 4 — DISTRIBUTEUR (YouTube Data v3 + TikTok Content Posting)
// ============================================================================

async function jetonGoogle(portee: string): Promise<string> {
  const clientId = Deno.env.get("YOUTUBE_CLIENT_ID");
  const clientSecret = Deno.env.get("YOUTUBE_CLIENT_SECRET");
  const refreshToken = Deno.env.get("YOUTUBE_REFRESH_TOKEN");

  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error("YouTube non configuré (YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET, YOUTUBE_REFRESH_TOKEN).");
  }

  const reponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
    signal: AbortSignal.timeout(20_000),
  });

  const donnees = await reponse.json().catch(() => ({}));
  if (!reponse.ok || !donnees?.access_token) {
    throw new Error(`Jeton Google refusé (HTTP ${reponse.status}). Vérifiez la portée ${portee}.`);
  }
  return String(donnees.access_token);
}

async function telechargerSource(url: string): Promise<Uint8Array> {
  const reponse = await fetch(url, { signal: AbortSignal.timeout(150_000) });
  if (!reponse.ok) throw new Error(`Téléchargement de la vidéo impossible (HTTP ${reponse.status}).`);

  const annonce = Number(reponse.headers.get("content-length") ?? 0);
  if (annonce > MAX_OCTETS) {
    throw new Error(`Vidéo trop lourde (${Math.round(annonce / 1024 / 1024)} Mo). Limite : ${Math.round(MAX_OCTETS / 1024 / 1024)} Mo.`);
  }

  const octets = new Uint8Array(await reponse.arrayBuffer());
  if (octets.byteLength > MAX_OCTETS) {
    throw new Error(`Vidéo trop lourde. Limite : ${Math.round(MAX_OCTETS / 1024 / 1024)} Mo.`);
  }
  if (octets.byteLength === 0) throw new Error("Le fichier vidéo est vide.");
  return octets;
}

async function publierYoutube(
  projet: ProjetVideo,
  octets: Uint8Array,
  confidentialite: string,
): Promise<string> {
  const jeton = await jetonGoogle("https://www.googleapis.com/auth/youtube.upload");
  const copy = (projet.copy?.youtube ?? {}) as Record<string, unknown>;

  const titre = tronquer(copy.titre ?? projet.theme, 95) || "Kit Business";
  const description = tronquer(copy.description ?? "", 4900);
  const tags = normaliserTags(copy.tags ?? copy.hashtags);

  const initialisation = await fetch(
    "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${jeton}`,
        "Content-Type": "application/json; charset=UTF-8",
        "X-Upload-Content-Length": String(octets.byteLength),
        "X-Upload-Content-Type": "video/mp4",
      },
      body: JSON.stringify({
        snippet: {
          title: titre,
          description,
          tags,
          categoryId: "22",
          defaultLanguage: "fr",
        },
        status: {
          // Par défaut : PRIVÉ. Validation humaine obligatoire avant publication.
          privacyStatus: confidentialite === "public" ? "public" : "private",
          selfDeclaredMadeForKids: false,
        },
      }),
      signal: AbortSignal.timeout(30_000),
    },
  );

  const urlUpload = initialisation.headers.get("location");
  if (!initialisation.ok || !urlUpload) {
    const detail = await initialisation.text();
    throw new Error(`Initialisation YouTube refusée : ${detail.slice(0, 300)}`);
  }

  const envoi = await fetch(urlUpload, {
    method: "PUT",
    headers: {
      "Content-Type": "video/mp4",
      "Content-Length": String(octets.byteLength),
    },
    body: octets as unknown as BodyInit,
    signal: AbortSignal.timeout(145_000),
  });

  const resultat = await envoi.json().catch(() => ({}));
  if (!envoi.ok || !resultat?.id) {
    throw new Error(`Upload YouTube échoué : ${JSON.stringify(resultat).slice(0, 300)}`);
  }
  return String(resultat.id);
}

async function publierTiktok(projet: ProjetVideo, octets: Uint8Array): Promise<string> {
  const jeton = await jetonTiktokValide();
  const taille = octets.byteLength;

  // TikTok impose des morceaux de 5 à 64 Mo (hors dernier morceau).
  const tailleMorceau = taille > 5 * 1024 * 1024 ? Math.min(10 * 1024 * 1024, taille) : taille;
  const nombreMorceaux = Math.ceil(taille / tailleMorceau);

  const initialisation = await fetch("https://open.tiktokapis.com/v2/post/publish/inbox/video/init/", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${jeton}`,
      "Content-Type": "application/json; charset=UTF-8",
    },
    body: JSON.stringify({
      source_info: {
        source: "FILE_UPLOAD",
        video_size: taille,
        chunk_size: tailleMorceau,
        total_chunk_count: nombreMorceaux,
      },
    }),
    signal: AbortSignal.timeout(30_000),
  });

  const donneesInit = await initialisation.json().catch(() => ({}));
  const codeErreur = donneesInit?.error?.code;
  if (!initialisation.ok || (codeErreur && codeErreur !== "ok")) {
    throw new Error(`Initialisation TikTok refusée : ${donneesInit?.error?.message ?? initialisation.status}`);
  }

  const urlUpload = donneesInit?.data?.upload_url;
  const publishId = donneesInit?.data?.publish_id;
  if (!urlUpload || !publishId) throw new Error("TikTok n'a pas renvoyé d'URL d'upload.");

  for (let index = 0; index < nombreMorceaux; index++) {
    const debut = index * tailleMorceau;
    const fin = Math.min(taille, debut + tailleMorceau) - 1;
    const morceau = octets.subarray(debut, fin + 1);

    const reponse = await fetch(String(urlUpload), {
      method: "PUT",
      headers: {
        "Content-Type": "video/mp4",
        "Content-Length": String(morceau.byteLength),
        "Content-Range": `bytes ${debut}-${fin}/${taille}`,
      },
      body: morceau as unknown as BodyInit,
      signal: AbortSignal.timeout(60_000),
    });

    if (!reponse.ok) {
      const detail = await reponse.text();
      throw new Error(`Upload TikTok échoué (morceau ${index + 1}/${nombreMorceaux}) : ${detail.slice(0, 200)}`);
    }
  }

  return String(publishId);
}

/** Structure prête pour Facebook, Instagram et Pinterest (validation manuelle). */
function payloadsReseaux(projet: ProjetVideo): Array<{ platform: string; payload: Record<string, unknown> }> {
  const copy = (projet.copy ?? {}) as Record<string, unknown>;
  const instagram = (copy.instagram ?? {}) as Record<string, unknown>;
  const facebook = (copy.facebook ?? {}) as Record<string, unknown>;
  const pinterest = (copy.pinterest ?? {}) as Record<string, unknown>;

  return [
    {
      platform: "instagram",
      payload: {
        caption: instagram.caption ?? "",
        hashtags: normaliserTags(instagram.hashtags),
        media_type: "REELS",
        video_url: projet.video_url,
        api: "Instagram Graph API — POST /{ig-user-id}/media (media_type=REELS)",
      },
    },
    {
      platform: "facebook",
      payload: {
        message: facebook.post ?? "",
        hashtags: normaliserTags(facebook.hashtags),
        video_url: projet.video_url,
        api: "Facebook Graph API — POST /{page-id}/videos",
      },
    },
    {
      platform: "pinterest",
      payload: {
        title: pinterest.titre ?? "",
        description: pinterest.description ?? "",
        hashtags: normaliserTags(pinterest.hashtags),
        video_url: projet.video_url,
        api: "Pinterest API v5 — POST /v5/pins (media_source=video)",
      },
    },
  ];
}

// ============================================================================
//  POINT D'ENTRÉE
// ============================================================================

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const url = new URL(req.url);

  // Admin connecté (en-tête) ou jeton passé en query pour un téléchargement
  // navigateur (fichier .srt).
  const jetonQuery = url.searchParams.get("token");
  const autorise = jetonQuery ? await estAdminJeton(jetonQuery) : await estAdmin(req);
  if (!autorise) {
    return erreur("Accès réservé à l'administrateur (/admin-videos).", 401);
  }

  const admin = adminClient();
  const contentType = req.headers.get("content-type") ?? "";

  let octets: Uint8Array | null = null;
  let corps: Record<string, unknown> = {};

  try {
    if (contentType.startsWith("video/")) {
      // Upload direct depuis /admin-videos : le binaire reste en mémoire,
      // il n'est jamais écrit dans Supabase Storage.
      const brut = await req.arrayBuffer();
      if (brut.byteLength > MAX_OCTETS) {
        return erreur(`Vidéo trop lourde. Limite : ${Math.round(MAX_OCTETS / 1024 / 1024)} Mo.`, 413);
      }
      octets = new Uint8Array(brut);
    } else if (req.method === "POST") {
      corps = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    }

    const action = String(
      corps.action ?? url.searchParams.get("action") ?? (octets ? "publish" : "list"),
    );

    // ------------------------------------------------------------------
    //  ANALYSE (AGENTS 1 → 3)
    // ------------------------------------------------------------------
    if (action === "analyze") {
      const theme = tronquer(corps.theme, 400);
      if (theme.length < 4) return erreur("Décrivez le thème de la vidéo (4 caractères minimum).");

      const transcript = tronquer(corps.transcript, 8000);
      const projetIdExistant = corps.project_id ? String(corps.project_id) : null;
      const videoUrl = tronquer(corps.video_url, 800);

      const decorticage = await agentDecortiqueur(theme, transcript);
      const { srt, hooks } = await agentSousTitres(theme, decorticage);
      const copy = await agentCopywriter(theme, decorticage);

      const charge = {
        theme,
        transcript: transcript || null,
        decorticage,
        srt,
        hooks,
        copy,
        video_url: videoUrl || null,
        video_filename: tronquer(corps.video_filename, 200) || null,
        statut: "ANALYSE",
      };

      let projet: ProjetVideo;

      if (projetIdExistant) {
        const { data, error } = await admin
          .from("video_projects")
          .update(charge)
          .eq("id", projetIdExistant)
          .select("*")
          .single();
        if (error) throw new Error(error.message);
        projet = data as ProjetVideo;
      } else {
        const { data, error } = await admin.from("video_projects").insert(charge).select("*").single();
        if (error) throw new Error(error.message);
        projet = data as ProjetVideo;
      }

      return json({ success: true, project: projet });
    }

    // ------------------------------------------------------------------
    //  MISE À JOUR MANUELLE
    // ------------------------------------------------------------------
    if (action === "update") {
      const projetId = String(corps.project_id ?? "");
      if (!projetId) return erreur("Identifiant du projet manquant.");

      const modification: Record<string, unknown> = {};
      if (corps.decorticage) modification.decorticage = corps.decorticage;
      if (corps.srt !== undefined) modification.srt = String(corps.srt ?? "");
      if (corps.hooks) modification.hooks = corps.hooks;
      if (corps.copy) modification.copy = corps.copy;
      if (corps.theme) modification.theme = tronquer(corps.theme, 400);
      if (corps.video_url !== undefined) modification.video_url = tronquer(corps.video_url, 800);
      if (corps.video_filename !== undefined) modification.video_filename = tronquer(corps.video_filename, 200);

      if (Object.keys(modification).length === 0) return erreur("Aucune modification fournie.");

      const { data, error } = await admin
        .from("video_projects")
        .update(modification)
        .eq("id", projetId)
        .select("*")
        .single();
      if (error) throw new Error(error.message);

      return json({ success: true, project: data });
    }

    // ------------------------------------------------------------------
    //  TÉLÉCHARGEMENT DU .SRT
    // ------------------------------------------------------------------
    if (action === "srt") {
      const projetId = String(url.searchParams.get("id") ?? corps.project_id ?? "");
      if (!projetId) return erreur("Identifiant du projet manquant.");

      const { data, error } = await admin
        .from("video_projects")
        .select("theme, srt")
        .eq("id", projetId)
        .maybeSingle();
      if (error || !data) return erreur("Projet introuvable.", 404);

      const nomFichier = `sous-titres-${String(data.theme ?? "video")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .slice(0, 40)}.srt`;

      return new Response(String(data.srt ?? ""), {
        headers: {
          ...corsHeaders,
          "Content-Type": "text/plain; charset=utf-8",
          "Content-Disposition": `attachment; filename="${nomFichier}"`,
        },
      });
    }

    // ------------------------------------------------------------------
    //  LISTE
    // ------------------------------------------------------------------
    if (action === "list") {
      const { data, error } = await admin
        .from("video_projects")
        .select("id, theme, statut, youtube_video_id, tiktok_publish_id, created_at, updated_at")
        .order("created_at", { ascending: false })
        .limit(20);
      if (error) throw new Error(error.message);
      return json({ success: true, projects: data ?? [] });
    }

    // ------------------------------------------------------------------
    //  ÉTAT D'UN PROJET
    // ------------------------------------------------------------------
    if (action === "status") {
      const projetId = String(url.searchParams.get("id") ?? corps.project_id ?? "");
      if (!projetId) return erreur("Identifiant du projet manquant.");

      const { data: projet } = await admin.from("video_projects").select("*").eq("id", projetId).maybeSingle();
      if (!projet) return erreur("Projet introuvable.", 404);

      const { data: publications } = await admin
        .from("video_publications")
        .select("*")
        .eq("video_project_id", projetId)
        .order("created_at", { ascending: false });

      return json({ success: true, project: projet, publications: publications ?? [] });
    }

    // ------------------------------------------------------------------
    //  PUBLICATION (AGENT 4)
    // ------------------------------------------------------------------
    if (action === "publish") {
      const projetId = String(corps.project_id ?? req.headers.get("x-project-id") ?? url.searchParams.get("id") ?? "");
      if (!projetId) return erreur("Identifiant du projet manquant.");

      const { data: projetBrut, error } = await admin
        .from("video_projects")
        .select("*")
        .eq("id", projetId)
        .maybeSingle();
      if (error || !projetBrut) return erreur("Projet introuvable.", 404);

      const projet = projetBrut as ProjetVideo;
      if (!projet.copy) return erreur("Lancez d'abord l'analyse des 4 agents.");

      const plateformes = String(corps.platforms ?? req.headers.get("x-platforms") ?? "youtube,tiktok")
        .split(",")
        .map((p) => p.trim().toLowerCase())
        .filter(Boolean);

      // Source du flux vidéo : binaire direct ou URL externe (Drive, Bunny, R2…).
      const sourceUrl = tronquer(corps.source_url ?? projet.video_url, 800);
      if (!octets) {
        if (!sourceUrl) {
          return erreur("Aucune vidéo : envoyez le fichier (corps binaire) ou renseignez une URL source externe.");
        }
        octets = await telechargerSource(sourceUrl);
      }

      const confidentialite = String(corps.privacy ?? "private");
      const resultats: Record<string, unknown> = {};
      const erreursPublication: string[] = [];

      if (plateformes.includes("youtube")) {
        try {
          const videoId = await publierYoutube(projet, octets, confidentialite);
          resultats.youtube = { ok: true, video_id: videoId, privacy: confidentialite === "public" ? "public" : "private" };
          await admin.from("video_publications").insert({
            video_project_id: projet.id,
            platform: "youtube",
            status: "BROUILLON",
            external_id: videoId,
            payload: { privacy: confidentialite, titre: projet.copy?.youtube ?? null },
          });
        } catch (erreurYoutube) {
          const message = erreurYoutube instanceof Error ? erreurYoutube.message : String(erreurYoutube);
          erreursPublication.push(`YouTube : ${message}`);
          resultats.youtube = { ok: false, error: message };
        }
      }

      if (plateformes.includes("tiktok")) {
        try {
          const publishId = await publierTiktok(projet, octets);
          resultats.tiktok = { ok: true, publish_id: publishId, mode: "brouillon" };
          await admin.from("video_publications").insert({
            video_project_id: projet.id,
            platform: "tiktok",
            status: "BROUILLON",
            external_id: publishId,
            payload: { caption: projet.copy?.tiktok ?? null },
          });
        } catch (erreurTiktok) {
          const message = erreurTiktok instanceof Error ? erreurTiktok.message : String(erreurTiktok);
          erreursPublication.push(`TikTok : ${message}`);
          resultats.tiktok = { ok: false, error: message };
        }
      }

      // Facebook / Instagram / Pinterest : payload prêt, validation manuelle.
      for (const reseau of payloadsReseaux(projet)) {
        if (!plateformes.includes(reseau.platform)) continue;
        await admin.from("video_publications").insert({
          video_project_id: projet.id,
          platform: reseau.platform,
          status: "PRET_A_CONNECTER",
          payload: reseau.payload,
        });
        resultats[reseau.platform] = { ok: true, mode: "structure_prête" };
      }

      const youtubeId = (resultats.youtube as { video_id?: string } | undefined)?.video_id ?? projet.youtube_video_id;
      const tiktokId = (resultats.tiktok as { publish_id?: string } | undefined)?.publish_id ?? projet.tiktok_publish_id;
      const statut = erreursPublication.length === 0 ? "BROUILLON_ENVOYE" : "ERREUR_PARTIELLE";

      const { data: projetMisAJour } = await admin
        .from("video_projects")
        .update({
          youtube_video_id: youtubeId ?? null,
          tiktok_publish_id: tiktokId ?? null,
          video_size_bytes: octets.byteLength,
          statut,
          metadata: {
            ...(projet.metadata ?? {}),
            derniere_publication: new Date().toISOString(),
            source: octets ? "upload_direct" : "url_externe",
            aucun_stockage_supabase: true,
          },
        })
        .eq("id", projet.id)
        .select("*")
        .single();

      return json({
        success: erreursPublication.length === 0,
        warnings: erreursPublication,
        results: resultats,
        project: projetMisAJour,
      });
    }

    return erreur(`Action inconnue : ${action}`, 400);
  } catch (erreurInterne) {
    console.error("video-agency-pipeline :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Pipeline vidéo indisponible.",
      500,
    );
  }
});
