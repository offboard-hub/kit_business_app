# Contrat d'architecture — Refonte e-booklive (La Boutique + Studio Live)

> Document de référence partagé entre le frontend Flutter (`lib/`), les Edge Functions
> (`supabase/functions/`) et la base (`supabase/migrations/`).
> Toute implémentation doit respecter les noms de champs, les routes et les invariants ci-dessous.

## 1. Invariants produit

- **Deux univers distincts** : `La Boutique` (kits métiers, paiement unique) et
  `Studio Live` (abonnement 10 USD / 30 jours).
- **Prix de référence** : kits en XOF (FCFA) — 3 000 / 3 500 / 5 000 / 9 000.
  Studio Live : **10 USD** (source de vérité), converti dans la devise locale.
- **Essai Studio Live** : 3 jours gratuits, sans carte, un seul par utilisateur
  (email confirmé), créé côté serveur dans `studio_trials`, jamais prolongeable.
  Pendant l'essai : régie + chat IA (20 réponses/jour), **pas de Livre Guide**.
  Aucun prix d'essai chez Paddle ou SasPay ; aucun prélèvement automatique.
- **Routage paiement** :
  - 23 pays SasPay (voir §3) → montant calculé côté serveur dans la devise locale,
    `saspay-checkout`.
  - Tous les autres pays → `create-paddle-checkout` (Paddle Billing), montant
    EUR/USD + conversion indicative locale, `paddle-webhook`.
- **Aucun montant envoyé par le client n'est accepté** : tout est recalculé côté serveur.
- **`/admin-videos` invisible** pour tout non-admin : entrée du menu Compte uniquement
  si `is_admin = true` (table `profiles`) ou email dans `ADMIN_EMAILS`, route protégée.

## 2. Routes Flutter (URL strategy : path, pas hash)

| Route | Page | Accès |
| --- | --- | --- |
| `/` | HomePage | public |
| `/boutique` | BoutiquePage (2 étapes) | public |
| `/studio-live` | StudioLivePage | public |
| `/studio/regie` | StudioRegiePage (3 onglets) | abonné connecté |
| `/guide` | GuidePage | public |
| `/assistant` | AssistantPage (plein écran) | public |
| `/live/:roomId?invite=token` | LiveRoomPage | public (invité / co-animateur) |
| `/mon-espace` | AuthGate / Dashboard | connecté |
| `/admin-videos` | AdminGuard → AdminVideosPage | admin |
| `/cgv`, `/mentions-legales`, `/faq` | pages légales | public |
| `/?commande=<id>` | ConfirmationPage | public |
| `/studio-live?abonnement=<id>` | PaiementEnAttente (studio) | public |
| `/?code=...&state=...` | TiktokCallbackPage | admin |

Le site Netlify doit réécrire toutes les URL vers `index.html` (SPA fallback).

## 3. Pays & devises

### 23 pays SasPay actifs (devise locale)

| Devise | Pays |
| --- | --- |
| XOF | Mali (ML), Sénégal (SN), Côte d'Ivoire (CI), Burkina Faso (BF), Bénin (BJ), Togo (TG), Niger (NE) |
| XAF | Cameroun (CM), Gabon (GA), Congo-Brazzaville (CG) |
| CDF | Congo-Kinshasa (CD) |
| GNF | Guinée (GN) |
| NGN | Nigeria (NG) |
| GHS | Ghana (GH) |
| SLE | Sierra Leone (SL) |
| KES | Kenya (KE) |
| UGX | Ouganda (UG) |
| TZS | Tanzanie (TZ) |
| RWF | Rwanda (RW) |
| MWK | Malawi (MW) |
| MZN | Mozambique (MZ) |
| ZMW | Zambie (ZM) |
| INR | Inde (IN) |

Tous les autres pays (Maroc, France, Belgique, Suisse, Canada, USA, Émirats…) → Paddle.
Devise d'affichage Paddle : **EUR** pour l'Europe + Maghreb, **USD** sinon.
La conversion locale reste indicative.

### Taux (1 XOF = X devise locale)

Voir `lib/core/countries.dart` (frontend) et `supabase/functions/_shared/countries.ts`
(backend) — **mêmes valeurs**, à garder synchronisées :

```
XOF 1        XAF 1        EUR 0.00152449  USD 0.00165
CDF 4.60     GNF 14.30    NGN 2.56        GHS 0.0256
SLE 0.0371   KES 0.213    UGX 5.69        TZS 3.96
RWF 2.05     MWK 2.70     MZN 0.105       ZMW 0.0396
INR 0.138    MAD 0.0164   CAD 0.00226     GBP 0.00129
CHF 0.00145  AED 0.00606  AUD 0.00250     JPY 0.247
CNY 0.0118   BRL 0.0089   MXN 0.0300      ZAR 0.0295
```

## 4. Base de données (migration `20260101000500_paddle_et_studio_live.sql`)

### 4.1 Colonnes ajoutées à `public.orders`

```sql
provider text not null default 'saspay'      -- 'saspay' | 'paddle'
paddle_transaction_id text
montant_local numeric(12,2)                  -- montant réellement facturé
devise_locale text                           -- devise réellement facturée
kind text not null default 'kit'             -- 'kit' | 'studio'
```

### 4.2 `public.studio_subscriptions`

```sql
id uuid pk default gen_random_uuid()
user_id uuid null references auth.users(id) on delete set null
email text not null
nom_activite text not null
metier_code text not null
metier_label text
pays_code text not null
pays_label text
devise text not null
montant_local numeric(12,2) not null
montant_usd numeric(12,2) not null default 10
provider text not null check (provider in ('saspay','paddle'))
status text not null default 'EN_ATTENTE'
  check (status in ('EN_ATTENTE','PAYE','ACTIF','EXPIRE','ECHEC'))
saspay_session_id text
saspay_payment_id text
paddle_transaction_id text
guide_status text not null default 'EN_ATTENTE'
  check (guide_status in ('EN_ATTENTE','EN_COURS','PRET','ERREUR'))
guide_error text
started_at timestamptz
expires_at timestamptz
paid_at timestamptz
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

### 4.3 `public.studio_guides`

```sql
id uuid pk
subscription_id uuid unique not null references studio_subscriptions(id) on delete cascade
user_id uuid null
email text
metier_code text
metier_label text
pays_code text
titre text
contenu_html text
contenu_markdown text
statut text not null default 'EN_ATTENTE'
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

### 4.4 `public.studio_live_sessions`

```sql
id uuid pk
subscription_id uuid not null references studio_subscriptions(id) on delete cascade
user_id uuid null references auth.users(id) on delete set null
room_id text unique not null
invite_token text not null
titre text
plateformes text[] not null default '{}'    -- SALLE, TIKTOK, YOUTUBE, INSTAGRAM
format text not null default 'SOLO' check (format in ('SOLO','DUO'))
mode_visuel text not null default 'CAMERA' check (mode_visuel in ('CAMERA','ECRAN'))
fiche_produit jsonb not null default '{}'::jsonb
statut text not null default 'BROUILLON' check (statut in ('BROUILLON','PRET','EN_DIRECT','TERMINE'))
started_at timestamptz
ended_at timestamptz
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

### 4.5 `public.studio_live_messages`

```sql
id uuid pk
session_id uuid not null references studio_live_sessions(id) on delete cascade
room_id text not null
platform text not null default 'SALLE' check (platform in ('SALLE','TIKTOK','YOUTUBE','INSTAGRAM'))
role text not null check (role in ('user','assistant'))
author text
content text not null
created_at timestamptz not null default now()
```

### 4.7 `public.studio_trials` (essai gratuit 3 jours)

```sql
user_id uuid primary key references auth.users(id) on delete cascade
started_at timestamptz not null default now()
ends_at timestamptz not null default (now() + interval '3 days')
created_at timestamptz not null default now()
-- check : ends_at = started_at + interval '3 days' (jamais prolongeable)
```

- **RLS** : `select` uniquement pour `user_id = auth.uid()` ; aucune écriture client.
- **Création** : RPC `public.demarrer_essai_studio()` security definer :
  `auth.uid()` obligatoire, `auth.users.email_confirmed_at` non null, un seul
  essai par utilisateur, insertion avec `now()` du serveur. Erreurs `P0001`
  (déjà utilisé) / `P0002` (email non confirmé).
- Helpers : `essai_studio_actif()`, `acces_studio()` (abonnement actif OU essai),
  `compter_reponses_ia_essai()` (limite chat 20/jour).
- `studio_live_sessions.subscription_id` devient nullable pour les sessions
  d'essai ; la RLS des sessions utilise `acces_studio()` et `user_id = auth.uid()`.
- `studio_session_publique` vérifie l'abonnement actif **ou** l'essai actif.
- Le Livre Guide (`studio_guides` / `generate-live-guide`) reste strictement
  réservé aux abonnements payés.

### 4.8 RLS

- `studio_subscriptions` : `select` si `user_id = auth.uid()` OU
  `lower(email) = lower(coalesce(auth.jwt()->>'email',''))`. Aucun `insert/update/delete` client.
- `studio_guides` : `select` via l'abonnement accessible.
- `studio_live_sessions` : `select/insert/update/delete` si abonnement actif accessible
  (fonction `public.studio_a_acces(subscription_id)`), service_role pour le reste.
- `studio_live_messages` : `select` public si la session existe et
  `statut in ('PRET','EN_DIRECT')` ; aucune écriture client (service_role uniquement).
- Activer la publication temps réel sur `studio_live_messages`.
- Index sur `room_id`, `subscription_id`, `created_at`.
- Fonctions `public.studio_a_acces(uuid)` et `public.mon_abonnement_studio()`.

## 5. Edge Functions

### 5.1 `saspay-checkout` (modifiée)

Entrée :
```json
{
  "kind": "kit" | "studio",
  "metier_code": "ecommerce", "metier_label": "E-commerce & Mode",
  "nom_projet": "Ma boutique", "pays_code": "NG",
  "whatsapp": "8012345678", "email": "client@example.com",
  "produit_type": "pack",           // kit uniquement
  "precisions": "…"
}
```
Sortie :
```json
{
  "success": true, "provider": "saspay", "kind": "kit",
  "order_id": "uuid", "subscription_id": null,
  "session_id": "…", "checkout_url": "https://…",
  "montant": 23040, "devise": "NGN", "offre": "Pack Complet",
  "metier": "E-commerce & Mode", "pays": "Nigeria"
}
```
Le montant est calculé avec la table de taux serveur. Pour `kind=studio`, crée une
ligne `studio_subscriptions` (`status='EN_ATTENTE'`, `expires_at` null) et renvoie
`subscription_id`.

### 5.2 `create-paddle-checkout` (nouvelle)

Même entrée que §5.1. Utilise les prix Paddle :

```
PADDLE_PRICE_KIT_PROMPT / _SHEET / _LIVRE / _PACK
PADDLE_PRICE_STUDIO
// variantes EUR optionnelles : suffixe _EUR
PADDLE_PRICE_KIT_PACK_EUR, PADDLE_PRICE_STUDIO_EUR…
```

Sortie :
```json
{
  "success": true, "provider": "paddle", "kind": "kit",
  "order_id": "uuid", "subscription_id": null,
  "transaction_id": "txn_…", "checkout_url": "https://…|null",
  "client_token": "live_…", "environment": "production",
  "montant": 13.72, "devise": "EUR",
  "montant_indicatif": 165.0, "devise_indicative": "MAD",
  "offre": "Pack Complet", "metier": "E-commerce & Mode", "pays": "Maroc"
}
```

### 5.3 `paddle-webhook` (nouvelle)

- Vérifie `Paddle-Signature: ts=…;h1=…` = HMAC-SHA256(secret, `${ts}:${body}`),
  rejette si `|now - ts| > 300 s`.
- Événements : `transaction.completed`, `transaction.paid` → marque payé + livraison.
  `transaction.payment_failed`, `transaction.canceled` → `ECHEC`.
- Custom data : `{order_id}` ou `{subscription_id}`, `kind`.
- Idempotent : ne relivre jamais (`statut` déjà `LIVRE`/`ACTIF`).
- Kit → `livrerCommande(order_id)`.
- Studio → `activerAbonnementStudio(subscription_id)` (guide IA + email).

### 5.4 `verify-payment` (modifiée)

Entrée : `{ "order_id"?: "uuid", "subscription_id"?: "uuid", "provider"?: "saspay"|"paddle" }`.

- Kit : même sortie que l'existant (`paid`, `liens`, `livraison`, `commande`).
- Studio : 
```json
{
  "success": true, "paid": true, "statut": "ACTIF",
  "subscription_id": "uuid",
  "abonnement": { "id": "...", "status": "ACTIF", "expires_at": "..." },
  "guide": { "id": "...", "titre": "...", "statut": "PRET", "contenu_html": "<html>…" }
}
```
- Paddle : vérifie via `GET https://api.paddle.com/transactions/{id}` si le webhook
  n'est pas encore passé (statut `completed`/`paid`), puis livre.

### 5.5 `generate-live-guide` (nouvelle)

Entrée `{ "subscription_id": "uuid" }` (JWT requis, propriétaire ou email de l'abonnement).
Génère (DeepSeek plan + Gemini rédaction HTML) :
- script d'accroche,
- structure du live en 7 séquences,
- conseils caméra / partage d'écran,
- techniques de vente live,
- modèle de réponses aux questions,
- plan du Livre Guide.

Enregistre dans `studio_guides`, passe `guide_status='PRET'`, envoie l'email Resend.
Idempotent : renvoie le guide existant si `PRET`. Sortie `{ success, guide }`.

### 5.6 `live-auto-chat` (nouvelle)

Entrée :
```json
{ "action": "ask"|"messages",
  "room_id": "…", "message": "…", "author": "Awa",
  "platform": "SALLE"|"TIKTOK"|"YOUTUBE"|"INSTAGRAM",
  "invite_token": "…" }
```
- `ask` : valide la session (`room_id`), vérifie que l'accès est actif (abonnement
  ou essai), construit le prompt avec `fiche_produit`, appelle DeepSeek, insère
  les deux messages, renvoie `{ success, reply, message }`.
  En **essai**, limite stricte de **20 réponses IA par jour** (compteur
  `compter_reponses_ia_essai`) ; au-delà : HTTP 429 avec message d'abonnement.
- `messages` : 60 derniers messages de la salle.
- Aucune donnée sensible dans le prompt.

### 5.7 `studio-room` (nouvelle)

Entrée `{ "action": "get", "room_id": "…", "invite_token": "…" }`.
Sortie : session publique minimale (titre, mode_visuel, format, fiche_produit,
statut, owner_display). Vérifie le token d'invitation OU un JWT propriétaire.
Permet à un co-animateur invité de rejoindre `/live/:roomId?invite=…`.

### 5.8 `site-assistant` (contenu mis à jour)

Doit connaître : les 2 univers, les 8 secteurs, les tarifs kits en FCFA, Studio Live
10 USD, les 23 pays SasPay + Paddle, les routes `/boutique`, `/studio-live`, `/guide`.
Même contrat d'entrée/sortie qu'aujourd'hui.

## 6. Secrets

```
SITE_URL, WHATSAPP_AIDE_NUMBER, SUPPORT_EMAIL
SASPAY_API_KEY, SASPAY_WEBHOOK_SECRET, SASPAY_BASE_URL
PADDLE_API_KEY, PADDLE_CLIENT_TOKEN, PADDLE_WEBHOOK_SECRET
PADDLE_ENVIRONMENT=sandbox|production
PADDLE_PRICE_KIT_PROMPT, _SHEET, _LIVRE, _PACK, PADDLE_PRICE_STUDIO
PADDLE_PRICE_KIT_PACK_EUR, PADDLE_PRICE_STUDIO_EUR (optionnels)
RESEND_API_KEY, RESEND_FROM_EMAIL
DEEPSEEK_API_KEY, DEEPSEEK_MODEL
GEMINI_API_KEY, GEMINI_MODEL
ADMIN_EMAILS
```

## 7. Contrats frontend

`ApiService` expose :

```dart
Future<CheckoutCree> creerCheckoutKit({...});
Future<CheckoutCree> creerCheckoutStudio({...});
Future<ResultatCommande> verifierPaiement({String? orderId, String? subscriptionId, String? provider});
Future<AbonnementStudio?> monAbonnement();
Future<GuideLive?> monGuide(String subscriptionId);
Future<GuideLive> genererGuide(String subscriptionId);
Future<SessionLive> enregistrerSessionLive(SessionLive session);
Future<List<SessionLive>> mesSessionsLive();
Future<SessionLive?> sessionPublique(String roomId, {String? inviteToken});
Future<ReponseChatLive> chatLive({...});
Future<List<MessageLive>> messagesLive(String roomId);
Future<ReponseAssistant> assistant({...});
```

Le prix affiché est **toujours** calculé par `Prix` (frontend) à partir du pays
sélectionné ; le serveur recalcule et c'est le montant serveur qui fait foi.

## 8. Design system

- Fond `#090D16`, surfaces `#111827`, verre dépoli, bordures `#1E293B`.
- Dégradé de marque **or → émeraude** : `#F7D488 → #E7B84B → #34D399`.
- Logo vectoriel : livre ouvert + signal de diffusion, CustomPainter + SVG inline.
- Accent or pour les CTA, émeraude pour le live/succès.
- Navigation minimale : logo, 3 accès, Aide WhatsApp discret, menu Compte.
- Aucun formulaire en vrac sur l'accueil : deux univers, deux CTA.
