# Rapport de finitions — 24/11/2026

## 1. UI / navigation / vitrine

- Hiérarchie des boutons : un seul `OrButton` plein par carte/écran, actions
  secondaires transparentes à bordure fine avec survol (`lib/core/theme.dart`).
- Header desktop : seuil desktop à 1020 px, liens sans `ellipsis`, libellés
  complets « La Boutique », « Studio Live », « Guide & Tutoriel »
  (`lib/widgets/app_header.dart`).
- Accueil : vitrine animée avec cycle question client → réponse IA → lien de
  paiement → commande confirmée, et sélecteur **Caméra Produits / Partage
  d'Écran** (`lib/pages/home_page.dart`).

## 2. Essai gratuit Studio Live

- Modale d'inscription/connexion avant l'essai (`lib/widgets/auth_essai_dialog.dart`).
- **Inscription native Supabase Auth** : le compte est créé par `signUp`, l'email
  de confirmation part via le **SMTP Supabase** configuré (Resend). L'utilisateur
  doit confirmer son email avant de pouvoir démarrer l'essai.
- L'ancien contournement `auth-signup` n'est plus utilisé par l'application.
  La fonction reste temporairement déployée pour l'ancien build Netlify, puis
  pourra être supprimée après le déploiement du flux natif.
- Démarrage de l'essai via RPC `demarrer_essai_studio()` : un seul essai,
  3 jours exacts, email confirmé, aucune prolongation.
- Nouvelle source de vérité : `public.live_subscriptions`
  (`is_trial`, `trial_started_at`, `trial_ends_at`), migration
  `20260101000700_essais_gratuits_et_rendu_livres.sql`. L'ancienne table
  `studio_trials` est conservée et reprise pour compatibilité.
- Décompte `2 j 14 h` / `3 h 12 min` rafraîchi chaque minute dans la page et la
  régie (`EssaiStudio.compteARebours`).
- Compteur admin : `admin_compter_essais_gratuits()` + carte dans
  `/admin-videos`.
- Email Resend : `welcome-email` envoie le message d'accueil / d'activation
  d'essai et journalise dans `welcome_emails`.

> ⚠️ **SMTP Supabase** : les logs Auth ont montré
> `dial tcp: lookup stmp.resend.com ... no such host`. Le host configuré contient
> une faute (`stmp` au lieu de `smtp`). Corriger dans
> **Supabase → Authentication → Emails → SMTP Settings** :
> `smtp.resend.com`, port `465`, user `resend`, mot de passe = clé API Resend,
> expéditeur vérifié. Tant que cette faute est présente, `signUp` renvoie 500
> « Error sending confirmation email ».

### Résultats réels

- `auth-signup` HTTP **200** (ancien contournement, conservé uniquement pour
  l'ancien build en ligne).
- **SMTP Supabase corrigé** : hôte `smtp.resend.com`.
- Test `signUp` natif : **HTTP 200**, `session: null` → email de confirmation
  envoyé (test avec `delivered@resend.dev`).
- Les adresses de test `@example.com` sont refusées par Resend
  (`550 Invalid to field`) : utilisez une vraie adresse pour tester.
- Une fois le host corrigé, le flux est : `signUp` → email de confirmation
  Supabase/SMTP → clic → `signInWithPassword` → essai.
- Les tests de trial ci-dessous ont été validés avec un compte confirmé :
- Premier `demarrer_essai_studio` HTTP **200** ; deuxième HTTP **400 P0001**
  (« déjà utilisé »).
- `live_subscriptions` : durée mesurée **3 days**.
- `acces_studio()` et `essai_studio_actif()` : **true**.
- `admin_compter_essais_gratuits()` : **200** avec total/actifs.
- `live-auto-chat` après 20 réponses IA : **429** avec message d'abonnement.
- Données de test supprimées (utilisateur auth, session, essai, email).

## 3. Rendu éditorial des livres et guides

- `view-kit` : couverture bleu nuit / or / émeraude, badges secteur/pays,
  illustrations SVG avant chaque chapitre, encadrés « Conseil Pro »,
  checklists, typographie éditoriale, boutons Imprimer/PDF et
  Télécharger HTML.
- Prompts : cartes éditoriales avec bouton « Copier le prompt ».
- Sheet : tableau complet (ventes, stocks, marges, seuil de rentabilité),
  téléchargement CSV/Excel et copie Google Sheets.
- `generate-live-guide` : couverture, illustrations SVG, conseils Pro.
- Guide en régie : bouton « ← Retourner dans ma régie Studio Live » en haut et
  en bas de l'onglet.
- Email de livraison : liens vers le livre, les prompts et le tableau.

### Résultats réels

- `view-kit` POST : **200**, `Content-Type: text/html; charset=utf-8`,
  `Content-Disposition: inline`, **7 SVG**, accents français intacts.
- Prompts POST : **200**, **8 SVG**, cartes/scripts de copie.
- Sheet POST : **200**, table + boutons CSV + copie.
- Guide généré : **200**, `guide-cover`, **10 illustrations**, **7 Conseils Pro**,
  accents intacts.

> **Limite Supabase** : les réponses **GET** `text/html` sont réécrites en
> `text/plain` sur le domaine `functions.supabase.co`. `view-kit` redirige donc
> les GET vers `/kit.html`, page statique qui POSTe vers la fonction ; le POST
> conserve `text/html; charset=utf-8` et `Content-Disposition: inline`.
> Le build web contient `kit.html` ; **il doit être déployé sur Netlify**.

## 4. Supabase / déploiement

- Migration appliquée : `20260101000700_essais_gratuits_et_rendu_livres.sql`.
- **17 Edge Functions** déployées (dont `auth-signup`, conservé temporairement pour l'ancien build) : `view-kit`, `welcome-email`,
  `generate-kit`, `generate-live-guide`, `live-auto-chat`, `studio-room`,
  `paddle-webhook`, `saspay-webhook`, `verify-payment`.
- `RESEND_FROM_EMAIL` corrigé : le secret contenait `e-nooklive` (faute de
  frappe) ; remplacé par `e-booklive <bonjour@e-booklive.offboard-hub.com>`.
  Resend répond désormais **200**.
- Journal `welcome_emails` vérifié : ligne `delivered@resend.dev`,
  source `essai`, `envois = 1`.

## 5. Vérifications Flutter

| Commande | Résultat |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **39/39 passés** |
| `flutter build web --release` | **√ Built build\web** |
| `deno check` toutes fonctions | **0 erreur** |

Tests ajoutés : accueil desktop/mobile (nav complète, vitrine, sélecteur),
`live_subscriptions` / décompte, essai, accès, guide pendant essai.

## 6. À faire avant `git push`

1. Déployer Netlify : le build contient `kit.html`, les nouveaux textes et la
   vitrine ; sans ce déploiement le viewer `view-kit` et l'UI ne sont pas en
   ligne.
2. Vérifier dans Resend que `e-booklive.offboard-hub.com` est bien vérifié
   (l'envoi test 200 confirme le domaine, mais gardez-le vérifié).
3. Faire un test visuel navigateur du checkout Paddle/SasPay et de la modale
   d'essai (aucun navigateur n'était disponible dans cette session).
4. Ne pas modifier le flux payant Paddle/SasPay : il n'a pas été touché.
5. `git status` : aucun commit effectué.
