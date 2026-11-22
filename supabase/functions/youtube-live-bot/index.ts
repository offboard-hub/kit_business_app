// ============================================================================
//  youtube-live-bot — Robot de chat pour nos Lives OBS.
//  Lit les questions via YouTube Data API v3 (liveChatMessages) toutes les
//  10 secondes (intervalle configurable) et répond automatiquement avec le
//  lien du site. Un seul appel base par cycle pour économiser le quota.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { messageYouTube, repondreAssistant } from "../_shared/assistant.ts";
import { adminClient, estAdmin } from "../_shared/supabase.ts";
import { enArrierePlan } from "../_shared/background.ts";

const PORTEE = "https://www.googleapis.com/auth/youtube.force-ssl";

interface MessageLive {
  id: string;
  texte: string;
  auteur: string;
  chaineId: string;
  publieLe: string;
}

// ----------------------------------------------------------------------------
//  AUTHENTIFICATION GOOGLE
// ----------------------------------------------------------------------------

async function jetonGoogle(portee: string): Promise<string> {
  const direct = Deno.env.get("YOUTUBE_ACCESS_TOKEN");
  if (direct && portee === PORTEE) return direct;

  const clientId = Deno.env.get("YOUTUBE_CLIENT_ID") ?? Deno.env.get("GOOGLE_OAUTH_CLIENT_ID");
  const clientSecret = Deno.env.get("YOUTUBE_CLIENT_SECRET") ?? Deno.env.get("GOOGLE_OAUTH_CLIENT_SECRET");
  const refreshToken = Deno.env.get("YOUTUBE_REFRESH_TOKEN");

  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error(
      "YouTube non configuré : renseignez YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET et YOUTUBE_REFRESH_TOKEN.",
    );
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
    throw new Error(`Jeton Google refusé (HTTP ${reponse.status}). Vérifiez le refresh token et ses portées.`);
  }
  return String(donnees.access_token);
}

/** Retrouve le liveChatId à partir de l'identifiant de la vidéo live. */
async function resoudreLiveChatId(videoId: string, jeton: string): Promise<string> {
  const url = new URL("https://www.googleapis.com/youtube/v3/videos");
  url.searchParams.set("part", "liveStreamingDetails");
  url.searchParams.set("id", videoId);

  const reponse = await fetch(url, {
    headers: { Authorization: `Bearer ${jeton}` },
    signal: AbortSignal.timeout(20_000),
  });

  if (!reponse.ok) throw new Error(`YouTube videos.list a renvoyé HTTP ${reponse.status}`);
  const donnees = await reponse.json();
  const chatId = donnees?.items?.[0]?.liveStreamingDetails?.activeLiveChatId;
  if (!chatId) throw new Error("Aucun chat actif : le live n'a pas encore démarré ou est terminé.");
  return String(chatId);
}

// ----------------------------------------------------------------------------
//  LECTURE / ÉCRITURE DU CHAT
// ----------------------------------------------------------------------------

async function lireNouveauxMessages(liveChatId: string, jeton: string): Promise<MessageLive[]> {
  const url = new URL("https://www.googleapis.com/youtube/v3/liveChatMessages");
  url.searchParams.set("liveChatId", liveChatId);
  url.searchParams.set("part", "snippet,authorDetails");
  url.searchParams.set("maxResults", "50");

  const reponse = await fetch(url, {
    headers: { Authorization: `Bearer ${jeton}` },
    signal: AbortSignal.timeout(20_000),
  });

  if (!reponse.ok) throw new Error(`YouTube liveChatMessages a renvoyé HTTP ${reponse.status}`);
  const donnees = await reponse.json();

  const messages: MessageLive[] = [];
  for (const element of donnees?.items ?? []) {
    const texte = element?.snippet?.displayMessage ?? element?.snippet?.textMessageDetails?.messageText;
    if (!texte) continue; // ignore les superchats et les évènements système
    messages.push({
      id: String(element.id),
      texte: String(texte).trim(),
      auteur: String(element?.authorDetails?.displayName ?? "spectateur"),
      chaineId: String(element?.authorDetails?.channelId ?? ""),
      publieLe: String(element?.snippet?.publishedAt ?? ""),
    });
  }
  return messages.sort((a, b) => a.publieLe.localeCompare(b.publieLe));
}

async function repondreDansLeChat(liveChatId: string, jeton: string, message: string): Promise<boolean> {
  const reponse = await fetch(
    "https://www.googleapis.com/youtube/v3/liveChatMessages?part=snippet",
    {
      method: "POST",
      headers: { Authorization: `Bearer ${jeton}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        snippet: {
          liveChatId,
          type: "textMessageEvent",
          textMessageDetails: { messageText: message.slice(0, 200) },
        },
      }),
      signal: AbortSignal.timeout(20_000),
    },
  );

  if (!reponse.ok) {
    const detail = await reponse.text();
    console.error("Réponse chat refusée :", reponse.status, detail.slice(0, 300));
    return false;
  }
  return true;
}

// ----------------------------------------------------------------------------
//  UN CYCLE (10 s)
// ----------------------------------------------------------------------------

interface OptionsCycle {
  videoId?: string;
  liveChatId?: string;
  maxReponses: number;
}

async function cycle(options: OptionsCycle): Promise<Record<string, unknown>> {
  const admin = adminClient();
  const jeton = await jetonGoogle(PORTEE);

  const liveChatId = options.liveChatId || (await resoudreLiveChatId(options.videoId ?? "", jeton));

  const { data: etat } = await admin
    .from("live_chat_state")
    .select("last_message_id, last_published_at, replies_sent")
    .eq("live_chat_id", liveChatId)
    .maybeSingle();

  const dernierId = String(etat?.last_message_id ?? "");
  const dernierDate = String(etat?.last_published_at ?? "");
  const reponsesDejaEnvoyees = Number(etat?.replies_sent ?? 0);

  const messages = await lireNouveauxMessages(liveChatId, jeton);
  const chaineBot = (Deno.env.get("YOUTUBE_CHANNEL_ID") ?? "").trim();

  const nouveaux = messages.filter((message) => {
    if (message.id === dernierId) return false;
    if (dernierDate && message.publieLe <= dernierDate) return false;
    if (chaineBot && message.chaineId === chaineBot) return false;
    if (message.texte.startsWith("!")) return false;
    return true;
  });

  const aTraiter = nouveaux.slice(0, Math.max(0, options.maxReponses));
  const reponses: Array<{ auteur: string; question: string; reponse: string }> = [];
  let reponsesEnvoyees = 0;

  for (const message of aTraiter) {
    // Seules les vraies questions déclenchent une réponse (coût quota maîtrisé).
    const estQuestion = /\?|comment|combien|prix|kit|payer|paiement|où|ou est|aide/i.test(message.texte);
    if (!estQuestion) continue;

    const reponse = await repondreAssistant(message.texte, []);
    const texte = messageYouTube(`@${message.auteur} ${reponse.reply}`);
    const envoye = await repondreDansLeChat(liveChatId, jeton, texte);
    if (envoye) {
      reponsesEnvoyees += 1;
      reponses.push({ auteur: message.auteur, question: message.texte, reponse: texte });
      await new Promise((resoudre) => setTimeout(resoudre, 1200));
    }
  }

  // Le pointeur avance jusqu'au dernier message examiné, pas seulement répondu,
  // afin de ne jamais boucler sur les mêmes messages.
  const dernierExamine = aTraiter.length > 0 ? aTraiter[aTraiter.length - 1] : messages[messages.length - 1];

  await admin.from("live_chat_state").upsert(
    {
      live_chat_id: liveChatId,
      last_message_id: dernierExamine?.id ?? dernierId,
      last_published_at: dernierExamine?.publieLe ?? dernierDate,
      replies_sent: reponsesDejaEnvoyees + reponsesEnvoyees,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "live_chat_id" },
  );

  return {
    live_chat_id: liveChatId,
    messages_lus: messages.length,
    nouveaux: nouveaux.length,
    reponses_envoyees: reponsesEnvoyees,
    reponses,
  };
}

// ----------------------------------------------------------------------------
//  POINT D'ENTRÉE
// ----------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const url = new URL(req.url);
  let corps: Record<string, unknown> = {};
  if (req.method === "POST") {
    corps = (await req.json().catch(() => ({}))) as Record<string, unknown>;
  }

  // Protection : admin connecté OU secret de cron.
  const secretAttendu = Deno.env.get("CRON_SECRET") ?? "";
  const secretFourni =
    req.headers.get("x-cron-secret") ?? url.searchParams.get("secret") ?? (corps.secret as string) ?? "";

  const autorise = (secretAttendu && secretFourni === secretAttendu) || (await estAdmin(req));
  if (!autorise) return erreur("Accès réservé à l'administrateur ou au planificateur.", 401);

  const action = String(corps.action ?? url.searchParams.get("action") ?? "tick");
  const options: OptionsCycle = {
    videoId: String(corps.video_id ?? url.searchParams.get("video_id") ?? Deno.env.get("YOUTUBE_LIVE_VIDEO_ID") ?? ""),
    liveChatId: String(corps.live_chat_id ?? url.searchParams.get("live_chat_id") ?? Deno.env.get("YOUTUBE_LIVE_CHAT_ID") ?? ""),
    maxReponses: Number(corps.max_reponses ?? url.searchParams.get("max_reponses") ?? 2),
  };

  try {
    if (action === "start") {
      const iterations = Math.min(Number(corps.iterations ?? 12), 60);
      const intervalle = Math.max(Number(corps.intervalle_secondes ?? 10), 5);

      enArrierePlan(
        (async () => {
          for (let i = 0; i < iterations; i++) {
            try {
              await cycle(options);
            } catch (erreurCycle) {
              console.error(`Cycle ${i + 1}/${iterations} en échec :`, erreurCycle);
            }
            await new Promise((resoudre) => setTimeout(resoudre, intervalle * 1000));
          }
        })(),
      );

      return json({
        success: true,
        start: true,
        iterations,
        intervalle_secondes: intervalle,
        message: "Le robot tourne en tâche de fond. Relancez /start avant la fin du live.",
      });
    }

    if (action === "status") {
      const admin = adminClient();
      const { data } = await admin.from("live_chat_state").select("*").order("updated_at", { ascending: false }).limit(5);
      return json({ success: true, etats: data ?? [] });
    }

    const resultat = await cycle(options);
    return json({ success: true, ...resultat });
  } catch (erreurInterne) {
    console.error("youtube-live-bot :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Robot YouTube indisponible.",
      500,
    );
  }
});
