-- ============================================================================
--  ESSAIS GRATUITS STUDIO LIVE + RENDU ÉDITORIAL DES LIVRES
--
--  Le socle `studio_trials` (migration 20260101000600) est conservé pour
--  compatibilité, mais la source de vérité des essais devient
--  `public.live_subscriptions` : un essai = une ligne (user_id unique),
--  is_trial = true, trial_started_at / trial_ends_at.
--
--  Aucune écriture client : la RPC security definer est le seul chemin.
--  Aucun prix Paddle/SasPay n'est créé : l'essai est purement applicatif.
-- ============================================================================

create extension if not exists pgcrypto;

-- Le tableau de gestion est désormais conservé en JSON pour un rendu web
-- (aperçu, CSV, copie Google Sheets) même si Google Sheets est indisponible.
alter table public.kits add column if not exists sheet_data jsonb not null default '[]'::jsonb;
comment on column public.kits.sheet_data is
  'Lignes du tableau de gestion (tableau de tableaux) pour view-kit : aperçu, CSV et copie Sheets.';

-- ----------------------------------------------------------------------------
-- 1. TABLE live_subscriptions (essais gratuits)
-- ----------------------------------------------------------------------------
create table if not exists public.live_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  is_trial boolean not null default true,
  trial_started_at timestamptz not null default now(),
  trial_ends_at timestamptz not null default (now() + interval '3 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint live_subscriptions_trial_check check (is_trial = true),
  constraint live_subscriptions_dates_check check (
    trial_ends_at = trial_started_at + interval '3 days'
  )
);

comment on table public.live_subscriptions is
  'Essais gratuits Studio Live (3 jours). Un seul essai par utilisateur, créé côté serveur.';
comment on column public.live_subscriptions.is_trial is
  'Vrai pour un essai gratuit. La table est réservée aux essais ; les abonnements payés restent dans studio_subscriptions.';
comment on column public.live_subscriptions.trial_ends_at is
  'Fin de l''essai : exactement 3 jours après trial_started_at, jamais prolongeable.';

create index if not exists live_subscriptions_trial_ends_idx
  on public.live_subscriptions (trial_ends_at);
create index if not exists live_subscriptions_created_idx
  on public.live_subscriptions (created_at desc);

-- Reprise des essais déjà créés dans l'ancienne table.
insert into public.live_subscriptions (
  user_id, is_trial, trial_started_at, trial_ends_at, created_at, updated_at
)
select
  t.user_id, true, t.started_at, t.ends_at, t.created_at, t.created_at
from public.studio_trials t
on conflict (user_id) do nothing;

-- ----------------------------------------------------------------------------
-- 2. RLS — lecture de son propre essai uniquement
-- ----------------------------------------------------------------------------
alter table public.live_subscriptions enable row level security;

drop policy if exists "live_subscriptions_select_own" on public.live_subscriptions;
create policy "live_subscriptions_select_own" on public.live_subscriptions
  for select to authenticated
  using (user_id = auth.uid());

revoke insert, update, delete on public.live_subscriptions from anon, authenticated;
grant select on public.live_subscriptions to authenticated;

drop trigger if exists live_subscriptions_touch_updated_at on public.live_subscriptions;
create trigger live_subscriptions_touch_updated_at
  before update on public.live_subscriptions
  for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 3. DÉMARRAGE DE L'ESSAI (serveur uniquement)
-- ----------------------------------------------------------------------------
drop function if exists public.demarrer_essai_studio();

create function public.demarrer_essai_studio()
returns public.live_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_email_confirme timestamptz;
  v_essai public.live_subscriptions;
begin
  if v_user is null then
    raise exception 'Connexion requise pour démarrer l''essai gratuit.'
      using errcode = '28000';
  end if;

  select email_confirmed_at into v_email_confirme
  from auth.users
  where id = v_user;

  if v_email_confirme is null then
    raise exception 'Confirmez votre adresse email avant de démarrer l''essai gratuit.'
      using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.studio_subscriptions s
    where s.user_id = v_user
      and s.status = 'ACTIF'
      and (s.expires_at is null or s.expires_at > now())
  ) then
    raise exception 'Vous avez déjà un abonnement Studio Live actif.'
      using errcode = 'P0001';
  end if;

  insert into public.live_subscriptions (
    user_id, is_trial, trial_started_at, trial_ends_at
  )
  values (v_user, true, now(), now() + interval '3 days')
  on conflict (user_id) do nothing
  returning * into v_essai;

  if v_essai.user_id is null then
    raise exception 'Votre essai gratuit a déjà été utilisé et ne peut pas être prolongé.'
      using errcode = 'P0001';
  end if;

  return v_essai;
end;
$$;

revoke all on function public.demarrer_essai_studio() from public;
grant execute on function public.demarrer_essai_studio() to authenticated;

-- ----------------------------------------------------------------------------
-- 4. HELPERS D'ACCÈS (remplacent les versions studio_trials)
-- ----------------------------------------------------------------------------
create or replace function public.essai_studio_actif(p_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.live_subscriptions t
    where t.user_id = p_user
      and t.is_trial
      and t.trial_ends_at > now()
  );
$$;

create or replace function public.acces_studio(p_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.studio_subscriptions s
      where s.user_id = p_user
        and s.status = 'ACTIF'
        and (s.expires_at is null or s.expires_at > now())
    )
    or exists (
      select 1
      from public.live_subscriptions t
      where t.user_id = p_user
        and t.is_trial
        and t.trial_ends_at > now()
    );
$$;

create or replace function public.compter_reponses_ia_essai(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.studio_live_messages m
  join public.studio_live_sessions s on s.id = m.session_id
  where s.user_id = p_user
    and s.subscription_id is null
    and m.role = 'assistant'
    and m.created_at >= date_trunc('day', now());
$$;

revoke all on function public.essai_studio_actif(uuid) from public;
revoke all on function public.acces_studio(uuid) from public;
revoke all on function public.compter_reponses_ia_essai(uuid) from public;
grant execute on function public.essai_studio_actif(uuid) to authenticated, service_role;
grant execute on function public.acces_studio(uuid) to authenticated, service_role;
grant execute on function public.compter_reponses_ia_essai(uuid) to service_role;

-- Une salle d'essai reste publique tant que l'essai est actif.
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
    left join public.studio_subscriptions a on a.id = s.subscription_id
    where s.id = p_session_id
      and s.statut in ('PRET', 'EN_DIRECT')
      and (
        (
          s.subscription_id is not null
          and a.status = 'ACTIF'
          and (a.expires_at is null or a.expires_at > now())
        )
        or (
          s.subscription_id is null
          and s.user_id is not null
          and exists (
            select 1
            from public.live_subscriptions t
            where t.user_id = s.user_id
              and t.is_trial
              and t.trial_ends_at > now()
          )
        )
      )
  );
$$;

-- ----------------------------------------------------------------------------
-- 5. COMPTEUR ADMINISTRATEUR
-- ----------------------------------------------------------------------------
create or replace function public.admin_compter_essais_gratuits()
returns table (
  total bigint,
  actifs bigint,
  aujourdhui bigint,
  sept_derniers_jours bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Accès administrateur requis.' using errcode = '42501';
  end if;

  return query
  select
    count(*)::bigint as total,
    count(*) filter (where trial_ends_at > now())::bigint as actifs,
    count(*) filter (where created_at >= date_trunc('day', now()))::bigint as aujourdhui,
    count(*) filter (where created_at >= now() - interval '7 days')::bigint as sept_derniers_jours
  from public.live_subscriptions
  where is_trial;
end;
$$;

revoke all on function public.admin_compter_essais_gratuits() from public;
grant execute on function public.admin_compter_essais_gratuits() to authenticated;

-- ----------------------------------------------------------------------------
-- 6. FIN — aucun prix d'essai Paddle/SasPay.
-- ----------------------------------------------------------------------------
