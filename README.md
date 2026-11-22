# 🚀 Kit Business — kits métiers clés en main pour l'Afrique francophone

Application **Flutter Web + Supabase** qui vend des kits business générés par IA,
**exclusivement en FCFA**, à des entrepreneurs de Côte d'Ivoire, du Sénégal, du Mali,
du Cameroun, du Burkina Faso, du Bénin, du Togo, du Gabon, du Niger, du Tchad, du Congo,
de Centrafrique, de Guinée-Bissau et de Guinée Équatoriale.

> Positionnement : un secteur choisi en **1 clic**, un nom de projet, un pays, un
> numéro WhatsApp — et le client reçoit immédiatement son livre stratégique, ses
> prompts IA et son Google Sheet automatisé.

---

## 💰 Offres (100 % FCFA — plus aucun prix en dirham)

| Offre | Prix | Contenu |
|---|---|---|
| **Prompts IA** | **3 000 FCFA** | 10 prompts d'élite prêts à copier |
| **Sheet Automatisé** | **3 500 FCFA** | Google Sheet : ventes, stocks, marges, point mort |
| **Livre Stratégique** | **5 000 FCFA** | Plan d'action complet, adapté au pays |
| **Pack Complet** *(le plus choisi)* | **9 000 FCFA** | Livre + prompts + Google Sheet |

## 🧩 Les 6 kits métiers

🍲 Restaurant / Maquis · 🛍️ Boutique E-commerce + livraison · 🌾 Élevage / Agriculture
💅 Salon de Beauté · 💼 Agence de Services · 🏦 Dossier de Financement

---

## ✨ Fonctionnalités

- **Tunnel de commande visuel** : kit métier → offre → nom du projet, pays, WhatsApp,
  précisions facultatives. Aucun formulaire libre.
- **Paiement exclusif SasPay** (mobile money + carte) en XOF / XAF. YouCan Pay,
  Paddle et PaySaS ont été retirés. Le montant est toujours calculé côté serveur.
- **Livraison automatique par email** : dès que `verify-payment` valide le paiement,
  le kit est généré (Gemini + DeepSeek + Google Sheets) puis envoyé par
  **email (Resend)** et affiché immédiatement sur la page de confirmation.
- **Email d'accueil Resend** sans lien de confirmation, à l'inscription et au checkout.
- **Bouton « Aide WhatsApp »** (simple lien `wa.me`, aucun envoi automatique).
- **Assistant IA du site** (bulle de chat DeepSeek) : il connaît l'offre, répond aux
  spectateurs des Lives OBS et redirige vers le lien d'achat SasPay.
- **Notes & Avis de nos clients** : note de 1 à 5 étoiles et commentaire publiés
  depuis la page d'accueil (table `avis_site` protégée par RLS).
- **Robot YouTube Live** : lit le `liveChatId`, répond toutes les 10 secondes avec
  le lien du site.
- **Agence Vidéo IA `/admin-videos`** : 4 agents (décortiqueur, sous-titres & hooks,
  copywriter multi-réseaux, distributeur) et **zéro stockage Supabase** : seuls les
  textes sont enregistrés, le `.mp4` part directement vers YouTube (privé) et TikTok
  (brouillon). Un bouton **« Connecter TikTok »** réalise l'OAuth sans curl : le retour
  sur `SITE_URL/?code=...` échange le code et stocke les jetons côté serveur.

---

## 🏗️ Structure

```
lib/
  main.dart                     Entrée, thème, routes (/commande, /mon-espace, /admin-videos…)
  core/
    config.dart                 Tarifs FCFA, 6 kits métiers, 14 pays, liens
    models.dart                 Modèles API (checkout, liens, livraison, vidéo, avis)
    theme.dart                  Palette, motif bogolan, composants partagés
    links.dart                  Ouverture de liens externes
  services/
    api.dart                    Appels Edge Functions + base Supabase
    video_picker*.dart          Sélection vidéo (web via package:web, stub hors web)
  widgets/
    app_header.dart             En-tête + bouton Aide WhatsApp
    site_assistant_chat.dart    Bulle de chat IA
    whatsapp.dart               Boutons WhatsApp
  pages/
    landing_page.dart           Accueil, tarifs, kits, pays, notes & avis clients
    commande_page.dart          Tunnel + attente de paiement
    confirmation_page.dart      Liens de livraison + état de l'envoi email
    auth_page.dart              Connexion / inscription automatique
    dashboard_page.dart         Espace client (commandes, kits, régénération)
    admin_videos_page.dart      /admin-videos
    legal_pages.dart            CGV, mentions légales, FAQ

supabase/
  config.toml                   Configuration des 10 Edge Functions
  migrations/                   Schéma SQL (base, commandes/assistant/vidéo, avis)
  functions/
    _shared/                    config, SasPay, moteur de kit, livraison, IA, fulfillment
    saspay-checkout/            Création commande + session de paiement
    verify-payment/             Vérification SasPay + génération + livraison
    saspay-webhook/             Webhook signé + livraison idempotente
    generate-kit/               Régénération avec crédits
    view-kit/                   Consultation / PDF protégé par jeton
    welcome-email/              Email d'accueil Resend
    site-assistant/             Chat IA DeepSeek (bulle du site)
    youtube-live-bot/           Robot chat YouTube Live
    video-agency-pipeline/      Agence vidéo (4 agents + distribution)
    tiktok-auth/                OAuth TikTok (start / callback / status / disconnect)
```

---

## 🚦 Démarrage local

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SITE_URL=http://localhost:5000 \
  --dart-define=WHATSAPP_AIDE_NUMBER=22670123456
```

Fonctions en local (nécessite Docker) :

```bash
supabase start
supabase functions serve --env-file supabase/.env
```

> Les Edge Functions appellent les APIs externes : sans clés valides, la génération
> échouera mais l'interface et le tunnel restent testables.

---

## 🧪 Vérifications

```bash
flutter analyze     # 0 erreur
flutter test        # tests unitaires + widgets (accueil, tunnel mobile)
flutter build web --release
```

---

## 🔐 Secrets et mise en production

Tout est détaillé dans **[DEPLOIEMENT.md](DEPLOIEMENT.md)** : liste complète des
secrets Supabase, configuration SasPay / Resend / Google / YouTube / TikTok,
déploiement des fonctions, puis GitHub et Netlify.

---

## 📌 Règles à ne pas casser

1. **Tarifs en FCFA uniquement** — jamais de DH ni d'USD affiché.
2. **SasPay uniquement** — aucune autre solution de paiement.
3. **Aucun fichier vidéo dans Supabase Storage** — métadonnées texte seulement.
4. **La livraison n'a lieu qu'après un statut SasPay `SUCCESS`**, et une seule fois.
5. **Aucune clé secrète dans Flutter ni dans Git** — seulement la clé *publishable*.

© Kit Business — Offboard-Hub
