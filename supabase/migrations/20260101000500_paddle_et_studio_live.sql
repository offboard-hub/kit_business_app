-- ============================================================================
--  e-booklive — PADDLE + STUDIO LIVE
--  Migration idempotente : peut être rejouée sans casser l'existant.
--
--  Contenu :
--   1. Colonnes Paddle / route de paiement sur public.orders
--   2. public.studio_subscriptions   (abonnement 10 USD / 30 jours)
--   3. public.studio_guides          (Livre Guide Live généré)
--   4. public.studio_live_sessions   (régie / salles de live)
--   5. public.studio_live_messages   (chat de la salle + chat IA)
--   6. RLS complète, fonctions d'accès, grants, triggers, realtime
--
--  Règle de sécurité : AUCUNE table Studio n'est accessible en écriture au
--  client. Les messages sont écrits exclusivement par le service_role
--  (Edge Functions live-auto-chat / paddle-webhook / saspay-webhook).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. COMMANDES : prestataire, transaction Paddle, montant local, type d'achat
-- ----------------------------------------------------------------------------
alter table public.orders add column if not exists provider text not null default 'saspay';
alter table public.orders add column if not exists paddle_transaction_id text;
alter table public.orders add column if not exists montant_local numeric(12, 2);
alter table public.orders add column if not exists devise_locale text;
alter table public.orders add column if not exists kind text not null default 'kit';

create index if not exists orders_provider_idx on public.orders (provider);
create index if not exists orders_kind_idx on public.orders (kind);
create unique index if not exists orders_paddle_transaction_id_key
  on public.orders (paddle_transaction_id)
  where paddle_transaction_id is not null;
-- Anti-rejeu : un paiement SasPay ne peut servir qu'une seule commande.
create unique index if not exists orders_saspay_payment_id_key
  on public.orders (saspay_payment_id)
  where saspay_payment_id is not null;

comment on column public.orders.provider is
  'Prestataire du paiement : saspay (devise locale) ou paddle (EUR/USD).';
comment on column public.orders.paddle_transaction_id is
  'Identifiant txn_… de la transaction Paddle Billing.';
comment on column public.orders.montant_local is
  'Montant réellement facturé dans devise_locale (le client n''envoie jamais de montant).';
comment on column public.orders.devise_locale is
  'Devise réellement facturée : devise locale SasPay, ou EUR/USD Paddle.';
comment on column public.orders.kind is
  'Type d''achat : kit (livré par livrerCommande) ou studio (abonnement Studio Live).';

-- ----------------------------------------------------------------------------
-- 2. ABONNEMENTS STUDIO LIVE
-- ----------------------------------------------------------------------------
create table if not exists public.studio_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references auth.users (id) on delete set null,
  email text not null,
  nom_activite text not null,
  metier_code text not null,
  metier_label text,
  pays_code text not null,
  pays_label text,
  devise text not null,
  montant_local numeric(12, 2) not null,
  montant_usd numeric(12, 2) not null default 10,
  provider text not null default 'saspay',
  status text not null default 'EN_ATTENTE',
  saspay_session_id text,
  saspay_payment_id text,
  paddle_transaction_id text,
  guide_status text not null default 'EN_ATTENTE',
  guide_error text,
  started_at timestamptz,
  expires_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint studio_subscriptions_provider_check
    check (provider in ('saspay', 'paddle')),
  constraint studio_subscriptions_status_check
    check (status in ('EN_ATTENTE', 'PAYE', 'ACTIF', 'EXPIRE', 'ECHEC')),
  constraint studio_subscriptions_guide_status_check
    check (guide_status in ('EN_ATTENTE', 'EN_COURS', 'PRET', 'ERREUR'))
);

create index if not exists studio_subscriptions_user_idx
  on public.studio_subscriptions (user_id, created_at desc);
create index if not exists studio_subscriptions_email_idx
  on public.studio_subscriptions (lower(email));
create index if not exists studio_subscriptions_status_idx
  on public.studio_subscriptions (status, expires_at);
create unique index if not exists studio_subscriptions_saspay_session_key
  on public.studio_subscriptions (saspay_session_id)
  where saspay_session_id is not null;
create unique index if not exists studio_subscriptions_paddle_transaction_key
  on public.studio_subscriptions (paddle_transaction_id)
  where paddle_transaction_id is not null;
-- Anti-rejeu : un paiement SasPay ne peut activer qu'un seul abonnement.
create unique index if not exists studio_subscriptions_saspay_payment_key
  on public.studio_subscriptions (saspay_payment_id)
  where saspay_payment_id is not null;

comment on table public.studio_subscriptions is
  'Abonnements Studio Live (10 USD / 30 jours), activés uniquement côté serveur.';
comment on column public.studio_subscriptions.devise is
  'Devise réellement facturée (devise locale SasPay ou EUR/USD Paddle).';
comment on column public.studio_subscriptions.montant_local is
  'Montant facturé dans la devise ci-dessus.';
comment on column public.studio_subscriptions.montant_usd is
  'Prix de référence : 10 USD pour 30 jours.';
comment on column public.studio_subscriptions.guide_status is
  'État du Livre Guide Live : EN_ATTENTE, EN_COURS, PRET ou ERREUR.';
comment on column public.studio_subscriptions.expires_at is
  'Fin de l''abonnement : started_at + 30 jours (posé à l''activation).';

-- ----------------------------------------------------------------------------
-- 3. LIVRE GUIDE LIVE
-- ----------------------------------------------------------------------------
create table if not exists public.studio_guides (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid unique not null
    references public.studio_subscriptions (id) on delete cascade,
  user_id uuid null,
  email text,
  metier_code text,
  metier_label text,
  pays_code text,
  titre text,
  contenu_html text,
  contenu_markdown text,
  statut text not null default 'EN_ATTENTE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists studio_guides_user_idx
  on public.studio_guides (user_id, created_at desc);

comment on table public.studio_guides is
  'Livre Guide Live personnalisé (une ligne par abonnement, générée par IA).';
comment on column public.studio_guides.statut is
  'État du guide : EN_ATTENTE, EN_COURS, PRET ou ERREUR.';

-- ----------------------------------------------------------------------------
-- 4. SESSIONS DE LIVE (régie)
-- ----------------------------------------------------------------------------
create table if not exists public.studio_live_sessions (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null
    references public.studio_subscriptions (id) on delete cascade,
  user_id uuid null references auth.users (id) on delete set null,
  room_id text unique not null,
  invite_token text not null,
  titre text,
  plateformes text[] not null default '{}'::text[],
  format text not null default 'SOLO',
  mode_visuel text not null default 'CAMERA',
  fiche_produit jsonb not null default '{}'::jsonb,
  statut text not null default 'BROUILLON',
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint studio_live_sessions_format_check check (format in ('SOLO', 'DUO')),
  constraint studio_live_sessions_mode_visuel_check check (mode_visuel in ('CAMERA', 'ECRAN')),
  constraint studio_live_sessions_statut_check
    check (statut in ('BROUILLON', 'PRET', 'EN_DIRECT', 'TERMINE'))
);

create index if not exists studio_live_sessions_subscription_idx
  on public.studio_live_sessions (subscription_id, created_at desc);
create index if not exists studio_live_sessions_user_idx
  on public.studio_live_sessions (user_id, created_at desc);

comment on table public.studio_live_sessions is
  'Salles de live du Studio Live (régie + accès invité par invite_token).';
comment on column public.studio_live_sessions.invite_token is
  'Jeton d''invitation à ne jamais exposer publiquement hors du lien /live/:roomId?invite=…';
comment on column public.studio_live_sessions.mode_visuel is
  'CAMERA (produits) ou ECRAN (partage d''écran).';

-- ----------------------------------------------------------------------------
-- 5. MESSAGES DU LIVE (chat salle + chat IA)
-- ----------------------------------------------------------------------------
create table if not exists public.studio_live_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null
    references public.studio_live_sessions (id) on delete cascade,
  room_id text not null,
  platform text not null default 'SALLE',
  role text not null,
  author text,
  content text not null,
  created_at timestamptz not null default now(),
  constraint studio_live_messages_platform_check
    check (platform in ('SALLE', 'TIKTOK', 'YOUTUBE', 'INSTAGRAM')),
  constraint studio_live_messages_role_check check (role in ('user', 'assistant'))
);

create index if not exists studio_live_messages_room_idx
  on public.studio_live_messages (room_id, created_at desc);
create index if not exists studio_live_messages_session_idx
  on public.studio_live_messages (session_id, created_at desc);
create index if not exists studio_live_messages_created_idx
  on public.studio_live_messages (created_at desc);

comment on table public.studio_live_messages is
  'Messages du chat de live. Écriture exclusivement via service_role (chat IA inclus).';

-- ----------------------------------------------------------------------------
-- 6. TRIGGERS updated_at (fonction créée par la migration de base)
-- ----------------------------------------------------------------------------
drop trigger if exists studio_subscriptions_touch_updated_at on public.studio_subscriptions;
create trigger studio_subscriptions_touch_updated_at
  before update on public.studio_subscriptions
  for each row execute function public.touch_updated_at();

drop trigger if exists studio_guides_touch_updated_at on public.studio_guides;
create trigger studio_guides_touch_updated_at
  before update on public.studio_guides
  for each row execute function public.touch_updated_at();

drop trigger if exists studio_live_sessions_touch_updated_at on public.studio_live_sessions;
create trigger studio_live_sessions_touch_updated_at
  before update on public.studio_live_sessions
  for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 7. FONCTIONS D'ACCÈS (security definer : jamais de récursion RLS)
-- ----------------------------------------------------------------------------

-- L'abonnement est-il actif ET appartient-il à l'appelant (uid ou email du JWT) ?
create or replace function public.studio_a_acces(p_subscription_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.studio_subscriptions s
    where s.id = p_subscription_id
      and s.status = 'ACTIF'
      and (s.expires_at is null or s.expires_at > now())
      and (
        s.user_id = auth.uid()
        or (
          coalesce(auth.jwt() ->> 'email', '') <> ''
          and lower(s.email) = lower(auth.jwt() ->> 'email')
        )
      )
  );
$$;

-- L'abonnement Studio le plus récent de l'appelant (ACTIF en priorité).
create or replace function public.mon_abonnement_studio()
returns public.studio_subscriptions
language sql
stable
security definer
set search_path = public
as $$
  select s.*
  from public.studio_subscriptions s
  where s.user_id = auth.uid()
     or (
       coalesce(auth.jwt() ->> 'email', '') <> ''
       and lower(s.email) = lower(auth.jwt() ->> 'email')
     )
  order by
    case when s.status = 'ACTIF' then 0 else 1 end,
    s.expires_at desc nulls last,
    s.created_at desc
  limit 1;
$$;

-- La session est-elle publique (PRET ou EN_DIRECT) ? Utilisé par la RLS du chat
-- pour éviter d'exposer les lignes de studio_live_sessions (invite_token inclus).
create or replace function public.studio_session_publique(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.studio_live_sessions s
    join public.studio_subscriptions a on a.id = s.subscription_id
    where s.id = p_session_id
      and s.statut in ('PRET', 'EN_DIRECT')
      and a.status = 'ACTIF'
      and (a.expires_at is null or a.expires_at > now())
  );
$$;

revoke all on function public.studio_a_acces(uuid) from public;
revoke all on function public.mon_abonnement_studio() from public;
revoke all on function public.studio_session_publique(uuid) from public;

grant execute on function public.studio_a_acces(uuid) to authenticated, service_role;
grant execute on function public.mon_abonnement_studio() to authenticated, service_role;
grant execute on function public.studio_session_publique(uuid) to anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 8. RLS — lecture seule côté client, écriture service_role uniquement
-- ----------------------------------------------------------------------------
alter table public.studio_subscriptions enable row level security;
alter table public.studio_guides enable row level security;
alter table public.studio_live_sessions enable row level security;
alter table public.studio_live_messages enable row level security;

-- 8.1 Abonnements : lecture par le propriétaire (uid) ou par email du JWT.
drop policy if exists "studio_subscriptions_select_own" on public.studio_subscriptions;
create policy "studio_subscriptions_select_own" on public.studio_subscriptions
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      coalesce(auth.jwt() ->> 'email', '') <> ''
      and lower(email) = lower(auth.jwt() ->> 'email')
    )
  );

-- 8.2 Guides : lecture via l'abonnement accessible (même règle, sans statut).
drop policy if exists "studio_guides_select_own" on public.studio_guides;
create policy "studio_guides_select_own" on public.studio_guides
  for select to authenticated
  using (
    exists (
      select 1
      from public.studio_subscriptions s
      where s.id = studio_guides.subscription_id
        and (
          s.user_id = auth.uid()
          or (
            coalesce(auth.jwt() ->> 'email', '') <> ''
            and lower(s.email) = lower(auth.jwt() ->> 'email')
          )
        )
    )
  );

-- 8.3 Sessions : CRUD réservé au propriétaire d'un abonnement ACTIF.
drop policy if exists "studio_live_sessions_owner_all" on public.studio_live_sessions;
create policy "studio_live_sessions_owner_all" on public.studio_live_sessions
  for all to authenticated
  using (public.studio_a_acces(subscription_id))
  with check (public.studio_a_acces(subscription_id));

-- 8.4 Messages : lecture publique uniquement quand le live est ouvert
--     (PRET / EN_DIRECT). Aucune policy d'écriture : service_role seulement.
drop policy if exists "studio_live_messages_public_read" on public.studio_live_messages;
create policy "studio_live_messages_public_read" on public.studio_live_messages
  for select to anon, authenticated
  using (public.studio_session_publique(session_id));

-- Le propriétaire peut relire le chat de son live même terminé (archive).
drop policy if exists "studio_live_messages_owner_read" on public.studio_live_messages;
create policy "studio_live_messages_owner_read" on public.studio_live_messages
  for select to authenticated
  using (
    exists (
      select 1
      from public.studio_live_sessions s
      where s.id = studio_live_messages.session_id
        and public.studio_a_acces(s.subscription_id)
    )
  );

-- ----------------------------------------------------------------------------
-- 9. GRANTS (la RLS reste la barrière d'écriture)
-- ----------------------------------------------------------------------------
grant select on public.studio_subscriptions to authenticated;
grant select on public.studio_guides to authenticated;
grant select, insert, update, delete on public.studio_live_sessions to authenticated;
grant select on public.studio_live_messages to anon, authenticated;

grant all on public.studio_subscriptions to service_role;
grant all on public.studio_guides to service_role;
grant all on public.studio_live_sessions to service_role;
grant all on public.studio_live_messages to service_role;

-- ----------------------------------------------------------------------------
-- 10. TEMPS RÉEL sur le chat de live
-- ----------------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.studio_live_messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

-- ----------------------------------------------------------------------------
-- 11. EXPIRATION AUTOMATIQUE (à planifier avec pg_cron si disponible)
--     Marque EXPIRE les abonnements arrivés à échéance.
-- ----------------------------------------------------------------------------
create or replace function public.expirer_abonnements_studio()
returns void
language sql
security definer
set search_path = public
as $$
  update public.studio_subscriptions
  set status = 'EXPIRE'
  where status = 'ACTIF'
    and expires_at is not null
    and expires_at <= now();
$$;

revoke all on function public.expirer_abonnements_studio() from public;
grant execute on function public.expirer_abonnements_studio() to service_role;

comment on function public.expirer_abonnements_studio() is
  'Passe en EXPIRE les abonnements Studio Live échus (à planifier via pg_cron).';
