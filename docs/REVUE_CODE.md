# REVUE DE CODE INDÉPENDANTE — e-booklive (`kit_business_app`)

> **Rôle** : code reviewer indépendant (aucun fichier de `lib/`, `supabase/`, `web/`, `test/` modifié par cette revue).
> **Livrable** : ce document uniquement.
> **Date de la revue** : 22/11/2026, 22:05 → 22:25 (Africa/Casablanca).
> **Commit de référence** : `6b9c9d8` (« Deploiement final FCFA SasPay Resend Avis TikTok OAuth »), **arbre de travail sale** (`git status --porcelain` : 31 fichiers modifiés, 2 supprimés, 46 nouveaux).
> **Périmètre** : frontend Flutter (`lib/`), Edge Functions (`supabase/functions/`), migration `20260101000500_paddle_et_studio_live.sql`, `supabase/config.toml`, `web/index.html`, `netlify.toml`, `test/`.
> **Contrat de référence** : [`docs/ARCHITECTURE_REFONTE.md`](ARCHITECTURE_REFONTE.md) (cité « ARCH §x ») et [`docs/PLAN_REFONTE.md`](PLAN_REFONTE.md) (cité « PLAN §x »).
>
> 🔄 **Mise à jour du 23/11/2026, 00:05 — voir § 8 « Contre-revue des correctifs ».** Les deux findings **critiques C-1 et C-2 sont fermés** après correction. Le **verdict final est « À CORRIGER »** (et non plus « BLOQUANT ») : il reste **1 bloquant de déploiement** (`supabase/config.toml` invalide, CC-1) et **2 régressions de paiement à prouver en sandbox** (CC-2, CC-3). Le verdict « BLOQUANT » du § 0 ci-dessous est celui de la **revue initiale**, conservé comme historique.

---

## 0. Verdict global — **BLOQUANT**

Le code est **de bonne facture sur l'essentiel** : les montants sont intégralement recalculés côté serveur, la parité pays/devises/taux front↔back est **exacte** (vérifiée indépendamment, cf. § 1.2), les signatures de webhook sont correctement vérifiées (HMAC + fenêtre 300 s + comparaison à temps constant), l'idempotence des livraisons est verrouillée par des updates conditionnels atomiques, et la RLS interdit toute écriture client sur les tables Studio.

Mais **deux vulnérabilités critiques** permettent aujourd'hui de **ne pas payer** ou de **récupérer un livrable payant sans compte** :

| # | Vulnérabilité | Effet |
| --- | --- | --- |
| **C-1** | `verify-payment` ne rattache jamais le `payment_id` SasPay reçu à la commande/abonnement qu'il valide | **rejeu d'un paiement unique sur N commandes** → kits et abonnements gratuits |
| **C-2** | `verify-payment` renvoie l'abonnement **et le Livre Guide complet** (HTML) à un appelant **non authentifié** qui connaît le `subscription_id` (présent dans l'URL de retour) | **fuite du livrable payant** par simple partage d'URL |

S'y ajoutent deux sujets **élevés** qui touchent le cœur de l'offre Studio Live (salle Jitsi non protégée par le jeton d'invitation ; devise facturée potentiellement ≠ devise affichée chez Paddle) : ce sont des corrections à faire **avant** d'ouvrir le Studio Live au public.

> **En clair** : on ne peut pas mettre en production en l'état. La bonne nouvelle est que les correctifs de C-1/C-2 sont **courts et localisés** (`verify-payment` ≈ 30 lignes + 2 index SQL), et que le reste du socle (prix, RLS, idempotence) est solide.

---

## 1. Méthode, état du dépôt et limites de cette revue

### 1.1 Ce qui a été vérifié, et comment

| Type de vérification | Méthode | Fiabilité |
| --- | --- | --- |
| Lecture intégrale ou ciblée des fichiers du périmètre | outil de lecture (UTF-8), relecture des zones modifiées en fin de revue | ✅ directe |
| Parité pays / devises / taux front↔back | **script de comparaison exécuté** (cf. § 1.2) | ✅ prouvée |
| Recherche de motifs (URL sync, `setState` après `dispose`, `catch (_)`, secrets, `target=_blank`) | `grep` sur `lib/`, `web/`, `supabase/` | ✅ prouvée (absence ou présence) |
| Comportement d'exécution (UI, paiement réel, Jitsi, DeepSeek) | **non exécuté** — pas de navigateur, pas de Supabase déployé, SDK Flutter non exploitable en sandbox (cf. PLAN § 1.3) | ⚠️ lecture seule |
| `flutter analyze` / `flutter test` / `flutter build web` | **non rejoués ici** ; je reprends les résultats du lead (`No issues found`, 24 tests, build en cours) | ⚠️ non reproduit |

### 1.2 Preuves exécutées pendant cette revue

Comparaison automatique `lib/core/countries.dart` ↔ `supabase/functions/_shared/countries.ts` :

```
devises dart=152  ts=152            divergences taux  : 0
pays    dart=215  ts=215            divergences pays  : 0 (devise, zone, indicatif, indicateur SasPay)
sasPay  dart=23   ts=23             divergences sasPay: 0
```

→ La promesse « prix affiché = prix facturé » est **tenue au niveau des données**. Les formules d'arrondi (seuils 10 000 / 1 000, devises entières) sont identiques (`lib/core/pricing.dart:194-201` ↔ `_shared/pricing.ts:89-98`), y compris le cas Studio Live (`10 / 0,00165 × taux`).

### 1.3 Ce qui n'a **pas** pu être vérifié (à ne pas lire comme « conforme »)

1. Aucun **test d'exécution** de l'UI (débordements mobiles, focus clavier, rendu du guide `HtmlWidget`, salle Jitsi, overlay Paddle).
2. Aucun **appel réel** SasPay / Paddle / DeepSeek / Gemini / Resend / Supabase : les chemins d'erreur fournisseur sont lus, pas éprouvés.
3. **Migration non appliquée** : les policies RLS et les index sont revus sur le fichier SQL, pas sur une base.
4. Les **price IDs Paddle ne sont pas dans le dépôt** (attendu) : le chemin de paiement international n'est donc pas prouvable ici, et il est probablement encore **non fonctionnel en production** tant que `PADDLE_PRICE_*` n'est pas posé (cf. E-2).
5. `flutter analyze` : la sortie du lead **a peut-être précédé les dernières modifications** (cf. § 1.4) → à rejouer.

### 1.4 ⚠️ Avertissement : l'arbre de travail a bougé **pendant** la revue

Des fichiers ont été réécrits **entre 22:16 et 22:21**, c'est-à-dire pendant cette revue (un autre intervenant applique visiblement les points P0.5/D4/D7) :

| Fichier | Dernière écriture | SHA-256 (12 premiers) |
| --- | --- | --- |
| `lib/core/models.dart` | 22:16:40 | `08071444BEA3` |
| `lib/pages/confirmation_page.dart` | 22:16:45 | `BE2972398AC1` |
| `lib/pages/dashboard_page.dart` | 22:17:04 | `B71C3F986932` |
| `lib/services/jitsi_view_web.dart` | 22:17:47 | `F22A06823F89` |
| `lib/pages/studio_regie_page.dart` | 22:18:00 | `C0197F5361F1` |
| `lib/widgets/app_header.dart` | 22:18:07 | `B68E3CEE2978` |
| `lib/services/paddle_checkout_web.dart` | 22:21:01 | `4E67D157166D` |

**Conséquences pour le lecteur** :
- Les constats `D4` (montant en FCFA sur la confirmation et l'espace client) du PLAN sont **déjà corrigés** dans l'arbre que j'ai relu (`confirmation_page.dart:252-257`, `dashboard_page.dart:510`, `models.dart:160-161/178-179/216-220`). Je ne les rouvre donc pas.
- `D7` (scripts Jitsi + Paddle.js chargés globalement en `async`) est également **corrigé** : `web/index.html` ne contient plus que `flutter_bootstrap.js` (l. 557), et les deux SDK sont chargés **à la demande** (`jitsi_view_web.dart:169-183`, `paddle_checkout_web.dart:31-45`).
- En revanche, la validation `flutter analyze` / `flutter test` doit être **rejouée sur l'arbre final** : elle ne peut pas avoir couvert des écritures postérieures à son exécution.

---

## 2. Synthèse des findings

| Sévérité | Nombre | Identifiants |
| --- | --- | --- |
| 🔴 **Critique** | 2 | C-1, C-2 |
| 🟠 **Élevé** | 2 | E-1, E-2 |
| 🟡 **Moyen** | 12 | M-1 → M-12 |
| 🔵 **Faible** | 10 | F-1 → F-10 |
| **Total** | **26** | |

---

## 3. Findings détaillés

### 3.1 🔴 CRITIQUE

---

#### C-1 — `verify-payment` : le `payment_id` SasPay n'est jamais rattaché à la commande → rejeu d'un paiement pour livrer N commandes

**Fichiers / lignes**
- `supabase/functions/verify-payment/index.ts:351` — `let paymentId = paymentIdParam ?? commande.saspay_payment_id ?? null;`
- `supabase/functions/verify-payment/index.ts:366-371` — `verifierPaiement(paymentId)` puis `paye = verification.paye;`
- `supabase/functions/verify-payment/index.ts:393` — seul garde-fou : `montantVerifie + 1 < attendu`
- `supabase/functions/verify-payment/index.ts:146` — même schéma pour le Studio (`paymentIdParam ?? abonnement.saspay_payment_id`)
- `supabase/functions/_shared/saspay.ts:168-181` — `verifierPaiement(id)` interroge `GET /payments/{id}/verify/` **sans aucune notion de commande**
- `supabase/functions/_shared/saspay.ts:202-210` — `payment_id` accepté depuis le **corps JSON ou la query string**
- `supabase/migrations/20260101000100_commandes_assistant_video.sql:27` et `.../20260101000500_paddle_et_studio_live.sql:62` — colonne `saspay_payment_id` **sans index unique** (seul `saspay_session_id` est unique, l. 44-45)

**Scénario de reproduction (aucun outil spécial)**
1. Acheter le Pack Complet (9 000 XOF) au Mali. SasPay confirme. La commande **A** passe `PAYE` puis `LIVRE`, et `orders.saspay_payment_id = pay_123`.
   *L'identifiant de paiement est même fourni à l'acheteur* : `verify-payment` renvoie la ligne `orders` **complète** (`fulfillment.ts:223-245` : `commande: commandeFinale` issue d'un `.select("*")`, sérialisée par `verify-payment/index.ts:426`), donc `saspay_payment_id` **et** `saspay_session_id` figurent dans la réponse JSON de la page de confirmation.
2. Créer une **seconde** commande **B** identique (même pays, même offre) : elle reste `EN_ATTENTE`, montant calculé par le serveur = 9 000 XOF.
3. Appeler la fonction publique :
   ```bash
   curl -X POST https://<projet>.supabase.co/functions/v1/verify-payment \
     -H 'Content-Type: application/json' \
     -d '{"order_id":"<uuid de B>","payment_id":"pay_123"}'
   ```
4. `verifierPaiement("pay_123")` renvoie `SUCCESS` + `amount = 9000`. Le contrôle `9000 + 1 < 9000` est **faux** → la commande B passe `PAYE` puis `LIVRE`, un second kit est généré et envoyé par email.
5. Répéter l'étape 2-3 autant de fois que voulu → **N kits pour un paiement**.

Variante Studio Live (plus coûteuse) : un abonnement payé 10 USD sert à activer un nombre illimité d'abonnements de 30 jours (`verify-payment/index.ts:146-196` : `activerAbonnementStudio` est appelé dès que `paye == true`).

**Impact** — Perte de revenu directe et illimitée, sans compte ni outil : la fonction est `verify_jwt = false` (`supabase/config.toml:17-21`) et accessible en `curl`. Le contrôle de montant protège d'un **sous-paiement**, pas d'un **rejeu**. Aucun index unique n'empêche le même `payment_id` d'être écrit sur plusieurs lignes.

**Correctif proposé**
1. Lier le paiement à la commande **avant** de faire confiance à `payment_id` :
   ```ts
   // verify-payment — branche kit SasPay, juste après la ligne 351
   let paymentId = paymentIdParam ?? commande.saspay_payment_id ?? null;

   if (paymentIdParam && commande.saspay_session_id) {
     // Le paiement doit être CELUI de la session SasPay enregistrée sur la commande.
     const session = await statutSession(commande.saspay_session_id);
     if (session.paymentId && session.paymentId !== paymentIdParam) {
       return erreur("Ce paiement n'est pas rattaché à cette commande.", 403);
     }
     if (!session.paymentId) {
       return erreur("Paiement non confirmé par le fournisseur.", 409);
     }
   }
   ```
   Appliquer le même contrôle dans la branche Studio (`:146`). À défaut de `paymentId` exposé par `statutSession`, comparer `metadata.order_id` / `metadata.subscription_id` renvoyés par SasPay (les métadonnées sont déjà envoyées à la création : `saspay-checkout/index.ts:159-163` et `:229-233`).
2. Verrouiller l'unicité en base (défense en profondeur) :
   ```sql
   create unique index if not exists orders_saspay_payment_id_key
     on public.orders (saspay_payment_id) where saspay_payment_id is not null;
   create unique index if not exists studio_subscriptions_saspay_payment_key
     on public.studio_subscriptions (saspay_payment_id) where saspay_payment_id is not null;
   ```
3. Test de non-régression à ajouter (voir M-12) : « deux commandes EN_ATTENTE + un seul paiement → la seconde reste EN_ATTENTE / 4xx ».

---

#### C-2 — `verify-payment` sert le Livre Guide Live complet à un appelant non authentifié (IDOR sur le livrable payant)

**Fichiers / lignes**
- `supabase/functions/verify-payment/index.ts:119-130` — `chargerAbonnement(subscriptionId)` avec le client **service_role**, **sans aucun contrôle d'appartenance**
- `supabase/functions/verify-payment/index.ts:59-79` — `reponseStudio()` renvoie `abonnement` **et** `guide` (`contenu_html` compris)
- `supabase/functions/verify-payment/index.ts:110-112` — `subscription_id` accepté tel quel depuis le corps **ou** la query string
- URL de retour SasPay qui transporte l'identifiant : `saspay-checkout/index.ts:228` (`returnUrl: ${SITE_URL}/studio-live?abonnement=${abonnement.id}`)
- La RLS protège bien l'accès direct (`migration:313-329`), mais la fonction **contourne la RLS** avec `service_role` (`_shared/supabase.ts:8-17`)
- Contraste avec la fonction voisine, correctement protégée : `generate-live-guide/index.ts:26-42` (JWT obligatoire + `abonnementAppartient`)
- Même sur-exposition côté kit : la réponse contient la ligne `orders` **entière** (email, WhatsApp, `saspay_session_id`, `saspay_payment_id`) et pas seulement les liens utiles (`fulfillment.ts:223-245` + `verify-payment/index.ts:426`)

**Scénario de reproduction**
1. Un abonné paie, atterrit sur `https://…/studio-live?abonnement=<uuid>`. Il partage ce lien (ou une capture, ou le lien atterrit dans un outil analytics / un historique d'URL).
2. N'importe qui, **sans compte**, appelle :
   ```bash
   curl -X POST https://<projet>.supabase.co/functions/v1/verify-payment \
     -H 'Content-Type: application/json' -d '{"subscription_id":"<uuid>"}'
   ```
3. La réponse contient `abonnement` (email, activité, montant, statut) **et** `guide.contenu_html` : le Livre Guide payant est lisible en clair, sans JWT, sans rate limit.

**Impact** — Fuite du livrable vendu (le guide est l'argument de vente du Studio Live), fuite de l'email et du nom d'activité de l'abonné, et contournement complet de la protection mise en place par `generate-live-guide`. La quasi-totalité des UUID ne sont pas publics, mais **celui-ci est conçu pour circuler dans une URL de retour** (et le contrat ARCH §2 le prévoit explicitement : `/studio-live?abonnement=<id>`).

**Correctif proposé**
```ts
// verify-payment — branche studio (remplace reponseStudio)
const utilisateur = await utilisateurCourant(req);
const proprietaire = utilisateur ? abonnementAppartient(abonnement, utilisateur) : false;

return json({
  success: true,
  paid: true,
  statut: abonnement.status,
  subscription_id: abonnement.id,
  // Vue publique minimale si l'appelant n'est pas le propriétaire :
  abonnement: proprietaire
    ? abonnement
    : { id: abonnement.id, status: abonnement.status, expires_at: abonnement.expires_at },
  guide: proprietaire ? (options.guide ?? await chargerGuide(abonnement.id)) : null,
});
```
Le frontend n'a pas besoin du guide ici : `paiement_en_attente_page.dart:86-89` n'utilise que `resultat.abonnement.estActif`, et `studio_live_page.dart:1312` ne teste que `_guide?.estPret`. Le guide est de toute façon lisible en direct par le propriétaire via la RLS (`monGuide`, `api.dart:208-221`).

**Complément (même correctif, côté kit)** : remplacer `...resultat` (qui sérialise `commande` en entier, `select("*")`) par une vue réduite aux champs réellement affichés par `ResultatCommande.fromJson` (`models.dart:181-221`) :
```ts
const c = resultat.commande;
return json({
  success: true, paid: true, source,
  order_id: c.id,
  statut: c.statut,
  liens: resultat.liens,
  livraison: resultat.livraison,
  avertissements: resultat.avertissements,
  commande: {
    // champs d'affichage uniquement — jamais d'identifiants de paiement
    id: c.id, statut: c.statut, nom_projet: c.nom_projet, metier_label: c.metier_label,
    produit_type: c.produit_type, montant_fcfa: c.montant_fcfa,
    montant_local: c.montant_local, devise_locale: c.devise_locale, whatsapp: c.whatsapp,
  },
});
```

---

### 3.2 🟠 ÉLEVÉ

---

#### E-1 — Le jeton d'invitation ne protège pas la visio : le nom de salle Jitsi est public et dérivé du `room_id`

**Fichiers / lignes**
- `lib/services/jitsi_view_web.dart:78` — `String get _nomSalle => 'ebooklive-${widget.roomId}';`
- `lib/services/jitsi_view_web.dart:159` — repli iframe : `iframe.src = 'https://meet.jit.si/${Uri.encodeComponent(_nomSalle)}'`
- `lib/pages/live_room_page.dart:428-433` — tout visiteur de `/live/<roomId>` monte le Jitsi avec `moderateur: false`
- `lib/pages/studio_regie_page.dart:78-79` — le lien **spectateur** public contient `roomId` : `/live/<roomId>`
- `lib/pages/studio_regie_page.dart:123-124` — `roomId: _hex(8)` (8 caractères hex = **32 bits**), `inviteToken: _hex(12)`
- `supabase/functions/studio-room/index.ts:110-118` — la session publique est renvoyée (avec `room_id`) dès `PRET`/`EN_DIRECT`

**Scénario de reproduction**
1. L'animateur partage le lien spectateur `https://…/live/1a2b3c4d` (bouton « copier le lien spectateur », `live_room_page.dart:70-78`).
2. Un spectateur quelconque — ou un robot qui balaie les 2³² identifiants, ou toute personne ayant vu le lien — ouvre `https://meet.jit.si/ebooklive-1a2b3c4d` **dans un onglet séparé**.
3. Il est dans la salle vidéo de l'animateur, caméra et micro disponibles, **sans jamais utiliser** `?invite=<token>`.

**Impact** — Le `invite_token` (48 bits, comparaison à temps constant, correctement vérifié par `studio-room`) donne une **fausse impression de sécurité** : il ne garde que la page Flutter, pas la visio. Un inconnu peut écouter/voir le direct privé et se présenter à l'antenne ; l'animateur n'a aucun outil de modération (`moderateur: false` pour tous, y compris lui-même dans `live_room_page`). Sur `meet.jit.si` public, aucune authentification n'est possible : c'est le nom de salle qui fait office de secret, et il est public.

**Correctif proposé**
- **Ne jamais exposer le nom de salle Jitsi au visiteur non invité.** Ajouter une colonne `jitsi_room` distincte, générée côté serveur avec un secret (≥ 128 bits) et renvoyée **uniquement** à l'animateur et au co-animateur (`studio-room` : brancher `jitsi_room` dans `sessionComplete` seulement, jamais dans `sessionPublique`).
- Pour les spectateurs : ne pas monter Jitsi du tout (lecture du chat + éventuel HLS), ou passer à **JaaS** (`8x8.vc`) avec un **JWT `role: viewer`** signé côté serveur — c'est la seule façon d'avoir un vrai mode « regarder sans publier ».
- À défaut (correctif minimal immédiat) : dériver le nom de salle d'un HMAC serveur (`HMAC(secret, room_id)`) et exiger que `studio-room` renvoie ce nom ; le lien spectateur ne doit plus contenir la valeur utilisée par Jitsi.
- Ajouter `moderateur: true` pour le propriétaire dans la régie (`studio_regie_page.dart` passe actuellement la valeur par défaut `false`).

---

#### E-2 — Devise affichée ≠ devise facturée chez Paddle (repli silencieux sur le price USD) et montant affiché jamais confronté au prix réel du `price_id`

**Fichiers / lignes**
- `supabase/functions/_shared/paddle.ts:193-224` — `priceIdPaddle()` : pour un pays EUR, si `PADDLE_PRICE_*_EUR` est absent, **repli silencieux** sur le price de base (USD) : `const variante = …; if (variante) return variante; const base = …; if (base) return base;`
- `supabase/functions/create-paddle-checkout/index.ts:217-231` — la devise facturée est réalignée **après** la création de la transaction, avec un simple `console.warn` (l. 219-225) ; l'utilisateur, lui, a déjà vu un autre montant
- `lib/core/pricing.dart:148-168` — le prix affiché sur La Boutique est calculé localement (`13,72 €` pour un pack au Maroc / en France)
- `supabase/functions/_shared/paddle.ts:128-149` — `creerTransactionPaddle` n'envoie **que** `price_id` : le montant réel vient du catalogue Paddle, il n'est **jamais comparé** au montant affiché avant le paiement
- `supabase/functions/_shared/pricing.ts:161-186` — `montant_indicatif` est calculé depuis le prix de référence XOF, pas depuis le montant réellement facturé

**Scénario de reproduction**
1. Visiteur en France (devise d'affichage EUR). La carte du Pack affiche « 13,72 € » (`Prix.devisKit(9000, FR)`).
2. Seul `PADDLE_PRICE_KIT_PACK` (USD) est configuré : `priceIdPaddle("kit","pack","EUR")` retourne le price USD.
3. La page Paddle s'ouvre en **USD** (ex. « $14.85 »), le client paie une devise qu'il n'a jamais vue ; le front n'a aucun moyen de l'anticiper.
4. Variante plus grave : le prix du `price_id` dans Paddle vaut 19 € alors que le front affiche 13,72 € → le client est débité de 19 € après avoir lu 13,72 €. Rien dans le code ne bloque cet écart (le `montantFacture` de Paddle écrase la valeur calculée, l. 218).

**Impact** — Litige commercial et risque juridique (prix affiché ≠ prix payé), taux de conversion dégradé, et impossibilité de vérifier l'intégrité tarifaire. C'est exactement le risque **R2** du PLAN, encore ouvert dans le code.

**Correctif proposé**
```ts
// 1) _shared/paddle.ts — ne pas se rabattre silencieusement sur l'USD
if (eur) {
  const variante = lireVariable(`PADDLE_PRICE_KIT_${suffixe}_EUR`);
  if (!variante) throw new Error(
    `Prix Paddle EUR manquant pour ${produit} : renseignez PADDLE_PRICE_KIT_${suffixe}_EUR.`,
  );
  return variante;
}
```
```ts
// 2) create-paddle-checkout — refuser (ou réaligner l'affichage) AVANT de créer la transaction
const prix = await recupererPricePaddle(priceId);   // GET /prices/{id}
if (prix.devise !== tarif.devise) {
  return erreur(`Ce prix n'est pas disponible en ${tarif.devise}. Choisissez un autre moyen de paiement.`, 503);
}
if (Math.abs(prix.montant - tarif.montant) > 0.01) {
  // écart catalogue vs barème : on prévient l'utilisateur du montant réel
  return json({ success: false, error: "Montant mis à jour", montant: prix.montant, devise: prix.devise }, 409);
}
```
Alternative acceptable (et moins coûteuse) : **afficher la devise du `price_id`** dès La Boutique, en remontant `devise_prix` depuis une fonction de pré-vol, pour que le prix affiché soit toujours celui du catalogue Paddle.

---

### 3.3 🟡 MOYEN

---

#### M-1 — `create-paddle-checkout` : mise en échec sur une colonne inexistante pour le Studio (`statut` au lieu de `status`)

**Fichiers / lignes** : `supabase/functions/create-paddle-checkout/index.ts:205-209` — `await admin.from(table).update({ statut: "ECHEC" }).eq("id", id);` où `table` peut valoir `studio_subscriptions`, dont la colonne est **`status`** (`migration:60`). L'erreur Supabase n'est pas lue → échec silencieux.

**Scénario** : `PADDLE_PRICE_STUDIO` absent ou Paddle indisponible → `creerTransactionPaddle` lève → on tente `update({statut})` sur `studio_subscriptions` → PostgREST renvoie `column "statut" does not exist` (ignoré) → la ligne reste `EN_ATTENTE` **pour toujours**.

**Impact** : lignes fantômes en `EN_ATTENTE` ; `ApiService.monAbonnement()` (`api.dart:186-206`) retourne la première ligne non active → l'utilisateur voit « En attente de paiement » sur un abonnement qui n'existe pas côté Paddle, et `verify-payment` répond « Transaction Paddle introuvable ». Aucune trace exploitable pour le support.

**Correctif** :
```ts
const patch = kind === "kit" ? { statut: "ECHEC" } : { status: "ECHEC" };
const { error } = await admin.from(table).update(patch).eq("id", id);
if (error) console.error("create-paddle-checkout : échec du marquage ECHEC", error);
```
(+ test unitaire de la fonction avec un faux client Supabase.)

---

#### M-2 — `?commande=` (et `?code=` TikTok) sont relus **à chaque** navigation : la page de confirmation devient impossible à quitter

**Fichiers / lignes**
- `lib/main.dart:270` — `final uri = Uri.base;` **à chaque appel** de `_genererRoute` (et non une seule fois au démarrage)
- `lib/main.dart:281` et `:290-291` — `if (nom == '/' && commandeId != null…) page = ConfirmationPage(...)`
- `lib/widgets/app_header.dart:87-89` — `_accueil()` → `Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false)`

**Scénario** : après un paiement SasPay, l'URL est `https://…/?commande=<uuid>`. L'utilisateur clique sur le logo e-booklive (ou « Retour à l'accueil » depuis la 404) → nouvelle route nommée `/` → `_genererRoute` relit `Uri.base` (qui n'a pas changé) → **la ConfirmationPage est réaffichée**. Impossible de revenir à l'accueil sans recharger la page.

**Impact** : navigation cassée sur le chemin le plus sensible du tunnel ; même mécanisme pour le retour OAuth TikTok (`main.dart:273-289`).

**Correctif** : consommer les paramètres **une seule fois**, dans `_routeInitiale()`/un état d'initialisation :
```dart
class _EbookliveAppState extends State<EbookliveApp> {
  late final String? _commandeInitiale;
  late final bool _retourTiktok;
  @override
  void initState() { super.initState(); _lireParametresDeRetour(); }
  ...
}
Route<dynamic> _genererRoute(RouteSettings settings) {
  // ne plus lire Uri.base ici : utiliser _commandeInitiale / _retourTiktok
}
```
Et faire de `/?commande=` une **route nommée distincte** (`/confirmation/:id`) pour qu'elle ne pollue plus `/`.

---

#### M-3 — `initialRoute` multi-segments : les deep links empilent des routes fantômes (`HomePage` sous la page cible)

**Fichiers / lignes** : `lib/main.dart:112-113` — `initialRoute: _routeInitiale()` + `onGenerateRoute: _genererRoute`, **sans** `onGenerateInitialRoutes`.

**Scénario** : ouverture directe de `https://…/studio/regie` → `Navigator.defaultGenerateInitialRoutes` découpe le chemin et génère une route par préfixe (`/`, `/studio`, `/studio/regie`). `_genererRoute` renvoie `HomePage` pour `/` et `/studio` (branche `default`, `main.dart:344-353`) → la pile contient **HomePage → HomePage → StudioRegiePage**. Idem pour `/live/<room>` et `/admin-videos`.

**Impact** : écrans construits trois fois (appels réseau `monAbonnement`/`mesSessionsLive` inutiles), bouton retour qui ramène sur un accueil fantôme, et `ModalRoute.of(context)?.settings.name` (utilisé pour l'état actif du menu, `app_header.dart:308`) incohérent.

**Correctif** :
```dart
onGenerateInitialRoutes: (navigator, initialRoute) => [
  _genererRoute(RouteSettings(name: initialRoute)),
],
```

---

#### M-4 — L'URL du navigateur n'est jamais synchronisée avec la navigation interne (exigence « URLs path » à moitié tenue)

**Fichiers / lignes** : `lib/widgets/app_header.dart:77-85` (`pushNamedAndRemoveUntil`), idem `live_room_page.dart:81`, `studio_regie_page.dart:278`, `assistant_page.dart:62`, `home_page.dart:47`. `grep -rn "routeInformationUpdated\|SystemNavigator\|go_router" lib` → **0 résultat**.

**Scénario** : arriver sur `/` puis cliquer « Studio Live » → l'UI change, **l'URL reste `https://…/`**. Copier l'URL, l'envoyer, ou recharger (F5) → retour à l'accueil.

**Impact** : partage de lien impossible depuis n'importe quel écran, retour navigateur incohérent, analytics faussés, et contradiction avec l'invariant ARCH §2/§1.9. Les deep links *entrants* fonctionnent (Netlify + `_routeInitiale`), c'est la sortie qui manque.

**Correctif** : après chaque `pushNamed`, appeler `SystemNavigator.routeInformationUpdated(uri: Uri.parse(route), replace: true)` (ou `Router`/`go_router` pour une solution pérenne). Un `NavigatorObserver` unique suffit à centraliser l'appel.

---

#### M-5 — `setState()` après `dispose()` dans la page d'attente de paiement

**Fichiers / lignes** : `lib/pages/paiement_en_attente_page.dart:51` (`Future<void>.delayed(const Duration(seconds: 2), () => _verifier(...))`, **non annulable**) puis `:71` (`setState(() { _verification = true; … })`, **sans** `if (!mounted) return;`).

**Scénario** : ouvrir `PaiementEnAttentePage`, puis appuyer sur « Annuler » ou « Fermer » en moins de 2 secondes. Le callback s'exécute sur un `State` démonté → `FlutterError: setState() called after dispose()`.

**Impact** : exception framework à chaque fermeture rapide (bruit Sentry/console, écran rouge en debug) ; en release, l'exception est avalée mais laisse la page dans un état incohérent. Le timer de 5 s, lui, est bien annulé (`:55-58`) — seul le `Future.delayed` échappe au nettoyage.

**Correctif** :
```dart
Timer? _demarrage;
@override
void initState() {
  super.initState();
  _demarrage = Timer(const Duration(seconds: 2), () => _verifier(silencieux: true));
  _minuteur = Timer.periodic(const Duration(seconds: 5), (_) => _verifier(silencieux: true));
}
@override
void dispose() { _demarrage?.cancel(); _minuteur?.cancel(); super.dispose(); }
// et, par sécurité, en tête de _verifier :
if (!mounted) return;
```

---

#### M-6 — `ADMIN_EMAILS` est ignoré par le frontend : un admin déclaré par email tombe sur la page « 404 »

**Fichiers / lignes**
- `lib/services/api.dart:461-474` — `estAdmin()` ne lit **que** `profiles.is_admin`
- `supabase/functions/_shared/supabase.ts:55-71` — le backend, lui, accepte `is_admin **OU** ADMIN_EMAILS`
- `docs/ARCHITECTURE_REFONTE.md:19-20` — l'invariant exige les deux

**Scénario** : poser `ADMIN_EMAILS=patron@exemple.com` sans passer `profiles.is_admin = true`. Le compte est admin pour toutes les fonctions serveur, mais `_admin` reste `false` dans `app_header.dart:66-74` → **aucune entrée « Administration »**, et `/admin-videos` affiche `_PageIntrouvable` (`admin_guard_page.dart:33-50`).

**Impact** : fonctionnalité admin inaccessible pour un admin légitime ; risque de « correction » côté client seule (masquage) au lieu du serveur.

**Correctif** : faire exposer la décision par le serveur (petite fonction `whoami` ou renvoi `is_admin` dans le JWT claim) et **ne pas** dupliquer la règle en Dart. À court terme, si l'on veut garder le client : ajouter le même test d'email dans `ApiService.estAdmin()` avec la liste fournie par `--dart-define=ADMIN_EMAILS`.

---

#### M-7 — `live-auto-chat` : anti-abus en mémoire par isolate, IP falsifiable, salle publique ouverte = budget IA non plafonné

**Fichiers / lignes**
- `supabase/functions/live-auto-chat/index.ts:47-49` — `LIMITE_QUESTIONS = 12`, `new Map()` **en mémoire** (donc par instance ; Supabase en lance plusieurs)
- `:69-74` — `adresseIp()` prend le **premier** élément de `x-forwarded-for`, valeur contrôlable par le client si le proxy ajoute au lieu de remplacer
- `:119-122` — `salleOuverte` autorise l'appel **sans jeton** dès `PRET`/`EN_DIRECT`
- `:205-213` — chaque `ask` déclenche un appel DeepSeek (coût réel)

**Scénario** : script qui envoie `x-forwarded-for: <ip aléatoire>` en boucle sur une salle en direct → nouvelle clé de limite à chaque requête, 1 appel DeepSeek par message, insertion de 2 lignes par message. Aucun plafond par salle, par jour, ni par abonné.

**Impact** : coût DeepSeek illimité, pollution de `studio_live_messages` (la table alimente aussi le guide et le contexte du chat), et possibilité de saturer la fonction (déni de service sur le chat d'un live payant).

**Correctif** : limite **par `room_id`** et non par IP (compteur en table `rate_limits` ou Redis/Upstash, `room_id + fenêtre`), plafond journalier par abonnement, et refus des `x-forwarded-for` multiples. Ajouter aussi un `maxTokens` déjà présent mais un **timeout** court sur `appelDeepSeek`.

---

#### M-8 — Avis clients publiés sans modération ni limite (spam de la page d'accueil)

**Fichiers / lignes** : `lib/services/api.dart:422-441` (`publierAvis` insère `'est_publie': true`) ; `supabase/migrations/20260101000200_avis_site.sql` — policy `avis_site_insertion_publique` `for insert to anon` avec `with check (est_publie = true)`, **aucune limite de débit**, `select` public sur `est_publie = true`.

**Scénario** : `curl` en boucle sur `/rest/v1/avis_site` avec `est_publie: true` → 100 avis 5★ identiques sur l'accueil en quelques secondes, ou 1★ injurieux (le contenu est rendu tel quel, sans filtre).

**Impact** : preuve sociale manipulable (argument commercial central), risque d'image, et `listerAvis` (`api.dart:404-420`) charge ces lignes sur la page d'accueil.

**Correctif** : passer `est_publie` à `false` par défaut côté SQL + validation/modération serveur (une Edge Function `submit-review` avec rate limit et filtre), et n'autoriser l'insert client que si `est_publie = false`. Le front ne doit plus décider de la publication.

---

#### M-9 — Fiabilité de la livraison : le webhook répond 202 avant la fin de la tâche de fond (aucune reprise)

**Fichiers / lignes**
- `supabase/functions/paddle-webhook/index.ts:169-175` — `enArrierePlan(livrerCommande(...))` puis `return json(..., 202)`
- `supabase/functions/paddle-webhook/index.ts:199-209` — idem pour `activerAbonnementStudio`
- `supabase/functions/saspay-webhook/index.ts:106-111`
- `supabase/functions/_shared/background.ts:6-18` — `waitUntil` sans repli ni retry

**Scénario** : le webhook est reçu, la réponse 202 part, puis l'isolate est recyclé (ou Gemini/Resend échoue) avant la fin de `livrerCommande`. Paddle/SasPay considèrent l'événement livré → **pas de retry**. La commande reste `PAYE` sans kit.

**Impact** : client débité sans livraison tant qu'il ne rappelle pas `verify-payment` (ce que fait la page d'attente, mais pas un utilisateur qui a fermé l'onglet). Aucun job de reprise, aucun écran d'admin pour les commandes `PAYE` bloquées.

**Correctif** : répondre **200 seulement après** la persistance d'un job (table `delivery_jobs` + worker planifié), ou ajouter un cron `pg_cron` qui reprend les `orders.statut = 'PAYE'` de plus de 5 minutes et les `studio_subscriptions.status = 'PAYE'`. Au minimum, une alerte sur ces compteurs.

---

#### M-10 — Co-animateur : le chat n'envoie pas le `invite_token` (403 en salle `BROUILLON`) et `studio-room` lui rend le jeton du propriétaire

**Fichiers / lignes**
- `lib/pages/live_room_page.dart:208-212` — `ChatLivePanel(roomId:, statut:, nomAnimateur:)` : pas de paramètre de jeton
- `lib/services/api.dart:310-340` — `chatLive()` accepte `inviteToken` mais l'appelant ne le fournit jamais
- `supabase/functions/live-auto-chat/index.ts:117-122` — sans jeton, l'accès est refusé si la session n'est pas `PRET`/`EN_DIRECT`
- `supabase/functions/studio-room/index.ts:52-61` — `sessionComplete` renvoie `invite_token` au co-animateur invité

**Scénario** : l'animateur prépare son live (`BROUILLON`), envoie le lien d'invitation. Le co-animateur ouvre la salle : `sessionPublique` réussit (le jeton est valide), mais son premier message renvoie **403 « Cette salle live n'est pas ouverte »**.

**Impact** : régression fonctionnelle sur le scénario « co-animateur » vendu dans l'offre. Effet secondaire : le jeton du propriétaire est transmis au co-animateur (`sessionComplete`) alors qu'il n'en a pas besoin — il peut le rediffuser indéfiniment.

**Correctif** : passer `inviteToken` de `LiveRoomPage` à `ChatLivePanel` puis à `chatLive()` ; et dans `studio-room`, ne pas inclure `invite_token` dans la réponse au co-animateur (il connaît déjà le sien) — le réserver au propriétaire.

---

#### M-11 — Aucun timeout sur les appels `functions.invoke` : spinner infini possible

**Fichiers / lignes** : `lib/services/api.dart` — 21 occurrences de `_client.functions.invoke(...)` sans `.timeout(...)` ; côté serveur, seuls les appels HTTP sortants ont un `AbortSignal.timeout(30_000)` (`_shared/paddle.ts:69`, `_shared/saspay.ts:37`).

**Scénario** : réseau mobile lent, fonction froide ou DeepSeek qui traîne → `creerCheckoutKit` ne rend jamais la main ; `boutique_page.dart:123-139` garde `_chargement = true` (bouton CTA définitif) et `paiement_en_attente_page` tourne sur un `_verification` bloqué (`:61`).

**Impact** : tunnel d'achat bloqué sans message ni recours, alors que le paiement a pu être créé côté serveur.

**Correctif** : envelopper chaque `invoke` dans `.timeout(const Duration(seconds: 25))` avec un message dédié, et toujours réarmer `_chargement` dans un `finally`.

---

#### M-12 — La suite de tests ne couvre aucun des chemins critiques (paiement, routes, admin, Studio)

**Fichiers / lignes** : `test/pricing_test.dart` (12 tests : pays, tarifs, arrondis, formatage), `test/models_test.dart` (8 tests : parsing), `test/widget_test.dart` (4 tests : logo, Guide, Accueil, étape 1 de La Boutique). **Aucun** test de : `verify-payment`, résolution de routes (`/live/:room`, `?commande=`, `?abonnement=`), masquage admin, `ChatLivePanel`, `PaiementEnAttentePage`, parité front↔back verrouillée en CI.

**Scénario** : les régressions C-1/C-2, M-2, M-3, M-5 sont **toutes** dans des zones non testées. `flutter test` peut rester vert avec ces défauts.

**Impact** : le « 24 tests verts » ne prouve aucune des 6 exigences côté tunnel de paiement ; la confiance affichée est surévaluée.

**Correctif** : ajouter au minimum — (a) test de non-rejeu `verify-payment` (C-1) côté Deno, (b) `routes_test.dart` sur `_genererRoute` (nom + query), (c) test widget « entrée Administration absente quand `estAdmin()` renvoie faux » (mock de `ApiService`), (d) `parite_backend_test.dart` comparant `countries.dart` à `_shared/countries.ts` (le script du § 1.2 peut être porté tel quel).

---

### 3.4 🔵 FAIBLE

| # | Constat | Fichier:ligne | Impact / correctif |
| --- | --- | --- | --- |
| **F-1** | Assainissement HTML par expressions régulières : contournable (`&#106;avascript:`, `<svg onload>` partiel, `<style>@import`, `data:text/html`), appliqué **avant** stockage. | `supabase/functions/_shared/studio.ts:583-590` | Risque réel **limité** : `HtmlWidget` reconstruit des widgets Flutter (les `<script>` ne s'exécutent pas) et `onTapUrl: (_) async => true` neutralise les liens (`studio_regie_page.dart:1720-1724`) ; le téléchargement produit un fichier local (`telechargement_web.dart:19` : attribut `download`). À durcir tout de même (liste blanche de balises) car le HTML vient d'un LLM alimenté par une fiche produit **contrôlée par le client** (`live-auto-chat`/`studio.ts:285`). |
| **F-2** | `catch (_) {}` généralisé : **29 occurrences** dans `lib/`. Exemple critique : `changerStatutSession` avale toute erreur (`api.dart:262-270`) → le statut `EN_DIRECT` peut ne pas être enregistré alors que l'UI affiche « en direct ». | `lib/services/api.dart:262-270`, `:203`, `:218`, `:305`… | Diagnostic impossible en production ; incohérence silencieuse entre UI et base. Journaliser au minimum (`debugPrint`/Sentry) et remonter un état d'erreur sur les actions critiques. |
| **F-3** | Accessibilité : `K.faint = #64748B` sur `K.bg = #090D16` = **4,08:1** (calcul WCAG), en dessous du seuil AA 4,5:1, et utilisé jusqu'à **8,5 px** ; cibles tactiles sous 44 px ; aucune `Semantics` sur les boutons icône critiques. | `lib/core/theme.dart:30` ; `live_room_page.dart:465-492` (`_BoutonInvite` ≈ 31 px de haut) ; `site_assistant_chat.dart:265-271` (40 px) ; `guide_page.dart:661/694/715/759` (8,5 px) | Lisibilité dégradée sur mobile et daltoniens ; audit Lighthouse a11y probablement < 90 (PLAN P3.5). Éclaircir `K.faint` vers `#7C8CA3` (≈ 5,1:1) et plancher typographique à 11 px. |
| **F-4** | Code mort / textes obsolètes : `Pays`, `paysAfricains`, `kitsMetiers`, `kitParCode`, `Offre.prixAffiche` ne sont **plus référencés** hors `config.dart` ; en-tête « 100 % FCFA » ; message WhatsApp « Bonjour Kit Business ». | `lib/core/config.dart:4`, `:32`, `:94`, `:167`, `:222-260` | Confusion de maintenance (deux référentiels pays, exactement le risque D3/R8 du PLAN) ; message WhatsApp hors marque. Supprimer les symboles legacy et corriger les libellés. |
| **F-5** | Texte incohérent : la confirmation parle de **SasPay** même pour une commande Paddle. | `lib/pages/confirmation_page.dart:148` | Utiliser `checkout.fournisseur.libelle` / `resultat.provider`. |
| **F-6** | Duplication des chemins de lecture du chat : action `messages` de l'Edge Function (**60** messages, service_role) **jamais appelée** par le front, qui lit en direct via la RLS (**80** messages). | `live-auto-chat/index.ts:129-140` ; `lib/services/api.dart:342-356` ; `studio_regie_page.dart:1216-1235` | Deux comportements divergents, deux surfaces d'attaque. Supprimer l'action `messages` ou l'utiliser (et aligner la limite). |
| **F-7** | `montant_indicatif` calculé depuis le prix de référence XOF, **jamais** depuis le montant réellement facturé par Paddle. | `create-paddle-checkout/index.ts:227-230` | Si Paddle facture un autre montant (cf. E-2), la conversion « ≈ en local » affichée reste fausse. Recalculer depuis `montantFacture`. |
| **F-8** | `conversation_id` de l'assistant prédictible (`web-<microsecondes en base 36>`) et utilisé comme clé d'historique côté serveur, sans limite de débit. | `lib/core/app_state.dart:81-82` ; `site-assistant/index.ts:36-58` | Un tiers peut deviner un identifiant et **injecter du contexte** dans la conversation d'un autre visiteur, et spammer la fonction (coût DeepSeek + croissance de `site_assistant_messages`). Utiliser `crypto.randomUUID()` et une limite par IP. |
| **F-9** | Pas d'en-têtes de sécurité HTTP sur le site : ni CSP, ni `X-Frame-Options`, ni `Permissions-Policy`. | `netlify.toml:19-29` | Clickjacking possible sur les pages de paiement, aucun garde-fou si un script tiers est compromis (Jitsi, Paddle). Ajouter au minimum `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy: no-referrer` sur `/live/*` (le jeton d'invitation est dans l'URL) et une CSP autorisant `*.supabase.co`, `meet.jit.si`, `cdn.paddle.com`. |
| **F-10** | `checkout_url` nul **et** `PADDLE_CLIENT_TOKEN` absent ⇒ aucun moyen de payer, et l'interface pousse quand même la page d'attente. | `create-paddle-checkout/index.ts:253-256` (simple `console.error`) ; `checkout_ouverture.dart:30-34` (dialogue « Paiement indisponible ») ; `boutique_page.dart:141-154` et `studio_live_page.dart:1021-1033` (la valeur de retour de `lancerCheckout` est **ignorée**, `Navigator.push` exécuté inconditionnellement) | Le client voit « Paiement indisponible » puis une page « En attente de votre paiement » pendant 4 minutes, pour une commande qui ne pourra jamais être payée. Correctif : si `lancerCheckout` renvoie `false`, **ne pas** pousser la page d'attente (rester sur la boutique avec un message + WhatsApp), et faire échouer `create-paddle-checkout` en 503 si ni URL ni client token ne sont disponibles. |

---

## 4. Points conformes — à ne surtout pas casser

Ces points ont été vérifiés et sont **corrects** ; ils constituent la valeur du travail déjà abattu.

| Invariant | Preuve |
| --- | --- |
| **Aucun montant client n'est accepté** : le corps du checkout ne contient jamais de prix | `lib/services/api.dart:66-88` (`_corpsCheckout` : `kind, metier_*, nom_projet, pays_code, whatsapp, email, produit_type, precisions`) ; recalcul serveur `saspay-checkout/index.ts:110`, `create-paddle-checkout/index.ts:116` |
| **Parité pays / devises / taux front↔back** | script exécuté : 215/215 pays, 23/23 SasPay, 152/152 devises, **0 divergence** (§ 1.2) |
| **Arrondis identiques** front/back (seuils 10 000 / 1 000) | `pricing.dart:194-201` ↔ `_shared/pricing.ts:89-98` |
| **Studio Live = 10 USD / 30 jours**, source de vérité serveur | `_shared/pricing.ts:38-44`, `pricing.dart:121-125`, `studio.ts:950` |
| **Signature Paddle** : HMAC-SHA256 sur `${ts}:${body}`, fenêtre 300 s, comparaison à temps constant, secret absent ⇒ refus | `_shared/paddle.ts:271-304`, `paddle-webhook/index.ts:54-59` |
| **Signature SasPay** : HMAC sur `${timestamp}.${body}`, fenêtre 300 s | `_shared/saspay.ts:229-258` |
| **Idempotence** : verrou atomique de livraison kit (`EN_ATTENTE/ECHEC → PAYE`, puis `PAYE/ERREUR → EN_COURS`), activation Studio, génération de guide | `fulfillment.ts:128-146`, `studio.ts:804-825`, `studio.ts:952-974` |
| **RLS Studio** : aucune écriture client, `security definer` + `search_path`, chat public uniquement si `PRET`/`EN_DIRECT` | `migration:295-356`, `:222-290` |
| **`studio-room` ne divulgue jamais `invite_token` au public** (session minimale) et renvoie 404 générique | `studio-room/index.ts:35-49`, `:110-121` |
| **`generate-live-guide`** : JWT obligatoire + contrôle d'appartenance (`user_id` ou email) | `generate-live-guide/index.ts:26-42` + `studio.ts:173-181` |
| **Aucun secret commité** : seule la clé `sb_publishable_…` (publique par nature) est dans `config.dart` | `lib/core/config.dart:11-12` ; `supabase/.env` absent de `git ls-files` |
| **Pas de `target=_blank` sans `noopener`, pas d'`innerHTML`, pas de HTML brut** | `grep -rn "target=\|noopener\|innerHTML" web lib` → **0 résultat** ; tous les liens externes passent par `url_launcher` en `LaunchMode.externalApplication` (`lib/core/links.dart:5-13`) ; le guide est rendu par widgets Flutter (`HtmlWidget`), pas injecté dans le DOM |
| **15 Edge Functions déclarées** dans `config.toml` | `supabase/config.toml` (15 blocs `[functions.*]`) |
| **Migration idempotente** : `add column if not exists`, `create table if not exists`, `drop policy if exists`, bloc `do $$ … exception duplicate_object` | `migration:21-25`, `:47`, `:301-343`, `:361-367` |
| **Fallback Paddle.js** : URL hébergée → Paddle.js → dialogue de lien manuel | `checkout_ouverture.dart:10-34`, `paddle_checkout_web.dart:9-45`, `web/index.html:463-478` |

---

## 5. Checklist des 6 exigences client

Légende : ✅ conforme et prouvé · ⚠️ en place mais partiel / non prouvé · ❌ écart ouvert.

### Exigence 1 — Identité visuelle premium, logo, splash, navigation

| Case | Statut | Preuve |
| --- | --- | --- |
| Fond `#090D16`, surfaces `#111827`, bordures `#1E293B` | ✅ | `theme.dart:17-24` |
| Dégradé de marque or → émeraude | ✅ | `theme.dart:66-80` (`K.marque`, `K.or`, `K.emeraude`) |
| Logo vectoriel + splash web + splash Flutter | ✅ | `logo_ebooklive.dart` (`_PeintreLogo`), `web/index.html:335-422`, `splash_page.dart` + `main.dart:121-130` |
| Navigation : logo, 3 accès, Aide WhatsApp, menu Compte | ✅ | `app_header.dart:117-177` |
| `/admin-videos` invisible pour un non-admin | ⚠️ | Masqué par `_admin` (`app_header.dart:237`, `:402`) et route gardée (`admin_guard_page.dart:33-50`) — **mais** un admin `ADMIN_EMAILS` seul est traité comme non-admin (M-6) |
| Accessibilité AA (contraste, cibles, focus) | ❌ | `K.faint` 4,08:1, textes 8,5 px, cibles tactiles < 44 px (F-3) |
| Icônes PWA + `og:image` à la marque | ❌ | `og:image` toujours en SVG (`web/index.html:25`) ; PNG 192/512 toujours déclarés (`manifest.json:20-40`) sans preuve de régénération (D9/D10 du PLAN) |

### Exigence 2 — Pays du monde, drapeaux, conversion, SasPay/Paddle

| Case | Statut | Preuve |
| --- | --- | --- |
| 215 pays, drapeaux, recherche instantanée (nom/code/devise/indicatif, sans accents) | ✅ | `countries.dart:779-818` ; script § 1.2 |
| 23 pays SasPay exactement, en devise locale | ✅ | `countries.dart:772-776` ↔ `_shared/countries.ts:311-315`, **0 divergence** |
| Reste du monde via Paddle (EUR Europe+Maghreb, USD sinon) | ✅ | `countries.dart:308-312`, `_shared/countries.ts:609-612` |
| Conversion dynamique affichée (kit + Studio), persistance du pays | ✅ | `pricing.dart:128-191`, `app_state.dart:19-48`, `country_picker.dart:165-167` |
| Prix serveur seul juge | ✅ | § 4 (aucun montant dans le corps) |
| Devise affichée = devise facturée | ❌ | **E-2** : repli silencieux sur le price USD, montant Paddle non confronté au prix affiché |
| Deep links publics + refresh (SPA fallback) | ⚠️ | `netlify.toml:14-17` ✅ ; mais URL non synchronisée en navigation interne (**M-4**) et routes fantômes (**M-3**) |

### Exigence 3 — La Boutique : 8 secteurs + « Autre métier », 2 étapes, 4 kits, paiement

| Case | Statut | Preuve |
| --- | --- | --- |
| 8 secteurs + « Autre métier » (≥ 3 caractères, validé serveur) | ✅ | `pricing.dart:35-101`, `boutique_page.dart:82-86`, `saspay-checkout/index.ts:82-85` |
| Parcours en 2 étapes (garde de validation) | ✅ | `boutique_page.dart:41`, `:89`, test `widget_test.dart:54-78` |
| 4 kits aux tarifs FCFA inchangés (3 000 / 3 500 / 5 000 / 9 000) | ✅ | `config.dart:97-139` ↔ `_shared/pricing.ts:30-35` |
| Récapitulatif + prix local / indicatif | ✅ | `boutique_page.dart:669`, `pricing.dart:148-168` |
| Routage SasPay/Paddle + montant serveur | ✅ | `api.dart:60-64`, `saspay-checkout/index.ts:110`, `create-paddle-checkout/index.ts:116` |
| Paiement Paddle réellement opérationnel | ⚠️ | code complet, **price IDs absents du dépôt** ; devise non garantie (E-2) ; `ECHEC` studio mal écrit (M-1) |
| Livraison après paiement (email + liens) | ⚠️ | `fulfillment.ts` idempotent ✅ ; reprise en cas d'échec de tâche de fond absente (M-9) |
| Montant affiché dans la bonne devise en confirmation | ✅ *(corrigé pendant la revue)* | `confirmation_page.dart:252-257` + `models.dart:160-161/216-220` ; `dashboard_page.dart:510` |

### Exigence 4 — Studio Live : 10 USD, régie 3 onglets, Jitsi + chat IA, invitation

| Case | Statut | Preuve |
| --- | --- | --- |
| Abonnement 10 USD / 30 jours, converti | ✅ | `pricing.dart:121-145`, `_shared/pricing.ts:38-44`, `studio_live_page.dart:1100` |
| Régie 3 onglets (Préparer / Salle / Guide) | ✅ | `studio_regie_page.dart:280`, `:345`, `:513-548` |
| Accès régie réservé à un abonné actif | ✅ (RLS) / ⚠️ (client) | `migration:222-243`, `:332-336` ; `studio_regie_page.dart:316-318` (`_Porte`) |
| Salle Jitsi intégrée + repli si CDN absent | ✅ | `jitsi_view_web.dart:99-183` (retry 6 s + `_iframeDeSecours`) |
| **Salle protégée par le jeton d'invitation** | ❌ | **E-1** : nom de salle public (`ebooklive-<roomId>`), caméra/micro pour tout visiteur |
| Chat IA temps réel + réponse persistée | ✅ | `studio_regie_page.dart:1213-1253` (stream + polling 6 s), `live-auto-chat/index.ts:159-239` |
| Anti-abus du chat IA | ❌ | **M-7** : limite par isolate + IP falsifiable, budget IA non plafonné |
| Livre Guide généré, idempotent, envoyé par email | ✅ | `studio.ts:791-909` (verrou `EN_COURS`), `generate-live-guide/index.ts` |
| **Livre Guide non accessible sans autorisation** | ❌ | **C-2** : `verify-payment` sert le guide à un anonyme |
| Co-animateur : lien `?invite=`, refus si jeton invalide | ⚠️ | `studio-room/index.ts:92-121` ✅ (comparaison à temps constant) ; chat en `BROUILLON` en 403 (**M-10**) |
| Expiration à 30 jours | ⚠️ | `expires_at` + `estActif`, mais `expirer_abonnements_studio()` **n'est planifiée nulle part** (`migration:370-390`, « à planifier via pg_cron ») |

### Exigence 5 — Assistant IA flottant + pleine page, « Retour au site », Guide 3 étapes

| Case | Statut | Preuve |
| --- | --- | --- |
| Bulle flottante sur les pages publiques | ✅ | `SiteAssistantChat` monté sur `home_page.dart:103`, `boutique_page.dart`, `studio_live_page.dart:105` |
| « Ouvrir en pleine interface » → `/assistant` | ✅ | `site_assistant_chat.dart:69-72` |
| « Retour au site » conserve l'état de la page précédente | ✅ | `assistant_page.dart:58-64` (`Navigator.pop`), conversation partagée `app_state.dart:65-105` |
| Contexte assistant à jour (2 univers, 8 secteurs, tarifs, 23 pays, routes) | ✅ | `_shared/assistant.ts:65-110` |
| Guide & Tutoriel en 3 étapes navigables | ✅ | `guide_page.dart:20-62` + test `widget_test.dart:23-36` |
| Sécurité/abus de l'assistant | ⚠️ | `conversation_id` prédictible, aucune limite de débit (**F-8**) |

### Exigence 6 — Migration SQL, `config.toml`, `analyze` / `test` / `build` 0 erreur

| Case | Statut | Preuve |
| --- | --- | --- |
| Migration complète (5 tables/colonnes, 3 fonctions, 4 policies, index, realtime) | ✅ (fichier) / ⚠️ (application) | `20260101000500_paddle_et_studio_live.sql` (390 lignes) — **jamais appliquée sur un projet** |
| Migration idempotente | ✅ (lecture) | constructions `if not exists` / `drop … if exists` / `do $$ … exception` |
| `config.toml` à jour, 15 fonctions | ✅ | `supabase/config.toml` |
| Aucun import TS local non résolu | ✅ | revue des 30 fichiers `functions/**` |
| `flutter analyze` → 0 issue | ⚠️ | annoncé par le lead, **non reproduit ici**, et **antérieur** aux écritures de 22:16-22:21 (§ 1.4) |
| `flutter test` → 24 tests verts | ⚠️ | annoncé par le lead ; couverture : prix/pays/modèles + 4 widgets, **aucun** test paiement/routes/admin/studio (**M-12**) |
| `flutter build web --release` | ⚠️ | en cours au moment de la revue, **non vérifié** |
| URL path (pas hash) + fallback SPA | ✅ | `url_strategy_web.dart:5`, `netlify.toml:14-17` |
| Aucun secret commité | ✅ | seule la clé publishable ; `supabase/.env` hors Git |
| Sécurité des paiements (non-rejeu, autorisation) | ❌ | **C-1**, **C-2** |

---

## 6. Top 5 des actions avant mise en production

| # | Action | Fichiers | Critère de sortie (preuve) |
| --- | --- | --- | --- |
| **1** | **Fermer C-1 et C-2** : rattacher le `payment_id` SasPay à la commande (via `statutSession`/métadonnées), ajouter les 2 index uniques, et ne renvoyer `abonnement` complet + `guide` qu'à un JWT propriétaire | `supabase/functions/verify-payment/index.ts`, `_shared/saspay.ts`, `supabase/migrations/20260101000600_*.sql` | Test Deno : (a) 2 commandes EN_ATTENTE + 1 paiement → 2ᵉ refusée en 4xx ; (b) `curl` anonyme avec `subscription_id` → `guide: null` |
| **2** | **Sécuriser la salle de live** : nom de salle Jitsi secret (colonne `jitsi_room`, HMAC serveur) révélé uniquement à l'animateur/co-animateur ; spectateurs sans caméra (JaaS `viewer`) ou sans Jitsi | `_shared/studio.ts`, `studio-room/index.ts`, `jitsi_view_web.dart`, `live_room_page.dart`, `studio_regie_page.dart` | Ouvrir le lien spectateur en navigation privée : l'onglet ne rejoint pas `meet.jit.si/ebooklive-<roomId>` ; `curl studio-room` sans jeton → pas de champ de salle |
| **3** | **Aligner devise affichée / devise facturée** et échouer explicitement si le price EUR manque | `_shared/paddle.ts:188-224`, `create-paddle-checkout/index.ts:116-231` | Test Paddle sandbox FR (EUR) et MA (EUR) : `devise` renvoyée = devise affichée ; sans `_EUR`, erreur 503 claire au lieu d'un repli USD |
| **4** | **Réparer la navigation** : lire `?commande=`/`?code=` une seule fois, `onGenerateInitialRoutes`, synchronisation d'URL, et corriger `create-paddle-checkout` (colonne `status`) | `lib/main.dart:112-113`, `:254-291` ; `app_header.dart:77-89` ; `create-paddle-checkout/index.ts:205-209` | `/?commande=x` → clic logo → accueil ; `/studio/regie` en direct → une seule route ; `?abonnement=y` sur échec Paddle → `status = 'ECHEC'` en base |
| **5** | **Fiabiliser et prouver** : `setState` après `dispose` (M-5), timeouts sur `invoke` (M-11), reprise des commandes `PAYE` bloquées (M-9), et **tests de non-régression** paiement/routes/admin ; rejouer `flutter analyze`, `flutter test`, `flutter build web` sur l'arbre final | `paiement_en_attente_page.dart:47-75`, `api.dart` (21 `invoke`), `test/` | `flutter test` ≥ 40 tests dont 1 test de rejeu, 1 test de route, 1 test « admin masqué » ; logs des 3 commandes Flutter joints au dossier |

> **Ordre recommandé** : 1 et 2 sont bloquants (sécurité/revenu) ; 3 et 4 sont nécessaires à la crédibilité commerciale ; 5 peut se faire en parallèle mais doit être clos avant l'ouverture publique du Studio Live.

---

## 7. Annexes

### 7.1 Commandes de vérification utilisées (reproductibles)

```powershell
# Parité pays / devises / taux front <-> back (script ad hoc, lecture seule)
# -> devises 152/152, pays 215/215, SasPay 23/23, divergences 0

# Absence de synchronisation d'URL
grep -rn "routeInformationUpdated|SystemNavigator|go_router" lib   # 0 résultat

# Absence d'index unique sur le payment id SasPay
grep -rn "saspay_payment_id" supabase/migrations                    # colonnes seules

# Scripts tiers chargés globalement (doit être vide depuis le correctif D7)
grep -n "external_api|paddle.js" web/index.html                     # 0 résultat
```

### 7.2 Ordre de lecture conseillé pour le correcteur

1. `supabase/functions/verify-payment/index.ts` (C-1, C-2) — 449 lignes, cœur du risque.
2. `supabase/functions/_shared/paddle.ts:188-304` + `create-paddle-checkout/index.ts:116-231` (E-2, M-1).
3. `lib/services/jitsi_view_web.dart:73-166` + `live_room_page.dart:190-239` (E-1).
4. `lib/main.dart:254-379` (M-2, M-3, M-4).
5. `lib/pages/paiement_en_attente_page.dart:47-146` (M-5, M-11).

### 7.3 Ce que cette revue **ne dit pas**

- Elle ne dit pas que l'application « fonctionne » : aucun parcours n'a été exécuté (ni paiement, ni Jitsi, ni génération de guide).
- Elle ne dit pas que le build web est bon : il était en cours.
- Elle ne couvre pas `admin_videos_page.dart` (48 k), `video-agency-pipeline`, `tiktok-auth`, `view-kit`, `welcome-email`, ni le legacy TikTok au-delà de la navigation, qui sont hors du périmètre confié.
- Les constats datés peuvent être invalidés par les modifications en cours : **relire le hash des fichiers du § 1.4** avant d'ouvrir un ticket.

---

## 8. Contre-revue des correctifs — 23/11/2026, 00:05 (Africa/Casablanca)

> Contre-revue **ciblée, en lecture seule** : uniquement C-1/C-2, les régressions de paiement et les bloquants restants.
> Fichiers relus : `verify-payment/index.ts` (613 l., réécrit), `create-paddle-checkout/index.ts`, `_shared/paddle.ts`, `_shared/studio.ts`, `supabase/config.toml`, `20260101000500_paddle_et_studio_live.sql`, `lib/main.dart`, `lib/services/api.dart`, `lib/pages/boutique_page.dart`, `lib/pages/studio_live_page.dart`, `supabase/functions/admin-check/index.ts`, `netlify.toml`.

### 8.1 Verdict final : **À CORRIGER** — sécurité des paiements fermée, 1 bloquant de déploiement

**Les deux vulnérabilités critiques sont réellement fermées** (pas seulement contournées). Il reste **un bloquant de déploiement** (fichier de configuration invalide) et **deux régressions de paiement à prouver en sandbox** avant d'ouvrir la vente.

### 8.2 C-1 / C-2 : ce qui a été vérifié

| Point | Statut | Preuve |
| --- | --- | --- |
| **C-1** — le paiement n'est plus dérivé du client | ✅ fermé | `verify-payment/index.ts:503-528` : `paymentId` vient de `commande.saspay_payment_id` ou de `statutSession(commande.saspay_session_id)` ; tout `payment_id` client **différent** → 409 (`:523-525`) et client fourni alors que la ligne n'en a pas → 409 (`:526-528`). Même logique Studio `:262-287`. L'ancien lookup `orders.eq('saspay_payment_id', <client>)` a **disparu** (`:402-412` : plus que `order_id` / `session_id`). |
| **C-1** — anti-rejeu en base | ✅ | index uniques ajoutés dans la migration : `orders_saspay_payment_id_key` (`...0500:33-35`) et `studio_subscriptions_saspay_payment_key` (`...0500:96-98`) ; l'erreur d'unicité est **exploitée** → 409 (`:574-576`, `:319-327`). |
| **C-1** — contrôle du montant **et** de la devise | ✅ | `controlerMontant()` (`:69-86`) : devise comparée, montant obligatoire, tolérance 0,02 (devises décimales) / 1 (entières), appliqué aux 4 chemins (`:311`, `:371`, `:447`, `:554`). |
| **C-1** — rejeu résiduel | ✅ aucun trouvé | Un ordre neuf a sa **propre** session SasPay : `paymentId` reste `null` → `paye=false` (`:539`) ou 409 (`:526-528`). Impossible de rattacher le paiement d'un autre ordre. |
| **C-2** — guide réservé au propriétaire | ✅ fermé | `proprietaireStudio()` (`:88-97`, JWT requis) ; `reponseStudio()` (`:143-177`) : non-propriétaire → `guide: null` + `abonnementPublic()` (`:100-112`, **sans** email ni nom d'activité). |
| **C-2** — réponses kit expurgées | ✅ | `commandePublique()` (`:114-132`) remplace la ligne `orders` complète ; plus d'email, de WhatsApp, de `saspay_*` ni de `paddle_*` dans la réponse (l'ancien `...resultat` de `:138` est corrigé). |
| Fuite du guide par un autre chemin | ✅ aucune | `generate-live-guide` (JWT), RLS `studio_guides`, `monGuide` client : inchangés et corrects. |

### 8.3 Correctifs confirmés (échantillon)

`create-paddle-checkout/index.ts:210`, `:228`, `:279` → `status` pour le Studio (M-1 ✅) · `:222-241` devise Paddle incohérente → 409 + `ECHEC` (E-2 ✅) · `:243-249` indicatif recalculé depuis le montant facturé (F-7 ✅) · `:273-286` 503 si ni URL ni client token (F-10 ✅) · `_shared/paddle.ts:195-230` plus de repli USD silencieux (E-2 ✅) · `_shared/studio.ts:961` un `ECHEC` peut être réactivé par un succès ✅ · `lib/main.dart:119-122` `onGenerateInitialRoutes` (M-3 ✅), `:292-305` `?commande=`/TikTok consommés une fois (M-2 ✅), `:398-405` observer d'URL (M-4 ✅) · `admin-check/index.ts` + `api.dart:475-495` ADMIN_EMAILS (M-6 ✅) · `boutique_page.dart:141-149` / `studio_live_page.dart:1021-1028` plus de page d'attente si le checkout n'ouvre pas (F-10 ✅).

### 8.4 Nouveaux constats (bloquants et régressions)

#### CC-1 — 🔴 BLOQUANT DÉPLOIEMENT : `supabase/config.toml` contient 5 tables TOML dupliquées (fichier invalide)

`supabase/config.toml` déclare **deux fois** les mêmes tables : `[functions.create-paddle-checkout]` (`:34` et `:89`), `[functions.paddle-webhook]` (`:39` et `:94`), `[functions.generate-live-guide]` (`:44` et `:99`), `[functions.live-auto-chat]` (`:49` et `:104`), `[functions.studio-room]` (`:54` et `:109`).

En TOML, redéclarer une table est une **erreur de parse** (« Cannot declare [x] twice »). Conséquence : `supabase functions deploy`, `supabase config push` (et `supabase start` en local) **échouent avant tout déploiement** — aucune des 16 fonctions ne part, `admin-check` compris.
**Correctif** : supprimer le second bloc dupliqué (lignes 89-112), garder `[functions.admin-check]` en fin de fichier. Vérifier ensuite avec `npx supabase@latest functions list` ou `python -c "import tomllib;tomllib.load(open('supabase/config.toml','rb'))"`.

#### CC-2 — 🟠 RÉGRESSION PAIEMENT : le contrôle montant/devise est *fail-closed* — des commandes réellement payées peuvent être refusées en 402

`controlerMontant()` (`verify-payment/index.ts:69-86`) renvoie désormais une erreur **si `montant === null`** (`:78-80`) et si la devise reçue diffère **en égalité stricte** (`:75-77`, sans `trim()`). Auparavant, un montant `null` était **toléré** (livraison effectuée).

Deux chemins sont exposés :
1. **SasPay « session status »** (aucun `payment_id` disponible) : `montantVerifie = session.montant` (`:512`) issu de `_shared/saspay.ts:149` (`data.amount ?? paiement.amount`) — si SasPay n'expose pas `amount` sur `/checkout-sessions/{id}/status/`, la commande passe de « livrée » à **402 « Le montant n'a pas pu être vérifié »**, alors que l'argent est encaissé.
2. **Devise** : `deviseVerifiee = session.devise` (`:513`, `saspay.ts:150` → `data.currency ?? paiement.currency`). Si SasPay renvoie `FCFA`, `XOF ` (espace) ou une casse inattendue, **toutes les commandes de la zone XOF** sont bloquées en 402.

**Impact** : client débité + kit non livré + message « contactez le support » — c'est le pire scénario de régression pour un tunnel de paiement.
**Correctif / vérification obligatoire** : sur sandbox SasPay, capturer une réponse réelle `SUCCESS` (session XOF et NGN) et vérifier la présence + le format de `amount` et `currency`. Si l'un des deux peut manquer : tolérer `null` en **journalisant** (`console.warn` + `delivery_error`) plutôt qu'en bloquant, ou s'appuyer sur le montant de la commande serveur (`montant_local`) déjà vérifié à la création. Ajouter `.trim().toUpperCase()` sur `deviseRecue` et `devise`.

#### CC-3 — 🟠 RÉGRESSION (risque opérationnel) : les 5 price IDs `_EUR` deviennent obligatoires — le pays par défaut est en EUR

`_shared/paddle.ts:216-229` lève désormais une erreur si `PADDLE_PRICE_KIT_*_EUR` / `PADDLE_PRICE_STUDIO_EUR` manque, et `create-paddle-checkout` l'appelle **avant** toute création de ligne → **500** pour tout pays Paddle facturé en EUR (`:116-119`). Or `countries.dart` définit le **Maroc comme pays par défaut** (`paysParDefaut = _maroc`) et le Maghreb + toute l'Europe sont en EUR.
**Impact** : si le déploiement ne pose pas les 5 variantes EUR, l'expérience par défaut (Maroc) et toute l'Europe renvoient « Paiement international indisponible ». Le correctif est bon sur le fond (plus de débit dans une devise non affichée) mais **durcit un pré-requis de déploiement** qui n'était pas bloquant avant.
**Correctif / vérification** : ajouter les 5 `_EUR` aux secrets **et** un test de fumée `curl create-paddle-checkout {pays_code:"MA"}` → 200 attendu ; sinon afficher côté front un message « paiement indisponible pour ce pays » plutôt qu'une 500 brute.

#### CC-4 — 🟡 RÉGRESSION MINEURE : l'observer d'URL supprime la query string (le `?invite=` disparaît du lien co-animateur)

`lib/main.dart:398-405` réécrit l'URL avec `Uri.parse(nom)` où `nom` est le **nom de route** (`/live/<room>`), sans query. Conséquence : en entrant dans `/live/<room>?invite=<token>`, l'URL devient `/live/<room>` — bon pour la confidentialité, mais un **rafraîchissement (F5) après l'entrée en salle perd le jeton** et le co-animateur retombe sur « salle non accessible ». Même effet pour `?commande=` (souhaitable) et `?abonnement=` (`studio_live_page.dart:34` lit `Uri.base` : un refresh après paiement perd l'écran d'activation).
**Correctif** : conserver la query pour les routes qui en dépendent (`/live/*` : réinjecter `invite` ; `/studio-live?abonnement=` : soit réinjecter, soit faire lire l'id au constructeur plutôt que dans `Uri.base`).

#### CC-5 — 🟡 RISQUE NON VÉRIFIÉ : la CSP n'a jamais été exécutée (écran blanc possible)

`netlify.toml:24-31` ajoute une CSP stricte : `script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' https://cdn.paddle.com https://meet.jit.si`, `connect-src 'self' https://*.supabase.co wss://*.supabase.co https://api.paddle.com https://sandbox-api.paddle.com https://meet.jit.si wss://meet.jit.si`, `frame-src` Jitsi/Paddle, `worker-src blob:`.
Rien ne l'a testée (pas de navigateur en revue, build en cours). Un oubli d'origine — typiquement `https://www.gstatic.com` si CanvasKit n'est pas servi localement, ou un appel de Paddle.js vers un domaine non listé — produit un **écran blanc en production**, sans erreur serveur.
**Vérification obligatoire** : déployer sur une **preprod** (URL de preview Netlify), ouvrir les 6 pages + un paiement Paddle sandbox + une salle Jitsi avec la console ouverte ; contrôler 0 violation CSP. À défaut de preprod, ne pas poser la CSP sur `/*` : la limiter d'abord à `Report-Only` (`Content-Security-Policy-Report-Only`).

### 8.5 Ce qui reste ouvert (non revu dans cette contre-revue)

- **E-1** (salle Jitsi = `ebooklive-<roomId>` public) : **non corrigé** — la caméra/micro reste accessible à tout porteur du lien spectateur. Toujours bloquant pour l'ouverture publique du Studio Live.
- **M-7** (anti-abus `live-auto-chat`), **M-8** (avis non modérés), **M-9** (202 avant livraison, pas de reprise), **M-11** (pas de timeout `invoke`), **M-12** (tests) : inchangés.
- **M-5** (`setState` après `dispose` dans `paiement_en_attente_page.dart:51/71`) : à revérifier si le fichier a été retouché (non listé dans les correctifs).

### 8.6 Verdict

> **C-1 et C-2 sont fermés** — la dérivation serveur du paiement, les index uniques, le contrôle montant+devise et l'expurgation des réponses sont correctement implémentés (aucun chemin de rejeu ni de fuite de guide trouvé en lecture).
>
> **Mais la livraison n'est pas encore possible** : `supabase/config.toml` est **invalide** (tables dupliquées, CC-1) et deux régressions de paiement doivent être prouvées en sandbox avant d'ouvrir la vente (CC-2 SasPay *fail-closed*, CC-3 price IDs EUR obligatoires). Une fois CC-1 corrigé et CC-2/CC-3 validés, le tunnel de paiement peut être considéré comme assaini ; **E-1 reste le seul bloquant produit** pour le Studio Live.

---

*Fin de la revue — 26 findings initiaux (2 critiques, 2 élevés, 12 moyens, 10 faibles) + contre-revue du 23/11 : 2 critiques fermés, 1 bloquant de déploiement et 4 régressions/risques identifiés (CC-1 → CC-5).*

