// ============================================================================
//  admin-check — indique si l'appelant est administrateur.
//  Utilisé par le menu Compte et la garde /admin-videos pour prendre en compte
//  à la fois profiles.is_admin et la liste ADMIN_EMAILS (jamais exposée).
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders, json } from "../_shared/cors.ts";
import { estAdmin } from "../_shared/supabase.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET" && req.method !== "POST") {
    return json({ success: false, error: "Méthode non autorisée." }, 405);
  }

  const admin = await estAdmin(req);
  return json({ success: true, is_admin: admin });
});
