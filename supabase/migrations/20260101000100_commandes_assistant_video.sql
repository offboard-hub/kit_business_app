-- ============================================================================
--  KIT BUSINESS — COMMANDES, LIVRAISON, ASSISTANT IA, AGENCE VIDÉO
--  ⚠️ RÈGLE ZÉRO STOCKAGE : aucune table, aucun bucket ne contient de vidéo.
--     Seules les métadonnées texte (scripts, sous-titres, copy) sont stockées.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. COMMANDES (tunnel Saspay : 1 commande = 1 kit livré)
-- ----------------------------------------------------------------------------
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  email text not null,
  nom_projet text not null,
  metier_code text not null,
  metier_label text,
  produit_type text not null,
  montant_fcfa integer not null,
  devise text not null default 'XOF',
  pays_code text not null,
  pays_label text,
  indicatif text,
  whatsapp text not null,
  precisions text,
  statut text not null default 'EN_ATTENTE',
  saspay_session_id text,
  saspay_payment_id text,
  saspay_checkout_url text,
  kit_id uuid,
  delivered_whatsapp boolean not null default false,
  delivered_email boolean not null default false,
  delivery_error text,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  delivered_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint orders_statut_check check (
    statut in ('EN_ATTENTE', 'PAYE', 'EN_COURS', 'LIVRE', 'ERREUR', 'ECHEC')
  )
);

create index if not exists orders_user_id_idx on public.orders (user_id, created_at desc);
create index if not exists orders_statut_idx on public.orders (statut);
create unique index if not exists orders_saspay_session_id_key
  on public.orders (saspay_session_id) where saspay_session_id is not null;

alter table public.orders enable row level security;

drop policy if exists "orders_select_own" on public.orders;
create policy "orders_select_own" on public.orders
  for select to authenticated using (user_id = auth.uid());

drop trigger if exists orders_touch_updated_at on public.orders;
create trigger orders_touch_updated_at
  before update on public.orders
  for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 2. EMAIL D'ACCUEIL (Resend) — simple information, sans lien de confirmation
-- ----------------------------------------------------------------------------
create table if not exists public.welcome_emails (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  source text,
  envois integer not null default 1,
  last_sent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.welcome_emails enable row level security;
-- Aucune policy : table accessible uniquement via la clé service_role.

-- ----------------------------------------------------------------------------
-- 3. ASSISTANT IA DU SITE (bulle de chat DeepSeek)
-- ----------------------------------------------------------------------------
create table if not exists public.site_assistant_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id text not null,
  channel text not null default 'web',
  role text not null,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists site_assistant_conversation_idx
  on public.site_assistant_messages (conversation_id, created_at);

alter table public.site_assistant_messages enable row level security;

-- ----------------------------------------------------------------------------
-- 4. AGENCE VIDÉO IA (/admin-videos)
--    Métadonnées uniquement — le fichier .mp4 n'est JAMAIS envoyé dans
--    Supabase Storage : il part directement vers YouTube / TikTok.
-- ----------------------------------------------------------------------------
create table if not exists public.video_projects (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users (id) on delete set null,
  theme text not null,
  transcript text,
  video_filename text,
  video_url text,
  video_size_bytes bigint,
  statut text not null default 'BROUILLON',
  decorticage jsonb,
  srt text,
  hooks jsonb,
  copy jsonb,
  youtube_video_id text,
  tiktok_publish_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists video_projects_created_at_idx
  on public.video_projects (created_at desc);

alter table public.video_projects enable row level security;

drop policy if exists "video_projects_admin_all" on public.video_projects;
create policy "video_projects_admin_all" on public.video_projects
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop trigger if exists video_projects_touch_updated_at on public.video_projects;
create trigger video_projects_touch_updated_at
  before update on public.video_projects
  for each row execute function public.touch_updated_at();

create table if not exists public.video_publications (
  id uuid primary key default gen_random_uuid(),
  video_project_id uuid not null references public.video_projects (id) on delete cascade,
  platform text not null,
  status text not null default 'EN_ATTENTE',
  external_id text,
  payload jsonb,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint video_publications_platform_check check (
    platform in ('youtube', 'tiktok', 'instagram', 'facebook', 'pinterest')
  )
);

create index if not exists video_publications_project_idx
  on public.video_publications (video_project_id);

alter table public.video_publications enable row level security;

drop policy if exists "video_publications_admin_all" on public.video_publications;
create policy "video_publications_admin_all" on public.video_publications
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop trigger if exists video_publications_touch_updated_at on public.video_publications;
create trigger video_publications_touch_updated_at
  before update on public.video_publications
  for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 5. ROBOT YOUTUBE LIVE — état minimal (aucun message complet stocké)
-- ----------------------------------------------------------------------------
create table if not exists public.live_chat_state (
  live_chat_id text primary key,
  last_message_id text,
  last_published_at timestamptz,
  replies_sent integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.live_chat_state enable row level security;

-- ----------------------------------------------------------------------------
-- 6. NETTOYAGE / RÉTENTION (le plan gratuit Supabase reste léger)
-- ----------------------------------------------------------------------------
create or replace function public.purge_site_assistant_messages()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.site_assistant_messages
  where created_at < now() - interval '30 days';
$$;

grant execute on function public.purge_site_assistant_messages() to service_role;
