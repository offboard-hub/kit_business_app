// ============================================================================
//  studio-room — accès à une salle de live (spectateur, invité ou propriétaire).
//
//  Entrée : { action: "get", room_id, invite_token }.
//  Trois cas d'accès, dans cet ordre :
//    1. invite_token fourni et valide → session (co-animateur), même BROUILLON ;
//    2. session PRET / EN_DIRECT        → session PUBLIQUE minimale, sans jeton
//       (lien spectateur /live/:roomId sans token) ;
//    3. JWT propriétaire (user_id ou email de l'abonnement) → session complète.
//  Sinon : 404 générique (on ne divulgue jamais l'existence d'une salle privée).
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, erreur, json } from "../_shared/cors.ts";
import {
  chargerSessionParRoom,
  sessionAccesActif,
  verifierAccesSession,
  type StudioSessionLive,
} from "../_shared/studio.ts";

const ROOM_ID = /^[A-Za-z0-9_-]{6,80}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface CorpsRequete {
  action?: string;
  room_id?: string;
  id?: string;
  invite_token?: string;
}

function nettoyer(valeur: unknown, max: number): string {
  return String(valeur ?? "").trim().slice(0, max);
}

/** Champs publics : jamais le jeton d'invitation ni les données de contact. */
function sessionPublique(session: StudioSessionLive, ownerDisplay: string) {
  return {
    id: session.id,
    room_id: session.room_id,
    titre: session.titre,
    mode_visuel: session.mode_visuel,
    format: session.format,
    fiche_produit: session.fiche_produit ?? {},
    statut: session.statut,
    plateformes: session.plateformes ?? [],
    owner_display: ownerDisplay,
    started_at: session.started_at,
  };
}

/** Champs complets pour le propriétaire / co-animateur invité. */
function sessionComplete(session: StudioSessionLive, ownerDisplay: string) {
  return {
    ...sessionPublique(session, ownerDisplay),
    subscription_id: session.subscription_id,
    user_id: session.user_id,
    room_id: session.room_id,
    invite_token: session.invite_token,
    ended_at: session.ended_at,
    created_at: session.created_at,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST" && req.method !== "GET") return erreur("Méthode non autorisée.", 405);

  try {
    const url = new URL(req.url);
    let corps: CorpsRequete = {};

    if (req.method === "POST") {
      corps = (await req.json().catch(() => ({}))) as CorpsRequete;
    }

    const roomId = nettoyer(
      corps.room_id ?? corps.id ?? url.searchParams.get("room_id") ?? url.searchParams.get("id"),
      80,
    );
    const inviteToken = nettoyer(
      corps.invite_token ?? url.searchParams.get("invite") ?? url.searchParams.get("invite_token"),
      200,
    );

    if (!ROOM_ID.test(roomId) && !UUID.test(roomId)) {
      return erreur("Salle live introuvable.", 404);
    }

    const session = await chargerSessionParRoom(roomId);
    if (!session) return erreur("Salle live introuvable.", 404);

    const acces = await verifierAccesSession(req, session, inviteToken);
    const accesActif = await sessionAccesActif(session);
    const ownerDisplay = acces.abonnement?.nom_activite?.trim() ||
      acces.abonnement?.metier_label?.trim() ||
      session.titre?.trim() ||
      "e-booklive";

    // 0. Un accès expiré (abonnement ou essai) ferme la salle, même au propriétaire.
    if (!accesActif) {
      return erreur(
        "Votre accès Studio Live est terminé. Abonnez-vous pour continuer.",
        403,
      );
    }

    // 1 & 3. Jeton d'invitation valide (co-animateur) ou propriétaire connecté.
    if (acces.tokenValide || acces.proprietaire) {
      return json({
        success: true,
        room_id: session.room_id,
        invite: acces.tokenValide,
        proprietaire: acces.proprietaire,
        session: sessionComplete(session, ownerDisplay),
      });
    }

    // 2. Salle ouverte au public : session minimale, sans jeton.
    if (session.statut === "PRET" || session.statut === "EN_DIRECT") {      return json({
        success: true,
        room_id: session.room_id,
        invite: false,
        proprietaire: false,
        session: sessionPublique(session, ownerDisplay),
      });
    }

    // Sinon : 404 générique, aucune information sur la salle.
    return erreur("Salle live introuvable.", 404);
  } catch (erreurInterne) {
    console.error("studio-room :", erreurInterne);
    return erreur(
      erreurInterne instanceof Error ? erreurInterne.message : "Accès à la salle impossible.",
      500,
    );
  }
});
