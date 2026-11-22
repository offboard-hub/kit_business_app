// ============================================================================
//  site-assistant — Bulle de chat IA du site (DeepSeek).
//  Elle connaît toute l'offre, répond aux questions des spectateurs des Lives
//  OBS et les redirige vers le lien d'achat SasPay.
//  Aucun webhook WhatsApp : le contact WhatsApp se fait via le bouton wa.me.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { repondreAssistant, type MessageHistorique } from "../_shared/assistant.ts";
import { adminClient } from "../_shared/supabase.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  if (req.method === "GET") {
    return json({
      success: true,
      service: "site-assistant",
      message: "Envoyez un POST JSON { message, conversation_id }.",
    });
  }

  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  try {
    const corps = (await req.json().catch(() => ({}))) as {
      message?: string;
      conversation_id?: string;
      channel?: string;
      prenom?: string;
    };

    const message = String(corps.message ?? "").trim().slice(0, 1200);
    const conversationId =
      String(corps.conversation_id ?? "").trim() || `web:${crypto.randomUUID()}`;
    const canal = corps.channel === "youtube" ? "youtube" : "web";
    const prenom = String(corps.prenom ?? "");

    const admin = adminClient();

    // Historique court : 8 messages, une seule requête SQL.
    const { data: historiqueBrut } = await admin
      .from("site_assistant_messages")
      .select("role, content")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: false })
      .limit(8);

    const historique: MessageHistorique[] = (historiqueBrut ?? [])
      .slice()
      .reverse()
      .map((ligne: { role: string; content: string }) => ({
        role: ligne.role === "assistant" ? "assistant" : "user",
        content: ligne.content,
      }));

    const reponse = await repondreAssistant(message || "Bonjour", historique);

    // Journalisation (texte uniquement, purge automatique à 30 jours).
    await admin.from("site_assistant_messages").insert([
      { conversation_id: conversationId, channel: canal, role: "user", content: message || "Bonjour" },
      { conversation_id: conversationId, channel: canal, role: "assistant", content: reponse.reply },
    ]);

    return json({
      success: true,
      reply: reponse.reply,
      cta_url: reponse.ctaUrl,
      suggestions: reponse.suggestions,
      conversation_id: conversationId,
      prenom,
    });
  } catch (erreurInterne) {
    console.error("site-assistant :", erreurInterne);
    return erreur("L'assistant est momentanément indisponible.", 500);
  }
});
