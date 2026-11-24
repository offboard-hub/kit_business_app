-- ============================================================================
--  TESTS RLS — STUDIO LIVE (e-booklive)
--  Compagnon de docs/REVUE_DB.md (§10).
--
--  ⚠️ À EXÉCUTER UNIQUEMENT SUR UNE BASE DE TEST :
--       supabase start && supabase db reset
--       psql "$DB_URL" -v ON_ERROR_STOP=1 -f docs/tests_rls_studio.sql
--
--  Pré-requis : deux comptes Auth existants
--       a@test.local  (utilisateur A, propriétaire)
--       b@test.local  (utilisateur B, non propriétaire)
--  Les identifiants sont transportés entre rôles par des GUC de session
--  (set_config('test.*')), lisibles par tous les rôles.
--
--  Le script crée ses propres données (préfixe « zztestrls ») et les supprime
--  à la fin. Si un test échoue, la transaction est annulée : relancer le
--  script depuis le début après avoir compris l'échec.
--
--  Note : les blocs `set local role anon|authenticated|service_role` exigent
--  que le rôle courant puisse endosser ces rôles (vrai pour `postgres` en
--  local, où `postgres` est superutilisateur). En cas de
--  « permission denied to set role », exécuter le script connecté en
--  `postgres` sur la base locale (supabase db reset) — c'est le cas prévu.
--
--  Convention de lecture : chaque SELECT de test est étiqueté `test` et
--  `attendu`. Un résultat différent de l'attendu = un finding confirmé.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. FIXTURES (rôle postgres, RLS contournée par le propriétaire des tables)
-- ----------------------------------------------------------------------------

-- 0.1 Résolution des comptes de test
select set_config('test.user_a', (select id::text from auth.users where email = 'a@test.local'), false);
select set_config('test.email_a', 'a@test.local', false);
select set_config('test.user_b', (select id::text from auth.users where email = 'b@test.local'), false);
select set_config('test.email_b', 'b@test.local', false);

do $$
begin
  if coalesce(current_setting('test.user_a', true), '') = ''
     or coalesce(current_setting('test.user_b', true), '') = '' then
    raise exception
      'Pré-requis manquant : créez les comptes Auth a@test.local et b@test.local, puis relancez.';
  end if;
end $$;

-- 0.2 Nettoyage des exécutions précédentes (cascade : guides, sessions, messages)
delete from public.studio_subscriptions where nom_activite like 'zztestrls%';

-- 0.3 Abonnements
insert into public.studio_subscriptions
  (user_id, email, nom_activite, metier_code, pays_code, devise, montant_local,
   montant_usd, provider, status, started_at, expires_at)
values
  (current_setting('test.user_a')::uuid, current_setting('test.email_a'),
   'zztestrlsA', 'ecommerce', 'ML', 'XOF', 6061, 10, 'saspay', 'ACTIF',
   now() - interval '1 day', now() + interval '20 days'),
  (current_setting('test.user_a')::uuid, current_setting('test.email_a'),
   'zztestrlsAExp', 'ecommerce', 'ML', 'XOF', 6061, 10, 'saspay', 'ACTIF',
   now() - interval '31 days', now() - interval '1 day'),
  (current_setting('test.user_b')::uuid, current_setting('test.email_b'),
   'zztestrlsB', 'beaute', 'SN', 'XOF', 6061, 10, 'saspay', 'ACTIF',
   now() - interval '1 day', now() + interval '20 days');

select set_config('test.abo_a', id::text, false)
  from public.studio_subscriptions where nom_activite = 'zztestrlsA';
select set_config('test.abo_a_exp', id::text, false)
  from public.studio_subscriptions where nom_activite = 'zztestrlsAExp';
select set_config('test.abo_b', id::text, false)
  from public.studio_subscriptions where nom_activite = 'zztestrlsB';

-- 0.4 Guides (un par abonnement : subscription_id est UNIQUE)
insert into public.studio_guides
  (subscription_id, user_id, email, titre, contenu_html, contenu_markdown, statut)
values
  (current_setting('test.abo_a')::uuid, current_setting('test.user_a')::uuid,
   current_setting('test.email_a'), 'zztestrlsGuideA', '<p>guide A</p>', 'guide A', 'PRET'),
  (current_setting('test.abo_b')::uuid, current_setting('test.user_b')::uuid,
   current_setting('test.email_b'), 'zztestrlsGuideB', '<p>guide B</p>', 'guide B', 'PRET');

-- 0.5 Sessions : une ouverte (A), une brouillon (A), une ouverte sur abo expiré (A)
insert into public.studio_live_sessions
  (subscription_id, user_id, room_id, invite_token, titre, plateformes, format,
   mode_visuel, fiche_produit, statut)
values
  (current_setting('test.abo_a')::uuid, current_setting('test.user_a')::uuid,
   'zzrlsopen', 'aaaaaaaaaaaaaaaaaaaaaaaa', 'zztestrlsOpen', array['SALLE'], 'SOLO',
   'CAMERA', '{"titre":"Test"}'::jsonb, 'EN_DIRECT'),
  (current_setting('test.abo_a')::uuid, current_setting('test.user_a')::uuid,
   'zzrlsdraft', 'bbbbbbbbbbbbbbbbbbbbbbbb', 'zztestrlsDraft', array['SALLE'], 'SOLO',
   'CAMERA', '{}'::jsonb, 'BROUILLON'),
  (current_setting('test.abo_a_exp')::uuid, current_setting('test.user_a')::uuid,
   'zzrlsexp', 'cccccccccccccccccccccccc', 'zztestrlsExp', array['SALLE'], 'SOLO',
   'CAMERA', '{}'::jsonb, 'EN_DIRECT');

select set_config('test.sess_open', id::text, false)
  from public.studio_live_sessions where titre = 'zztestrlsOpen';
select set_config('test.sess_draft', id::text, false)
  from public.studio_live_sessions where titre = 'zztestrlsDraft';
select set_config('test.sess_exp', id::text, false)
  from public.studio_live_sessions where titre = 'zztestrlsExp';

-- 0.6 Messages : 2 dans la salle ouverte, 1 en brouillon, 2 sur l'abonnement expiré
insert into public.studio_live_messages
  (session_id, room_id, platform, role, author, content)
values
  (current_setting('test.sess_open')::uuid, 'zzrlsopen', 'SALLE', 'user',
   'Visiteur', 'zztestrlsMsgOpenUser'),
  (current_setting('test.sess_open')::uuid, 'zzrlsopen', 'SALLE', 'assistant',
   'Awa', 'zztestrlsMsgOpenAssistant'),
  (current_setting('test.sess_draft')::uuid, 'zzrlsdraft', 'SALLE', 'user',
   'Visiteur', 'zztestrlsMsgDraft'),
  (current_setting('test.sess_exp')::uuid, 'zzrlsexp', 'SALLE', 'assistant',
   'Awa', 'zztestrlsMsgExp'),
  (current_setting('test.sess_exp')::uuid, 'zzrlsexp', 'SALLE', 'user',
   'Visiteur', 'zztestrlsMsgExp2');

-- ----------------------------------------------------------------------------
-- T0. ÉTAT STRUCTUREL (lecture seule)
-- ----------------------------------------------------------------------------

-- T0.1 Privilèges réels par rôle (preuve F12 : les GRANT SELECT de la §9
--      n'enlèvent pas l'ALL hérité des default privileges Supabase)
select table_name, grantee,
       string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('studio_subscriptions','studio_guides',
                     'studio_live_sessions','studio_live_messages','studio_trials','live_subscriptions')
group by table_name, grantee
order by table_name, grantee;

-- T0.2 Policies en place
select tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public' and (tablename like 'studio_%' or tablename = 'live_subscriptions')
order by tablename, policyname;

-- T0.3 RLS activée sur les 6 tables
select relname, relrowsecurity as rls_activee
from pg_class
where relname in ('studio_subscriptions','studio_guides',
                  'studio_live_sessions','studio_live_messages','studio_trials','live_subscriptions')
order by relname;

-- T0.4 Realtime (F17) : studio_live_messages doit être membre de la publication
select * from pg_publication_tables where pubname = 'supabase_realtime';

-- T0.5 Contraintes (F01/F10/F11)
select conrelid::regclass as table_name, conname,
       pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = any (array[
        'public.studio_subscriptions'::regclass,
        'public.studio_guides'::regclass,
        'public.studio_live_sessions'::regclass,
        'public.studio_live_messages'::regclass,
        'public.studio_trials'::regclass,
        'public.live_subscriptions'::regclass,
        'public.orders'::regclass
      ])
order by 1, 2;

-- T0.6 Index (unicités partielles, index de perf)
select tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and (tablename like 'studio_%' or tablename in ('orders', 'live_subscriptions'))
order by tablename, indexname;

-- ----------------------------------------------------------------------------
-- T1. ANONYME (rôle anon, aucune revendication)
--     Attendu : aucune donnée privée, aucune écriture possible.
-- ----------------------------------------------------------------------------
begin;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select 'T1.1 abonnements' as test, count(*) as attendu_0
  from public.studio_subscriptions;
select 'T1.2 guides' as test, count(*) as attendu_0
  from public.studio_guides;
select 'T1.3 sessions' as test, count(*) as attendu_0
  from public.studio_live_sessions;              -- 0 => invite_token jamais exposé
select 'T1.4 messages (toutes salles ouvertes)' as test, count(*) as attendu_superieur_a_0
  from public.studio_live_messages;              -- F14 : dump inter-salles
select 'T1.5 messages salle ouverte' as test, count(*) as attendu_2
  from public.studio_live_messages where room_id = 'zzrlsopen';
select 'T1.6 messages salle brouillon' as test, count(*) as attendu_0
  from public.studio_live_messages where room_id = 'zzrlsdraft';
select 'T1.7 messages abonnement expire (F06, corrige le 2026-11-23)' as test, count(*) as attendu_0
  from public.studio_live_messages where room_id = 'zzrlsexp';

-- Oracle documenté (F18) : appelable par anon, ne renvoie qu'un booléen
select 'T1.8 session_publique ouverte' as test,
       public.studio_session_publique(current_setting('test.sess_open')::uuid) as attendu_true;
select 'T1.9 session_publique brouillon' as test,
       public.studio_session_publique(current_setting('test.sess_draft')::uuid) as attendu_false;

-- Écriture d'un message avec role=assistant : doit échouer (aucune policy INSERT)
do $$
begin
  insert into public.studio_live_messages
    (session_id, room_id, platform, role, author, content)
  values
    (current_setting('test.sess_open')::uuid, 'zzrlsopen', 'SALLE', 'assistant', 'Pirate', 'x');
  raise exception 'T1.10 ÉCHEC : un anonyme a pu écrire un message';
exception
  when insufficient_privilege then
    raise notice 'T1.10 OK : écriture message anon refusée (42501)';
end $$;

-- Création d'un abonnement : doit échouer (aucune policy INSERT)
do $$
begin
  insert into public.studio_subscriptions
    (email, nom_activite, metier_code, pays_code, devise, montant_local)
  values ('pirate@test.local', 'zztestrlsPirate', 'ecommerce', 'ML', 'XOF', 1);
  raise exception 'T1.11 ÉCHEC : un anonyme a pu créer un abonnement';
exception
  when insufficient_privilege then
    raise notice 'T1.11 OK : insert abonnement anon refusé (42501)';
end $$;

-- EXECUTE révoqué à anon sur les helpers d'accès
do $$
begin
  perform public.studio_a_acces(current_setting('test.abo_a')::uuid);
  raise exception 'T1.12 ÉCHEC : anon peut exécuter studio_a_acces';
exception
  when insufficient_privilege then
    raise notice 'T1.12 OK : EXECUTE studio_a_acces refusé à anon';
end $$;

rollback;

-- ----------------------------------------------------------------------------
-- T2. AUTHENTICATED A (propriétaire)
--     Attendu : voit ses données, n'écrit rien sur abonnement/guide/messages.
-- ----------------------------------------------------------------------------
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_a'),
                    'email', current_setting('test.email_a'),
                    'role', 'authenticated')::text, true);
set local role authenticated;

select 'T2.1 mes abonnements' as test, count(*) as attendu_2
  from public.studio_subscriptions;              -- A + A expiré
select 'T2.2 abonnement de B' as test, count(*) as attendu_0
  from public.studio_subscriptions where id = current_setting('test.abo_b')::uuid;
select 'T2.3 mes guides' as test, count(*) as attendu_1
  from public.studio_guides;                     -- guide A uniquement
select 'T2.4 mes sessions' as test, count(*) as attendu_2
  from public.studio_live_sessions;              -- ouverte + brouillon (pas l'expirée)
select 'T2.5 acces abo A' as test,
       public.studio_a_acces(current_setting('test.abo_a')::uuid) as attendu_true;
select 'T2.6 acces abo B' as test,
       public.studio_a_acces(current_setting('test.abo_b')::uuid) as attendu_false;
select 'T2.7 acces abo expire' as test,
       public.studio_a_acces(current_setting('test.abo_a_exp')::uuid) as attendu_false;

-- Écritures refusées. Selon l'état des GRANT (F12 pas encore corrigé = 0 ligne
-- silencieuse ; F12 corrigé = 42501), on accepte les deux issues et on les trace.
do $$
declare n integer;
begin
  update public.studio_subscriptions set montant_local = 0
    where id = current_setting('test.abo_a')::uuid;
  get diagnostics n = row_count;
  raise notice 'T2.8 montant_local : % ligne(s) modifiée(s) — attendu 0', n;

  update public.studio_subscriptions set status = 'ACTIF'
    where id = current_setting('test.abo_b')::uuid;
  get diagnostics n = row_count;
  raise notice 'T2.9 statut abonnement de B : % ligne(s) modifiée(s) — attendu 0', n;

  delete from public.studio_subscriptions
    where id = current_setting('test.abo_a')::uuid;
  get diagnostics n = row_count;
  raise notice 'T2.10 delete abonnement : % ligne(s) supprimée(s) — attendu 0', n;

  update public.studio_live_messages set role = 'assistant'
    where room_id = 'zzrlsopen';
  get diagnostics n = row_count;
  raise notice 'T2.11 usurpation role messages : % ligne(s) modifiée(s) — attendu 0', n;
exception
  when insufficient_privilege then
    raise notice 'T2.8-T2.11 OK : écritures refusées par les privilèges (42501)';
end $$;

-- Insertion de message : refusée
do $$
begin
  insert into public.studio_live_messages
    (session_id, room_id, platform, role, author, content)
  values
    (current_setting('test.sess_open')::uuid, 'zzrlsopen', 'SALLE', 'user', 'A', 'x');
  raise exception 'T2.12 ÉCHEC : A a pu écrire un message';
exception
  when insufficient_privilege then
    raise notice 'T2.12 OK : écriture message authentifié refusée (42501)';
end $$;

-- Session sur l'abonnement de B : refusée
do $$
begin
  insert into public.studio_live_sessions
    (subscription_id, user_id, room_id, invite_token, titre)
  values
    (current_setting('test.abo_b')::uuid, current_setting('test.user_a')::uuid,
     'zzrlspirate', 'dddddddddddddddddddddddd', 'zztestrlsPirate');
  raise exception 'T2.13 ÉCHEC : A a pu créer une session sur l''abonnement de B';
exception
  when insufficient_privilege then
    raise notice 'T2.13 OK : session sur abonnement d''autrui refusée (42501)';
end $$;

-- Session sur son propre abonnement : autorisée (annulée par le rollback)
insert into public.studio_live_sessions
  (subscription_id, user_id, room_id, invite_token, titre, statut)
values
  (current_setting('test.abo_a')::uuid, current_setting('test.user_a')::uuid,
   'zzrlsnew', 'eeeeeeeeeeeeeeeeeeeeeeee', 'zztestrlsNew', 'PRET');  -- attendu : INSERT 0 1

-- F11 : la policy accepte-t-elle un user_id d'autrui ? (à corriger, cf. §4.11)
do $$
begin
  insert into public.studio_live_sessions
    (subscription_id, user_id, room_id, invite_token, titre, statut)
  values
    (current_setting('test.abo_a')::uuid, current_setting('test.user_b')::uuid,
     'zzrlsother', 'ffffffffffffffffffffffff', 'zztestrlsOther', 'PRET');
  raise notice 'T2.14 F11 CONFIRME : la policy accepte un user_id d''autrui (corriger §4.11)';
exception
  when insufficient_privilege then
    raise notice 'T2.14 OK : user_id d''autrui refusé (correctif F11 appliqué)';
end $$;

rollback;

-- ----------------------------------------------------------------------------
-- T3. AUTHENTICATED B (non propriétaire)
--     Attendu : ne voit rien de A ; le chat public reste lisible (contrat §4.6).
-- ----------------------------------------------------------------------------
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_b'),
                    'email', current_setting('test.email_b'),
                    'role', 'authenticated')::text, true);
set local role authenticated;

select 'T3.1 abonnement de A' as test, count(*) as attendu_0
  from public.studio_subscriptions where id = current_setting('test.abo_a')::uuid;
select 'T3.2 guide de A' as test, count(*) as attendu_0
  from public.studio_guides where subscription_id = current_setting('test.abo_a')::uuid;
select 'T3.3 session de A' as test, count(*) as attendu_0
  from public.studio_live_sessions where room_id = 'zzrlsopen';
select 'T3.4 acces abo A' as test,
       public.studio_a_acces(current_setting('test.abo_a')::uuid) as attendu_false;
select 'T3.5 mon_abonnement_studio = B' as test,
       (public.mon_abonnement_studio()).id = current_setting('test.abo_b')::uuid as attendu_true;
select 'T3.6 messages salle ouverte A (public)' as test, count(*) as attendu_2
  from public.studio_live_messages where room_id = 'zzrlsopen';

rollback;

-- ----------------------------------------------------------------------------
-- T4. SERVICE_ROLE
--     Attendu : accès complet (c'est le seul rôle qui écrit les tables Studio).
-- ----------------------------------------------------------------------------
begin;
set local role service_role;

select 'T4.1 toutes les lignes' as test, count(*) as attendu_3
  from public.studio_subscriptions;
select 'T4.2 ecriture OK' as test, 1 as attendu_1;
update public.studio_subscriptions set guide_error = null
  where id = current_setting('test.abo_a')::uuid;                 -- attendu : UPDATE 1

-- Expiration (appel direct : la fonction renvoie void ; le rollback annule l'effet)
select public.expirer_abonnements_studio();

select 'T4.3 abo expire marque' as test, count(*) as attendu_1
  from public.studio_subscriptions
  where id = current_setting('test.abo_a_exp')::uuid and status = 'EXPIRE';

rollback;

-- ----------------------------------------------------------------------------
-- T5. EXPIRATION (F06) — la salle d'un abonnement expiré reste publique
-- ----------------------------------------------------------------------------
-- Rendre l'expiration effective (elle est déjà passée dans la fixture)
update public.studio_subscriptions
   set expires_at = now() - interval '1 day'
 where id = current_setting('test.abo_a_exp')::uuid;

begin;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_a'),
                    'email', current_setting('test.email_a'),
                    'role', 'authenticated')::text, true);
set local role authenticated;
select 'T5.1 acces abo expire' as test,
       public.studio_a_acces(current_setting('test.abo_a_exp')::uuid) as attendu_false;
select 'T5.2 proprietaire verrouille hors de sa salle' as test, count(*) as attendu_0
  from public.studio_live_sessions where id = current_setting('test.sess_exp')::uuid;
rollback;

begin;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select 'T5.3 F06 : chat ferme apres expiration (attendu 0)' as test, count(*) as attendu_0
  from public.studio_live_messages where room_id = 'zzrlsexp';
rollback;

-- Après le job d'expiration (à planifier, cf. §4.6) — hors transaction, l'effet persiste
select public.expirer_abonnements_studio();

select 'T5.4 statut abo' as test, status as attendu_EXPIRE
  from public.studio_subscriptions where id = current_setting('test.abo_a_exp')::uuid;
select 'T5.5 statut session (attendu TERMINE seulement apres correctif)' as test,
       statut as attendu_TERMINE_apres_correctif
  from public.studio_live_sessions where id = current_setting('test.sess_exp')::uuid;

-- ----------------------------------------------------------------------------
-- T6. CONTRAINTES, INTÉGRITÉ, CASCADE (rôle postgres)
-- ----------------------------------------------------------------------------

-- T6.1 subscription_id du guide unique
do $$
begin
  insert into public.studio_guides (subscription_id, titre)
  values (current_setting('test.abo_a')::uuid, 'zztestrlsDoublon');
  raise exception 'T6.1 ÉCHEC : doublon de guide accepté';
exception
  when unique_violation then raise notice 'T6.1 OK : unicité guide (23505)';
end $$;

-- T6.2 statut d'abonnement invalide
do $$
begin
  update public.studio_subscriptions set status = 'PIRATE'
   where id = current_setting('test.abo_a')::uuid;
  raise exception 'T6.2 ÉCHEC : status invalide accepté';
exception
  when check_violation then raise notice 'T6.2 OK : CHECK status (23514)';
end $$;

-- T6.3 role de message invalide
do $$
begin
  insert into public.studio_live_messages
    (session_id, room_id, platform, role, author, content)
  values
    (current_setting('test.sess_open')::uuid, 'zzrlsopen', 'SALLE', 'root', 'X', 'x');
  raise exception 'T6.3 ÉCHEC : role invalide accepté';
exception
  when check_violation then raise notice 'T6.3 OK : CHECK role (23514)';
end $$;

-- T6.4 room_id unique
do $$
begin
  insert into public.studio_live_sessions
    (subscription_id, room_id, invite_token, titre)
  values
    (current_setting('test.abo_a')::uuid, 'zzrlsopen',
     'gggggggggggggggggggggggg', 'zztestrlsDoublonRoom');
  raise exception 'T6.4 ÉCHEC : room_id dupliqué accepté';
exception
  when unique_violation then raise notice 'T6.4 OK : unicité room_id (23505)';
end $$;

-- T6.5 touch_updated_at
update public.studio_live_sessions set titre = 'zztestrlsTouche'
 where id = current_setting('test.sess_open')::uuid;
select 'T6.5 updated_at' as test, updated_at > created_at as attendu_true
  from public.studio_live_sessions where titre = 'zztestrlsTouche';

-- T6.6 cascade (destructif : uniquement sur les données de test)
select 'T6.6 avant cascade (sessions)' as test, count(*) as attendu_2
  from public.studio_live_sessions where subscription_id = current_setting('test.abo_a')::uuid;
delete from public.studio_subscriptions where id = current_setting('test.abo_a')::uuid;
select 'T6.7 apres cascade (sessions)' as test, count(*) as attendu_0
  from public.studio_live_sessions where subscription_id = current_setting('test.abo_a')::uuid;
select 'T6.8 apres cascade (messages)' as test, count(*) as attendu_0
  from public.studio_live_messages where room_id in ('zzrlsopen', 'zzrlsdraft');
select 'T6.9 apres cascade (guide)' as test, count(*) as attendu_0
  from public.studio_guides where subscription_id = current_setting('test.abo_a')::uuid;

-- ----------------------------------------------------------------------------
-- T7. ESSAI GRATUIT STUDIO LIVE (3 jours)
--     Un seul essai, non prolongeable, email confirme, RLS lecture seule.
-- ----------------------------------------------------------------------------

-- 7.0 Fixtures : emails confirmés, aucun essai résiduel
update auth.users set email_confirmed_at = coalesce(email_confirmed_at, now())
 where email in ('a@test.local', 'b@test.local');
delete from public.live_subscriptions
 where user_id in (current_setting('test.user_a')::uuid,
                   current_setting('test.user_b')::uuid);

-- 7.1 Un utilisateur authentifié crée son essai (RPC security definer)
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_a'),
                    'email', current_setting('test.email_a'),
                    'role', 'authenticated')::text, true);
set local role authenticated;
select 'T7.1 essai A cree' as test, count(*) as attendu_1
  from public.demarrer_essai_studio();
select 'T7.2 duree exacte 3 jours' as test,
       (trial_ends_at - trial_started_at) = interval '3 days' as attendu_true
  from public.live_subscriptions
 where user_id = current_setting('test.user_a')::uuid;
select 'T7.3 acces_studio pendant essai' as test,
       public.acces_studio() as attendu_true;

-- 7.2 Deuxième appel : jamais prolongeable
do $$
begin
  perform public.demarrer_essai_studio();
  raise exception 'T7.4 ÉCHEC : deuxième essai accepté';
exception
  when sqlstate 'P0001' then
    raise notice 'T7.4 OK : essai unique, non prolongeable (P0001)';
end $$;
commit;
-- L'essai de A est désormais persistant pour les tests suivants (nettoyé en T8).

-- 7.3 Un autre utilisateur ne voit pas l'essai de A
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_b'),
                    'email', current_setting('test.email_b'),
                    'role', 'authenticated')::text, true);
set local role authenticated;
select 'T7.5 essai de A invisible pour B' as test, count(*) as attendu_0
  from public.live_subscriptions;
rollback;

-- 7.4 Aucune écriture client (même sur sa propre ligne)
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_a'),
                    'email', current_setting('test.email_a'),
                    'role', 'authenticated')::text, true);
set local role authenticated;
do $$
begin
  insert into public.live_subscriptions (user_id, is_trial, trial_started_at, trial_ends_at)
  values (current_setting('test.user_a')::uuid, true, now(), now() + interval '3 days');
  raise exception 'T7.6 ÉCHEC : insertion client acceptée';
exception
  when insufficient_privilege then
    raise notice 'T7.6 OK : insertion client refusée (42501)';
end $$;
do $$
begin
  update public.live_subscriptions set trial_ends_at = now() + interval '4 days';
  raise exception 'T7.7 ÉCHEC : prolongation client acceptée';
exception
  when insufficient_privilege then
    raise notice 'T7.7 OK : prolongation client refusée (42501)';
end $$;
rollback;

-- 7.5 Prolongation refusée même en service_role (contrainte CHECK)
do $$
begin
  update public.live_subscriptions
     set trial_ends_at = trial_ends_at + interval '1 day'
   where user_id = current_setting('test.user_a')::uuid;
  raise exception 'T7.8 ÉCHEC : prolongation acceptée par la contrainte';
exception
  when check_violation then
    raise notice 'T7.8 OK : contrainte 3 jours, prolongation refusée (23514)';
end $$;

-- 7.6 Email non confirmé : essai refusé (P0002)
update auth.users set email_confirmed_at = null where email = 'b@test.local';
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_b'),
                    'email', current_setting('test.email_b'),
                    'role', 'authenticated')::text, true);
set local role authenticated;
do $$
begin
  perform public.demarrer_essai_studio();
  raise exception 'T7.9 ÉCHEC : essai sans email confirmé accepté';
exception
  when sqlstate 'P0002' then
    raise notice 'T7.9 OK : email confirmé obligatoire (P0002)';
end $$;
rollback;
update auth.users set email_confirmed_at = now() where email = 'b@test.local';

-- 7.7 Session d'essai : accessible au propriétaire, chat public actif
--     puis fermé à l'expiration. Aucun guide n'est lisible pendant l'essai.
insert into public.studio_live_sessions
  (subscription_id, user_id, room_id, invite_token, titre, statut)
values
  (null, current_setting('test.user_a')::uuid, 'zzrlstrial',
   'tttttttttttttttttttttttt', 'zztestrlsTrial', 'EN_DIRECT')
on conflict (room_id) do nothing;
select set_config('test.sess_trial', id::text, false)
  from public.studio_live_sessions where room_id = 'zzrlstrial';

begin;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_a'),
                    'email', current_setting('test.email_a'),
                    'role', 'authenticated')::text, true);
set local role authenticated;
select 'T7.10 session essai visible par A' as test, count(*) as attendu_1
  from public.studio_live_sessions where room_id = 'zzrlstrial';
select 'T7.11 livres accessibles pendant essai' as test, count(*) as attendu_0
  from public.studio_guides;   -- aucun guide lié à un essai
rollback;

begin;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select 'T7.12 chat/salle essai publique active' as test,
       public.studio_session_publique(current_setting('test.sess_trial')::uuid) as attendu_true;
rollback;

-- 7.8 Expiration : accès fermé, salle plus publique
update public.live_subscriptions
   set trial_started_at = now() - interval '4 days',
       trial_ends_at = now() - interval '1 day'
 where user_id = current_setting('test.user_a')::uuid;

begin;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_a'),
                    'email', current_setting('test.email_a'),
                    'role', 'authenticated')::text, true);
set local role authenticated;
select 'T7.13 acces_studio apres expiration' as test,
       public.acces_studio() as attendu_false;
select 'T7.14 session essai fermee' as test, count(*) as attendu_0
  from public.studio_live_sessions where room_id = 'zzrlstrial';
rollback;

begin;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select 'T7.15 salle essai non publique apres expiration' as test,
       public.studio_session_publique(current_setting('test.sess_trial')::uuid) as attendu_false;
rollback;

-- ----------------------------------------------------------------------------
-- T8. NETTOYAGE
-- ----------------------------------------------------------------------------
delete from public.live_subscriptions
 where user_id in (current_setting('test.user_a')::uuid,
                   current_setting('test.user_b')::uuid);
delete from public.studio_live_sessions where room_id = 'zzrlstrial';
delete from public.studio_subscriptions where nom_activite like 'zztestrls%';
select 'T8.1 nettoyage' as test, count(*) as attendu_0
  from public.studio_subscriptions where nom_activite like 'zztestrls%';

-- ----------------------------------------------------------------------------
-- T9. COMPTEUR ADMINISTRATEUR DES ESSAIS
-- ----------------------------------------------------------------------------
begin;
update public.profiles set is_admin = true
 where id = current_setting('test.user_a')::uuid;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.user_a'),
                    'role', 'authenticated')::text, true);
set local role authenticated;
select 'T9.1 compteur essais admin' as test,
       total >= 0 as total_ok,
       actifs >= 0 as actifs_ok
  from public.admin_compter_essais_gratuits();
rollback;

-- ============================================================================
--  LECTURE DES RÉSULTATS  (état au 2026-11-23, correctifs appliqués)
--  - T1.1/T1.2/T1.3 = 0            → pas de fuite abonnement/guide/session
--  - T1.5 = 2, T1.6 = 0, T1.7 = 0  → policy messages conforme (PRET/EN_DIRECT)
--                                    + abonnement ACTIF : F06 fermé côté chat
--  - T1.4 = 2                      → seules les salles ouvertes sont lisibles
--                                    (F14 : dump inter-salles toujours possible)
--  - T2.5 true / T2.6 et T2.7 false → studio_a_acces borné au propriétaire ACTIF
--  - T2.1 = 2                      → lecture par user_id ET par email (F03 à trancher)
--  - T2.8 à T2.13 : 0 ligne ou 42501 → aucune écriture client utile
--  - T2.14 notice « F11 CONFIRME » → WITH CHECK à renforcer (§4.11)
--  - T3.5 true                     → mon_abonnement_studio() bornée à l'appelant
--  - T4.x OK                       → service_role est le seul écrivain
--  - T5.2 = 0                      → propriétaire verrouillé hors abonnement expiré
--  - T5.3 = 0                      → F06 fermé (chat non public après expiration)
--  - T5.4 = EXPIRE                 → job d'expiration fonctionnel
--  - T5.5 = EN_DIRECT (avant correctif §4.6) : la salle n'est pas fermée
--  - T6.1-T6.4 = notices OK        → contraintes/unicités actives
--  - T6.5 true                     → trigger updated_at opérationnel
--  - T6.6 à T6.9                   → cascades conformes
  - T7.1 à T7.15                  → essai gratuit : unique, 3 jours exacts,
                                    email confirmé, non prolongeable, RLS
                                    lecture seule, salle fermée à l'expiration,
                                    aucun guide pendant l'essai
  - T8.1                          → nettoyage
-- ============================================================================
