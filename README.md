# e-booklive — La Boutique & Studio Live

Plateforme **Flutter Web + Supabase** pour les entrepreneurs : des **kits business
sur mesure** par métier (La Boutique) et un **studio de vente en direct** avec
chat IA et Livre Guide (Studio Live).

> Positionnement : deux univers clairs, des prix convertis dans la devise du pays,
> un paiement local ou international, une livraison immédiate.

---

## Les deux univers

### 1. La Boutique — kits métiers
Parcours en 2 étapes : choix du secteur (8 métiers ou « Autre métier »), puis choix
du kit, du pays et paiement. L'IA (DeepSeek + Gemini) génère un livre stratégique,
des prompts et un tableau de gestion, livrés par email (Resend).

| Kit | Prix de référence |
|---|---|
| Prompts IA | 3 000 FCFA |
| Sheet Automatisé | 3 500 FCFA |
| Livre Stratégique | 5 000 FCFA |
| Pack Complet *(le plus choisi)* | 9 000 FCFA |

### 2. Studio Live — essai 3 jours, puis 10 USD / 30 jours
- **Essai gratuit 3 jours**, sans carte ni paiement : régie, co-animateur et chat IA
  (20 messages IA/jour). Le Livre Guide reste réservé aux abonnés payants.
- Un seul essai par utilisateur, email confirmé requis, jamais prolongeable.
- **Abonnement 10 USD / 30 jours** (bouton « S'abonner maintenant : 10 USD / 30 jours »),
  converti dans la devise du pays et encaissé par SasPay ou Paddle.
- Régie en 3 onglets :
- **Préparer mon Live** : plateformes (salle e-booklive, TikTok, YouTube, Instagram),
  format solo/duo, caméra produits ou partage d'écran, Fiche Produit IA.
- **Salle en direct** : Jitsi Meet IFrame API, contrôles micro/caméra/partage,
  chat IA temps réel (Supabase Realtime) et bouton « Copier en 1 clic ».
- **Mon Livre Guide Live** : guide personnalisé généré après paiement, envoyé par
  email et téléchargeable.

Lien co-animateur : `/live/:roomId?invite=<token>` — le spectateur rejoint via
`/live/:roomId`.

---

## Paiements & devises

- **23 pays SasPay** en devise locale : XOF (ML, SN, CI, BF, BJ, TG, NE), XAF (CM,
  GA, CG), CDF (CD), GNF (GN), NGN (NG), GHS (GH), SLE (SL), KES (KE), UGX (UG),
  TZS (TZ), RWF (RW), MWK (MW), MZN (MZ), ZMW (ZM), INR (IN).
- **Reste du monde : Paddle** en **USD par défaut**, TVA gérée,
  conversion locale indicative.
- Le montant est **toujours recalculé côté serveur** ; aucun prix client n'est
  accepté. Les price IDs Paddle sont configurés par secrets (`PADDLE_PRICE_*`).

---

## Routes

| Route | Page |
|---|---|
| `/` | Accueil (2 univers) |
| `/boutique` | La Boutique en 2 étapes |
| `/studio-live` | Présentation Studio Live + souscription |
| `/studio/regie` | Régie abonné (3 onglets) |
| `/live/:roomId` | Salle publique / co-animateur |
| `/guide` | Guide & Tutoriel en 3 étapes |
| `/assistant` | Assistant IA plein écran |
| `/mon-espace` | Compte / commandes |
| `/admin-videos` | Admin uniquement (`is_admin` ou `ADMIN_EMAILS`) |
| `/cgv`, `/mentions-legales`, `/faq` | Pages légales |

URL propres (path strategy) ; Netlify réécrit `/*` vers `index.html`.

---

## Stack & structure

```
lib/
  core/        countries.dart, pricing.dart, models.dart, app_state.dart, theme.dart
  pages/       home, boutique, studio_live, studio_regie, live_room, guide,
               assistant, paiement_en_attente, splash, admin_guard, légal
  services/    api.dart, checkout_ouverture, jitsi_view, paddle_checkout,
               telechargement, stockage_pays, url_strategy
  widgets/     logo_ebooklive, app_header, country_picker, site_assistant_chat
supabase/
  functions/   * 16 Edge Functions (voir DEPLOIEMENT.md)
  migrations/  20260101000500_paddle_et_studio_live.sql
               20260101000600_studio_essai_gratuit.sql
web/           index.html (splash SVG), favicon.svg, manifest, icônes
test/          pricing_test, models_test, widget_test
docs/          architecture, plan, revues DB/code, vérification build
```

- **Design** : fond `#090D16`, verre `#111827`, dégradé or → émeraude,
  logo vectoriel CustomPainter + SVG miroir.
- **État global** : `CountryStore` (pays persisté, prix partout), `AssistantState`
  (conversation partagée bulle / pleine page).
- **Sécurité** : RLS sur les tables Studio, écritures service_role uniquement,
  index uniques anti-rejeu paiement, webhooks signés (SasPay/Paddle), admin-check.

---

## Développement

Prérequis : Flutter 3.47.9+, Dart 3.13+, Node 20+ (outils), Supabase CLI.

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/
```

Lancer en local :

```bash
flutter run -d chrome \
  --dart-define=SITE_URL=http://localhost:3000 \
  --dart-define=WHATSAPP_AIDE_NUMBER=22670123456
```

La configuration Supabase (URL + clé publishable) est dans `lib/core/config.dart`.

---

## Déploiement

Tout est détaillé dans [`DEPLOIEMENT.md`](DEPLOIEMENT.md) :
1. appliquer les migrations (`supabase db push`) ;
2. déployer les 16 Edge Functions (`supabase functions deploy`) ;
3. renseigner les secrets (SasPay, Paddle + price IDs, Resend, DeepSeek, Gemini) ;
4. configurer le webhook Paddle et le webhook SasPay ;
5. vérifier `flutter analyze`, `flutter test`, `flutter build web --release` ;
6. déployer sur Netlify (build command dans `netlify.toml`).

Points de vigilance avant production :
- créer les **price IDs Paddle USD** et les renseigner ;
- dédoublonner `saspay_payment_id` avant l'index unique ;
- tester la CSP Netlify en préproduction (CanvasKit local + Jitsi + Paddle) ;
- trancher le risque F03 (accès régie par email sans confirmation d'email).

---

## Documentation

- [`docs/ARCHITECTURE_REFONTE.md`](docs/ARCHITECTURE_REFONTE.md) — contrat front/back/DB.
- [`docs/PLAN_REFONTE.md`](docs/PLAN_REFONTE.md) — plan et matrice d'acceptation.
- [`docs/REVUE_DB.md`](docs/REVUE_DB.md) — revue RLS/migration et contre-revue.
- [`docs/REVUE_CODE.md`](docs/REVUE_CODE.md) — revue code/sécurité et contre-revue.
- [`docs/BUILD_VERIFICATION.md`](docs/BUILD_VERIFICATION.md) — artefacts et release.
- [`docs/PADDLE_SANDBOX_TEST.md`](docs/PADDLE_SANDBOX_TEST.md) — audit sandbox et procédure de test Paddle.
- [`docs/tests_rls_studio.sql`](docs/tests_rls_studio.sql) — tests RLS manuels.
