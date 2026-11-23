# VÉRIFICATION BUILD & RELEASE — e-booklive

**Vérificateur** : build-error-resolver (équipe ECC)
**Date** : 2026-11-23
**Périmètre** : artefacts `build/web`, `netlify.toml`, `supabase/config.toml`, sources `web/` + `lib/`
**Mode** : vérification indépendante, **aucune modification du code applicatif** (seul ce document a été créé).

---

## 1. Verdict global

| # | Point | Statut |
|---|-------|--------|
| 1 | `build/web/index.html` : splash e-booklive, ponts JS, bootstrap, métadonnées | ✅ |
| 2 | Artefacts présents et non vides (manifest, favicon, icônes, JS, SW) | ✅ |
| 3 | Cohérence `AssetManifest*` / `FontManifest.json` | ✅ |
| 4 | `netlify.toml` : redirect SPA, headers, CSP, cache | ⚠️ **1 faille bloquante** (CanvasKit / gstatic) |
| 5 | Pas d'ancien branding « Kit Business », pas de 🚀, pas de script tiers au boot | ✅ |
| 6 | `supabase/config.toml` vs `supabase/functions/*` | ❌ **TOML invalide** (5 tables dupliquées) |
| 7 | Erreurs de build évidentes (pages supprimées, imports, `flutter_web_plugins`) | ✅ |
| 8 | Re-exécution `flutter analyze` / `test` | ⚠️ Non exécutable ici (Flutter absent) — vérifs statiques indépendantes à la place |

**Conclusion : NE PAS DÉPLOYER en l'état.** 3 actions bloquantes (CSP/CanvasKit, `config.toml`, code non commité) + 2 prérequis de mise en service (secrets Paddle, migration).

> **Addendum lead (23/11 00:31) — P0 #1 et #2 corrigés.**
> - `netlify.toml` : build avec `--dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/` ; CSP élargie à `www.gstatic.com` / `fonts.gstatic.com` (sécurité + polices emoji) et `frame-ancestors 'self'`. Le bundle final référence bien `/canvaskit/` local (`main.dart.js` : `canvasKitBaseUrl == null ? "/canvaskit/"`).
> - `supabase/config.toml` : doublons supprimés ; `python tomllib` → **TOML valide, 16 fonctions**.
> - `flutter analyze` → `No issues found!` (exit 0) ; `flutter test` → **24/24** (exit 0) ; `flutter build web --release --no-wasm-dry-run --dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/` → `√ Built build\web` (exit 0).
> - Reste P0 #3 : la refonte n'est pas commitée (à faire par le lead avant push Netlify) ; secrets Paddle et migration toujours à appliquer.

---

## 2. Détail par point

### ✅ 1. `build/web/index.html`

`build/web/index.html` (19 250 o) est **identique octet pour octet** à `web/index.html` (19 267 o) après normalisation de `<base href="$FLUTTER_BASE_HREF">` → `<base href="/">` (vérifié par comparaison normée : 19 189 == 19 189 caractères).

| Élément attendu | Présent | Emplacement |
|---|---|---|
| Splash e-booklive (SVG badge/livre/ondes, wordmark `e-booklive.`, barre de progression, messages, sortie sur `flutter-first-frame`) | ✅ | `#splash-screen` L81–331, L335–422, script L483–555 |
| Pont `window.ebookliveJitsi` (`create`/`command`/`dispose`) | ✅ | L435–458 |
| Pont `window.ebooklivePaddle` (`open`) | ✅ | L463–478 |
| `<script src="flutter_bootstrap.js" async>` | ✅ | L557 (1 seule balise `<script src>`) |
| Titre `e-booklive — La Boutique & Studio Live` | ✅ | L14 |
| `theme-color` = `#090D16` + `color-scheme: dark` | ✅ | L8–9 |
| Favicon SVG (`favicon.svg`) + apple-touch-icon 192 | ✅ | L31–32 |
| `manifest.json` | ✅ | L33 |
| OG/Twitter/JSON-LD/canonical | ✅ | L18–45 |
| `lang="fr"`, noscript, media query `prefers-reduced-motion` | ✅ | L2, L424–429, L322–330 |

SHA-256 de `build/web/index.html` : `E74E69728DC56277F7C28F4B909BA25C0220B8C450882CE6059695AF618E14C1`

### ✅ 2. Artefacts

| Fichier | Taille | Contrôle |
|---|---|---|
| `manifest.json` | 1 045 o | JSON valide, UTF-8 sans BOM, `theme_color`/`background_color` = `#090D16`, `display: standalone`, 5 icônes |
| `favicon.svg` | 2 037 o | XML/SVG bien formé, `viewBox="0 0 96 96"` |
| `favicon.png` | 3 009 o | PNG 64×64, signature valide |
| `icons/Icon-192.png` | 11 156 o | **192×192** ✅ |
| `icons/Icon-512.png` | 44 492 o | **512×512** ✅ |
| `icons/Icon-maskable-192.png` / `-512.png` | 11 156 / 44 492 o | 192×192 / 512×512, `purpose: maskable` |
| `icons/logo-ebooklive.svg` | 1 871 o | SVG bien formé `0 0 96 96` |
| `main.dart.js` | **4 300 050 o (4,10 Mo)** | bundle release dart2js présent |
| `flutter_service_worker.js` | 815 o | présent (voir note) |
| `flutter_bootstrap.js` | 13 091 o | buildConfig + `_flutter.loader.load` |
| `flutter.js` | 12 136 o | loader |
| `version.json` | 102 o | `1.0.0+1` |
| `canvaskit/` (12 fichiers) | 25,11 Mo | dont `canvaskit.js` + `canvaskit.wasm` **locaux** |
| **`build/web` total** | **41,76 Mo / 43 fichiers** | |

Note : `flutter_service_worker.js` est le stub de dépréciation de Flutter (il appelle `self.registration.unregister()`). C'est le comportement attendu en 3.4x → **pas de cache hors-ligne PWA**, mais le fichier existe et répond au `serviceWorkerVersion` `2431533486` du bootstrap.

Note : `version.json` expose `"app_name":"kit_business_app"` — identifiant technique, non visible dans l'UI (voir §5, résidus).

### ✅ 3. Manifestes d'assets

- `assets/AssetManifest.json` **absent** : c'est normal — le manifeste JSON a été retiré par Flutter (≥ 3.19) au profit de `AssetManifest.bin`.
- `assets/AssetManifest.bin` (319 o) + `assets/AssetManifest.bin.json` (430 o) présents et cohérents. Décodage : **3 assets attendus, 3 présents sur disque** :
  - `packages/cupertino_icons/assets/CupertinoIcons.ttf` → 2 460 o ✅
  - `packages/material_ui/shaders/ink_sparkle.frag` → 8 890 o ✅
  - `packages/wakelock_plus/assets/no_sleep.js` → 13 669 o ✅
- `assets/FontManifest.json` (208 o) : 2 familles — `MaterialIcons` → `fonts/MaterialIcons-Regular.otf` (25 256 o ✅) et `CupertinoIcons` → `packages/cupertino_icons/...` (✅).
- **Aucun asset manquant.** Le `pubspec.yaml` ne déclare aucune section `assets:` et le code n'utilise ni `Image.asset`, ni `AssetImage`, ni `rootBundle` (grep sur `lib/` : 0 occurrence) → aucun risque d'asset 404 au runtime.

### ⚠️ 4. `netlify.toml` — 1 défaut bloquant

| Contrôle | Statut |
|---|---|
| `publish = "build/web"`, commande `flutter build web --release` + `--dart-define SITE_URL / WHATSAPP_AIDE_NUMBER` | ✅ |
| Redirect SPA `from = "/*"` → `to = "/index.html"` `status = 200` | ✅ (Netlify sert les fichiers existants en priorité) |
| `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` (camera/micro/display-capture/fullscreen + `meet.jit.si`) | ✅ |
| `Permissions-Policy` autorise Jitsi | ✅ |
| `Cache-Control: no-cache` sur `/index.html` et `/flutter_service_worker.js` | ✅ |
| CSP ne bloque pas `flutter_bootstrap.js` | ✅ (`script-src 'self'` + `async` same-origin) |
| CSP autorise Supabase | ✅ `connect-src https://*.supabase.co wss://*.supabase.co` |
| CSP autorise Jitsi | ✅ `script-src` + `frame-src` + `connect-src`/`wss` `https://meet.jit.si` |
| CSP autorise Paddle | ✅ `script-src https://cdn.paddle.com`, `frame-src https://*.paddle.com`, `connect-src api.paddle.com` + `sandbox-api.paddle.com` |
| CSP autorise blob/worker (Flutter, téléchargements, photos) | ✅ `worker-src 'self' blob:`, `img-src blob: data: https:`, `media-src blob:`, `'wasm-unsafe-eval'` |
| **CSP autorise le CanvasKit effectivement chargé** | ❌ **NON — voir ci-dessous** |

#### ❌ BLOQUANT — la CSP interdit la source CanvasKit réellement utilisée

Preuve (analyse du bundle livré) :

```
build/web/flutter_bootstrap.js:
  _flutter.buildConfig = {"engineRevision":"89c39edfdfae2949f6806e4a315c0c08522238b7",
                          "wasmHashes":{...},
                          "builds":[{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}]}
  _flutter.loader.load({ serviceWorkerSettings: { serviceWorkerVersion: "2431533486" } });
```

`buildConfig` ne contient **ni `canvasKitBaseUrl`, ni `useLocalCanvasKit`**. Le loader applique donc sa règle par défaut :

```js
canvasKitBaseUrl = cfg.canvasKitBaseUrl ? cfg.canvasKitBaseUrl
  : (buildConfig.engineRevision && !buildConfig.useLocalCanvasKit
      ? "https://www.gstatic.com/flutter-canvaskit/<engineRevision>"
      : "canvaskit");
```

→ **URL runtime = `https://www.gstatic.com/flutter-canvaskit/89c39…/canvaskit.js` + `canvaskit.wasm`** (la même URL est aussi compilée en dur dans `main.dart.js`, ainsi que `https://fonts.gstatic.com/s/` pour les polices de repli).

Or la CSP ne contient `www.gstatic.com` **ni dans `script-src`, ni dans `connect-src`**, et pas `fonts.gstatic.com` dans `font-src`/`connect-src`. Conséquence en production : `canvaskit.js` puis `canvaskit.wasm` sont bloqués → le moteur ne s'initialise pas → le splash reste affiché puis l'erreur « Le chargement prend plus de temps que prévu » apparaît au bout de 22 s. **Le build est bon, mais la page déployée serait blanche/cassée.**

**Deux corrections possibles (au choix)** — recommandation : la n°1 (garde la CSP stricte, les fichiers sont déjà dans l'artefact) :

1. *Servir CanvasKit localement* — `build/web/canvaskit/` (25,11 Mo) existe déjà. Ajouter au `[build]` de `netlify.toml` :
   `--dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/` (ou `--no-web-resources-cdn` selon la version du SDK), puis **rebuild** pour que `buildConfig.canvasKitBaseUrl` soit renseigné.
2. *Assouplir la CSP* — ajouter `https://www.gstatic.com` à `script-src` **et** `connect-src`, et `https://fonts.gstatic.com` à `font-src` + `connect-src`.

Dans les deux cas, ajouter `https://fonts.gstatic.com` à `connect-src`/`font-src` (polices de repli CanvasKit ; non bloquant pour du texte latin, mais évite des avertissements console).

#### ⚠️ Recommandations non bloquantes `netlify.toml`

- Aucune règle de cache long pour les assets statiques : ajouter `[[headers]] for = "/assets/*"`, `/icons/*`, `/canvaskit/*` avec `Cache-Control = "public, max-age=31536000, immutable"`. **Ne pas** mettre `main.dart.js`, `flutter.js` ou `flutter_bootstrap.js` en cache long : ces noms ne sont pas hashés par Flutter.
- Ajouter `frame-ancestors 'self'` à la CSP (X-Frame-Options est legacy).
- Si un jour Paddle.js fait des appels XHR depuis la page parente, prévoir `https://*.paddle.com` dans `connect-src` (aujourd'hui l'overlay est en iframe → couvert par `frame-src`).
- `FLUTTER_VERSION = "3.47.9"` dans `[build.environment]` : version non vérifiable hors-ligne (Flutter absent de cet environnement) — à confirmer sur une release publiée avant le premier déploiement, sinon le build Netlify échouera. Le plugin `netlify-plugin-flutter` est ancien : à valider lors du premier build distant.

### ✅ 5. Branding, emoji, scripts tiers

| Contrôle | `web/index.html` | `build/web/index.html` |
|---|---|---|
| « Kit Business » (casse exacte) | 0 | 0 |
| `kit_business` | 0 | 0 |
| Emoji 🚀 (U+1F680) | 0 | 0 |
| Balises `<script src>` | 1 : `flutter_bootstrap.js` (async) | idem |
| Chargement Jitsi au boot (`meet.jit.si`) | 0 | 0 |
| Chargement Paddle au boot (`cdn.paddle.com`) | 0 | 0 |
| Ponts `ebookliveJitsi` / `ebooklivePaddle` | 1 / 1 | 1 / 1 |

Seule occurrence de « kit business » : dans `meta keywords` (L16), en minuscules et à visée SEO générique — pas le nom du produit, acceptable.

Chargement à la demande **confirmé côté code** :
- `lib/services/jitsi_view_web.dart:169-183` — `external_api.js` injecté seulement à l'ouverture de la régie (avec repli iframe direct `https://meet.jit.si/<salle>`).
- `lib/services/paddle_checkout_web.dart:31-45` — `paddle.js` injecté seulement au moment du checkout.

### ❌ 6. `supabase/config.toml` — TOML invalide

- Dossiers `supabase/functions/*` : **17** dont **16 fonctions** + `_shared` (pas une fonction). Les 16 ont bien un `index.ts` et un `serve(...)` (16/16). Aucun dossier sans entrée.
- `config.toml` déclare **16 fonctions uniques** (donc le compte 11 + 5 + `admin-check` est bon) **mais 5 tables sont définies deux fois** :

```
[functions.create-paddle-checkout]   L34  et  L89
[functions.paddle-webhook]           L39  et  L94
[functions.generate-live-guide]      L44  et  L99
[functions.live-auto-chat]           L49  et  L104
[functions.studio-room]              L54  et  L109
```

Validation stricte (TOML 1.0) :

```
TOMLDecodeError: Cannot declare ('functions', 'create-paddle-checkout') twice (at line 89, column 34)
```

Le CLI Supabase (même norme TOML) refusera ce fichier → `supabase functions deploy …` / `supabase db push` / `supabase start` échouent. **Correction** : supprimer le second bloc, lignes **89–112** (les 5 doublons), en gardant `[functions.admin-check]` (L114–117). Non corrigé ici (hors périmètre autorisé).

Fonctions ↔ dossiers : `admin-check`, `create-paddle-checkout`, `generate-kit`, `generate-live-guide`, `live-auto-chat`, `paddle-webhook`, `saspay-checkout`, `saspay-webhook`, `site-assistant`, `studio-room`, `tiktok-auth`, `verify-payment`, `video-agency-pipeline`, `view-kit`, `welcome-email`, `youtube-live-bot` → **16/16 alignés**.
`import_map` déclaré pour `generate-kit`, `verify-payment`, `view-kit` → les 3 `deno.json` existent (136 o chacun, identiques).
`project_id = "ynephuutnazdnjhsdlsy"` cohérent avec `supabase/.temp/project-ref` ✅ (projet nommé `kit-business-v2` côté Supabase → résidu, §5).

### ✅ 7. Erreurs de build évidentes

| Contrôle | Résultat |
|---|---|
| Références à `landing_page` / `commande_page` / `LandingPage` / `CommandePage` | **0** (grep `lib/`, `test/`, `web/`) ; `git status` montre bien `D lib/pages/landing_page.dart` et `D lib/pages/commande_page.dart` |
| Imports cassés (Dart) | **184 imports/exports/parts relatifs et `package:kit_business_app/...` résolus, 0 non résolu** (scan indépendant de `lib/` + `test/`) |
| Imports relatifs TypeScript (Edge Functions) | **94 résolus, 0 non résolu** |
| `pubspec.yaml` : `flutter_web_plugins` | ✅ L33–34 (`sdk: flutter`) |
| Dépendance `web` (package:web) | ✅ `web: ^1.1.0` ; aucun `dart:html` résiduel (6 fichiers `*_web.dart` utilisent `dart:js_interop` + `package:web/web.dart`) |
| Conditionnels `*_stub.dart` / `*_web.dart` | présents et résolus (`nettoyage_url`, `stockage_pays`, `url_strategy`, `jitsi_view`, `paddle_checkout`, `telechargement`, `video_picker`) |
| `localhost` / `127.0.0.1` dans `main.dart.js` | 0 |
| Contenu du bundle à jour | `main.dart.js` (compilé 22:58:37) contient bien les littéraux de la version courante de `api.dart` (`metier_label`, `create-paddle-checkout`, `subscription_id`, `admin-check`) alors que `api.dart` a un mtime postérieur (23:00:49) → **pas de dérive fonctionnelle**, mais un rebuild avant tag reste prudent |

### ⚠️ 8. Re-exécution `flutter analyze` / `flutter test`

`flutter` et `dart` ne sont **pas installés** dans cet environnement (`where flutter` → vide ; `flutter --version` → exit 1). Impossible de relancer `analyze`/`test`/`build` ici. La vérification s'appuie donc sur :

1. les logs du lead (`analyze` 0 issue, 24 tests, `build web` OK, `deno check` OK) — non rejoués ;
2. des contrôles statiques indépendants équivalents : résolution de tous les imports, absence d'assets référencés manquants, absence de références aux pages supprimées, bundle release complet et cohérent, 16/16 entrypoints `serve()`.

À rejouer hors sandbox pour lever le doute : `flutter analyze`, `flutter test`, puis **rebuild après correction CSP** (§4).

---

## 3. Commandes exécutées

```powershell
# Inventaire / tailles
Get-ChildItem build\web -Recurse -File | Measure-Object Length -Sum     # 41,76 Mo / 43 fichiers
Get-FileHash build\web\index.html -Algorithm SHA256

# Cohérence web/ <-> build/web/
# (comparaison normée : remplacement de $FLUTTER_BASE_HREF par "/") -> identique (19 189 car.)

# Validation artefacts (Python 3.13)
python -c "import json; json.load(open('build/web/manifest.json'))"            # OK, UTF-8 sans BOM
python -c "import struct; struct.unpack('>II', open('build/web/icons/Icon-512.png','rb').read()[16:24])"  # 512x512
python -c "import xml.etree.ElementTree as ET; ET.parse('build/web/favicon.svg')"                        # OK
python -c "import base64; base64.b64decode(open('build/web/assets/AssetManifest.bin.json').read())"      # 3 assets

# Validation TOML
python -c "import tomllib; tomllib.load(open('supabase/config.toml','rb'))"
# -> TOMLDecodeError: Cannot declare ('functions','create-paddle-checkout') twice (at line 89, column 34)

# Audits CSP / branding / imports
# - parse de la CSP + comparaison aux origines runtime exigées
# - comptage 'Kit Business' / U+1F680 / <script src> dans les deux index.html
# - résolution de 184 imports Dart et 94 imports TS relatifs
# - scan de main.dart.js (gstatic, supabase, jitsi, paddle, localhost)

# Git
git status --porcelain     # 85 entrées ; build/ non suivi (0 fichier) ; branche main @ 6b9c9d8
```

---

## 4. Actions bloquantes avant déploiement

| Priorité | Action | Référence |
|---|---|---|
| **P0** | Rendre CanvasKit compatible CSP : ajouter `--dart-define=FLUTTER_WEB_CANVASKIT_URL=/canvaskit/` (ou `--no-web-resources-cdn`) au build Netlify **et rebuild**, *ou* autoriser `https://www.gstatic.com` dans `script-src` + `connect-src`. Sinon : page blanche en production. | §4 |
| **P0** | Supprimer les 5 tables dupliquées de `supabase/config.toml` (lignes 89–112) — sinon le CLI Supabase refuse le fichier. | §6 |
| **P0** | Committer la refonte : 85 entrées git (2 suppressions, ~45 fichiers non suivis dont tous les nouveaux `pages/`/`services/`, les 5 nouvelles Edge Functions, la migration Paddle, `docs/`). Netlify déploie depuis Git : sans commit/push, la refonte n'est pas publiée. | §7 |
| **P1** | Renseigner les secrets Paddle dans Supabase : `PADDLE_API_KEY`, `PADDLE_CLIENT_TOKEN`, `PADDLE_WEBHOOK_SECRET`, `PADDLE_ENVIRONMENT`, `PADDLE_PRICE_KIT_PROMPT`, `PADDLE_PRICE_KIT_SHEET`, `PADDLE_PRICE_KIT_LIVRE`, `PADDLE_PRICE_KIT_PACK`, `PADDLE_PRICE_STUDIO` (+ variantes `_EUR` optionnelles). Sans les `PADDLE_PRICE_*`, `create-paddle-checkout` renvoie une erreur explicite. Aucun `supabase/.env` local n'existe. | `supabase/.env.example` |
| **P1** | Appliquer la migration `supabase/migrations/20260101000500_paddle_et_studio_live.sql` (idempotente) — `supabase db push`, ou SQL Editor dans l'ordre des 6 migrations. Aucune trace d'application dans l'environnement. | `DEPLOIEMENT.md` L28–43, L208–216 |
| **P1** | Renseigner les autres secrets requis par `_shared` : `SASPAY_API_KEY`, `SASPAY_WEBHOOK_SECRET`, `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `DEEPSEEK_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_WORKSPACE_CREDENTIALS`, `ADMIN_EMAILS`, `CRON_SECRET`, `SITE_URL`, `WHATSAPP_AIDE_NUMBER`, `SUPPORT_EMAIL`, (`YOUTUBE_*`, `TIKTOK_*` si studio/admin vidéo). | scan `Deno.env.get` des 16 fonctions |
| **P2** | Corriger les résidus d'ancienne marque **hors artefacts web** : `README.md` L1 (`# 🚀 Kit Business — …`) et L147 (`© Kit Business`), `DEPLOIEMENT.md` L96/L140 et `supabase/.env.example` L50 (`RESEND_FROM_EMAIL=Kit Business <…>` → expéditeur d'e-mail encore à l'ancien nom), projet Supabase nommé `kit-business-v2`. | §5 |
| **P2** | Ajouter les règles de cache immutable (`/assets/*`, `/icons/*`, `/canvaskit/*`) et `frame-ancestors 'self'`, puis valider `FLUTTER_VERSION = 3.47.9`. | §4 |
| **P3** | Rejouer `flutter analyze` + `flutter test` hors sandbox, puis rebuild final (mtime de `lib/services/api.dart` postérieur au bundle). | §8 |

---

## 5. Ce qui est validé sans réserve

- Le dossier `build/web` est un artefact **release complet et cohérent** (index + bootstrap + `main.dart.js` + canvaskit + assets + manifestes + icônes + SW), 41,76 Mo.
- L'écran de chargement et les deux ponts JavaScript sont présents dans la source **et** dans l'artefact publié, sans divergence.
- Aucun ancien branding ni emoji 🚀 dans les pages servies ; aucun script tiers bloquant (Jitsi/Paddle réellement paresseux, vérifié dans le code Dart).
- Aucun asset, import ou page supprimée ne casse la compilation : 184 imports Dart + 94 imports TS résolus, 0 manquant.
- Les 16 Edge Functions existent, exposent `serve()` et sont toutes déclarées dans `config.toml` (le défaut est purement syntaxique : doublons).
