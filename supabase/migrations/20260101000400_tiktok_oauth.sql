-- ============================================================================
--  CONNEXION TIKTOK (OAuth 2.0) — jetons stockés côté serveur uniquement.
--  Ces tables ne sont JAMAIS exposées au client : RLS activée, aucun grant à
--  anon/authenticated, accès réservé à la clé service_role des Edge Functions.
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. JETONS TIKTOK (une seule ligne, id = 'default')
-- ----------------------------------------------------------------------------
create table if not exists public.tiktok_credentials (
  id text primary key default 'default',
  access_token text,
  refresh_token text,
  open_id text,
  scope text,
  expires_at timestamptz,
  refresh_expires_at timestamptz,
  connected_by uuid references auth.users (id) on delete set null,
  connected_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.tiktok_credentials enable row level security;

-- Aucune policy : la table est invisible pour anon et authenticated.
revoke all on public.tiktok_credentials from anon, authenticated;
grant all on public.tiktok_credentials to service_role;

drop trigger if exists tiktok_credentials_touch_updated_at on public.tiktok_credentials;
create trigger tiktok_credentials_touch_updated_at
  before update on public.tiktok_credentials
  for each row execute function public.touch_updated_at();

comment on table public.tiktok_credentials is
  'Jetons OAuth TikTok (access/refresh). Accès service_role uniquement, jamais exposés au client.';

-- ----------------------------------------------------------------------------
-- 2. ÉTATS OAUTH (protection CSRF + expiration, usage unique)
-- ----------------------------------------------------------------------------
create table if not exists public.tiktok_oauth_states (
  state text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists tiktok_oauth_states_created_idx
  on public.tiktok_oauth_states (created_at desc);

alter table public.tiktok_oauth_states enable row level security;

revoke all on public.tiktok_oauth_states from anon, authenticated;
grant all on public.tiktok_oauth_states to service_role;

comment on table public.tiktok_oauth_states is
  'États OAuth TikTok en attente (validité 15 min, supprimés après échange du code).';
