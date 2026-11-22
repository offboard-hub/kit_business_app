// ============================================================================
//  En-têtes CORS communs à toutes les Edge Functions.
// ============================================================================

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-video-filename, x-project-id, x-platforms",
  "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
};

/** Réponse JSON standardisée. */
export function json(body: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8", ...extraHeaders },
  });
}

/** Réponse d'erreur lisible côté client Flutter. */
export function erreur(message: string, status = 400, details?: unknown): Response {
  return json({ success: false, error: message, details: details ?? null }, status);
}

/** Réponse texte (fichier .srt, HTML…). */
export function texte(body: string, contentType = "text/plain; charset=utf-8", status = 200): Response {
  return new Response(body, { status, headers: { ...corsHeaders, "Content-Type": contentType } });
}
