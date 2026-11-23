// ============================================================================
//  live-auto-chat — assistant commercial "Awa" du chat de la salle live.
//
//  • action=ask      : valide la salle, appelle DeepSeek avec la fiche produit,
//                      insère le message du spectateur + la réponse, renvoie
//                      { success, reply, message }.
//  • action=messages : renvoie les 60 derniers messages de la salle.
//
//  Accès : jeton d'invitation OU propriétaire connecté ; en salle PRET/EN_DIRECT
//  le chat public reste ouvert. Limite de débit en mémoire par salle + IP.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import { adminClient } from "../_shared/supabase.ts";
import { appelDeepSeek } from "../_shared/ia.ts";
import { chargerSessionParRoom, compterReponsesIaEssai, sessionAccesActif, verifierAccesSession } from "../_shared/studio.ts";

const LIMITE_ESSAI_JOUR = 20;

interface CorpsRequete {
  action?: string;
  room_id?: string;
  message?: string;
  author?: string;
  platform?: string;
  invite_token?: string;
}

interface MessageLive {
  id: string;
  session_id: string;
  room_id: string;
  platform: string;
  role: string;
  author: string | null;
  content: string;
  created_at: string;
}

const PLATEFORMES = new Set(["SALLE", "TIKTOK", "YOUTUBE", "INSTAGRAM"]);
const ROOM_ID = /^[A-Za-z0-9_-]{6,80}$/;
const MAX_MESSAGE = 500;
const MAX_AUTHOR = 40;

// ----------------------------------------------------------------------------
//  LIMITE DE DÉBIT EN MÉMOIRE (par salle + IP) — 12 questions / minute
// ----------------------------------------------------------------------------
const LIMITE_QUESTIONS = 12;
const FENETRE_MS = 60_000;
const historiqueRequetes = new Map<string, number[]>();

function limiteAtteinte(cle: string): boolean {
  const maintenant = Date.now();
  const requetes = (historiqueRequetes.get(cle) ?? []).filter(
    (horodatage) => maintenant - horodatage < FENETRE_MS,
  );
  requetes.push(maintenant);
  historiqueRequetes.set(cle, requetes);

  if (historiqueRequetes.size > 2000) {
    for (const [autreCle, valeurs] of historiqueRequetes) {
      if (!valeurs.some((horodatage) => maintenant - horodatage < FENETRE_MS)) {
        historiqueRequetes.delete(autreCle);
      }
    }
  }
  return requetes.length > LIMITE_QUESTIONS;
}

function adresseIp(req: Request): string {
  const entete = req.headers.get("x-forwarded-for") ??
    req.headers.get("x-real-ip") ??
    "";
  return entete.split(",")[0].trim() || "inconnu";
}

function nettoyer(valeur: unknown, max: number): string {
  return String(valeur ?? "").trim().slice(0, max);
}

function texteFiche(fiche: Record<string, unknown> | null): string {
  if (!fiche) return "Aucune fiche produit fournie.";
  const texte = JSON.stringify(fiche).slice(0, 1200);
  return texte === "{}" ? "Aucune fiche produit fournie." : texte;
}

function reponseDeSecours(fiche: Record<string, unknown> | null): string {
  const nom = fiche && typeof fiche["nom"] === "string" ? fiche["nom"] : "";
  const prix = fiche && (fiche["prix"] ?? fiche["prix_local"] ?? fiche["montant"]);
  if (nom && prix) {
    return `Bonne question 👋 ${nom} est disponible aujourd'hui à ${prix}. ` +
      `Écrivez-moi votre besoin en une phrase : je vous dis si c'est adapté, sans engagement.`;
  }
  if (nom) {
    return `Bonne question 👋 ${nom} est disponible aujourd'hui. ` +
      `Dites-moi votre besoin en une phrase : je vous réponds personnellement.`;
  }
  return "Bonne question 👋 Je note votre demande. " +
    "Précisez votre besoin en une phrase et je vous réponds tout de suite.";
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return erreur("Méthode non autorisée.", 405);

  try {
    const corps = (await req.json().catch(() => ({}))) as CorpsRequete;
    const action = nettoyer(corps.action, 20).toLowerCase() === "messages" ? "messages" : "ask";
    const roomId = nettoyer(corps.room_id, 80);

    if (!ROOM_ID.test(roomId)) {
      return erreur("Salle live invalide.", 400);
    }

    const session = await chargerSessionParRoom(roomId);
    if (!session) return erreur("Salle live introuvable.", 404);

    const inviteToken = nettoyer(corps.invite_token, 200);
    const acces = await verifierAccesSession(req, session, inviteToken);
    const accesActif = await sessionAccesActif(session);
    const salleOuverte = (session.statut === "PRET" || session.statut === "EN_DIRECT") && accesActif;

    if (!accesActif) {
      return erreur(
        "Votre accès Studio Live est terminé. Abonnez-vous pour continuer.",
        403,
      );
    }
    if (!acces.autorise && !salleOuverte) {
      return erreur("Cette salle live n'est pas ouverte. Demandez un lien d'invitation.", 403);
    }

    const admin = adminClient();

    // ------------------------------------------------------------------
    // 1. HISTORIQUE
    // ------------------------------------------------------------------
    if (action === "messages") {
      const { data, error } = await admin
        .from("studio_live_messages")
        .select("*")
        .eq("room_id", roomId)
        .order("created_at", { ascending: false })
        .limit(60);
      if (error) throw new Error(`Lecture des messages impossible : ${error.message}`);

      const messages = ((data ?? []) as MessageLive[]).slice().reverse();
      return json({ success: true, room_id: roomId, messages });
    }

    // ------------------------------------------------------------------
    // 2. QUESTION AU CHAT IA
    // ------------------------------------------------------------------
    const message = nettoyer(corps.message, MAX_MESSAGE);
    if (message.length < 2) {
      return erreur("Écrivez votre question (2 caractères minimum).", 400);
    }

    const cleLimite = `${roomId}:${adresseIp(req)}`;
    if (limiteAtteinte(cleLimite)) {
      return erreur("Trop de messages d'un coup. Patientez une minute avant de reposer une question.", 429);
    }

    // Essai gratuit : 20 réponses IA maximum par jour et par utilisateur.
    // Les salles d'essai n'ont pas de subscription_id (accès via studio_trials).
    if (!session.subscription_id && session.user_id) {
      const dejaGenerees = await compterReponsesIaEssai(session.user_id);
      if (dejaGenerees >= LIMITE_ESSAI_JOUR) {
        return erreur(
          "Votre essai gratuit est limité à 20 réponses IA par jour. Passez à l'abonnement pour un chat illimité.",
          429,
        );
      }
    }

    const platformBrute = nettoyer(corps.platform, 20).toUpperCase();
    const platform = PLATEFORMES.has(platformBrute) ? platformBrute : "SALLE";
    const auteur = nettoyer(corps.author, MAX_AUTHOR) || "Invité";

    const { error: erreurUtilisateur } = await admin.from("studio_live_messages").insert({
      session_id: session.id,
      room_id: roomId,
      platform,
      role: "user",
      author: auteur,
      content: message,
    });
    if (erreurUtilisateur) {
      throw new Error(`Enregistrement du message impossible : ${erreurUtilisateur.message}`);
    }

    // Contexte court : les 8 derniers messages de la salle.
    const { data: historiqueBrut } = await admin
      .from("studio_live_messages")
      .select("role, content")
      .eq("room_id", roomId)
      .order("created_at", { ascending: false })
      .limit(8);

    const historique = ((historiqueBrut ?? []) as Array<{ role: string; content: string }>)
      .slice()
      .reverse()
      .map((ligne) => ({
        role: ligne.role === "assistant" ? "assistant" : "user",
        content: String(ligne.content ?? "").slice(0, 400),
      }));

    const fiche = session.fiche_produit ?? null;
    const systeme = `Tu es "Awa", l'assistante commerciale de e-booklive, en direct dans une salle de live.
Salle : "${session.titre ?? "Live e-booklive"}" — plateforme : ${platform} — format : ${session.format} — mode : ${session.mode_visuel}.
Fiche produit fournie par l'animateur : ${texteFiche(fiche)}

Règles :
- Réponds en français simple, chaleureux et direct, en 3 à 5 lignes maximum.
- Réponds précisément à la question, avec un conseil actionnable.
- Utilise les informations de la fiche produit quand elles existent ; n'invente jamais un prix, une remise ou une garantie.
- Si la question sort du cadre commercial, redirige poliment vers l'animateur.
- Ne demande jamais de données bancaires, de mot de passe ou de numéro complet.
- Termine par une invitation douce (lien en bio, bouton d'achat ou question).`;

    const conversation = historique.length
      ? historique.map((m) => `${m.role === "assistant" ? "Awa" : "Spectateur"} : ${m.content}`).join("\n")
      : "Aucun historique.";

    let reply = "";
    try {
      reply = (await appelDeepSeek(
        `Conversation récente :\n${conversation}\n\nNouvelle question du spectateur : ${message}`,
        { systeme, maxTokens: 260, temperature: 0.75 },
      )).trim();
    } catch (erreurIa) {
      console.error("live-auto-chat : DeepSeek indisponible.", erreurIa);
      reply = reponseDeSecours(fiche);
    }

    if (!reply) reply = reponseDeSecours(fiche);
    reply = reply.slice(0, 1200);

    const { data: messageAssistant, error: erreurAssistant } = await admin
      .from("studio_live_messages")
      .insert({
        session_id: session.id,
        room_id: roomId,
        platform,
        role: "assistant",
        author: "Awa",
        content: reply,
      })
      .select("*")
      .single();

    if (erreurAssistant || !messageAssistant) {
      throw new Error(`Enregistrement de la réponse impossible : ${erreurAssistant?.message ?? "inconnu"}`);
    }

    return json({
      success: true,
      reply,
      message: messageAssistant as MessageLive,
    });
  } catch (erreurInterne) {
    console.error("live-auto-chat :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Le chat du live est indisponible.",
      500,
    );
  }
});
