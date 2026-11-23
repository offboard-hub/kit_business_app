# Déploiement — e-booklive (kits FCFA + paiement international Paddle)

Ce guide couvre **tout ce qui est nécessaire pour mettre le projet en production** :
base de données, secrets Supabase, déploiement des Edge Functions, configuration
SasPay / Resend / Google / YouTube / TikTok, puis GitHub et Netlify.

---

## 1. Prérequis

| Outil | Version conseillée | Vérification |
|---|---|---|
| Flutter | 3.47+ (Dart 3.13+) | `flutter --version` |
| Supabase CLI | 2.x | `supabase --version` |
| Git | 2.x | `git --version` |
| Comptes | SasPay, Resend, Google Cloud, TikTok Developers | — |

```bash
flutter pub get
supabase login
supabase link --project-ref ynephuutnazdnjhsdlsy
```

---

## 2. Base de données (à faire en premier)

Dans **Supabase → SQL Editor**, exécutez les migrations **dans cet ordre** :

1. `supabase/migrations/20260101000000_schema_base.sql`
2. `supabase/migrations/20260101000100_commandes_assistant_video.sql`
3. `supabase/migrations/20260101000200_avis_site.sql`
4. `supabase/migrations/20260101000300_suppression_livraison_whatsapp.sql`
5. `supabase/migrations/20260101000400_tiktok_oauth.sql`
6. `supabase/migrations/20260101000500_paddle_et_studio_live.sql`
7. `supabase/migrations/20260101000600_studio_essai_gratuit.sql`

Ou en ligne de commande :

```bash
supabase db push
```

Ces migrations sont **idempotentes** : elles peuvent être rejouées sans casser l'existant.

### 2.1 Vous nommer administrateur (`/admin-videos`)

```sql
update public.profiles
set is_admin = true
where email = 'votre-email@exemple.com';
```

> Si le profil n'existe pas encore : créez d'abord le compte via la page
> « Mon espace » (l'inscription est automatique, sans confirmation), puis relancez
> la requête.

### 2.2 Désactiver la confirmation d'email (obligatoire pour « sans confirmation »)

**Supabase → Authentication → Providers → Email** : désactivez
`Confirm email`. L'utilisateur est connecté immédiatement après l'inscription.
L'email d'accueil (`welcome-email`) est **informatif** et ne contient aucun lien de confirmation.

> 🔐 **Choix de sécurité à assumer** : l'accès à la régie Studio Live d'un acheteur
> invité se fait par correspondance d'email (`studio_subscriptions.email` =
> email du JWT). Sans confirmation d'email, un tiers pourrait revendiquer un
> abonnement acheté en invité s'il crée un compte avec le même email avant le
> client. Pour une mise en production stricte, **activez `Confirm email`** ou
> liez systématiquement l'achat à un compte connecté. Voir `docs/REVUE_DB.md` (F03).

### 2.3 Vérifier qu'aucun bucket vidéo n'existe

**Supabase → Storage** : ne créez **aucun** bucket pour les vidéos.
L'application n'écrit jamais de `.mp4` dans Supabase Storage (plan gratuit 1 Go préservé).

---

## 3. Secrets Supabase (liste complète et exacte)

> ⚠️ Les secrets ne doivent **jamais** être commités dans Git ni exposés côté Flutter.
> La clé `sb_publishable_...` présente dans `lib/core/config.dart` est publique par nature.

### 3.1 Tableau des secrets

| Secret | Obligatoire | Rôle / où l'obtenir |
|---|---|---|
| `SASPAY_API_KEY` | ✅ | Clé SasPay `sk_live_...` (ou `sk_test_...` en test) — app.saspay.me → Développeur |
| `SASPAY_WEBHOOK_SECRET` | ✅ (recommandé) | `signing_secret` affiché à la création du webhook SasPay |
| `SASPAY_BASE_URL` | ❌ | Défaut `https://api.saspay.me/api/v1` (utile pour un sandbox) |
| `SASPAY_PAYMENT_LINK` | ❌ (legacy) | Ancien lien de paiement réutilisable — plus utilisé : les CTA pointent vers `/boutique` |
| `PADDLE_API_KEY` | ✅ (hors 23 pays SasPay) | Clé API Paddle Billing (`pdl_live_...` ou `pdl_sdbx_...`) — developer.paddle.com |
| `PADDLE_CLIENT_TOKEN` | ✅ (Paddle) | Jeton public Paddle.js (`live_...` / `test_...`). Alias accepté : `PADDLE_TOKEN_KIT`. |
| `PADDLE_WEBHOOK_SECRET` | ✅ (Paddle) | Secret de signature du webhook Paddle (`pdl_ntfset_...`) |
| `PADDLE_ENVIRONNEMENT` | ✅ | `sandbox` ou `production` (nom historique français ; `PADDLE_ENVIRONMENT` accepté aussi). Aucun défaut : le checkout échoue si absent. |
| `PADDLE_PRICE_KIT_PROMPT` | ✅ (Paddle) | Price ID du kit Prompts IA (USD) |
| `PADDLE_PRICE_KIT_SHEET` | ✅ (Paddle) | Price ID du kit Sheet Automatisé (USD) |
| `PADDLE_PRICE_KIT_LIVRE` | ✅ (Paddle) | Price ID du kit Livre Stratégique (USD) |
| `PADDLE_PRICE_KIT_PACK` | ✅ (Paddle) | Price ID du Pack Complet (USD) |
| `PADDLE_PRICE_STUDIO` | ✅ (Paddle) | Price ID de l'abonnement Studio Live (USD, 10 USD) |
| `PADDLE_PRICE_*_EUR` | ❌ (obsolète) | Plus utilisées : Paddle facture en USD par défaut. |
| `SITE_URL` | ✅ | URL publique du site **sans slash final**, ex. `https://e-booklive.offboard-hub.com` |
| `WHATSAPP_AIDE_NUMBER` | ✅ | Numéro d'aide WhatsApp au format international **sans `+`**, ex. `22670123456` |
| `RESEND_API_KEY` | ✅ | Clé API Resend (`re_...`) — resend.com/api-keys |
| `RESEND_FROM_EMAIL` | ✅ | Expéditeur vérifié, ex. `e-booklive <bonjour@votre-domaine.com>` |
| `SUPPORT_EMAIL` | ❌ | Adresse de réponse (`reply_to`) des emails |
| `DEEPSEEK_API_KEY` | ✅ | platform.deepseek.com — stratégie, prompts, assistant, copy vidéo |
| `DEEPSEEK_MODEL` | ❌ | Défaut `deepseek-chat` |
| `GEMINI_API_KEY` | ✅ | aistudio.google.com — rédaction du livre, du sheet, décorticage vidéo |
| `GEMINI_MODEL` | ❌ | Défaut `gemini-2.5-flash` |
| `GOOGLE_WORKSPACE_CREDENTIALS` | ✅ | JSON **complet** de la clé du compte de service Google (Sheets + Drive) |
| `ADMIN_EMAILS` | ❌ | Emails administrateurs séparés par des virgules (alternative à `is_admin`) |
| `YOUTUBE_CLIENT_ID` | ✅ (robot + distribution) | Google Cloud → OAuth 2.0 Client |
| `YOUTUBE_CLIENT_SECRET` | ✅ (robot + distribution) | Google Cloud → OAuth 2.0 Client |
| `YOUTUBE_REFRESH_TOKEN` | ✅ (robot + distribution) | Obtenu avec les portées `youtube.upload` et `youtube.force-ssl` |
| `YOUTUBE_CHANNEL_ID` | ❌ (recommandé) | Chaîne du bot, pour ne jamais répondre à ses propres messages |
| `YOUTUBE_LIVE_VIDEO_ID` | ❌ | ID de la vidéo live par défaut (sinon passé en paramètre) |
| `YOUTUBE_LIVE_CHAT_ID` | ❌ | `liveChatId` fixe si vous préférez éviter la résolution automatique |
| `YOUTUBE_ACCESS_TOKEN` | ❌ | Jeton court (tests uniquement, expire en 1 h) |
| `TIKTOK_CLIENT_KEY` | ✅ (TikTok) | developers.tiktok.com → votre application |
| `TIKTOK_CLIENT_SECRET` | ✅ (TikTok) | developers.tiktok.com → votre application |
| `TIKTOK_REDIRECT_URI` | ❌ | URL de retour OAuth (défaut `${SITE_URL}/`), à déclarer chez TikTok |
| `TIKTOK_SCOPES` | ❌ | Portées demandées, défaut `video.upload` |
| `TIKTOK_REFRESH_TOKEN` | ❌ (legacy) | Secours si vous préférez un refresh token manuel |
| `TIKTOK_ACCESS_TOKEN` | ❌ | Jeton court (tests uniquement) |
| `MAX_VIDEO_MB` | ❌ | Taille max du fichier vidéo traité, défaut `90` |
| `CRON_SECRET` | ✅ (robot YouTube) | Chaîne aléatoire protégeant `youtube-live-bot` |
| `SUPABASE_URL` | 🤖 auto | Injecté par Supabase |
| `SUPABASE_ANON_KEY` | 🤖 auto | Injecté par Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | 🤖 auto | Injecté par Supabase — ne jamais l'exposer |

### 3.2 Les définir

Le plus simple : remplissez `supabase/.env` (modèle fourni : `supabase/.env.example`), puis :

```bash
supabase secrets set --env-file ./supabase/.env
```

Ou un par un :

```bash
supabase secrets set \
  SASPAY_API_KEY=sk_live_xxxxxxxx \
  SASPAY_WEBHOOK_SECRET=whsec_xxxxxxxx \
  SITE_URL=https://e-booklive.offboard-hub.com \
  WHATSAPP_AIDE_NUMBER=22670123456 \
  RESEND_API_KEY=re_xxxxxxxx \
  RESEND_FROM_EMAIL="e-booklive <bonjour@votre-domaine.com>" \
  DEEPSEEK_API_KEY=sk-xxxxxxxx \
  GEMINI_API_KEY=xxxxxxxx \
  CRON_SECRET=une-chaine-aleatoire-longue
```

Pour les valeurs contenant des espaces, des guillemets ou des retours à la ligne
(`GOOGLE_WORKSPACE_CREDENTIALS`, `RESEND_FROM_EMAIL`), **utilisez `--env-file`** :
c'est la méthode fiable.

```bash
supabase secrets list   # vérifier les noms (valeurs masquées)
```

---

## 4. Déployer les Edge Functions

```bash
supabase functions deploy
```

Si votre version de la CLI n'applique pas `supabase/config.toml`, déployez
fonction par fonction en désactivant la vérification JWT globale (chaque fonction
vérifie elle-même l'identité) :

```bash
for f in generate-kit verify-payment view-kit saspay-checkout saspay-webhook \
         create-paddle-checkout paddle-webhook generate-live-guide live-auto-chat \
         studio-room admin-check welcome-email site-assistant youtube-live-bot \
         video-agency-pipeline tiktok-auth; do
  supabase functions deploy "$f" --no-verify-jwt
done
```

Fonctions déployées :

| Fonction | Rôle |
|---|---|
| `saspay-checkout` | Crée la commande (kit) ou l'abonnement Studio + la session SasPay |
| `create-paddle-checkout` | Crée la commande/abonnement + la transaction Paddle en USD |
| `verify-payment` | Vérifie SasPay **ou** Paddle, livre le kit ou active le Studio |
| `saspay-webhook` | Confirmation SasPay (signature HMAC) + livraison/activation idempotente |
| `paddle-webhook` | Confirmation Paddle (signature `Paddle-Signature`) + livraison/activation |
| `generate-live-guide` | Génère le Livre Guide Live (JWT propriétaire requis) |
| `live-auto-chat` | Chat IA « Awa » du live (DeepSeek) + historique des messages |
| `studio-room` | Session publique minimale d'une salle live (jeton d'invitation / JWT) |
| `generate-kit` | Régénération manuelle du kit avec crédits |
| `view-kit` | Page de consultation / téléchargement PDF, protégée par jeton |
| `welcome-email` | Email d'accueil Resend (sans confirmation) |
| `site-assistant` | Chat IA DeepSeek (bulle de chat du site) |
| `youtube-live-bot` | Robot du chat YouTube Live (cycle de 10 s) |
| `video-agency-pipeline` | Agence vidéo IA : 4 agents + distribution brouillon |
| `tiktok-auth` | Connexion OAuth TikTok (start / callback / status / disconnect) |

---

## 4 bis. Refonte e-booklive — Paddle & Studio Live

Cette refonte ajoute **deux univers** : La Boutique (kits, paiement unique) et
le **Studio Live** (10 USD / 30 jours). Le routage du paiement est automatique :

- **23 pays SasPay** (ML, SN, CI, BF, BJ, TG, NE, CM, GA, CG, CD, GN, NG, GH,
  SL, KE, UG, TZ, RW, MW, MZ, ZM, IN) → `saspay-checkout`, montant dans la
  devise locale.
- **Tous les autres pays** → `create-paddle-checkout`, facturation **USD par
  défaut**, conversion locale indicative.

### 4 bis.1 Migration à appliquer

`supabase/migrations/20260101000500_paddle_et_studio_live.sql` (idempotente) :
colonnes Paddle sur `orders`, tables `studio_subscriptions`, `studio_guides`,
`studio_live_sessions`, `studio_live_messages`, RLS, temps réel et fonctions
`studio_a_acces`, `mon_abonnement_studio`, `studio_session_publique`.

```bash
supabase db push
```

### 4 bis.2 Secrets Paddle à définir

```bash
supabase secrets set PADDLE_ENVIRONNEMENT=sandbox
supabase secrets set PADDLE_API_KEY=pdl_sdbx_xxx
supabase secrets set PADDLE_CLIENT_TOKEN=test_xxx
supabase secrets set PADDLE_WEBHOOK_SECRET=pdl_ntfset_xxx
```

### 4 bis.3 Price IDs Paddle (Products → Prices)

Créez dans Paddle un **prix one-time par offre, en USD**. C'est la devise de
facturation **par défaut pour tous les pays Paddle** ; les prix EUR ne sont plus
utilisés.

| Variable | Offre | Montant conseillé (USD) |
|---|---|---|
| `PADDLE_PRICE_KIT_PROMPT` | Prompts IA | 4,95 |
| `PADDLE_PRICE_KIT_SHEET` | Sheet Automatisé | 5,78 |
| `PADDLE_PRICE_KIT_LIVRE` | Livre Stratégique | 8,25 |
| `PADDLE_PRICE_KIT_PACK` | Pack Complet | 14,85 |
| `PADDLE_PRICE_STUDIO` | Studio Live 30 jours | 10,00 |

Les variantes `_EUR` sont **obsolètes** : ne les créez pas. Les montants locaux
sont purement indicatifs ; Paddle débite le prix USD.

> **Tous ces prix doivent être des prix one-time** (pas de facturation
> récurrente) : le Studio Live est un accès de 30 jours géré par l'application,
> pas un abonnement Paddle. Un prix récurrent créerait un second prélèvement
> que l'application ne suivrait pas.

> Sans `PADDLE_PRICE_KIT_*`, `create-paddle-checkout` renvoie une erreur
> explicite en français : c'est volontaire (aucun paiement au mauvais prix).

### 4 bis.4 Webhook Paddle à configurer

Dans **Paddle → Developer Tools → Notifications**, créez une destination :

```
https://<project-ref>.supabase.co/functions/v1/paddle-webhook
```

Événements à cocher :

- `transaction.completed`
- `transaction.paid`
- `transaction.payment_failed`
- `transaction.canceled`

Copiez le secret de signature dans `PADDLE_WEBHOOK_SECRET` (fenêtre de 300 s,
signature `Paddle-Signature: ts=…;h1=…`).

### 4 bis.5 Webhook SasPay (inchangé, étendu au Studio)

La destination existante `…/functions/v1/saspay-webhook` traite désormais les
kits **et** les abonnements Studio Live (`metadata.subscription_id`, `kind`).
Événements à conserver : `transaction.success`, `transaction.failed`,
`transaction.cancelled`.

### 4 bis.5 bis Essai gratuit Studio Live (3 jours)

L'essai est **applicatif** : aucun prix d'essai n'est créé chez Paddle ou SasPay,
aucune carte n'est demandée et aucun prélèvement automatique n'a lieu.

- Migration : `supabase/migrations/20260101000600_studio_essai_gratuit.sql`.
- Table `studio_trials` (un seul essai par utilisateur, `ends_at = started_at + 3 jours`).
- RPC `public.demarrer_essai_studio()` : `auth.uid()` requis, **email confirmé**
  (`auth.users.email_confirmed_at`) requis, un seul essai, jamais prolongeable.
- Accès régie = abonnement payé actif **ou** essai non expiré.
- Pendant l'essai : chat IA limité à **20 réponses par jour** ; le Livre Guide et
  les guides restent réservés aux abonnements payés.
- À l'expiration : la régie affiche « Votre essai est terminé » et le bouton
  d'abonnement ; la salle n'est plus publique et le chat est fermé.

> Sans confirmation d'email activée dans Supabase, l'essai restera refusé
> (`P0002`). Activez `Confirm email` ou utilisez un compte déjà confirmé.

### 4 bis.6 Routes Flutter concernées

| Route | Usage |
|---|---|
| `/boutique` | Kits métiers, choix du secteur et du pays |
| `/studio-live` | Essai 3 jours + abonnement Studio Live (10 USD / 30 jours) |
| `/?commande=<id>` | Retour SasPay/Paddle pour un kit (`verify-payment`) |
| `/studio-live?abonnement=<id>` | Paiement Studio en attente (`verify-payment`) |
| `/studio/regie` | Régie de l'abonné (sessions, chat, guide) |
| `/live/:roomId?invite=<token>` | Salle publique / co-animateur (`studio-room`) |
| `/guide` | Guide & Tutoriel public |

Le site doit servir ces URLs en **path** (plus de `/#/`) : réécriture SPA vers
`index.html` côté Netlify.

### 4 bis.7 Vérifications rapides

```bash
# Refus attendu : signature Paddle absente → 401
curl -i -X POST "https://<project-ref>.supabase.co/functions/v1/paddle-webhook" \
  -H "Content-Type: application/json" -d '{}'

# Refus attendu : pays Paddle envoyé à saspay-checkout → message explicite
curl -s -X POST "https://<project-ref>.supabase.co/functions/v1/saspay-checkout" \
  -H "Content-Type: application/json" \
  -d '{"kind":"kit","metier_code":"ecommerce","nom_projet":"Test","pays_code":"MA","whatsapp":"600000000","email":"test@example.com","produit_type":"pack"}'
```

---

## 5. Configurer SasPay (23 pays, devise locale)

1. **app.saspay.me → Développeur** : créez une clé `sk_test_...` puis `sk_live_...`.
2. Renseignez `SASPAY_API_KEY`.
3. **Webhooks** : créez un point de réception
   `https://ynephuutnazdnjhsdlsy.supabase.co/functions/v1/saspay-webhook`
   avec les événements `transaction.success`, `transaction.failed`, `transaction.cancelled`.
4. Copiez immédiatement le `signing_secret` dans `SASPAY_WEBHOOK_SECRET`
   (il n'est affiché qu'une fois).
5. Testez avec la clé `sk_test_...` : le tunnel Flutter appelle `saspay-checkout`,
   ouvre `checkout_url`, puis `verify-payment` vérifie
   `GET /payments/{payment_id}/verify/` — **seul `SUCCESS` autorise la livraison**.

> YouCan Pay et PaySaS ne sont plus utilisés. Paddle reste utilisé pour les pays
> hors SasPay (voir §4 bis) : les deux prestataires coexistent désormais. Si
> d'anciennes clés YouCan Pay existent dans vos secrets Supabase, supprimez-les :
> `supabase secrets unset YOUCAN_*`.

---

## 6. Configurer Resend (emails)

1. Créez un compte sur [resend.com](https://resend.com) et **vérifiez votre domaine**.
2. Créez une clé API → `RESEND_API_KEY`.
3. `RESEND_FROM_EMAIL` doit utiliser ce domaine (sinon Resend refuse l'envoi en production).
4. Test rapide :
   ```bash
   curl -X POST https://ynephuutnazdnjhsdlsy.supabase.co/functions/v1/welcome-email \
     -H "Content-Type: application/json" \
     -d '{"email":"vous@exemple.com","source":"test"}'
   ```

---

## 7. Avis clients (notation & modération)

La table `avis_site` est créée par la migration `20260101000200_avis_site.sql`.

1. **Publication** : un visiteur dépose un avis depuis la page d'accueil (note 1 à 5,
   nom, ville, pays, commentaire). L'avis est publié immédiatement
   (`est_publie = true`), sans compte.
2. **Modération** : pour retirer un avis, passez `est_publie` à `false` :
   ```sql
   update public.avis_site set est_publie = false where id = 'identifiant-de-l-avis';
   ```
3. **Suppression définitive** :
   ```sql
   delete from public.avis_site where id = 'identifiant-de-l-avis';
   ```
4. La page d'accueil affiche la moyenne, les derniers avis et le formulaire.
   Si la table n'existe pas encore, la section reste affichée sans erreur.

> Le bouton **« Aide WhatsApp »** reste un simple lien `wa.me` construit à partir
> de `WHATSAPP_AIDE_NUMBER` : aucun message n'est envoyé automatiquement par le site.

---

## 8. Google Sheets (compte de service)

1. Google Cloud Console → activez **Google Sheets API** et **Google Drive API**.
2. Créez un **compte de service**, générez une clé JSON.
3. Mettez le **contenu JSON complet** dans `GOOGLE_WORKSPACE_CREDENTIALS`
   (via `--env-file`, une seule ligne ou JSON indenté avec guillemets).
4. Le compte de service crée le classeur et le partage en écriture (`anyone`).
   Sur un compte Google Workspace restreint, autorisez la création de fichiers Drive
   pour ce compte de service, sinon le kit sera livré sans Google Sheet (le reste fonctionne).

---

## 9. YouTube (robot de live + distribution vidéo)

1. Google Cloud Console → activez **YouTube Data API v3**.
2. **Écran de consentement OAuth** → type Externe, ajoutez votre compte en « testeur ».
3. **Identifiants → Créer → ID client OAuth**, type *Application Web*.
4. Générez un `refresh_token` avec **les deux portées** :
   - `https://www.googleapis.com/auth/youtube.upload` (envoi privé des vidéos)
   - `https://www.googleapis.com/auth/youtube.force-ssl` (lecture/écriture du chat live)

   Le plus simple : [OAuth 2.0 Playground](https://developers.google.com/oauthplayground)
   → roue dentée → *Use your own OAuth credentials* → autorisez les deux portées
   → échangez le code contre un refresh token.
5. Renseignez `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET`, `YOUTUBE_REFRESH_TOKEN`,
   et `YOUTUBE_CHANNEL_ID` (ID de votre chaîne, visible dans YouTube Studio).
6. ⚠️ Tant que l'application OAuth est en mode « Testing », Google révoque le
   refresh token au bout de 7 jours. Passez en « In production » pour la stabilité.

### Lancer le robot sur un live

```bash
curl "https://ynephuutnazdnjhsdlsy.supabase.co/functions/v1/youtube-live-bot?action=start&video_id=VOTRE_VIDEO_ID&secret=VOTRE_CRON_SECRET"
```

Le robot tourne alors pendant ~2 minutes en tâche de fond, avec un cycle toutes
les **10 secondes** (paramètre `intervalle_secondes`, minimum 5) et au maximum
2 réponses par cycle. Relancez la commande avant la fin du live, ou planifiez-la
toutes les 2 minutes (cron-job.org, GitHub Actions, ou `pg_cron` + `pg_net`).

Vérification :

```bash
curl "https://ynephuutnazdnjhsdlsy.supabase.co/functions/v1/youtube-live-bot?action=status&secret=VOTRE_CRON_SECRET"
```

---

## 10. TikTok (Connexion en un clic + Content Posting API)

1. [developers.tiktok.com](https://developers.tiktok.com) → créez une application.
2. Ajoutez les produits **Login Kit** (OAuth) et **Content Posting API** avec la portée
   `video.upload` (l'envoi se fait dans la boîte de réception TikTok : brouillon,
   validation manuelle).
3. Dans **Login Kit / Redirect URI**, déclarez exactement l'URL de retour :
   `https://votre-domaine.com/` (la racine du site, avec le slash final).
   Si vous utilisez une autre URL, renseignez-la dans `TIKTOK_REDIRECT_URI`.
4. Renseignez `TIKTOK_CLIENT_KEY` et `TIKTOK_CLIENT_SECRET` dans les secrets Supabase.
5. Exécutez la migration `20260101000400_tiktok_oauth.sql` (tables
   `tiktok_credentials` et `tiktok_oauth_states`, accès service_role uniquement).
6. **Connectez le compte depuis l'application** :
   - ouvrez `/admin-videos` avec le compte administrateur ;
   - cliquez sur **« Connecter TikTok »** ;
   - autorisez l'application dans l'onglet TikTok qui s'ouvre ;
   - TikTok revient sur `SITE_URL/?code=...&state=...` : la page de retour échange
     automatiquement le code, enregistre les jetons dans Supabase et affiche
     « TikTok est connecté » ;
   - revenez sur `/admin-videos` et cliquez sur « Actualiser » si nécessaire.

> Aucun `curl`, aucun `refresh_token` à copier. Les jetons ne sont jamais exposés
> au navigateur : ils restent dans `public.tiktok_credentials` (service_role).
> Le jeton d'accès est rafraîchi automatiquement par `video-agency-pipeline`.
> `TIKTOK_REFRESH_TOKEN` n'est plus nécessaire ; il reste accepté comme secours.

7. L'application doit être approuvée par TikTok pour publier sur un compte réel ;
   en attendant, utilisez un compte de test/sandbox.

---

## 11. GitHub

Le dépôt distant est déjà configuré (`origin` → `offboard-hub/kit_business_app`).

```bash
git status
git add .
git commit -m "Afrique francophone FCFA, SasPay, livraison email, avis clients, assistant IA et agence vidéo"
git push origin main
```

> **Avant de pousser** : vérifiez qu'aucun secret n'est présent dans le code.
> `supabase/.env` est ignoré par Git. Le fichier `lib/core/config.dart` ne contient
> que l'URL Supabase et la clé *publishable* (publique).

---

## 12. Netlify

Le fichier `netlify.toml` est déjà prêt (plugin Flutter, `build/web`).

1. **Site settings → Build & deploy** :
   - Build command : `flutter build web --release --dart-define=SITE_URL=$SITE_URL --dart-define=WHATSAPP_AIDE_NUMBER=$WHATSAPP_AIDE_NUMBER`
   - Publish directory : `build/web`
2. **Environment variables** (Netlify) :
   - `SITE_URL` = `https://votre-domaine.com`
   - `WHATSAPP_AIDE_NUMBER` = `22670123456`
   - `FLUTTER_VERSION` = `3.47.9` (ou laissez le plugin choisir)
3. Déclenchez un déploiement : `git push` suffit (build automatique).
4. Vérifiez que `SITE_URL` (secret Supabase) est **identique** à l'URL Netlify :
   c'est l'URL de retour SasPay (`/?commande=...`).

> Le routage utilise des **paths** (`/boutique`, `/studio-live`, `/guide`,
> `/studio/regie`, `/live/:roomId`) : la réécriture SPA de `netlify.toml`
> renvoie toutes les URLs vers `index.html`.

---

## 13. Checklist de recette après déploiement

- [ ] La page d'accueil affiche **3 000 / 3 500 / 5 000 / 9 000 FCFA** (aucun « DH »).
- [ ] Les 6 kits métiers sont sélectionnables en 1 clic.
- [ ] Le bouton **Aide WhatsApp** ouvre bien `https://wa.me/<numéro>`.
- [ ] Un paiement SasPay de test débloque la génération, affiche les liens et
      envoie l'email Resend.
- [ ] La page de confirmation affiche « Email envoyé » (et les liens même si l'email échoue).
- [ ] Un avis déposé depuis l'accueil apparaît immédiatement dans la liste.
- [ ] La migration `avis_site` est appliquée et la RLS limite la lecture aux avis publiés.
- [ ] Un second appel à `verify-payment` ne duplique **pas** le kit (idempotence).
- [ ] `saspay-webhook` renvoie `401` avec une signature invalide et `202` avec une valide.
- [ ] La bulle de chat IA répond et propose le lien d'achat.
- [ ] Le robot YouTube répond dans le chat d'un live de test.
- [ ] `/admin-videos` est inaccessible avec un compte non admin.
- [ ] Un envoi vidéo YouTube arrive bien en **privé** et TikTok en **brouillon**.
- [ ] « Connecter TikTok » aboutit et `/admin-videos` affiche « Connecté ».
- [ ] **Storage Supabase : 0 fichier vidéo.**
- [ ] `flutter analyze` : aucune erreur — `flutter test` : tout passe.

---

## 14. Dépannage express

| Symptôme | Cause probable | Solution |
|---|---|---|
| `SASPAY_API_KEY n'est pas configurée` | Secret absent | `supabase secrets set SASPAY_API_KEY=...` |
| `Paiement invalide` / lien absent | Clé en mode test mais numéro non sandbox | Utiliser un numéro de test SasPay |
| Email non reçu | Domaine Resend non vérifié ou expéditeur invalide | Vérifier le domaine + `RESEND_FROM_EMAIL` |
| `Jeton Google refusé` | Refresh token expiré (mode Testing) | Repasser l'app OAuth en production |
| `Création Google Sheet impossible` | API Drive/Sheets désactivée | Activer les deux API dans Google Cloud |
| `Le Google Sheet n'a pas pu être créé` | Compte de service restreint | Autoriser la création Drive |
| Vidéo trop lourde | Limite Edge Function | Compresser sous 90 Mo ou utiliser une URL externe |
| `Accès réservé à l'administrateur` | Profil non admin | `update profiles set is_admin = true ...` |
| Aucun email | Domaine Resend non vérifié | Vérifier le domaine + `RESEND_FROM_EMAIL` |
| TikTok non connecté | Aucun jeton en base | `/admin-videos` → « Connecter TikTok » |
| `invalid_grant` au retour TikTok | Code déjà utilisé ou `redirect_uri` différent | Relancer la connexion, vérifier l'URL déclarée chez TikTok |
| `Lien de connexion expiré` | Plus de 15 min entre l'autorisation et le retour | Relancer depuis `/admin-videos` |
| `tiktok-auth` renvoie 401/403 | Session non admin ou expirée | Se reconnecter avec le compte administrateur |

---

## 15. Rappel architecture « zéro stockage vidéo »

```
/admin-videos (Flutter, package:web)
        │  .mp4 choisi en mémoire (ou URL externe)
        ▼
video-agency-pipeline (Edge Function)
        │  texte uniquement : decorticage, srt, hooks, copy  ──► PostgreSQL
        └─ flux binaire direct ──► YouTube Data v3 (privé)
                                └─► TikTok Content Posting (brouillon)
```

Aucun bucket, aucun fichier vidéo dans Supabase. Seuls des textes (jsonb/text)
sont conservés, ce qui reste compatible avec le plan gratuit.
