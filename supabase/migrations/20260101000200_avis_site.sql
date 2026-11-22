-- ============================================================================
--  AVIS CLIENTS DU SITE — notation de 1 à 5 étoiles
--  Les visiteurs peuvent noter le site et laisser un commentaire depuis la
--  page d'accueil. Les avis sont publiés immédiatement (est_publie = true).
--  Aucune donnée sensible n'est collectée : nom affiché, pays, ville, texte.
-- ============================================================================

create extension if not exists pgcrypto;

create table if not exists public.avis_site (
  id uuid primary key default gen_random_uuid(),
  note integer not null,
  nom text not null,
  pays text,
  ville text,
  commentaire text not null,
  est_publie boolean not null default true,
  created_at timestamptz not null default now(),
  constraint avis_site_note_check check (note between 1 and 5),
  constraint avis_site_nom_check check (char_length(btrim(nom)) between 2 and 60),
  constraint avis_site_commentaire_check check (char_length(btrim(commentaire)) between 5 and 1200),
  constraint avis_site_pays_check check (pays is null or char_length(pays) <= 80),
  constraint avis_site_ville_check check (ville is null or char_length(ville) <= 80)
);

create index if not exists avis_site_publie_idx
  on public.avis_site (est_publie, created_at desc);

alter table public.avis_site enable row level security;

-- Lecture publique des avis publiés (page d'accueil).
drop policy if exists "avis_site_lecture_publique" on public.avis_site;
create policy "avis_site_lecture_publique" on public.avis_site
  for select to anon, authenticated
  using (est_publie = true);

-- Dépôt d'un avis par un visiteur, sans compte. Il ne peut pas créer un avis
-- masqué : est_publie doit valoir true. Aucune policy d'update/delete publique :
-- la modération se fait côté serveur (service_role) ou en SQL.
drop policy if exists "avis_site_insertion_publique" on public.avis_site;
create policy "avis_site_insertion_publique" on public.avis_site
  for insert to anon, authenticated
  with check (est_publie = true);

grant select, insert on public.avis_site to anon, authenticated;

comment on table public.avis_site is
  'Avis clients affichés sur la page d''accueil (note 1-5, nom, pays/ville, commentaire).';
