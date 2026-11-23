# Test Paddle sandbox — audit et procédure

**Date** : 2026-11-23  
**Périmètre** : intégration Paddle Billing de e-booklive (`create-paddle-checkout`, `paddle-webhook`, `verify-payment`, Studio Live).  
**Statut** : audit statique + correctifs de configuration. **Aucun achat réel n'a été exécuté.**

---

## 0. Outils disponibles et limites

Cette session ne dispose **d'aucun MCP `paddle-sandbox` ni MCP base de données** :
les seuls outils exposés sont les outils génériques (fichiers, shell, web).

- Impossible d'ouvrir un checkout Paddle.js et de saisir une carte de test sans navigateur.
- Impossible de lire les valeurs des secrets Supabase (seulement leurs noms/digests).
- Impossible de requêter la base directement sans MCP/psql/`SUPABASE_DB_URL` en clair.

Les points ci-dessous sont donc **vérifiés statiquement** ou **à exécuter par vous**
dans le dashboard / avec les commandes fournies. Les actions marquées ❌ n'ont
pas pu être exécutées.

### Résultats réels déjà obtenus (23/11, sans MCP)

Un diagnostic temporaire déployé puis supprimé a permis de vérifier réellement :

```json
{
  "environnement": "sandbox",
  "coherence": "ok",
  "api_key_prefix": "pdl_sdbx_…",
  "client_token_prefix": "test_…",
  "webhook_secret_present": true,
  "prix_presents": {
    "prompt": true, "sheet": true, "livre": true, "pack": true, "studio": true
  },
  "paddle_api_url": "https://sandbox-api.paddle.com",
  "paddle_http_status": 200,
  "paddle_reachable": true
}
```

- ✅ Environnement **sandbox** réel, clé API `pdl_sdbx_…`, jeton client `test_…`.
- ✅ `sandbox-api.paddle.com` répond **200** avec la clé configurée.
- ✅ Destination Paddle sandbox active :
  `ntfset_01m82sj4sr0t44x334p7pb2c5s` → `https://ynephuutnazdnjhsdlsy.supabase.co/functions/v1/paddle-webhook`
  (description « Webhook Supabase-Sandbox », type `url`, active).
- ✅ Un vrai checkout Studio a été créé en sandbox :
  - `transaction_id = txn_01m84wzj1r6844ews993373nmf`
  - `subscription_id` locale = `56b02547-3a42-4479-b472-06f48a35e38c`
  - montant **10 USD**, indicatif **99,39 MAD** (USD par défaut)
  - `checkout_url = https://e-booklive.offboard-hub.com?_ptxn=txn_…`
- ✅ Après redéploiement du correctif, un second checkout a confirmé le défaut USD :
  - `transaction_id = txn_01m84z9m2bd809djmvdbmnqj3x`
  - `subscription_id = 0d2d4912-b25f-4adb-8b29-0e4804268bba`
  - `devise = USD`, `montant = 10`, `montant_indicatif = 99.39 MAD`.
- ❌ Aucun paiement carte n'a été effectué (pas de navigateur) : aucun webhook
  `transaction.completed` n'a encore été reçu, donc pas de statut `completed`,
  pas de livraison, pas de test de refus.
- ❌ Aucune subscription Paddle créée (Option A, voir §4) : le test crée une
  transaction one-time, pas un abonnement récurrent.

> Le `checkout_url` renvoyé par Paddle pointe vers **notre propre domaine** avec
> `_ptxn=…`. L'ancien `lancerCheckout` l'ouvrait comme une page externe : aucun
> paiement ne s'affichait. Correctif local appliqué : pour Paddle, on ouvre
> **Paddle.js en priorité** avec `transaction_id` + `client_token`, et on refuse
> d'ouvrir une URL Paddle sur notre propre domaine sans overlay
> (`lib/services/checkout_ouverture.dart`). Le build web a été refait ; il doit
> être déployé sur Netlify pour que ce correctif soit actif.

> ✅ **Prix localisé** : décision produit = **USD par défaut**. Le prix affiché
> est maintenant **10,00 $** (Paddle) et l'indicatif local est **≈ 99,39 MAD**,
> exactement ce que renvoie Paddle. Les price IDs EUR ne sont plus utilisés.

> 🧹 Les lignes de test ont été nettoyées côté base. Si l'une subsiste :
> ```sql
> delete from public.studio_subscriptions
>  where email in ('sandbox-e2e-20261123@example.com',
>                  'sandbox-usd-20261123@example.com');
> ```
> Les transactions Paddle sandbox `txn_01m84wzj1r6844ews993373nmf` et
> `txn_01m84z9m2bd809djmvdbmnqj3x` restent non payées.

---

## 1. Configuration sandbox — findings réels

### 1.1 Environnement : sandbox confirmé, mais le code lisait le mauvais secret

`supabase secrets list` montre le secret **`PADDLE_ENVIRONNEMENT`** (orthographe
française), et son digest SHA-256 est exactement :

```
sha256("sandbox") = b7ad567477c83756aab9a542b2be04f77dbae25115d85f22070d74d8cc4779dc
```

→ La valeur configurée est donc **`sandbox`**. ✅

**Mais** `_shared/paddle.ts` lisait `PADDLE_ENVIRONMENT` (anglais) avec un défaut
`production` : le serveur appelait donc **`api.paddle.com`** (production) avec les
secrets sandbox. C'est un bloquant majeur, corrigé localement :

- lecture de `PADDLE_ENVIRONNEMENT` puis `PADDLE_ENVIRONMENT` ;
- plus de défaut silencieux : absence de secret = erreur explicite ;
- `verifierCoherencePaddle()` refuse un checkout si :
  - sandbox + clé API qui ne commence pas par `pdl_sdbx_` ;
  - sandbox + jeton client qui ne commence pas par `test_` ;
  - production + clé/jeton live incohérents.

**À faire** : redéployer les fonctions concernées (`create-paddle-checkout`,
`verify-payment`, `paddle-webhook`) après ce correctif. Sans redéploiement, la
production continue d'utiliser l'ancien code qui appelle `api.paddle.com`.

### 1.2 Jeton client : `PADDLE_CLIENT_TOKEN` absent

`supabase secrets list` contient **`PADDLE_TOKEN_KIT`** mais **pas
`PADDLE_CLIENT_TOKEN`**. L'ancien code ne lisait que ce dernier → `client_token`
vide, donc pas de repli Paddle.js possible.

Correctif local : `clientTokenPaddle()` lit `PADDLE_CLIENT_TOKEN`, puis
`PADDLE_TOKEN_KIT`.

**À vérifier dans le dashboard Paddle sandbox** : `PADDLE_TOKEN_KIT` doit être un
jeton **`test_...`** (Developer Tools → Authentication → Client-side tokens).
Si c'est un jeton live, le nouveau garde-fou refusera le checkout.

### 1.3 Clé API et secret webhook

- `PADDLE_API_KEY` existe (valeur non lisible).
- `PADDLE_WEBHOOK_SECRET` existe.
- `PADDLE_PRICE_KIT_PROMPT`, `PADDLE_PRICE_KIT_SHEET`, `PADDLE_PRICE_KIT_LIVRE`,
  `PADDLE_PRICE_KIT_PACK`, `PADDLE_PRICE_STUDIO` existent.
- `PADDLE_PRICE_*_EUR` ne sont plus utilisés : **USD par défaut** pour tous les
  pays Paddle. Les montants locaux restent indicatifs.

### 1.4 Destination de notification

Le code ne peut pas savoir si la destination Paddle pointe vers le sandbox ou la
production : c'est configuré dans Paddle. **À vérifier** :

1. Paddle sandbox → **Developer Tools → Notifications**.
2. La destination doit être :
   `https://ynephuutnazdnjhsdlsy.supabase.co/functions/v1/paddle-webhook`
3. Elle doit être créée dans le **compte sandbox** (pas live), avec le secret
   sandbox `pdl_ntfset_...` correspondant à `PADDLE_WEBHOOK_SECRET`.
4. Événements à cocher au minimum :
   `transaction.completed`, `transaction.paid`, `transaction.payment_failed`,
   `transaction.canceled`.
   Pour le lifecycle subscription (voir §4) : `subscription.created`,
   `subscription.updated`, `subscription.canceled`.

### 1.5 Ce qui est encore ❌

- Aucun appel réel à `sandbox-api.paddle.com` n'a été fait (pas de clé lisible,
  pas de MCP).
- Aucun checkout Paddle.js n'a été ouvert.
- Aucune notification reçue.
- Aucune ligne DB vérifiée.

---

## 2. Procédure de test manuel (à exécuter après redéploiement)

### 2.1 Vérifier l'environnement effectif

Utilisez un compte sandbox et un pays **Paddle** (Maroc, France ou USA, pas un
pays SasPay). Lancez un checkout depuis `/studio-live` ou `/boutique`.

- Le serveur doit appeler `https://sandbox-api.paddle.com`.
- La réponse de `create-paddle-checkout` doit contenir `"environment":"sandbox"`.
- Si le garde-fou renvoie une erreur de cohérence, corrigez les secrets avant
  toute tentative de paiement.

Commande utile (adaptez le JWT) :

```bash
curl -sS -X POST \
  "https://ynephuutnazdnjhsdlsy.supabase.co/functions/v1/create-paddle-checkout" \
  -H "Content-Type: application/json" \
  -H "apikey: <SUPABASE_ANON_KEY>" \
  -d '{"kind":"studio","metier_code":"ecommerce","metier_label":"E-commerce & Mode","nom_projet":"Test Sandbox","pays_code":"MA","whatsapp":"600000000","email":"sandbox@example.com","produit_type":"studio"}'
```

Attendu : `success:true`, `provider:"paddle"`, `environment:"sandbox"`,
`checkout_url` ou `transaction_id` + `client_token`.

### 2.2 Paiement réussi — carte `4242 4242 4242 4242`

1. Ouvrez `checkout_url` (ou l'overlay Paddle.js) dans un navigateur.
2. Nom au choix, date d'expiration future, CVC quelconque.
3. Finalisez le paiement.
4. Vérifiez la transaction dans Paddle sandbox → **Transactions** : statut
   `completed`.
5. Vérifiez la notification : **Developer Tools → Notifications → Events** ;
   réponse HTTP **2xx**.
6. Vérifiez la base (voir §2.4).

### 2.3 Paiement refusé — carte `4000 0000 0000 0002`

1. Recommencez avec une nouvelle commande et cette carte.
2. Paddle doit refuser.
3. Vérifiez que la ligne locale passe à `ECHEC` (kit) ou `ECHEC`
   (`studio_subscriptions`) et qu'aucun accès payant n'est accordé.

### 2.4 Requêtes SQL de vérification

```sql
-- Kit
select id, statut, provider, paddle_transaction_id,
       montant_fcfa, montant_local, devise_locale, delivered_email
from public.orders
order by created_at desc limit 5;

-- Studio Live
select id, status, provider, paddle_transaction_id,
       montant_local, devise, expires_at, guide_status
from public.studio_subscriptions
order by created_at desc limit 5;

-- Journal financier
select provider, transaction_token, amount_paid, currency, status, created_at
from public.transactions
order by created_at desc limit 5;
```

Pour un **kit** réussi, on attend : `statut='LIVRE'`, `paddle_transaction_id`
non nul, `montant_local`/`devise_locale` renseignés, une ligne `transactions`.
Pour **Studio** réussi : `status='ACTIF'`, `expires_at` à ~30 jours,
`guide_status` `PRET` ou `EN_COURS`, ligne `transactions`.
Pour un refus : `statut/status='ECHEC'`, aucun accès.

### 2.5 Access helper

L'accès Studio est calculé par `AccesStudio` :
`abonnement.estActif` (status ACTIF + `expires_at > now`) OU essai actif.
Après un paiement Studio réussi, `expires_at` doit être dans ~30 jours et
`/studio/regie` doit s'ouvrir. Après un refus, aucun accès payant.

---

## 3. Vérification des webhooks

Si vous n'avez pas d'outil pour interroger les livraisons :

1. Paddle sandbox → **Developer Tools → Notifications**.
2. Ouvrez la destination `paddle-webhook`.
3. Onglet **Events** (ou **Delivery attempts**).
4. Chaque événement doit avoir un statut **2xx**.
5. En cas d'échec, copiez le **code HTTP**, le **corps de réponse** et les
   en-têtes `Paddle-Signature`/timestamp.

Causes probables :
- signature calculée avec le mauvais `PADDLE_WEBHOOK_SECRET` (sandbox vs live) ;
- fonction non redéployée après changement de secret ;
- body modifié par un proxy (la signature porte sur le corps brut) ;
- `PADDLE_ENVIRONNEMENT` absent → erreur 500 dans les fonctions Paddle.

---

## 4. Lifecycle subscription — ❌ bloqué par l'architecture actuelle

**Constat important** : l'intégration actuelle ne crée **aucune subscription
Paddle**. `create-paddle-checkout` crée une **transaction one-time** avec un
`price_id` ; le Studio Live est un accès de 30 jours géré dans
`studio_subscriptions`. Il n'y a :

- aucune colonne `paddle_subscription_id` ;
- aucun traitement de `subscription.created`, `subscription.updated`,
  `subscription.canceled` dans `paddle-webhook` ;
- aucune synchronisation de `current_billing_period`, `scheduled_change`,
  `cancel_at`, produit/prix Paddle.

Donc les opérations demandées (upgrade immédiat `do_not_bill`, annulation
programmée en fin de période, annulation immédiate) **ne s'appliquent pas** avec
l'Option A : il n'existe pas de subscription Paddle à manipuler.

### Option A — retenue par le client
- Le prix Paddle Studio reste **one-time** (accès 30 jours), **USD par défaut**.
- Le bouton affiche « 10 USD / 30 jours » et non « / mois ».
- Les tests de lifecycle subscription Paddle (§4) sont **hors périmètre** :
  aucune subscription Paddle n'est créée, aucun renouvellement automatique.
- On teste uniquement `transaction.completed` et l'activation 30 jours.

### Option B — passer à une vraie subscription Paddle récurrente
Il faut alors :
1. Créer un **prix récurrent** dans Paddle sandbox et le mettre dans
   `PADDLE_PRICE_STUDIO` (ou une variable dédiée).
2. Créer un checkout de subscription (et non une simple transaction) ;
3. Ajouter `paddle_subscription_id`, `paddle_customer_id`, `paddle_price_id`,
   `current_period_end`, `scheduled_change` à `studio_subscriptions` ;
4. Gérer `subscription.created`, `subscription.updated`,
   `subscription.canceled`, `transaction.completed` ;
5. Adapter `AccesStudio` (active/trialing, `cancel_at` programmé ≠ annulé) ;
6. Rejouer les tests §2 et §4.

Tant que le paiement carte réel et le déploiement web du correctif overlay ne sont
pas validés, **ne pas lancer le go-live**.

---

## 5. Bloquants avant mise en production

1. ✅ Correctif `PADDLE_ENVIRONNEMENT` / `PADDLE_TOKEN_KIT` / garde-fou déployé
   sur `create-paddle-checkout` et `verify-payment`.
2. ✅ Jeton `test_...` sandbox et clé `pdl_sdbx_...` confirmés ; API sandbox 200.
3. ✅ Destination sandbox `ntfset_01m82sj4sr0t44x334p7pb2c5s` active vers
   `paddle-webhook`. Le secret de signature doit encore être confirmé par un
   événement réel (aucun webhook reçu pour l'instant).
4. ❌ Exécuter un paiement carte test réussi **et** un refusé via le checkout réel
   (navigateur requis) ; vérifier `completed`/`ECHEC`, 2xx et les lignes SQL.
5. ✅ Option A retenue : pas de subscription Paddle, prix one-time 30 jours USD.
6. ❌ Déployer sur Netlify le build web contenant le correctif Paddle.js overlay.
7. Ne jamais utiliser de prix récurrent Paddle avec ce modèle : Paddle créerait
   des renouvellements non suivis par l'application.
