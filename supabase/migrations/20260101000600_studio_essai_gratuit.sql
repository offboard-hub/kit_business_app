-- ============================================================================
--  ESSAI GRATUIT STUDIO LIVE (3 JOURS) — géré dans l'application
--
--  • Un seul essai par utilisateur, créé uniquement côté serveur (RPC
--    security definer), avec l'heure du serveur : ends_at = started_at + 3 jours.
--  • Email confirmé obligatoire avant de démarrer l'essai.
--  • RLS : l'utilisateur ne peut que lire sa propre ligne ; aucune écriture
--    client, aucune prolongation possible.
--  • Accès Studio Live = abonnement payé ACTIF ou essai non expiré.
--  • Pendant l'essai : pas d'accès au Livre Guide (les guides restent liés aux
--    abonnements payés). Le chat IA est limité à 20 réponses par jour.
--
--  Aucun prix d'essai n'est créé chez Paddle ou SasPay : l'essai est purement
--  applicatif et ne déclenche aucun prélèvement.
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. TABLE studio_trials
-- ----------------------------------------------------------------------------
create table if not exists public.studio_trials (
  user_id uuid primary key references auth.users (id) on delete cascade,
  started_at timestamptz not null default now(),
  ends_at timestamptz not null default (now() + interval '3 days'),
  created_at timestamptz not null default now(),
  constraint studio_trials_dates_check check (
    ends_at = started_at + interval '3 days'
  )
);

comment on table public.studio_trials is
  'Essai gratuit Studio Live (3 jours), un seul par utilisateur, créé côté serveur.';
comment on column public.studio_trials.ends_at is
  'Fin de l''essai : exactement 3 jours après started_at, jamais prolongeable.';

alter table public.studio_trials enable row level security;

drop policy if exists "studio_trials_select_own" on public.studio_trials;
create policy "studio_trials_select_own" on public.studio_trials
  for select to authenticated
  using (user_id = auth.uid());

-- Aucune policy d'insertion/mise à jour/suppression : le client ne peut rien
-- écrire. La fonction security definer ci-dessous est le seul chemin de création.
revoke insert, update, delete on public.studio_trials from anon, authenticated;
grant select on public.studio_trials to authenticated;

-- ----------------------------------------------------------------------------
-- 2. DÉMARRAGE DE L'ESSAI (serveur uniquement)
-- ----------------------------------------------------------------------------
create or replace function public.demarrer_essai_studio()
returns public.studio_trials
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_email_confirme timestamptz;
  v_essai public.studio_trials;
begin
  if v_user is null then
    raise exception 'Connexion requise pour démarrer l''essai gratuit.'
      using errcode = '28000';
  end if;

  -- L'email doit être confirmé : l'essai est nominatif et non transférable.
  select email_confirmed_at into v_email_confirme
  from auth.users
  where id = v_user;

  if v_email_confirme is null then
    raise exception 'Confirmez votre adresse email avant de démarrer l''essai gratuit.'
      using errcode = 'P0002';
  end if;

  -- Un abonnement payé actif rend l'essai inutile : on évite les doublons.
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

  -- Un seul essai par utilisateur, jamais prolongeable.
  insert into public.studio_trials (user_id, started_at, ends_at)
  values (v_user, now(), now() + interval '3 days')
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
-- 3. HELPERS D'ACCÈS
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
    from public.studio_trials t
    where t.user_id = p_user
      and t.ends_at > now()
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
      from public.studio_trials t
      where t.user_id = p_user
        and t.ends_at > now()
    );
$$;

-- Compteur des réponses IA du jour pour un essai (service_role uniquement).
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

-- ----------------------------------------------------------------------------
-- 4. SESSIONS SANS ABONNEMENT (essai)
-- ----------------------------------------------------------------------------
alter table public.studio_live_sessions
  alter column subscription_id drop not null;

create index if not exists studio_live_sessions_user_idx
  on public.studio_live_sessions (user_id, created_at desc);

-- Le propriétaire peut gérer ses sessions s'il a un abonnement actif OU un
-- essai actif ; les autres écritures restent service_role.
drop policy if exists "studio_live_sessions_owner_all" on public.studio_live_sessions;
create policy "studio_live_sessions_owner_all" on public.studio_live_sessions
  for all to authenticated
  using (
    user_id = auth.uid()
    and public.acces_studio()
  )
  with check (
    user_id = auth.uid()
    and public.acces_studio()
  );

-- Le propriétaire peut relire le chat de son live, y compris pendant l'essai
-- et après la fin du direct, tant que son accès est actif.
drop policy if exists "studio_live_messages_owner_read" on public.studio_live_messages;
create policy "studio_live_messages_owner_read" on public.studio_live_messages
  for select to authenticated
  using (
    exists (
      select 1
      from public.studio_live_sessions s
      where s.id = studio_live_messages.session_id
        and s.user_id = auth.uid()
        and public.acces_studio()
    )
  );

-- Une salle d'essai reste publique (chat + salle) uniquement tant que l'essai
-- est actif ; une salle d'abonnement suit l'état de l'abonnement.
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
            from public.studio_trials t
            where t.user_id = s.user_id
              and t.ends_at > now()
          )
        )
      )
  );
$$;

-- ----------------------------------------------------------------------------
-- 5. FIN — aucun prix d'essai créé chez Paddle/SasPay.
--    L'essai est purement applicatif : aucun prélèvement, aucune reconduction.
-- ----------------------------------------------------------------------------
