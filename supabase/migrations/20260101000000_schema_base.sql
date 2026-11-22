-- ============================================================================
--  KIT BUSINESS — SCHÉMA DE BASE (positionnement Afrique francophone, FCFA)
--  Migration idempotente : peut être rejouée sans casser l'existant.
--  À exécuter dans Supabase > SQL Editor (ou via `supabase db push`).
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. PROFILS UTILISATEURS
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  credits integer not null default 0,
  created_at timestamptz not null default now()
);

-- Colonnes ajoutées pour le positionnement africain et l'espace admin.
alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists pays_code text;
alter table public.profiles add column if not exists whatsapp text;
alter table public.profiles add column if not exists welcome_email_sent_at timestamptz;

alter table public.profiles enable row level security;

-- Un utilisateur ne lit que son propre profil. Aucune policy d'écriture :
-- les crédits et le rôle admin sont modifiés uniquement côté serveur
-- (service_role), ce qui empêche toute auto-promotion depuis le client.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to authenticated using (id = auth.uid());

-- ----------------------------------------------------------------------------
-- 2. CATALOGUE PRODUITS (tarifs en FCFA, plus aucun prix en DH)
-- ----------------------------------------------------------------------------
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  credits_added integer not null default 1,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.products add column if not exists type_produit text;
alter table public.products add column if not exists price_fcfa integer not null default 0;
alter table public.products add column if not exists devise text not null default 'XOF';
alter table public.products add column if not exists active boolean not null default true;

-- Les identifiants sont conservés à l'identique pour ne rien casser côté app.
insert into public.products (id, name, description, type_produit, credits_added, price_fcfa, devise, active)
values
  ('8cbddad5-7747-424e-8ed1-a1829ae46914', 'Les Prompts IA',
   '10 prompts IA prêts à copier pour vendre, produire du contenu et gérer votre activité.',
   'prompt', 1, 3000, 'XOF', true),
  ('d4b7a69e-1720-4038-8da8-cf782fed24e9', 'Le Sheet Automatisé',
   'Un Google Sheet qui calcule vos ventes, stocks, marges et point mort à votre place.',
   'sheet', 1, 3500, 'XOF', true),
  ('f8a7dd07-d155-4b83-8289-286f2e44ee6b', 'Le Livre Stratégique',
   'Votre plan d''action complet, rédigé pour votre métier et votre pays.',
   'livre', 1, 5000, 'XOF', true),
  ('54e2150a-1648-4119-a4df-208bcb121c27', 'Le Pack Complet',
   'Le livre stratégique + les prompts IA + le Google Sheet automatisé : tout votre kit en une fois.',
   'pack', 3, 9000, 'XOF', true)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  type_produit = excluded.type_produit,
  credits_added = excluded.credits_added,
  price_fcfa = excluded.price_fcfa,
  devise = excluded.devise,
  active = true;

alter table public.products enable row level security;

drop policy if exists "products_public_read" on public.products;
create policy "products_public_read" on public.products
  for select to anon, authenticated using (active = true);

-- ----------------------------------------------------------------------------
-- 3. KITS GÉNÉRÉS (métadonnées texte uniquement : jamais de fichier stocké)
-- ----------------------------------------------------------------------------
create table if not exists public.kits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  secteur_client text,
  livre_html text,
  prompts_html text,
  sheet_url text,
  status text not null default 'EN_COURS',
  created_at timestamptz not null default now()
);

alter table public.kits add column if not exists metier_code text;
alter table public.kits add column if not exists nom_projet text;
alter table public.kits add column if not exists pays_code text;
alter table public.kits add column if not exists produit_type text;
alter table public.kits add column if not exists whatsapp text;
alter table public.kits add column if not exists order_id uuid;
alter table public.kits add column if not exists access_token uuid not null default gen_random_uuid();
alter table public.kits add column if not exists error_message text;
alter table public.kits add column if not exists updated_at timestamptz not null default now();

create index if not exists kits_user_id_idx on public.kits (user_id, created_at desc);
create index if not exists kits_order_id_idx on public.kits (order_id);

alter table public.kits enable row level security;

drop policy if exists "kits_select_own" on public.kits;
create policy "kits_select_own" on public.kits
  for select to authenticated using (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 4. TRANSACTIONS (Saspay exclusivement)
-- ----------------------------------------------------------------------------
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  provider text not null default 'saspay',
  transaction_token text,
  product_id uuid,
  amount_paid numeric(12, 2),
  status text not null default 'success',
  created_at timestamptz not null default now()
);

alter table public.transactions add column if not exists currency text not null default 'XOF';

create index if not exists transactions_user_id_idx on public.transactions (user_id, created_at desc);

alter table public.transactions enable row level security;

drop policy if exists "transactions_select_own" on public.transactions;
create policy "transactions_select_own" on public.transactions
  for select to authenticated using (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 5. FONCTIONS SERVEUR : crédits, remboursement, création de profil
-- ----------------------------------------------------------------------------
create or replace function public.use_credits(
  p_user_id uuid,
  p_metier text,
  p_product_type text,
  p_cost integer
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_credits integer;
  v_kit_id uuid;
begin
  select credits into v_credits from public.profiles where id = p_user_id for update;

  if v_credits is null then
    raise exception 'Profil introuvable pour cet utilisateur.';
  end if;

  if v_credits < p_cost then
    raise exception 'Crédits insuffisants : % crédit(s) requis, % disponible(s).', p_cost, v_credits;
  end if;

  update public.profiles set credits = credits - p_cost where id = p_user_id;

  insert into public.kits (user_id, secteur_client, produit_type, status)
  values (p_user_id, p_metier, p_product_type, 'EN_COURS')
  returning id into v_kit_id;

  return v_kit_id;
end;
$$;

create or replace function public.refund_credits(
  p_user_id uuid,
  p_amount integer
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set credits = credits + p_amount where id = p_user_id;
end;
$$;

revoke all on function public.use_credits(uuid, text, text, integer) from public;
revoke all on function public.refund_credits(uuid, integer) from public;
grant execute on function public.use_credits(uuid, text, text, integer) to authenticated, service_role;
grant execute on function public.refund_credits(uuid, integer) to service_role;

-- Création automatique du profil à l'inscription (sans email de confirmation).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Horodatage automatique de mise à jour.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists kits_touch_updated_at on public.kits;
create trigger kits_touch_updated_at
  before update on public.kits
  for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------------------
-- 6. ACCÈS ADMINISTRATEUR (lecture des profils / transactions côté back-office)
-- ----------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

grant execute on function public.is_admin() to authenticated, service_role;

drop policy if exists "profiles_admin_read" on public.profiles;
create policy "profiles_admin_read" on public.profiles
  for select to authenticated using (public.is_admin());
