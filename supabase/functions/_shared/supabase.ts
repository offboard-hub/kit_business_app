// ============================================================================
//  Clients Supabase (service_role côté serveur uniquement).
// ============================================================================

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/** Client d'administration : contourne la RLS. Ne jamais exposer sa clé. */
export function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY manquante.");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Client portant le JWT de l'appelant (respecte la RLS). */
export function clientUtilisateur(req: Request): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const authorization = req.headers.get("Authorization") ?? "";
  return createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export interface UtilisateurCourant {
  id: string;
  email: string | null;
}

/** Valide le JWT envoyé par le client et renvoie l'utilisateur (ou null). */
export async function utilisateurCourant(req: Request): Promise<UtilisateurCourant | null> {
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return null;
  const jwt = authorization.slice("Bearer ".length).trim();
  if (!jwt || jwt.split(".").length !== 3) return null;

  const admin = adminClient();
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data?.user) return null;
  return { id: data.user.id, email: data.user.email ?? null };
}

/** L'appelant est-il administrateur (table profiles ou liste ADMIN_EMAILS) ? */
export async function estAdmin(req: Request): Promise<boolean> {
  const user = await utilisateurCourant(req);
  if (!user) return false;
  return estAdminUtilisateur(user);
}

export async function estAdminUtilisateur(user: UtilisateurCourant): Promise<boolean> {
  const admin = adminClient();
  const { data } = await admin
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .maybeSingle();

  if (data?.is_admin === true) return true;

  const liste = (Deno.env.get("ADMIN_EMAILS") ?? "")
    .split(/[,;\s]+/)
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);

  return !!user.email && liste.includes(user.email.toLowerCase());
}

/**
 * Variante pour les téléchargements navigateur : le JWT est passé en paramètre
 * d'URL (impossible d'ajouter un en-tête Authorization à un lien direct).
 */
export async function estAdminJeton(jwt: string): Promise<boolean> {
  if (!jwt || jwt.split(".").length !== 3) return false;
  const admin = adminClient();
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data?.user) return false;
  return estAdminUtilisateur({ id: data.user.id, email: data.user.email ?? null });
}
