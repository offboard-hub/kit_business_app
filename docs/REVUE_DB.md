# Revue indépendante — couche base de données Supabase (refonte e-booklive)

> **Auteur** : Database Reviewer (équipe ECC) — revue indépendante, lecture seule.
> **Date** : 2026-11-22 · **contre-revue des correctifs : 2026-11-23 (§13)**.
> **Périmètre** : `docs/ARCHITECTURE_REFONTE.md` §4-5, la migration
> `supabase/migrations/20260101000500_paddle_et_studio_live.sql` (nouvelle, **non commitée** :
> `git status` → `?? supabase/migrations/20260101000500_paddle_et_studio_live.sql`), les
> 5 migrations antérieures, `supabase/config.toml`, et les Edge Functions listées par la mission
> (`_shared/studio.ts`, `_shared/paddle.ts`, `_shared/fulfillment.ts`, `saspay-webhook`,
> `paddle-webhook`, `verify-payment`, `studio-room`, `live-auto-chat`) + contrôle de cohérence
> front (`lib/services/api.dart`, `lib/core/models.dart`, `lib/pages/studio_regie_page.dart`,
> `lib/pages/live_room_page.dart`, `lib/pages/auth_page.dart`).
>
> **Aucun fichier de code n'a été modifié.** Cette revue produit ce rapport et le script de
> test `docs/tests_rls_studio.sql`. Les correctifs proposés sont fournis sous forme de SQL ou
> de patchs **à appliquer dans une nouvelle migration / une PR ultérieure**.
>
> **Limite majeure** : aucune base n'était joignable (pas de Docker, pas de `psql`, pas de
> `deno`, pas de mot de passe/`access token` Supabase dans le dépôt — seul
> `supabase/.env.example` existe). **Toutes les conclusions sont statiques** (lecture du SQL,
> des policies, des fonctions). Les vérifications dynamiques à exécuter sont listées §11 et
> fournies prêtes à l'emploi dans `docs/tests_rls_studio.sql`.

---

## 1. Verdict global

> **Mise à jour du 2026-11-23 — après correctifs (contre-revue §13)** :
> **PLUS AUCUN BLOQUANT.** Verdict : **À CORRIGER (résiduel)**.
> Fermés : **F01, F02, F04, F09, F13** ; **F06** fermé côté chat (résiduels `studio-room`, guide, job
> d'expiration) ; restent **1 majeur** — **F03** (l'email du JWT comme credential, non traité) — et les
> mineurs F05 (journal partiel), F10-F12, F14-F18. Preuves et limites : §13.

### 1.1 Verdict initial (2026-11-22) — conservé pour l'historique

## **À CORRIGER**

La migration est **bien construite** : schéma complet et conforme au contrat §4, RLS activée
sur les 4 tables, aucune récursion de policy, écriture client impossible sur les 4 tables,
fonctions `security definer` toutes dotées d'un `search_path`, idempotence soignée. Elle peut
être rejouée sans casse (sous réserve des vérifications §11).

**À la date du 2026-11-22, 2 points étaient bloquants** et 3 autres majeurs (statut au 2026-11-23
dans la dernière colonne) :

| # | Sévérité initiale | En une ligne | Statut au 2026-11-23 |
|---|---|---|---|
| **F01** | 🔴 **BLOQUANT** | `create-paddle-checkout/index.ts:208` écrivait `statut` au lieu de `status` sur `studio_subscriptions` → l'échec Paddle n'était **jamais** enregistré (erreur PostgREST silencieuse). | ✅ **FERMÉ** (§13.1) |
| **F02** | 🔴 **BLOQUANT** | `verify-payment` (public, `verify_jwt = false`) activait un abonnement via `service_role` **sans contrôle de propriétaire** et acceptait un `payment_id` **rejoué** : un paiement de 9 000 XOF (kit Pack) suffisait à activer un Studio à ≈ 6 100 XOF. | ✅ **FERMÉ** (§13.2) — résidu F03 |
| **F03** | 🟠 MAJEUR | L'email du JWT sert de **credential d'accès** (RLS + `studio_a_acces`) alors que l'app est conçue pour tourner **sans confirmation d'email** (`lib/pages/auth_page.dart:57-66`) → un tiers peut revendiquer l'abonnement d'un acheteur invité. | ❌ **OUVERT** (majeur) |
| **F04** | 🟠 MAJEUR | Le statut `ECHEC` était **terminal** pour `studio_subscriptions` (contrairement à `orders`) : un paiement réussi après un échec renvoyait 500 en boucle au webhook. | ✅ **FERMÉ** (§13.3) |
| **F05-F09** | 🟡 MODÉRÉ | Pas de journal `transactions` pour le Studio ; expiration non appliquée aux salles/guides ; `started_at`/`ended_at` jamais posés ; chat de l'invité illisible avant `PRET` ; chat du propriétaire illisible après `TERMINE`. | ⚠️ **PARTIEL** : F06 et F09 fermés (F06 avec résidus), F05, F07, F08 ouverts |
| **F10-F16** | 🔵 MINEUR | Contraintes CHECK manquantes, `invite_token` non unique, grants par défaut non révoqués, index/unicité `saspay_payment_id`, dump global du chat par `anon`, `montant_local` écrasé, heuristique front `limit 10`. | ⚠️ **PARTIEL** : F13 fermé ; F10-F12, F14-F16 ouverts |

**Réponses directes aux questions de sécurité de la mission** (détaillées §8) :

| Question | Réponse |
|---|---|
| Un client authentifié peut-il s'auto-attribuer un abonnement `ACTIF` ? | **Non par PostgREST** (aucune policy INSERT/UPDATE, RLS active). **Oui par `verify-payment`** en rejouant un `payment_id` SasPay suffisant (F02) — **corrigé le 2026-11-23**, cf. §13.2. |
| Peut-il modifier `montant_local` ? | **Non** côté client (aucun GRANT utile + RLS). Le montant est modifié uniquement par `service_role`. |
| Peut-il lire les messages d'une salle terminée ? | **Non** (policy `PRET/EN_DIRECT`), mais **le propriétaire non plus** (F09) et une salle laissée `EN_DIRECT` après expiration reste publique (F06). — **corrigé le 2026-11-23**, cf. §13.4/§13.5. |
| Peut-il écrire un message en usurpant `role = 'assistant'` ? | **Non** : aucune policy d'écriture + `live-auto-chat` force `role` (`live-auto-chat/index.ts:159-166`, `:218-229`). Il peut en revanche usurper `author` (nom affiché) — F14. |
| `invite_token` lisible par un anonyme ? | **Non** : aucune policy `SELECT` pour `anon` sur `studio_live_sessions` (0 ligne), et `studio-room` ne renvoie le jeton qu'au porteur d'un jeton valide. |

---

## 2. Ce qui est conforme (preuves)

Ces points ont été vérifiés et sont **corrects** — ils ne doivent pas être « corrigés » :

1. **Schéma conforme au contrat §4** : les 5 colonnes de `orders` (`provider`, `paddle_transaction_id`,
   `montant_local`, `devise_locale`, `kind`) existent (`migration:21-25`) et sont **toutes** lues/écrites
   par les fonctions (`fulfillment.ts:45-52`, `:118`, `:161`, `:206-209` ; `verify-payment/index.ts:51-56`,
   `:258`, `:268` ; `create-paddle-checkout/index.ts:144-153`, `:238-248`).
2. **Les 4 tables Studio existent avec les 23 + 13 + 15 + 8 colonnes attendues** ; les interfaces
   TypeScript (`_shared/studio.ts:24-82`) et les modèles Dart (`lib/core/models.dart:483-506`,
   `:539-549`, `:589-615`, `:678-688`) ne référencent **aucune colonne absente**. Seule divergence
   d'écriture : F01 (`statut` vs `status`).
3. **Aucune récursion RLS** : les policies de `studio_guides` (`migration:313-329`) interrogent
   `studio_subscriptions` (autre table), et les policies de `studio_live_sessions`/`studio_live_messages`
   passent par des fonctions `security definer` (`migration:222-243`, `:269-282`) qui contournent la RLS.
4. **Aucune écriture client** : `studio_subscriptions` et `studio_guides` n'ont qu'une policy `SELECT` ;
   `studio_live_messages` n'a **aucune** policy d'écriture ; `studio_live_sessions` est le seul CRUD client,
   borné par `studio_a_acces(subscription_id)` en `USING` **et** en `WITH CHECK` (`migration:332-336`).
5. **`search_path` présent sur toutes les fonctions `security definer`** du projet
   (`migration:227`, `:251`, `:274`, `:377` ; `20260101000000_schema_base.sql:149`, `:181`, `:197`, `:237` ;
   `...000100...:178`) — aucune fonction DEFINER « nue ».
6. **Idempotence** : `add column if not exists`, `create table if not exists`, `create index if not exists`,
   `drop policy/trigger if exists`, `create or replace function`, et le bloc `DO` realtime capture
   `duplicate_object` + `undefined_object` (`migration:361-367`).
7. **Grants d'exécution corrects** : `REVOKE ALL ... FROM PUBLIC` puis `GRANT EXECUTE` ciblé
   (`migration:284-290`, `:386-387`) ; `studio_session_publique` est la seule ouverte à `anon`, et elle
   ne renvoie qu'un booléen.
8. **Unicité du guide** : `subscription_id uuid unique not null` (`migration:110-111`) rend l'`upsert`
   `onConflict: "subscription_id"` de `_shared/studio.ts:854-872` valide.
9. **Cascades** : guide et sessions en `on delete cascade` sur l'abonnement (`migration:110-111`, `:138-139`),
   messages en cascade sur la session (`migration:176-177`) → pas d'orphelins.
10. **Verrou d'activation atomique** : `UPDATE ... .in("status", [...])` (`studio.ts:952-963`) + lecture
    après échec du verrou : deux webhooks concurrents ne peuvent pas activer deux fois
    (`dejaActif`).
11. **Anti-rejeu de livraison kit** : verrou `.in("statut", ["PAYE", "ERREUR"])` (`fulfillment.ts:129-146`)
    et court-circuit `statut = 'LIVRE'` (`fulfillment.ts:123-126`).
12. **Idempotence Paddle** : index unique partiel sur `orders.paddle_transaction_id`
    (`migration:29-31`) et sur `studio_subscriptions.paddle_transaction_id` (`migration:88-90`) ;
    le webhook retrouve la ligne par `transaction_id` (`paddle-webhook/index.ts:99-108`).
13. **Webhooks signés** : HMAC-SHA256 + fenêtre 300 s + comparaison à temps constant
    (`_shared/paddle.ts:271-303`, `_shared/saspay.ts:229-257`).
14. **Realtime** : `studio_live_messages` est bien ajoutée à `supabase_realtime` (`migration:361-367`) et
    la lecture temps réel est couverte par la policy `SELECT` (cf. test T5).
15. **Le front ne contourne pas la RLS** : `monAbonnement`, `monGuide`, `mesSessionsLive`, `messagesLive`
    passent bien par la clé `anon` + JWT utilisateur (pas de `service_role` dans `lib/`), et
    `sessionPublique`/`chatLive` passent par les Edge Functions.

---

## 3. Tableau des findings

> Convention de sévérité : 🔴 BLOQUANT (casse une fonction ou la sécurité) / 🟠 MAJEUR /
> 🟡 MODÉRÉ / 🔵 MINEUR / ⚪ INFO.
> « Correctif » = à porter dans une **nouvelle** migration (`20260101000600_*.sql`) ou une PR de
> fonction — **rien n'a été appliqué ici**.
>
> **État initial au 2026-11-22.** Les statuts à jour (après correctifs du 2026-11-23) sont dans §1
> et §13 ; les numéros de ligne visant la migration correspondent à sa version initiale (avant
> l'ajout des deux index uniques et de la policy `studio_live_messages_owner_read`).

| ID | Sév. | Fichier:ligne | Constat | Impact | Correctif (réf.) |
|---|---|---|---|---|---|
| **F01** | 🔴 | `supabase/functions/create-paddle-checkout/index.ts:205-209` (l.208) | `update({ statut: "ECHEC" })` est exécuté aussi sur `studio_subscriptions`, qui n'a **que** `status` (`migration:60`, `:73-74`) | L'erreur PostgREST `42703 column "statut" does not exist` n'est pas lue (pas de `.error`) : la ligne reste `EN_ATTENTE` pour toujours, `verify-payment` continue d'afficher « paiement en attente », lignes orphelines à chaque tentative Paddle en échec | §4.1 |
| **F02** | 🔴 | `supabase/functions/verify-payment/index.ts:119-234` (surtout `:146-151`, `:174-179`, `:188-195`) + `_shared/saspay.ts:202-210` | Aucun contrôle de propriétaire : `subscription_id`/`order_id` viennent du corps de requête et la fonction lit/écrit avec `service_role`. `payment_id` est accepté **du client** et n'est jamais vérifié comme « non déjà consommé ». Le contrôle de montant est `montantVerifie + 1 < attendu`, donc tout surpaiement passe | (a) IDOR : n'importe qui connaissant un UUID d'abonnement lit `email`, `nom_activite`, `pays`, `montant` et déclenche l'activation ; (b) **rejeu de paiement** : un achat Pack 9 000 XOF → `payment_id` P → `POST {subscription_id: studio_EN_ATTENTE_≈6100, payment_id: P}` → 9000+1 ≥ 6100 → `ACTIF` + guide, sans payer le Studio ; (c) idem pour les sessions SasPay | §4.2 |
| **F03** | 🟠 | `migration:235-241` (`studio_a_acces`), `:255-259` (`mon_abonnement_studio`), `:304-310` (policy SELECT) ; `lib/pages/auth_page.dart:57-66`, `20260101000000_schema_base.sql:193` | L'appartenance d'un abonnement est établie par `lower(email) = lower(auth.jwt()->>'email')`. Le projet est conçu pour fonctionner **sans confirmation d'email** (« Confirmez votre email… option à désactiver ») | Un acheteur invité (Studio acheté sans compte, `user_id = null`) peut être « revendiqué » par quiconque crée un compte avec son email : lecture de l'abonnement + **du guide**, et — via `studio_a_acces` — **UPDATE/DELETE de ses sessions et lecture de `invite_token`** | §4.3 |
| **F04** | 🟠 | `_shared/studio.ts:952-974` (l.961), `saspay-webhook/index.ts:73-112`, `paddle-webhook/index.ts:181-210` | Le verrou d'activation n'accepte que `EN_ATTENTE`/`PAYE`, puis `throw` sinon. `ECHEC` est donc **définitif** ; les webhooks renvoient 500 sur un abonnement `ECHEC` | Un `transaction.failed` transitoire (mobile money) suivi d'un `transaction.success` ne peut plus activer l'abonnement ; SasPay/Paddle re-livrent le webhook indéfiniment. Asymétrie avec `orders` qui accepte `ECHEC → PAYE` (`saspay-webhook/index.ts:154`) | §4.4 |
| **F05** | 🟡 | `saspay-webhook/index.ts:158-168`, `verify-payment/index.ts:317-327`/`:412-422`, `paddle-webhook/index.ts:157-167` | `transactions` n'est alimentée que pour les **kits**. Aucune ligne pour les 10 USD du Studio, et `transaction_token` n'a **aucun index unique** (`20260101000000_schema_base.sql:117-130`) | Aucune réconciliation financière possible pour le Studio ; pas de preuve de paiement par abonnement ; doublons possibles en cas de re-livraison | §4.5 |
| **F06** | 🟡 | `migration:269-282` (`studio_session_publique`), `:373-384` (`expirer_abonnements_studio`, jamais planifiée), `:313-329` (policy guides) | L'expiration n'est **pas** appliquée : `statut` reste `ACTIF` (aucun `pg_cron`), une session laissée `EN_DIRECT` reste **publiquement lisible** après expiration (la fonction ne regarde que `statut`), et le guide reste lisible indéfiniment (la policy est sans condition d'expiration) | Salle et fiche produit exposées *ad vitam* après la fin de l'abonnement ; le guide contredit la promesse « pendant 30 jours » (`studio.ts:1043-1045`) | §4.6 |
| **F07** | 🟡 | `migration:149-150` (`started_at`, `ended_at`) ; `lib/pages/studio_regie_page.dart:193`, `:215`, `:221` ; `lib/services/api.dart:262-270` | Personne ne remplit `started_at`/`ended_at` : le front ne change que `statut`, et aucun trigger ne les pose | `studio-room` renvoie `started_at: null` (`studio-room/index.ts:47`) ; pas de durée de live, pas d'audit ; colonnes mortes alors qu'elles sont au contrat §4.4 | §4.7 |
| **F08** | 🟡 | `migration:340-343` (policy messages) vs `studio-room/index.ts:98-107` (session complète dès `BROUILLON` avec jeton) + `lib/pages/studio_regie_page.dart:1216-1234`, `lib/pages/live_room_page.dart:208-212` | L'invité entre dans une salle `BROUILLON` mais la policy messages n'autorise que `PRET/EN_DIRECT` ; `ChatLivePanel` ne transmet **jamais** `invite_token` (le widget ne le reçoit pas — paramètre `statut` inutilisé) | Co-animateur invité : chat vide, et ses propres messages (insérés par `live-auto-chat` en `service_role`) ne lui sont pas relus | §4.8 |
| **F09** | 🟡 | `migration:340-343` ; `lib/pages/studio_regie_page.dart:954-958` ; `lib/services/api.dart:342-356` | Aucune policy ne permet au **propriétaire** de lire les messages d'une salle `TERMINE` (seule la condition `PRET/EN_DIRECT` existe) ; le front avale l'erreur et renvoie `[]` | Après « Terminer », la régie affiche un chat vide (perte d'historique côté animateur) ; aucun moyen de modérer a posteriori | §4.9 |
| **F10** | 🔵 | `migration:120` (`studio_guides.statut`), `:21`/`:25` (`orders.provider`, `orders.kind`) | Aucune contrainte `CHECK` : `studio_guides.statut` accepte n'importe quel texte (alors que `studio_subscriptions.guide_status` est contraint, `migration:75-76`) ; `orders.provider`/`kind` de même | Une faute de frappe (`'pret'`) crée un guide invisible (`models.dart:537` teste `'PRET'` strictement) ; `provider='stripe'` serait accepté ; incohérence avec le contrat §4.2 qui contraint `provider` | §4.10 |
| **F11** | 🔵 | `migration:141-142` (`room_id`, `invite_token`), `migration:332-336` (WITH CHECK sessions) | `invite_token` n'est ni `UNIQUE` ni borné en longueur ; `room_id` n'a aucun format/longueur en base (seules les Edge Functions valident `^[A-Za-z0-9_-]{6,80}$`) ; le `WITH CHECK` accepte `user_id` d'autrui | Jeton faible (`'1234'`) ou dupliqué accepté en base → accès co-animateur ; une session peut être « attribuée » à un autre `user_id` | §4.11 |
| **F12** | 🔵 | `migration:348-356` | Sur un projet Supabase standard, `ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ... TO anon, authenticated, service_role` s'applique aux nouvelles tables : les `GRANT SELECT` de la §9 **n'enlèvent rien** (`anon` possède INSERT/UPDATE/DELETE au niveau privilège) | Aujourd'hui la RLS bloque, mais la défense en profondeur est absente : toute policy permissive ajoutée plus tard (ou un `DISABLE ROW LEVEL SECURITY`) ouvre l'écriture. Le projet sait le faire (`20260101000400_tiktok_oauth.sql:28-29`) | §4.12 |
| **F13** | 🔵 | `verify-payment/index.ts:246-251` ; `20260101000100_commandes_assistant_video.sql:44-45` | `orders.saspay_payment_id` n'a **aucun index**, et la requête utilise `.maybeSingle()` sur une colonne non unique | Seq scan + `PGRST116` (500) si deux commandes partagent un `payment_id` — ce que rien n'empêche aujourd'hui | §4.13 |
| **F14** | 🔵 | `migration:340-343` ; `live-auto-chat/index.ts:129-140` | La policy `SELECT` publique n'est pas bornée à une salle : `GET /rest/v1/studio_live_messages?select=*` renvoie **toutes** les messages de **toutes** les salles ouvertes ; `author` est déclaré par le client (`live-auto-chat/index.ts:157`, `:164`) | Fuite inter-salles (noms + contenus) par simple requête `anon` ; usurpation du nom affiché. Conforme au contrat §4.6 (« select public si la session existe… »), donc risque *accepté* mais à documenter | §4.14 |
| **F15** | 🔵 | `paddle-webhook/index.ts:148-150`, `:190-197` ; `create-paddle-checkout/index.ts:238-248` ; `verify-payment/index.ts:50-56` | `montant_local`/`devise_locale` (orders) et `montant_local`/`devise` (studio) sont **écrasés** par le montant réellement facturé Paddle | Le montant *attendu* (calculé serveur) est perdu : le contrôle anti-sous-paiement de `verify-payment` compare ensuite le réel au réel (il est neutralisé pour les lignes déjà `PAYE`, mais l'audit du prix est perdu) | §4.15 |
| **F16** | 🔵 | `lib/services/api.dart:186-206` ; `lib/core/models.dart:509-514` | `monAbonnement()` lit les 10 abonnements les plus récents puis choisit côté client ; `toInsertJson()` n'envoie ni `email`, ni `devise`, ni `montant_local` (colonnes `NOT NULL`) | Au-delà de 10 lignes `EN_ATTENTE` (relances), l'abonnement `ACTIF` sort de la fenêtre → régie verrouillée à tort ; `toInsertJson()` est du code mort qui échouerait s'il était utilisé | §4.16 |
| **F17** | ⚪ | `migration:361-367` | Le bloc realtime avale `undefined_object` (publication absente) sans aucun message ; pas de `REPLICA IDENTITY FULL` | Realtime peut être **désactivé silencieusement** ; les DELETE (cascade) ne sont pas diffusés — masqué par le polling 6 s (`studio_regie_page.dart:1241-1243`) | §4.17 |
| **F18** | ⚪ | `migration:222-265` | `set search_path = public` (au lieu de `''` + noms qualifiés) ; `mon_abonnement_studio()` n'est appelée par **personne** (`grep` : migration uniquement) et renvoie la ligne complète (email) ; `owner_display` renvoyé par `studio-room` n'est consommé par aucun modèle Dart | Durcissement perfectible, surface d'API morte non testée, champ mort | §4.18 |

---

## 4. Détail des findings et correctifs exacts

### 4.1 F01 — `statut` vs `status` : le piège de nommage casse le chemin d'échec Paddle

`studio_subscriptions` utilise **`status`** (`migration:60`), tandis que `orders`, `studio_guides`,
`studio_live_sessions` utilisent **`statut`** (`20260101000100...:25`, `migration:120`, `:148`).
`create-paddle-checkout` factorise les deux tables dans une seule branche :

```ts
// supabase/functions/create-paddle-checkout/index.ts:205-209
const table = kind === "kit" ? "orders" : "studio_subscriptions";
const id = orderId ?? subscriptionId;
if (id) {
  await admin.from(table).update({ statut: "ECHEC" }).eq("id", id);   // ← 42703 si table = studio_subscriptions
}
```

PostgREST renvoie `{"code":"42703", "message":"column \"statut\" of relation \"studio_subscriptions\" does not exist"}`
dans `error`, qui n'est **pas** lu → aucune exception, aucun log, et l'abonnement reste `EN_ATTENTE`.

**Correctif (fonction, hors migration)** :

```ts
if (id) {
  const { error: erreurEchec } = kind === "kit"
    ? await admin.from("orders").update({ statut: "ECHEC" }).eq("id", id)
    : await admin.from("studio_subscriptions").update({ status: "ECHEC" }).eq("id", id);
  if (erreurEchec) console.error("create-paddle-checkout : échec non enregistré", erreurEchec.message);
}
```

**Test de non-régression** : provoquer un `price_id` invalide (ou `PADDLE_API_KEY` vide) sur
`kind=studio`, puis `select status from public.studio_subscriptions where id = …` → doit valoir `ECHEC`.

### 4.2 F02 — `verify-payment` : contournement de la RLS par `service_role` + rejeu de paiement

`supabase/config.toml:17-21` déclare `verify_jwt = false`, et la fonction ne fait **aucune**
vérification d'identité pour le Studio (ni JWT, ni propriétaire, ni jeton) :

```ts
// verify-payment/index.ts:119-123 puis 146-151
const abonnement = await chargerAbonnement(String(subscriptionId)); // adminClient() → RLS contournée
...
const paymentId = paymentIdParam ?? abonnement.saspay_payment_id;
if (paymentId) {
  const verification = await verifierPaiement(paymentId);  // n'importe quel payment_id SUCCESS
  ...
}
// :174-179 : refus seulement si le montant est INFÉRIEUR
if (montantVerifie !== null && montantVerifie + 1 < Number(abonnement.montant_local)) { … 402 }
// :188-195 : activation (service_role) → ACTIF + guide
const activation = await activerAbonnementStudio(abonnement.id, { attendreGuide: false });
```

Scénario concret (XOF, Mali) :

1. l'attaquant achète **legitimement** le kit « Pack Complet » (9 000 XOF) ; SasPay renvoie `payment_id = P` ;
2. il crée un abonnement Studio `EN_ATTENTE` (≈ 6 100 XOF après arrondi `arrondirPrix`, `pricing.ts:89-98`) via `saspay-checkout` — sans payer ;
3. `POST /functions/v1/verify-payment {"subscription_id":"<abo>","payment_id":"P"}` ;
4. `9000 + 1 < 6100` est **faux** → pas de 402 → `activerAbonnementStudio` → `ACTIF` + guide généré.

Coût de l'attaque : un achat qu'il voulait de toute façon ; le Studio est offert.
Le même mécanisme fonctionne dans **toutes** les devises SasPay : le Pack (9 000 XOF de référence)
reste supérieur au Studio (6 061 XOF de référence) quel que soit le taux appliqué.
Le même défaut permet l'**IDOR** : `email`, `nom_activite`, `pays_code`, `montant_local` de
n'importe quel abonnement dont l'UUID fuite (l'UUID est dans l'URL `/?abonnement=…`, les logs,
les référents) sont renvoyés dans `abonnement` (`verify-payment/index.ts:74`) — et l'appel
déclenche une activation si un paiement valide est connu.

**Correctifs (les deux sont nécessaires)** :

(a) Base — unicité des identifiants de paiement (nouvelle migration) :

```sql
create unique index if not exists orders_saspay_payment_key
  on public.orders (saspay_payment_id) where saspay_payment_id is not null;
create unique index if not exists studio_subscriptions_saspay_payment_key
  on public.studio_subscriptions (saspay_payment_id) where saspay_payment_id is not null;

-- Traçabilité minimale (cf. F05) : un paiement = une ligne de journal
create table if not exists public.paiements_recus (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('saspay','paddle')),
  payment_id text not null,
  kind text not null check (kind in ('kit','studio')),
  cible_id uuid not null,
  montant numeric(12,2) not null,
  devise text not null,
  created_at timestamptz not null default now(),
  constraint paiements_recus_unique unique (provider, payment_id)
);
alter table public.paiements_recus enable row level security;  -- service_role uniquement
```

(b) Fonction — refuser un paiement déjà consommé, exiger le montant exact et un jeton d'accès :

```ts
// avant activation, dans la branche Studio ET dans la branche kit
const dejaUtilise =
  (await admin.from("orders").select("id").eq("saspay_payment_id", paymentId).maybeSingle()).data ||
  (await admin.from("studio_subscriptions").select("id")
     .eq("saspay_payment_id", paymentId).neq("id", abonnementId).maybeSingle()).data;
if (dejaUtilise) return erreur("Ce paiement a déjà été utilisé pour un autre achat.", 409);
if (montantVerifie !== null && Math.abs(montantVerifie - Number(abonnement.montant_local)) > 1) {
  return erreur("Montant reçu différent du montant attendu.", 402);
}
```

(c) Cible — arrêter d'utiliser l'UUID comme credential : ajouter une colonne
`access_token uuid not null default gen_random_uuid()` sur `orders` et `studio_subscriptions` (même schéma que
`kits.access_token`, `20260101000000_schema_base.sql:101`), le renvoyer au checkout, et l'exiger
dans `verify-payment` (`{"subscription_id","access_token"}`). À défaut, exiger un JWT propriétaire
pour toute action qui **écrit** (l'activation), et ne laisser le GET public que pour la **lecture**
d'un statut déjà payé — sans renvoyer `abonnement` complet (limiter la réponse à
`{statut, expires_at, guide: {titre, statut}}`).

### 4.3 F03 — l'email du JWT n'est pas une preuve d'identité

Trois endroits accordent des droits sur la seule revendication `email` :

```sql
-- migration:302-310 (lecture abonnement)
user_id = auth.uid()
or (coalesce(auth.jwt() ->> 'email','') <> '' and lower(email) = lower(auth.jwt() ->> 'email'))
-- migration:235-241 (studio_a_acces → écriture sessions)
-- migration:255-259 (mon_abonnement_studio)
```

Or le front prévoit explicitement l'absence de confirmation d'email (`lib/pages/auth_page.dart:57-66` :
« Confirmez votre email pour vous connecter (option à désactiver dans Supabase) », et
`20260101000000_schema_base.sql:193` : « sans email de confirmation »). Dans ce mode, un `signUp`
avec l'email d'un acheteur invité (`studio_subscriptions.user_id = null`, cas normal d'un achat
Studio sans compte) permet de lire **et de piloter** son abonnement.

Garde-fou immédiat (utile **seulement** si la confirmation d'email est active) :

```sql
create or replace function public.email_verifie()
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from auth.users u
    where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;
revoke all on function public.email_verifie() from public;
grant execute on function public.email_verifie() to authenticated, service_role;
```

puis remplacer chaque branche email par
`(public.email_verifie() and lower(s.email) = lower(auth.jwt() ->> 'email'))`.

**Mais** : avec `Confirm email = OFF`, GoTrue renseigne `email_confirmed_at` à l'inscription → la garde
est inopérante. La seule correction robuste est de **retirer l'email des policies** :

```sql
-- cible : l'email ne sert plus à autoriser
drop policy if exists "studio_subscriptions_select_own" on public.studio_subscriptions;
create policy "studio_subscriptions_select_own" on public.studio_subscriptions
  for select to authenticated using (user_id = auth.uid());

-- studio_a_acces : uid uniquement
create or replace function public.studio_a_acces(p_subscription_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.studio_subscriptions s
    where s.id = p_subscription_id
      and s.status = 'ACTIF'
      and (s.expires_at is null or s.expires_at > now())
      and s.user_id = auth.uid()
  );
$$;
```

Le rattachement acheteur invité → compte doit alors se faire **côté serveur** (`user_id` rempli à
l'activation si l'email correspond à un compte existant, ou via un lien magique/de revendication
signé). C'est une décision produit, mais c'est la seule voie qui ferme F03.

**À vérifier avant tout** (dashboard, §11) : Authentication → Sign In / Providers → Email →
`Confirm email`. Et en SQL : `select count(*) filter (where email_confirmed_at is null) from auth.users;`.

### 4.4 F04 — `ECHEC` est un cul-de-sac pour le Studio

```ts
// _shared/studio.ts:952-963
const { data: verrou } = await admin.from("studio_subscriptions")
  .update({ status: "ACTIF", ... })
  .eq("id", subscriptionId)
  .in("status", ["EN_ATTENTE", "PAYE"])   // ← ECHEC exclu
  .select("*").maybeSingle();
// :965-974
if (!verrou) { … throw new Error(`Activation impossible : … ${actuel?.status}`); }
```

Conséquence enchaînée : `saspay-webhook/index.ts:74-81` met `ECHEC`, puis un `transaction.success`
arrive (`:84-111`) → `activerAbonnementStudio` → `throw` → `catch` global (`:175-178`) → **500** →
le prestataire re-livre → 500 à l'infini. Idem `paddle-webhook/index.ts:181-199`.

**Correctif** :

```ts
.in("status", ["EN_ATTENTE", "PAYE", "ECHEC"])
```

La transition `ECHEC → ACTIF` n'est sûre que parce que l'appelant a vérifié un paiement `SUCCESS`
(`verify-payment`) ou une signature de webhook : c'est bien le cas des trois appelants. Ajouter
au passage, dans le webhook, un renvoi `200` (et non 500) quand l'activation est impossible pour
un motif métier, afin d'éviter les re-livraisons infinies.

### 4.5 F05 — aucun journal financier pour le Studio

Recherche exhaustive : les 3 `insert` dans `transactions` sont **tous** dans une branche kit
(`saspay-webhook/index.ts:159`, `paddle-webhook/index.ts:158`, `verify-payment/index.ts:318`, `:413`).
La branche Studio de `verify-payment` (`:188-195`) et des webhooks n'écrit rien.

**Correctif** : à l'activation (dans `activerAbonnementStudio`, seulement quand `dejaActif === false`) :

```ts
await admin.from("transactions").insert({
  user_id: abonnement.user_id,
  provider: abonnement.provider,
  transaction_token: abonnement.saspay_payment_id ?? abonnement.paddle_transaction_id,
  product_id: null,                 // pas de produit catalogue pour le Studio
  amount_paid: abonnement.montant_local,
  currency: abonnement.devise,
  status: "success",
});
```

+ `create unique index if not exists transactions_provider_token_key on public.transactions
(provider, transaction_token) where transaction_token is not null;` (après dédoublonnage éventuel
des lignes existantes) pour rendre l'écriture idempotente.

### 4.6 F06 — l'expiration n'est appliquée ni aux salles ni au guide

`expirer_abonnements_studio()` (`migration:373-384`) n'est **appelée par personne** (`grep` : aucune
référence hors migration/plan) et n'est pas planifiée (le commentaire `migration:370` le reconnaît).
Surtout, elle ne ferme pas les salles, et `studio_session_publique` ne regarde que `statut` :

```sql
-- migration:269-282
where s.id = p_session_id and s.statut in ('PRET', 'EN_DIRECT')
```

→ une salle laissée `EN_DIRECT` reste lisible publiquement **après** l'expiration (messages + fiche
produit via `studio-room`), et `studio_guides_select_own` (`migration:313-329`) ne vérifie ni statut
ni expiration → le guide reste accessible indéfiniment.

**Correctif (nouvelle migration)** :

```sql
create or replace function public.expirer_abonnements_studio()
returns void
language sql security definer
set search_path = public
as $$
  with abonnements as (
    update public.studio_subscriptions
       set status = 'EXPIRE'
     where status = 'ACTIF'
       and expires_at is not null
       and expires_at <= now()
    returning id
  )
  update public.studio_live_sessions s
     set statut = 'TERMINE',
         ended_at = coalesce(s.ended_at, now())
    from abonnements a
   where s.subscription_id = a.id
     and s.statut in ('PRET', 'EN_DIRECT');
$$;

create or replace function public.studio_session_publique(p_session_id uuid)
returns boolean
language sql stable security definer
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
```

Planification (à adapter au plan Supabase ; `pg_cron` n'est pas disponible partout) :

```sql
-- si pg_cron est activé sur le projet
select cron.schedule('expirer-studio', '17 * * * *', $$select public.expirer_abonnements_studio()$$);
```

Et, pour le guide, ajouter la même condition d'abonnement valide dans la policy `studio_guides`
(ou assumer explicitement « le guide reste acquis » — dans ce cas corriger le texte de l'email
`_shared/studio.ts:1043-1045`).

### 4.7 F07 — `started_at` / `ended_at` jamais renseignés

Aucun écrivain : `api.dart:262-270` ne met que `statut` ; `studio_regie_page.dart:193` met `EN_DIRECT`
sans horodatage ; les fonctions serveur ne les touchent pas. `studio-room/index.ts:47` renvoie donc
toujours `null`.

**Correctif (trigger, plus robuste qu'un correctif front)** :

```sql
create or replace function public.studio_session_horodatage()
returns trigger language plpgsql as $$
begin
  if new.statut = 'EN_DIRECT' and new.started_at is null then
    new.started_at := now();
  end if;
  if new.statut = 'TERMINE' and new.ended_at is null then
    new.ended_at := now();
  end if;
  if new.statut = 'BROUILLON' then            -- réouverture propre
    new.started_at := null;
    new.ended_at := null;
  end if;
  return new;
end $$;

drop trigger if exists studio_live_sessions_horodatage on public.studio_live_sessions;
create trigger studio_live_sessions_horodatage
  before insert or update of statut on public.studio_live_sessions
  for each row execute function public.studio_session_horodatage();
```

(Le trigger `updated_at` existant reste indépendant, `migration:212-215`.)

### 4.8 F08 — l'invité n'a pas accès au chat avant `PRET`

`studio-room` documente et applique « jeton valide → session complète, **même BROUILLON** »
(`studio-room/index.ts:6`, `:98-107`). Mais la lecture des messages exige `PRET/EN_DIRECT`
(`migration:340-343`), et `ChatLivePanel` lit la table directement (`studio_regie_page.dart:1216-1234`)
**sans** transmettre `invite_token` (le widget ne le reçoit pas — `studio_regie_page.dart:1181-1195`,
`live_room_page.dart:208-212`).

**Correctif A (front, aucune migration)** : router le panneau via `live-auto-chat` (`action: "messages"`)
quand un jeton d'invitation est présent — la fonction valide déjà le jeton (`live-auto-chat/index.ts:117-122`)
et renvoie les 60 derniers messages.

**Correctif B (base, si l'on préfère garder la lecture directe + realtime)** : RPC `security definer`
scopée salle + jeton :

```sql
create or replace function public.studio_messages(p_room_id text, p_invite_token text default null)
returns setof public.studio_live_messages
language sql stable security definer
set search_path = public
as $$
  select m.*
  from public.studio_live_messages m
  join public.studio_live_sessions s on s.id = m.session_id
  where s.room_id = p_room_id
    and (
      s.statut in ('PRET', 'EN_DIRECT')
      or (coalesce(p_invite_token, '') <> '' and s.invite_token = p_invite_token)
    )
  order by m.created_at asc
  limit 80;
$$;
revoke all on function public.studio_messages(text, text) from public;
grant execute on function public.studio_messages(text, text) to anon, authenticated, service_role;
```

> ⚠️ Une fonction DEFINER qui renvoie des lignes **contourne la RLS** : la validation du jeton est ici
> la seule barrière — ne pas l'oublier lors d'une évolution. La comparaison n'est pas à temps
> constant (contrairement à `_shared/studio.ts:184-193`) : acceptable en SQL, à documenter.

### 4.9 F09 — le propriétaire ne peut plus lire son chat après `TERMINE`

La seule policy `SELECT` est publique et conditionnée à `PRET/EN_DIRECT`. Le panneau reste monté
après « Terminer » (`studio_regie_page.dart:954-958`) et `ApiService.messagesLive` renvoie `[]` en
avalant l'erreur (`api.dart:342-356`).

**Correctif (policy supplémentaire, additive — ne rouvre rien aux autres)** :

```sql
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
```

La sous-requête est filtrée par la RLS de `studio_live_sessions` (elle-même basée sur
`studio_a_acces`) : pour un tiers, `exists` est faux. Aucune récursion (deux tables différentes).
Variante plus propre si l'on veut éviter la double évaluation : helper DEFINER
`studio_est_proprietaire_session(uuid)`.

### 4.10 F10 — contraintes CHECK manquantes

```sql
alter table public.studio_guides
  add constraint studio_guides_statut_check
  check (statut in ('EN_ATTENTE', 'EN_COURS', 'PRET', 'ERREUR'));

alter table public.orders
  add constraint orders_provider_check check (provider in ('saspay', 'paddle')),
  add constraint orders_kind_check check (kind in ('kit', 'studio'));
```

Les ajouter de façon idempotente (une migration `add constraint` n'a pas de `if not exists`) :

```sql
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'studio_guides_statut_check') then
    alter table public.studio_guides add constraint studio_guides_statut_check
      check (statut in ('EN_ATTENTE','EN_COURS','PRET','ERREUR'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'orders_provider_check') then
    alter table public.orders add constraint orders_provider_check
      check (provider in ('saspay','paddle'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'orders_kind_check') then
    alter table public.orders add constraint orders_kind_check
      check (kind in ('kit','studio'));
  end if;
end $$;
```

> Avant d'ajouter ces contraintes, vérifier les données existantes :
> `select distinct provider, kind from public.orders;` et
> `select distinct statut from public.studio_guides;`.

### 4.11 F11 — `invite_token` et `room_id` : aucun garde-fou en base

```sql
create unique index if not exists studio_live_sessions_invite_token_key
  on public.studio_live_sessions (invite_token);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'studio_live_sessions_invite_token_longueur') then
    alter table public.studio_live_sessions add constraint studio_live_sessions_invite_token_longueur
      check (char_length(invite_token) between 16 and 200);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'studio_live_sessions_room_id_format') then
    alter table public.studio_live_sessions add constraint studio_live_sessions_room_id_format
      check (room_id ~ '^[A-Za-z0-9_-]{6,80}$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'studio_live_sessions_plateformes_check') then
    alter table public.studio_live_sessions add constraint studio_live_sessions_plateformes_check
      check (plateformes <@ array['SALLE','TIKTOK','YOUTUBE','INSTAGRAM']::text[]);
  end if;
end $$;
```

Et renforcer la policy d'écriture des sessions pour empêcher l'attribution d'un `user_id` d'autrui :

```sql
drop policy if exists "studio_live_sessions_owner_all" on public.studio_live_sessions;
create policy "studio_live_sessions_owner_all" on public.studio_live_sessions
  for all to authenticated
  using (public.studio_a_acces(subscription_id))
  with check (
    public.studio_a_acces(subscription_id)
    and (user_id is null or user_id = auth.uid())
  );
```

> `plateformes <@ array[...]` : les valeurs inconnues stockées aujourd'hui feraient échouer l'ajout
> de contrainte ; vérifier `select id, plateformes from public.studio_live_sessions where not
> plateformes <@ array['SALLE','TIKTOK','YOUTUBE','INSTAGRAM']::text[];` avant.

### 4.12 F12 — révoquer explicitement les écritures

```sql
revoke insert, update, delete, truncate, references, trigger
  on public.studio_subscriptions from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.studio_guides from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.studio_live_messages from anon, authenticated;
-- sessions : garder select/insert/update/delete pour authenticated (policy owner_all)
```

Vérification (à exécuter avant/après) :

```sql
select table_name, grantee, string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('studio_subscriptions','studio_guides','studio_live_sessions','studio_live_messages')
group by table_name, grantee
order by table_name, grantee;
```

**Attendu aujourd'hui** : `anon` et `authenticated` ont `DELETE, INSERT, REFERENCES, SELECT, TRIGGER,
TRUNCATE, UPDATE` sur les 4 tables (héritage des *default privileges* Supabase) — c'est la preuve du
constat. Après correctif : `anon` et `authenticated` conservent `SELECT` (la RLS décide des lignes,
elle renvoie 0 sur les abonnements/guides/sessions) et perdent `INSERT/UPDATE/DELETE` sur ces trois
tables ; `studio_live_sessions` garde son CRUD pour `authenticated` (policy `owner_all`).

### 4.13 F13 — index/unicité manquants sur `orders.saspay_payment_id`

```sql
create unique index if not exists orders_saspay_payment_key
  on public.orders (saspay_payment_id) where saspay_payment_id is not null;
```

Avant : `select saspay_payment_id, count(*) from public.orders where saspay_payment_id is not null
group by 1 having count(*) > 1;` (doit être vide). Bénéfice double : performance de
`verify-payment/index.ts:246-251` et cohérence du `.maybeSingle()` (sinon `PGRST116` → 500).

### 4.14 F14 — le chat public est lisible « toutes salles confondues » (accepté, à documenter)

```sql
-- migration:340-343
using (public.studio_session_publique(session_id))
```

La policy ne peut pas dépendre du `room_id` demandé (filtre client) : `GET /rest/v1/studio_live_messages`
sans filtre renvoie toutes les salles ouvertes. C'est **conforme au contrat §4.6** ; le risque est donc
accepté, mais il doit être écrit noir sur blanc et le nom affiché (`author`, fourni par le client,
`live-auto-chat/index.ts:157`) ne doit jamais être présenté comme vérifié.

Option de durcissement (si le produit l'exige) : retirer le `SELECT` direct à `anon`/`authenticated`,
garder le `SELECT` pour `service_role`, et faire passer la lecture par la RPC `studio_messages`
(§4.8) — au prix de la perte du realtime direct (remplacé par le polling 6 s déjà présent,
`studio_regie_page.dart:1241-1243`).

### 4.15 F15 — `montant_local` écrase le montant attendu

`paddle-webhook/index.ts:148-150` et `:190-197` (ainsi que `create-paddle-checkout/index.ts:238-248`)
remplacent `montant_local`/`devise_locale` par le montant réellement facturé. Le montant calculé
serveur (la seule référence anti-fraude, §1 du contrat) n'est plus stocké pour les lignes Paddle.

**Correctif** : conserver les deux notions.

```sql
alter table public.orders
  add column if not exists montant_attendu numeric(12,2);
alter table public.studio_subscriptions
  add column if not exists montant_attendu numeric(12,2);
-- puis, au checkout : montant_attendu = tarif.montant ; montant_local = montant facturé (webhook)
```

et faire porter le contrôle de `verify-payment` sur `montant_attendu ?? montant_local`.

### 4.16 F16 — heuristique front et code mort

```dart
// lib/services/api.dart:190-202
final lignes = await _client.from('studio_subscriptions').select()
    .order('created_at', ascending: false).limit(10);
```

Si l'utilisateur a plus de 10 lignes (relances de paiement), l'abonnement `ACTIF` peut être hors
fenêtre → la régie se croit sans abonnement. Utiliser la fonction prévue par le contrat :

```dart
final ligne = await _client.rpc('mon_abonnement_studio');
```

(ou, à défaut, `.eq('status', 'ACTIF')` en premier puis repli). Et supprimer
`AbonnementStudio.toInsertJson()` (`lib/core/models.dart:509-514`) : il omet `email`, `devise`,
`montant_local` (`NOT NULL`) et aucune policy d'INSERT n'existe — code mort trompeur.

### 4.17 F17 — realtime silencieux

`migration:361-367` : `when undefined_object then null` masque l'absence de la publication
`supabase_realtime` (realtime désactivé sans aucune trace). Ajouter au minimum un `raise warning`
et vérifier après déploiement :

```sql
select * from pg_publication_tables where pubname = 'supabase_realtime';
select relname, relreplident from pg_class where relname = 'studio_live_messages';  -- 'd' = default
```

`REPLICA IDENTITY FULL` n'est nécessaire que si les **DELETE** doivent être diffusés (cascade lors de
la suppression d'une session) ; aujourd'hui le polling de secours compense.

### 4.18 F18 — durcissement des fonctions

- Préférer `set search_path = ''` et des noms pleinement qualifiés (`public.studio_subscriptions`,
  `auth.uid()`) dans les fonctions `security definer` ; `public` dans le `search_path` d'une fonction
  DEFINER est un risque résiduel (création d'objets dans `public` par un rôle non privilégié).
- `public.mon_abonnement_studio()` (`migration:246-265`) n'a **aucun appelant** : soit le front
  l'utilise (§4.16), soit elle est supprimée — une fonction DEFINER non testée est une surface
  d'attaque gratuite. Elle renvoie la ligne complète (email inclus).
- `owner_display` (`studio-room/index.ts:46`) n'est lu par aucun modèle Dart
  (`lib/core/models.dart:589-615`) : champ mort côté produit.

---

## 5. Matrice de cohérence schéma ↔ usage (contrat §4)

### 5.1 `public.orders` — 5 colonnes ajoutées

| Colonne | Migration | Écrite par | Lue par | Verdict |
|---|---|---|---|---|
| `provider` | `migration:21` | `saspay-checkout:140`, `create-paddle-checkout:152` | `fulfillment.ts:206` (email), `verify-payment/index.ts:268` | ✅ |
| `paddle_transaction_id` | `migration:22` (+ index unique `:29-31`) | `create-paddle-checkout:240`, `paddle-webhook:148`, `verify-payment:306` | `paddle-webhook:104`, `verify-payment:272` | ✅ |
| `montant_local` | `migration:23` | `saspay-checkout:132`, `create-paddle-checkout:144`, `paddle-webhook:149` | `verify-payment:51`, `fulfillment:207`, `saspay-webhook:164` | ✅ (cf. F15) |
| `devise_locale` | `migration:24` | `saspay-checkout:133`, `create-paddle-checkout:145`, `paddle-webhook:150` | `fulfillment:161`, `verify-payment:55` | ✅ |
| `kind` | `migration:25` | `saspay-checkout:141`, `create-paddle-checkout:153` | `fulfillment:118`, `verify-payment:258` | ✅ |

Aucune colonne du contrat ne manque ; aucun nom divergent (le contrat §4.1 est respecté à la lettre).

### 5.2 `public.studio_subscriptions` — 23 colonnes

Toutes présentes (`migration:47-77`) et toutes couvertes par `StudioAbonnement` (`_shared/studio.ts:24-48`)
et `AbonnementStudio` (`lib/core/models.dart:483-506`). Colonnes `status` + `guide_status` (et non
`statut`) conformes au contrat §4.2. **Seul problème** : l'écriture `statut` de F01.

### 5.3 `public.studio_guides` — 13 colonnes

Toutes présentes (`migration:108-123`), interface `StudioGuide` (`:50-64`) et modèle `GuideLive`
(`models.dart:539-549`) alignés. `subscription_id` **unique** ✅. Manque uniquement le `CHECK` sur
`statut` (F10). `user_id` sans FK, conforme au contrat §4.3.

### 5.4 `public.studio_live_sessions` — 15 colonnes

Toutes présentes (`migration:136-157`), interface `StudioSessionLive` (`:66-82`) et modèle `SessionLive`
(`models.dart:589-615`, `toJson` `:617-629`) alignés — y compris `invite_token`, que le front envoie
bien à l'insertion (`api.dart:239-255`). Manquent : bornes/unicité du jeton (F11) et l'horodatage
automatique (F07).

### 5.5 `public.studio_live_messages` — 8 colonnes

Toutes présentes (`migration:174-187`), `MessageLive` (`live-auto-chat:28-37`) et
`lib/core/models.dart:678-688` alignés. `role`/`platform` contraints ✅. Aucune écriture client ✅.

---

## 6. RLS — audit policy par policy

| Table | Policy | Rôle | Verdict |
|---|---|---|---|
| `studio_subscriptions` | `studio_subscriptions_select_own` (`migration:302-310`) | authenticated | ✅ logique correcte (uid OU email) ; ⚠️ F03 (email non vérifié) ; aucun INSERT/UPDATE/DELETE → ✅ |
| `studio_guides` | `studio_guides_select_own` (`migration:313-329`) | authenticated | ✅ pas de récursion (autre table) ; ⚠️ pas de contrôle d'expiration (F06) ; sous-requête soumise à la RLS de `studio_subscriptions` (dépendance implicite à documenter) |
| `studio_live_sessions` | `studio_live_sessions_owner_all` (`migration:332-336`) | authenticated | ✅ `USING` + `WITH CHECK` sur `studio_a_acces` ; ⚠️ `user_id` non contraint (F11) ; `invite_token` non exposé à `anon` ✅ |
| `studio_live_messages` | `studio_live_messages_public_read` (`migration:340-343`) | anon, authenticated | ✅ conforme §4.6 ; ⚠️ portée non bornée à une salle (F14) ; manque la lecture propriétaire (F09) et la lecture invité (F08) ; aucune policy d'écriture ✅ |

**Absence de récursion** : vérifiée par construction —
`studio_guides` → `studio_subscriptions` (table différente, policy sans retour) ;
`studio_live_sessions` → `studio_a_acces()` DEFINER (contourne la RLS) ;
`studio_live_messages` → `studio_session_publique()` DEFINER. Aucune policy ne référence sa propre table.

**Fonctions d'accès, une par une** :

| Fonction | Lignes | Verdict |
|---|---|---|
| `studio_a_acces(uuid)` | `migration:222-243` | ✅ DEFINER + `search_path` + test `ACTIF` + `expires_at > now()` + appartenance ; refus par défaut ; ❌ accorde l'**écriture** sur la seule base de l'email (F03) ; `expires_at is null` = accès perpétuel (n'arrive que si `status='ACTIF'` posé hors activation — à documenter) |
| `mon_abonnement_studio()` | `migration:246-265` | ✅ tri ACTIF d'abord, `expires_at desc nulls last` ; ⚠️ non utilisée (F18), renvoie toute la ligne |
| `studio_session_publique(uuid)` | `migration:269-282` | ✅ DEFINER, booléen seul, pas de fuite du jeton ; ⚠️ oracle d'existence pour `anon` (acceptable) ; ❌ ignore la validité de l'abonnement (F06) |
| `expirer_abonnements_studio()` | `migration:373-384` | ✅ DEFINER + `search_path` + EXECUTE réservé à `service_role` ; ❌ jamais planifiée, ne ferme pas les salles (F06) |

**Grants d'exécution** : `REVOKE ALL FROM PUBLIC` puis `GRANT EXECUTE` ciblé (`migration:284-290`,
`:386-387`) — correct. Conséquence utile pour les tests : `anon` **ne peut pas** appeler
`studio_a_acces` (42501), ce qui est le comportement attendu.

---

## 7. Idempotence et `supabase db push`

État statique : **la migration est rejouable**, à trois nuances près.

| Point | Lignes | Verdict |
|---|---|---|
| Colonnes `orders` | `:21-25` | ✅ `add column if not exists` ; `not null default` remplit les lignes existantes |
| Index | `:27-31`, `:79-90`, `:125-126`, `:159-162`, `:189-194` | ✅ `create index if not exists` (les noms d'index uniques partiels sont libres) |
| Tables | `:47`, `:108`, `:136`, `:174` | ⚠️ `create table if not exists` **ne répare pas** un schéma partiel : si une table existe déjà sans ses `CHECK`/index (run interrompu, création manuelle), la migration « réussira » sans les ajouter. Vérifier avec la requête §11.3 avant de considérer la base conforme |
| Triggers | `:202-215` | ✅ `drop trigger if exists` + `create` ; dépend de `public.touch_updated_at()` créée en `20260101000000_schema_base.sql:214-222` (ordre OK) |
| Policies | `:301-343` | ✅ `drop policy if exists` + `create` |
| Fonctions | `:222-282`, `:373-384` | ✅ `create or replace` + `revoke/grant` rejouables |
| Publication realtime | `:361-367` | ✅ `duplicate_object` (déjà membre) et `undefined_object` (publication absente) capturés ; ⚠️ silencieux (F17) ; ne capture **pas** `insufficient_privilege` (sans objet si la migration tourne en `postgres`) |
| `ALTER TABLE ... ADD CONSTRAINT` | absent | — (les contraintes sont dans les `CREATE TABLE`, donc non rejouables séparément ; à faire via un bloc `DO` comme §4.10) |
| `supabase db push` | — | La migration est **non commitée** (`git status` → `??`). `supabase migration list --linked` est à exécuter avant : si l'historique distant est vide, `db push` rejouera **les 6** migrations — elles sont toutes conçues idempotentes, mais c'est à confirmer (T0) |

Aucune instruction destructrice (`drop table`, `drop column`, `drop function`) n'est présente :
le risque de `db push` est faible, hors le cas « schéma partiel » ci-dessus.

---

## 8. Sécurité — scénarios d'attaque rejoués

1. **Auto-attribution d'un abonnement ACTIF via PostgREST** → ❌ impossible :
   aucune policy INSERT/UPDATE sur `studio_subscriptions` ; un `insert`/`update` renvoie
   `42501` (RLS) ou 0 ligne. Le `GRANT ALL` hérité (F12) ne suffit pas, la RLS prime.
2. **Auto-attribution via `verify-payment`** → ✅ **possible** avec un `payment_id` déjà payé d'un
   montant supérieur (F02). C'est l'attaque la plus rentable pour un tiers.
3. **Modification de `montant_local`** → ❌ impossible côté client ; seul `service_role` écrit
   (`paddle-webhook:149`, `:194`) — d'où l'exigence de vérifier **toutes** les entrées des
   fonctions qui utilisent cette clé.
4. **Lecture de l'abonnement/guide d'autrui** → ❌ par UUID (RLS) ; ✅ **par email** si le tiers peut
   créer un compte avec l'email de la victime (F03).
5. **Lecture de `invite_token` par un anonyme** → ❌ 0 ligne sur `studio_live_sessions` (aucune policy
   `anon`) ; `studio-room` ne le renvoie qu'au porteur d'un jeton valide (`studio-room:98-107`). À
   noter : le jeton est ensuite affiché à l'invité (par conception).
6. **Écriture d'un message avec `role='assistant'`** → ❌ aucune policy d'écriture ; `live-auto-chat`
   force `role` (`:159-166`, `:218-229`). L'usurpation possible est limitée au champ `author`
   (nom affiché, `:157`) et à `platform` (validée contre une liste, `:155-156`).
7. **Inondation du chat / consommation de crédits IA** → ⚠️ `live-auto-chat` est public sur une salle
   ouverte, avec une limite **en mémoire** de 12 req/min par (salle, IP) (`:44-67`) — non partagée entre
   instances, contournable en changeant d'IP. Acceptable en v1, à surveiller (risque coût DeepSeek).
8. **Écriture de messages par le propriétaire après `TERMINE`** → ⚠️ `verifierAccesSession` autorise
   le propriétaire quel que soit le statut (`_shared/studio.ts:230-247`) et `live-auto-chat` insère ;
   mais la lecture RLS échoue (F09) → incohérence fonctionnelle, pas faille.
9. **Cascade destructive** → un propriétaire peut `DELETE` sa session (policy `for all`) → suppression
   des messages (cascade). Il ne peut pas supprimer son abonnement (aucune policy DELETE) ni celui
   d'un autre. OK.
10. **Élévation via les fonctions DEFINER** → `studio_a_acces` filtre par `auth.uid()`/email (cf. F03) ;
    `studio_session_publique` ne renvoie qu'un booléen ; `expirer_*` n'est exécutable que par
    `service_role`. Pas d'élévation directe.

---

## 9. Cohérence front ↔ policies (lecture seule, aucune modification)

| Requête front | Cible | Policy/fonction concernée | Verdict |
|---|---|---|---|
| `monAbonnement()` — `api.dart:186-206` | `select` sur `studio_subscriptions` (10 dernières) | `studio_subscriptions_select_own` | ✅ fonctionne (uid ou email) ; ⚠️ heuristique « 10 dernières » (F16) ; dépend de F03 pour les achats invités |
| `monGuide(subscriptionId)` — `api.dart:208-221` | `select` sur `studio_guides` par `subscription_id` | `studio_guides_select_own` (EXISTS sur l'abonnement) | ✅ fonctionne ; ⚠️ lisible après expiration (F06) ; le `catch` renvoie `null` sans distinguer « pas de droit » de « pas de guide » |
| `enregistrerSessionLive()` — `api.dart:236-260` | `insert`/`update` sur `studio_live_sessions` | `studio_live_sessions_owner_all` (`studio_a_acces`) | ✅ fonctionne pour un abonné **ACTIF non expiré** ; ❌ échoue (42501) pour un abonné expiré, y compris pour **clôturer** sa propre session ; `update` sans `.select()` peut être un no-op silencieux |
| `changerStatutSession()` — `api.dart:262-270` | `update statut` | idem | ⚠️ `catch (_) {}` : si la RLS refuse, le front affiche quand même « Live terminé » (et `started_at`/`ended_at` restent nuls, F07) |
| `messagesLive(roomId)` — `api.dart:342-356` | `select` sur `studio_live_messages` `.eq('room_id')` | `studio_live_messages_public_read` | ✅ fonctionne en `PRET/EN_DIRECT` (y compris `anon`) ; ❌ renvoie `[]` en `BROUILLON`/`TERMINE` (F08/F09) — le `catch` masque la cause |
| `ChatLivePanel` `.stream()` — `studio_regie_page.dart:1216-1234` | realtime `postgres_changes` sur `studio_live_messages` | policy `SELECT` + publication (`migration:361-367`) | ✅ fonctionne quand la session est `PRET/EN_DIRECT` ; ❌ aucun événement en `BROUILLON` (invité) ni après `TERMINE` ; repli polling 6 s ✅ |
| `sessionPublique(roomId, inviteToken)` — `api.dart:289-308` | RPC Edge `studio-room` | fonction (service_role) + `verifierAccesSession` | ✅ fonctionne (jeton OU propriétaire OU salle `PRET/EN_DIRECT`) ; le champ `owner_display` n'est pas consommé (F18) |
| `chatLive()` — `api.dart:310-340` | RPC Edge `live-auto-chat` | idem + insertion `service_role` | ✅ fonctionne ; le `invite_token` est bien transmis ici (`api.dart:326`) — contrairement à `ChatLivePanel` |

**Conclusion front** : aucune requête n'exige une policy qui n'existe pas **pour le cas nominal**
(abonné actif, salle ouverte). Les incompatibilités sont les cas limites F08/F09 et l'absence de
gestion d'erreur (les `catch` renvoient des valeurs vides, ce qui masque un refus RLS). Correctifs :
ajouter les 2 policies/RPC §4.8-4.9, et ne plus avaler les erreurs RLS dans `messagesLive`.

---

## 10. Requêtes de test RLS à exécuter manuellement

Le script complet, commenté et exécutable bloc par bloc, est fourni dans **`docs/tests_rls_studio.sql`**.
Il crée son propre jeu de données (`nom_activite like '__test_rls_%'`), résout les comptes par email,
utilise des GUC (`set_config('test.*')`) pour transporter les identifiants entre rôles, et **nettoie
tout** à la fin. Il doit être lancé **uniquement sur une base de test** (`supabase db reset`).

### 10.1 Rôles et attendus (résumé)

| Bloc | Rôle simulé | Attendu |
|---|---|---|
| T0 | `postgres` | `supabase_realtime` contient `studio_live_messages` ; 4 tables en RLS ; contraintes/idx conformes ; privilèges réels par rôle |
| T1 | `anon` | `studio_subscriptions` = **0** ; `studio_guides` = **0** ; `studio_live_sessions` = **0** (donc pas de `invite_token`) ; `studio_live_messages` = **uniquement** les salles `PRET/EN_DIRECT` (y compris d'autres salles → F14) ; `insert` message/subscription = **42501** ; `studio_a_acces` = **42501** (EXECUTE révoqué) |
| T2 | `authenticated` A (propriétaire) | voit **ses** abonnements (dont celui expiré), **son** guide, **ses** sessions ; `studio_a_acces(abo_A)` = `true` ; `studio_a_acces(abo_A_exp)` = `false` ; `studio_a_acces(abo_B)` = `false` ; `update montant_local`/`status`/`delete` = **0 ligne** (ou 42501 après F12) ; `insert` session sur `abo_B` = **42501** ; `insert` session sur `abo_A` = **OK** ; `insert` message = **42501** ; `user_id` d'autrui accepté (preuve F11) |
| T3 | `authenticated` B (non propriétaire) | `select` de l'abonnement/guide/session de A = **0 ligne** ; `studio_a_acces(abo_A)` = `false` ; `mon_abonnement_studio()` = **ligne B uniquement** ; messages de la salle A `EN_DIRECT` = **lisibles** (public, attendu) |
| T4 | `service_role` | voit **tout** ; `insert`/`update`/`delete` OK ; `expirer_abonnements_studio()` exécutable — c'est **l'unique** rôle qui doit pouvoir écrire ces tables |
| T5 | `postgres` (expiration, F06) | `expires_at` passé → `studio_a_acces` = `false` ; salle `EN_DIRECT` **toujours publique** (preuve de F06) ; après `expirer_abonnements_studio()`, `status='EXPIRE'` et (après correctif §4.6) `statut='TERMINE'` |
| T6 | `postgres` (contraintes/intégrité) | `subscription_id` guide dupliqué → **23505** ; `status='PIRATE'` → **23514** ; `role='root'` → **23514** ; `room_id` dupliqué → **23505** ; `updated_at` > `created_at` après `update` ; cascade abonnement → sessions/messages/guide supprimés |

### 10.2 Extraits directement réutilisables

```sql
-- 1) Quels privilèges anon/authenticated possèdent-ils réellement ? (preuve F12)
select table_name, grantee, string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('studio_subscriptions','studio_guides','studio_live_sessions','studio_live_messages')
group by table_name, grantee order by table_name, grantee;

-- 2) Policies en place (cmd/roles/qual/with_check)
select tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public' and tablename like 'studio_%'
order by tablename, policyname;

-- 3) Se mettre dans la peau de A (transaction annulée ensuite).
--    ⚠️ Remplacer les UUID par ceux des comptes de test : la version auto-résolue
--    (comptes a@test.local / b@test.local) est dans docs/tests_rls_studio.sql.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-00000000000a',
                    'email', 'a@test.local', 'role', 'authenticated')::text, true);
set local role authenticated;
select count(*) as mes_abonnements from public.studio_subscriptions;              -- attendu : ses lignes (0 si l'UUID est un placeholder)
select count(*) as abonnements_autre from public.studio_subscriptions
  where id = '00000000-0000-0000-0000-0000000000b0';                              -- attendu : 0
select public.studio_a_acces('00000000-0000-0000-0000-0000000000b0');            -- attendu : false
update public.studio_subscriptions set montant_local = 0;                          -- attendu : UPDATE 0
rollback;

-- 4) Anonyme
begin;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select count(*) as abonnements from public.studio_subscriptions;                   -- attendu : 0
select count(*) as sessions from public.studio_live_sessions;                      -- attendu : 0
select count(*) as messages from public.studio_live_messages;                      -- attendu : >0 (salles ouvertes)
rollback;

-- 5) service_role
begin;
set local role service_role;
select count(*) as tout from public.studio_subscriptions;                          -- attendu : toutes les lignes
select public.expirer_abonnements_studio();                                        -- attendu : aucune erreur
rollback;
```

### 10.3 Tests d'attaque (manuels, via HTTP — à faire après correctif)

```bash
# F02 (a) — IDOR : lire l'abonnement d'autrui sans être authentifié
curl -s -X POST "$SUPABASE_URL/functions/v1/verify-payment" \
  -H 'Content-Type: application/json' \
  -d '{"subscription_id":"<abo_d_un_autre>"}' | jq '{paid, statut, email: .abonnement.email}'

# F02 (b) — rejeu : réutiliser un payment_id SasPay déjà consommé
curl -s -X POST "$SUPABASE_URL/functions/v1/verify-payment" \
  -H 'Content-Type: application/json' \
  -d '{"subscription_id":"<mon_abo_EN_ATTENTE>","payment_id":"<payment_id_d_un_achat_pack>"}' \
  | jq '{paid, statut, expires_at: .abonnement.expires_at}'
# attendu après correctif : 409 "paiement déjà utilisé" / 402 "montant différent"
```

Le scénario F03 (revendication d'un abonnement invité par création de compte avec le même email) ne
se teste qu'avec l'Auth réelle : `Confirm email` désactivé, créer `victime@…` via `/auth/v1/signup`,
puis `select * from public.studio_subscriptions` avec le JWT obtenu → doit renvoyer **0** ligne après
correctif §4.3.

---

## 11. Vérifications qui n'ont pas pu être exécutées (pas de base disponible)

### 11.1 Ce qui manquait

| Élément | Constat |
|---|---|
| Base locale | `docker` **absent** → `supabase start` / `db reset` impossibles |
| Client SQL | `psql` **absent** ; aucun accès direct au projet lié (`supabase/.temp/linked-project.json` → `ynephuutnazdnjhsdlsy`, mais pas de `SUPABASE_DB_PASSWORD`, pas de `SUPABASE_ACCESS_TOKEN` dans l'environnement) |
| Secrets | seul `supabase/.env.example` (placeholders) est présent ; `supabase/.env` est absent |
| Runtime Edge | `deno` **absent** → pas de `deno check` sur `supabase/functions/**` |
| Flutter/Dart | `dart`/`flutter` **absents** → `flutter analyze`/`build web` non exécutables |
| Migration | `20260101000500_paddle_et_studio_live.sql` n'est **pas commitée** (`??`) et donc jamais appliquée à une base connue |

### 11.2 Ce qu'il faut lancer, dans cet ordre

```bash
# 0. Récupérer l'URL de la base locale
DB_URL="$(supabase status -o env | grep '^DB_URL=' | cut -d= -f2- | tr -d '"')"

# 1. Base locale propre
supabase start
supabase db reset                     # applique les 6 migrations dans l'ordre

# 2. Idempotence : rejouer le fichier une seconde fois (doit passer sans erreur)
psql "$DB_URL" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20260101000500_paddle_et_studio_live.sql

# 3. Lint / types / historique
supabase db lint --local
supabase gen types typescript --local > /tmp/types.ts     # comparer aux usages front
supabase migration list

# 4. RLS (script fourni)
psql "$DB_URL" -v ON_ERROR_STOP=1 -f docs/tests_rls_studio.sql

# 5. Projet distant (après revue du diff)
supabase link --project-ref <ref>
supabase migration list --linked        # AVANT push : vérifier l'historique
supabase db push --dry-run
supabase db push
```

### 11.3 Vérifications ciblées à ne pas oublier (SQL)

```sql
-- (a) Structure réellement créée (détecte un schéma partiel « if not exists »)
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('orders','studio_subscriptions','studio_guides','studio_live_sessions','studio_live_messages')
order by table_name, ordinal_position;

-- (b) Contraintes CHECK présentes (F01/F10/F11)
select conrelid::regclass as table_name, conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = any (array[
        'public.studio_subscriptions'::regclass,
        'public.studio_guides'::regclass,
        'public.studio_live_sessions'::regclass,
        'public.studio_live_messages'::regclass,
        'public.orders'::regclass
      ])
order by 1, 2;

-- (c) Index (dont unicités partielles)
select tablename, indexname, indexdef from pg_indexes
where schemaname = 'public'
  and (tablename like 'studio_%' or tablename = 'orders')
order by tablename, indexname;

-- (d) Realtime (F17)
select * from pg_publication_tables where pubname = 'supabase_realtime';

-- (e) RLS active partout
select relname, relrowsecurity, relforcerowsecurity, relreplident
from pg_class where relname like 'studio_%' order by relname;

-- (f) Doublons pré-existants (à corriger avant d'ajouter les index uniques F02/F13)
select saspay_payment_id, count(*) from public.orders
  where saspay_payment_id is not null group by 1 having count(*) > 1;
select saspay_payment_id, count(*) from public.studio_subscriptions
  where saspay_payment_id is not null group by 1 having count(*) > 1;
select lower(email), count(*) from public.studio_subscriptions group by 1 having count(*) > 20;

-- (g) Configuration Auth (F03) — le dashboard reste la source de vérité
select count(*) filter (where email_confirmed_at is null) as comptes_non_confirmes,
       count(*) as total
from auth.users;
```

### 11.4 Tests bout en bout qui dépendent de la base (impossible ici)

- `saspay-checkout` (kit + studio) → lignes `orders`/`studio_subscriptions` avec `provider`, `montant_local`,
  `devise_locale`, `kind` corrects (contrôle de cohérence du schéma) ;
- `create-paddle-checkout` → `paddle_transaction_id` posé, devise alignée sur le `price_id` ;
- `paddle-webhook` rejoué 2× → une seule activation, un seul guide, un seul email ;
- `saspay-webhook` `transaction.failed` puis `transaction.success` → vérifie F04 ;
- `live-auto-chat` → 2 lignes `studio_live_messages` (user + assistant) et diffusion realtime ;
- `expirer_abonnements_studio` planifié → `EXPIRE` + salles fermées (après correctif F06).

---

## 12. Checklist de sortie (à cocher avant release)

> État au **2026-11-23** (après correctifs, §13) : `[x]` = fait, `[~]` = partiel, `[ ]` = à faire.

- [x] **F01** corrigé (`status` pour Studio, 3 chemins d'échec) — reste à tester en sandbox Paddle.
- [x] **F02** corrigé : liaison serveur du `payment_id` (409 si non rattaché), réponse expurgée,
      montant + devise contrôlés, index uniques `saspay_payment_id`, 23505 → 409.
      `[~]` le contrôle de propriétaire retombe sur l'email → dépend de F03.
- [ ] **F03** tranché : `Confirm email` activé **ou** email retiré des policies (liaison par
      `user_id`/lien signé) — **seul majeur restant**.
- [x] **F04** `ECHEC` récupérable (`studio.ts:961`).
- [~] **F05** journal `transactions` : présent dans `verify-payment`, absent des webhooks ;
      pas d'unicité `(provider, transaction_token)`.
- [~] **F06** `studio_session_publique` liée à l'abonnement (chat fermé à l'expiration) ;
      restent `studio-room`, la policy du guide et le job d'expiration.
- [x] **F09** policy `studio_live_messages_owner_read` (archive du propriétaire).
- [ ] **F07** trigger `started_at`/`ended_at` ; **F08** chat invité avant `PRET`.
- [~] **F10-F13** : F13 fait (index uniques) ; contraintes CHECK, grants révoqués et
      `invite_token` unique restent à faire.
- [ ] `docs/tests_rls_studio.sql` exécuté : T1 (anon) = 0 ligne sur subscriptions/guides/sessions,
      écriture refusée ; T2/T3 (A/B) conformes ; T4 (service_role) OK ; T5 (F06) prouvé ;
      T6 (contraintes/cascade) OK — **et** T1.7/T5.3 doivent désormais renvoyer **0** (F06 fermé).
- [ ] Dédoublonnage `saspay_payment_id` exécuté (§11.3(f)) **avant** `db push` (sinon 23505).
- [ ] Migration commitée puis `supabase migration list --linked` + `db push --dry-run` + `db push`.
- [ ] Rejeu du fichier de migration sur base reset : aucune erreur (idempotence prouvée).
- [ ] `supabase db lint` sans erreur ; `gen types` comparé aux modèles Dart/TS.
- [ ] Aucune régression front : `monAbonnement`/`monGuide`/`enregistrerSessionLive`/`messagesLive`/
      `sessionPublique` testés sur une base réelle (les `catch` silencieux masquent les refus RLS) ;
      vérifier la page de confirmation sans `whatsapp` (N3) et la page d'attente sans JWT.

---

## 13. Contre-revue du 2026-11-23 (correctifs du lead)

Périmètre relu : migration `20260101000500` (414 lignes), `_shared/studio.ts` (l.961),
`verify-payment` (613 lignes), `create-paddle-checkout` (317 lignes). **Lecture seule** ; rien n'a été
appliqué ni exécuté (mêmes limites qu'au §11 : pas de base, pas de Deno).

### 13.1 F01 — ✅ fermé

`create-paddle-checkout:205-212`, `:222-241`, `:274-286` :
`update(kind === "kit" ? { statut: "ECHEC" } : { status: "ECHEC" })`. Les trois chemins d'échec
(création de transaction, devise incohérente, checkout indisponible) sont désormais corrects pour les
deux tables, et le nouveau garde-fou « devise Paddle ≠ devise affichée » renvoie 409.

Résidus (mineurs) : les erreurs PostgREST de ces `update` ne sont toujours pas lues (aucun `.error`) ;
et la transaction Paddle déjà créée peut encore être payée par le client alors qu'on lui a renvoyé
409 — le webhook la rattrapera (`ECHEC → PAYE/ACTIF`), comportement acceptable mais à documenter.

### 13.2 F02 — ✅ fermé (le chemin d'attaque ne fonctionne plus)

- **Liaison serveur** : `paymentId` provient de `abonnement.saspay_payment_id` ou de
  `statutSession(saspay_session_id)` (`verify-payment:262-280`) ; tout `payment_id` client différent,
  ou fourni sans rattachement, renvoie **409** (`:282-287`, `:319-327`). Le rejeu « Pack 9 000 XOF →
  Studio » n'est plus possible.
- **Réponse expurgée** : `abonnementPublic` (`:99-112`) ne contient plus email / nom / pays ; le guide
  n'est renvoyé qu'au propriétaire (`:143-177`, `:249`). L'IDOR de données personnelles est fermé ;
  un appelant anonyme n'obtient que `{id, status, provider, devise, montant_local, guide_status,
  expires_at, paid_at, created_at}`.
- **Montant + devise** : `controlerMontant` (`:68-86`) exige la devise exacte, un montant vérifiable
  (non nul) et un minimum (tolérance 0,02 pour les devises décimales, 1 sinon).
- **Anti-rejeu en base** : index uniques `saspay_payment_id` ; l'erreur 23505 des `update` est
  traduite en **409** (`:319-327` Studio, `:562-576` kits).

Résidu **majeur** : `proprietaireStudio:88-97` retombe sur l'email quand `user_id` est `null` → le
scénario de **F03** (revendication d'un abonnement invité) reste entier et donne accès au guide et au
pilotage des sessions. Le contrôle de propriétaire n'est robuste que si `user_id` est renseigné.

Résidus mineurs : `montant === null` → 402 systématique (`:78-80`) : si SasPay n'expose pas `amount`
sur `/payments/{id}/verify/`, tous les retours Studio échouent en 402 (à valider en sandbox) ; la
recherche par `payment_id` seul a été retirée pour les kits (aucun appelant front concerné).

### 13.3 F04 — ✅ fermé

`studio.ts:961` accepte `["EN_ATTENTE", "PAYE", "ECHEC"]`. Un `transaction.failed` suivi d'un
`transaction.success` active désormais l'abonnement ; le webhook ne renvoie plus 500 sur `ECHEC`.
`EXPIRE` reste volontairement non réactivable (renouvellement = nouvelle ligne) : correct.

### 13.4 F06 — ⚠️ fermé côté chat, trois résiduels

`studio_session_publique` (`migration:277-293`) joint désormais l'abonnement :
`s.statut in ('PRET','EN_DIRECT')` **et** `a.status='ACTIF'` **et** `a.expires_at > now()`. Les
messages d'un abonnement expiré ne sont plus publics, **même sans job d'expiration** : c'est le point
principal du finding, il tombe. Résiduels (aucun bloquant) :
(a) `studio-room` sert encore `titre` / `fiche_produit` / `owner_display` pour une session
`PRET/EN_DIRECT` d'un abonnement expiré (contrôle côté Edge, pas en base) ;
(b) `studio_guides_select_own` (`:324-340`) n'a toujours aucune condition d'expiration → guide lisible
indéfiniment (contredit la promesse « 30 jours ») ;
(c) `expirer_abonnements_studio` (`:397-408`) n'est toujours pas planifiée et ne ferme pas les
sessions.

### 13.5 F09 — ✅ fermé (policy saine)

Nouvelle policy `studio_live_messages_owner_read` (`migration:356-367`) :
- **Pas de récursion** : messages → `studio_live_sessions` (policy `owner_all`) → `studio_a_acces()`
  qui est `security definer` et ne touche jamais `studio_live_messages` ; aucun cycle.
- **Pas de fuite** : la sous-requête est évaluée avec les droits de l'appelant, donc filtrée par la RLS
  des sessions → un non-propriétaire obtient `exists = false` ; la policy est `to authenticated` et ne
  fait qu'**ajouter** un droit (elle n'élargit rien pour `anon`).
- **Limites** : l'archive redevient inaccessible dès que `expires_at` est passé (`studio_a_acces`
  exige `ACTIF`) — cohérent avec le modèle d'accès, à assumer ; coût d'une sous-requête par ligne
  (négligeable sur 60 messages, index PK sur `s.id`).

### 13.6 F13 — ✅ fermé, index valides et idempotents

`migration:32-35` (`orders_saspay_payment_id_key`) et `:95-98`
(`studio_subscriptions_saspay_payment_key`) : index **uniques partiels** (`where … is not null`),
syntaxe valide, et **idempotents** (`create unique index if not exists`). Trois précautions avant
`db push` :
1. des doublons pré-existants feraient **échouer** la migration (23505) → exécuter le dédoublonnage
   §11.3(f) avant ;
2. `CREATE INDEX` (non `CONCURRENTLY`) pose un verrou d'écriture bref sur `orders` /
   `studio_subscriptions` — sans gravité à ces volumes, et `CONCURRENTLY` est de toute façon interdit
   dans la transaction d'une migration ;
3. si un index du même nom existait déjà en non-unique, `if not exists` le conserverait tel quel
   (vérifier avec §11.3(c)).

### 13.7 Nouveaux constats (aucun bloquant)

| # | Sév. | Constat | Impact |
|---|---|---|---|
| N1 | 🔵 | `saspay-webhook:96-102` et `paddle-webhook:190-197` écrivent l'identifiant de paiement sans lire `.error` : un 23505 (paiement déjà rattaché) est ignoré puis l'activation est planifiée | Un routage erroné du prestataire pourrait activer un abonnement dont le paiement appartient déjà à une autre ligne — improbable (webhook signé), à couvrir par un test |
| N2 | 🔵 | F05 : le journal `transactions` du Studio n'est écrit que dans `verify-payment` (`:329-336`, `:379-386`), pas dans les webhooks | Un paiement confirmé uniquement par webhook (client qui ferme l'onglet) reste sans trace comptable |
| N3 | 🔵 | `commandePublique` (`verify-payment:115-132`) ne renvoie plus `whatsapp`, alors que `confirmation_page.dart:267` l'affiche conditionnellement | La ligne « WhatsApp » disparaît de la page de confirmation (cosmétique) |
| N4 | 🔵 | `journaliserTransaction` s'exécute avant l'activation, sans garde d'idempotence (pas d'index unique sur `transaction_token`) | Doublons possibles dans `transactions` si deux appels concurrents passent |

### 13.8 Verdict de contre-revue

**PLUS DE BLOQUANT en base.** Les quatre correctifs sont justes, les deux index sont valides et
idempotents, la policy propriétaire est saine (ni récursion, ni fuite). Avant release :
(i) trancher **F03** — seul majeur restant, hors périmètre des correctifs appliqués ;
(ii) dédoublonner `saspay_payment_id` **avant** `db push` ;
(iii) exécuter `docs/tests_rls_studio.sql` (T1-T6, T1.7/T5.3 doivent maintenant valoir **0**) et le
test d'attaque F02 §10.3 (doit répondre **409/402** au lieu d'activer).

---

### Annexe A — Correspondance contrat §4 ↔ migration

> Line numbers de la version courante (2026-11-23).

| Contrat | Migration | Écart |
|---|---|---|
| §4.1 colonnes `orders` | `:21-25` (+ index uniques `:29-35`) | aucun (les `CHECK` ne sont pas exigés par le contrat) |
| §4.2 `studio_subscriptions` | `:51-81` (+ index `:83-98`) | aucun (les 3 `CHECK` du contrat sont présents) |
| §4.3 `studio_guides` | `:116-131` | `statut` sans `CHECK` (le contrat n'en prévoit pas non plus → lacune de contrat, F10) |
| §4.4 `studio_live_sessions` | `:144-165` | aucun |
| §4.5 `studio_live_messages` | `:182-195` | aucun |
| §4.6 RLS / realtime / index / fonctions | `:230-391` (policies `:313-367`) | `mon_abonnement_studio` présente mais non utilisée ; realtime ✅ ; index ✅ ; policy owner ajoutée (`:356-367`) |
| §5.1/5.2 sorties checkout | `saspay-checkout`, `create-paddle-checkout` | conforme ; F01 corrigé (§13.1), garde-fou devise ajouté |
| §5.3 webhook Paddle | `paddle-webhook` | conforme ; F04 corrigé (§13.3) |
| §5.4 `verify-payment` | `verify-payment` | conforme ; **F02 corrigé** (§13.2) ; résidu F03 sur le repli email |
| §5.5 `generate-live-guide` | `generate-live-guide` | conforme (JWT + propriétaire, `:26-42`) ; ne bloque pas un abonnement `ACTIF` expiré → cohérent avec F06 |
| §5.6 `live-auto-chat` | `live-auto-chat` | conforme ; rate-limit en mémoire (risque accepté) |
| §5.7 `studio-room` | `studio-room` | conforme ; jeton constant-time ✅ ; `owner_display` mort côté front ; résidu F06(a) |
