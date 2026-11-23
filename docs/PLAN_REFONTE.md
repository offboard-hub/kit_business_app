# PLAN D'EXÉCUTION & CHECKLIST D'ACCEPTATION — Refonte e-booklive

> Projet : `kit_business_app` (Flutter Web + Supabase), marque **e-booklive**
> Contrat de référence : [`docs/ARCHITECTURE_REFONTE.md`](ARCHITECTURE_REFONTE.md)
> Rôle de ce document : plan de travail + matrice d'acceptation **vérifiable**.
> **Aucun fichier de `lib/`, `supabase/`, `web/`, `test/`, `pubspec.yaml` n'est modifié par le planner.**

- **Snapshot de l'audit** : 22/11/2026 22:58 (Africa/Casablanca), branche `main`, arbre de travail sale.
- **Avertissement d'état** : le dépôt évolue en continu (13+ fichiers suivis modifiés, ~40 nouveaux fichiers, 2 pages legacy supprimées pendant l'audit). Les constats sont datés ; la colonne « Statut » doit être re-jouée avant toute décision de mise en production (cf. § 6.1). Les points marqués **✅ prouvé** ont été vérifiés par exécution ou par script de cohérence ; les points **⚠️** le sont par inspection statique seulement.
- **Règle de lecture** : une case n'est « conforme » que si sa preuve est **reproductible** : fichier + symbole + commande + résultat attendu. Une capture d'écran ne remplace pas un test.

---

## 0. Synthèse exécutive

La refonte est **structurellement en place** : les 6 exigences client sont couvertes par du code réel (53 fichiers Dart ≈ 17 300 lignes, 15 Edge Functions ≈ 7 100 lignes, 6 migrations ≈ 825 lignes de SQL). Les invariants critiques sont respectés : **215 pays** dans les deux référentiels, **23 pays SasPay** strictement identiques front/back, **152 devises** avec les mêmes taux, prix toujours recalculés côté serveur.

Trois choses empêchent aujourd'hui de dire « livré » :

1. **La preuve Flutter manque** : `flutter analyze`, `flutter test` et `flutter build web` **n'ont pas pu être exécutés** dans cet environnement (blocage sandbox, cf. § 1.3). La cohérence **backend** est en revanche prouvée par un harness exécutable (§ 1.2).
2. **La suite de tests ne compile pas** : `test/widget_test.dart` importe deux pages désormais supprimées (l.7-8), attend une icône de logo qui n'existe plus (l.64) et ne couvre **aucune** des 6 exigences.
3. **Des écarts fonctionnels résiduels** existent : affichage du montant payé en FCFA quel que soit la devise réelle (`confirmation_page.dart` l.260, `dashboard_page.dart` l.506), espace client encore sur l'ancien référentiel (14 pays FCFA / 6 métiers legacy), icônes PWA aux couleurs Flutter par défaut, `og:image` en SVG (non supporté par WhatsApp/Facebook).

**Chemin critique** : P0 (rendre l'état mesurable + corriger l'affichage devise) → P1 (preuves page par page) → P2 (bout en bout paiement + Studio Live) → P3 (qualité + release).

---

## 1. Diagnostic de l'état actuel

### 1.1 Ce qui est en place (avec preuve fichier/symbole)

| Domaine | État | Preuves principales |
| --- | --- | --- |
| Design system premium | ✅ | `lib/core/theme.dart` — `K.bg = #090D16` (l.17), `K.surface = #111827` (l.18), `K.border = #1E293B` (l.24), `K.or = #E7B84B` (l.33), `K.emeraude = #34D399` (l.36), dégradé `K.marque` or→émeraude (l.66), `GlassCard`, `OrButton`, `Puce`, `Reveal` |
| Logo vectoriel (livre ouvert + signal live) | ✅ | `lib/widgets/logo_ebooklive.dart` — `_PeintreLogo` (pages or + ondes + point émeraude), `LogoEbookliveAnime` (pulsation), `WordmarkEbooklive`, `LogoLockup` ; miroir SVG dans `web/index.html` (splash, `web/icons/logo-ebooklive.svg`, `web/favicon.svg`) |
| Splash / preloader | ✅ | Web : `web/index.html` `#splash-screen` (SVG + barre de progression + messages + gestion d'erreur + `splash-out`) ; Flutter : `lib/pages/splash_page.dart` affiché en overlay par `lib/main.dart` (progression réelle 0.10 → 1.0, minimum 1 400 ms) |
| Navigation minimaliste | ✅ | `lib/widgets/app_header.dart` — `LogoLockup` + 3 accès (`La Boutique`, `Studio Live`, `Guide & Tutoriel`, l.115-130) + `AideWhatsApp(compact:true)` + `PaysSelector` + `_MenuCompte` ; bottom-sheet mobile (`_ouvrirMenu`) |
| `/admin-videos` invisible sauf admin | ✅ | `app_header.dart` : entrée admin conditionnée par `_admin` (`ApiService.estAdmin()`, l.52-65 et l.219/382) ; route protégée par `lib/pages/admin_guard_page.dart` (`estAdmin` l.33 → `AdminVideosPage` l.50, sinon page « introuvable » neutre) |
| Routage path + SPA fallback | ✅ | `lib/main.dart` `_routeInitiale()` (l.253, path + fragment legacy), table de routes (l.292-353) dont `/live/:roomId` (regex l.344) + `?invite=` ; `lib/core/url_strategy*.dart` (`configurerUrl()`) ; `netlify.toml` `[[redirects]] from "/*" to "/index.html" status 200` |
| 215 pays + drapeaux + recherche | ✅ | `lib/core/countries.dart` : `PaysMonde` (215 entrées), `tauxXof` (152 devises), `devisesEntieres`, `symbolesDevises`, `rechercherPays()` (nom/code/devise/indicatif, insensible aux accents), `paysSasPay` (23) ; UI `lib/widgets/country_picker.dart` (`PaysSelector`, `_DialoguePays`, `RoutePaiementBandeau`) ; persistance `lib/core/app_state.dart` (`CountryStore` + `stockage_pays_web.dart`) |
| Conversion dynamique | ✅ | `lib/core/pricing.dart` — `Prix.devisKit` (l.148), `Prix.devisStudio` (l.171), `Prix.arrondir` (l.194), `DevisPrix.principal/indicatif` ; parité serveur `supabase/functions/_shared/pricing.ts` (`arrondirPrix` l.89 « copie conforme ») |
| 23 pays SasPay / reste Paddle | ✅ | SasPay : `countries.dart` (`sasPay: true` × 23) = `_shared/countries.ts` `CODES_SASPAY` (23, ordre identique) ; Paddle : `devisePaddle()` → EUR (Europe + Maghreb) sinon USD ; facturation locale indicative exposée par `DevisPrix.indicatif` |
| La Boutique en 2 étapes | ✅ | `lib/pages/boutique_page.dart` — `_etape` (l.41), `_etape1Valide` (l.82, « Autre métier » ≥ 3 caractères), 8 secteurs + `secteurAutre` (l.309), `_etapeKit` (l.389) avec 4 kits + devis par pays (`Prix.devisKit`, l.661), CTA « Payer avec {SasPay|Paddle} » (l.736) |
| Paiement (SasPay + Paddle) | ✅ | `saspay-checkout/index.ts` (recalcul serveur `montantSasPay`, l.110) ; `create-paddle-checkout/index.ts` (`montantPaddle` l.114, `priceIdPaddle` l.116) ; `_shared/paddle.ts` (`priceIdPaddle` l.187, signature webhook l.274) ; `paddle-webhook/index.ts` ; `_shared/pricing.ts` |
| Studio Live (10 USD / 30 j) | ✅ | `pricing.dart` `Prix.studioUsd = 10` / `studioJours = 30` ; `_shared/pricing.ts` `PRIX_STUDIO_USD` (l.38) / `DUREE_STUDIO_JOURS` (l.43) ; `lib/pages/studio_live_page.dart` (offre + activation `?abonnement=<id>`) |
| Régie 3 onglets | ✅ | `lib/pages/studio_regie_page.dart` — `_onglet` (l.51), `_Onglets` (l.513) : « Préparer mon Live » (l.535), « Salle en direct » (l.541), « Mon Livre Guide » (l.548) ; lien de partage `/live/{room}?invite={token}` (l.79-85) |
| Salle Jitsi + chat IA | ✅ | `lib/services/jitsi_view.dart` (export conditionnel) + `jitsi_view_web.dart` (`construireJitsi`, pont `ebookliveJitsi` dans `web/index.html` l.435) ; chat temps réel `studio_regie_page.dart` `.stream(primaryKey:['id'])` (l.1218) + repli polling 6 s (l.1242) ; backend `live-auto-chat/index.ts` + `_shared/studio.ts` |
| Livre Guide | ✅ | `_OngletGuide` (`studio_regie_page.dart` l.1609) ; `generate-live-guide/index.ts` + `studio.ts` `genererGuidePourAbonnement` (l.731) ; email `emailGuideHtml` (l.943) |
| Salle invitée `/live/:roomId?invite=` | ✅ | `lib/pages/live_room_page.dart` — `_estInvite` (l.36), `sessionPublique` (l.51), `ChatLivePanel` (l.208), `construireJitsi` (l.428) ; backend `studio-room/index.ts` (vérifie token OU JWT propriétaire) |
| Assistant IA flottant + pleine page | ✅ | `lib/widgets/site_assistant_chat.dart` — « Ouvrir en pleine interface » → `Navigator.pushNamed('/assistant')` (l.71) ; `lib/pages/assistant_page.dart` — « Retour au site » (l.271) par `Navigator.pop` (l.61, état conservé) ; prompt à jour `_shared/assistant.ts` (l.70-91 : 2 univers, tarifs, 23 pays, routes) |
| Guide & Tutoriel 3 étapes | ✅ | `lib/pages/guide_page.dart` — `_etapes` (l.21) : 01 Commander · 02 Configurer la régie · 03 Chat IA & Livre Guide, navigation par pastilles (l.146) |
| Base de données studio | ✅ | `supabase/migrations/20260101000500_paddle_et_studio_live.sql` : colonnes `orders` (l.21-25), `studio_subscriptions` (l.47), `studio_guides` (l.108), `studio_live_sessions` (l.136), `studio_live_messages` (l.174), `studio_a_acces()` (l.222, security definer), `mon_abonnement_studio()` (l.246), policies (l.302-345), publication realtime idempotente (l.363, bloc `do $$ … exception duplicate_object`), `expirer_abonnements_studio()` (l.373) |
| Config Edge Functions | ✅ | `supabase/config.toml` déclare **15** fonctions (`create-paddle-checkout`, `paddle-webhook`, `generate-live-guide`, `live-auto-chat`, `studio-room` inclus) ; 15 dossiers présents ; **aucun import TS local non résolu** (vérifié) |
| Métadonnées web | ✅ | `web/index.html` : `<title>e-booklive — La Boutique &amp; Studio Live</title>`, OG/Twitter, JSON-LD, `manifest.json` (thème `#090D16`), `theme-color`, `noscript` ; `netlify.toml` : redirects + `Cache-Control: no-cache` sur `index.html` et `flutter_service_worker.js` |

### 1.2 Ce qui EST prouvé automatiquement (harness backend)

Un harnais de cohérence existe dans `.typecheck/verifier.mjs` (Node 24, non déployé) : il importe directement `_shared/countries.ts`, `pricing.ts`, `config.ts` et `assistant.ts` et compare les invariants.

```powershell
node .typecheck/verifier.mjs   # → « TOUTES LES VÉRIFICATIONS PASSENT »
```

Extraits de la sortie obtenue pendant l'audit (à archiver comme preuve) :

```
ok pack TD (USD/XAF) = {"montant":14.85,"devise":"USD","montantIndicatif":9000,"deviseIndicative":"XAF"}
ok studio MA = {"montant":9.24,"devise":"EUR","montantIndicatif":99.4,"deviseIndicative":"MAD"}
ok studio US = {"montant":10,"devise":"USD","montantIndicatif":null,"deviseIndicative":null}
ok format FCFA = "9 000 FCFA"   ok format NGN = "23 000 ₦"   ok format EUR = "13,72 €"
ok nb secteurs = 8   ok nb kits = 9
ok kit restaurant legacy = "restauration"   ok kit elevage legacy = "autre"
ok paysParCode route = "paddle"   ok paysParCode inconnu = undefined
ok même nombre de pays que le frontend = 215   ok parité pays backend/frontend = 0
ok codes SasPay identiques = ["ML","SN","CI","BF","BJ","TG","NE","CM","GA","CG","CD","GN","NG","GH","SL","KE","UG","TZ","RW","MW","MZ","ZM","IN"]
```

**Ce que cela prouve** : prix serveur conformes (kits + Studio 10 USD), arrondis et formatage par devise, 8 secteurs + « Autre », alias legacy (`restaurant`→`restauration`, `elevage`→`autre`), routage SasPay/Paddle, **parité 215 pays** et **23 codes SasPay identiques**.
**Ce que cela ne prouve pas** : que le code Dart compile, que les tests passent, que le build web aboutit — d'où § 1.3.

### 1.3 Ce qui ne peut PAS être prouvé ici (blocage d'environnement)

| Vérification | Commande tentée | Résultat observé |
| --- | --- | --- |
| SDK Flutter dans le PATH | `flutter --version` | `flutter : Le terme «flutter» n'est pas reconnu…` (SDK installé ailleurs : `C:\dev\flutter\bin\flutter.bat`) |
| Flutter CLI | `& C:\dev\flutter\bin\flutter.bat --version` | **pend > 4 min**, aucun processus `dart` enfant → tué (`job_kill`) |
| Analyse statique | `dart.exe analyze --no-fatal-warnings` | `CreateFile failed 5 (Accès refusé)` puis `ProcessException: Accès refusé` au spawn de `dartaotruntime … analysis_server_aot.dart.snapshot` |
| Compilation kernel | `dart.exe compile kernel lib/main.dart` | Même `ProcessException` au spawn de `gen_kernel_aot.dart.snapshot` |
| Dart seul (hors spawn) | `dart.exe --version` | ✅ `Dart SDK version: 3.13.7 (stable)` |

**Cause** : la sandbox de cette session (workspace-write) interdit la création des pipes/processus enfants nécessaires au *frontend server* et à l'*analysis server* de Dart. **Conséquence directe** : la clause « flutter analyze / test / build web 0 erreur » du client **n'est pas démontrée**. Elle doit être exécutée hors sandbox (poste utilisateur ou CI) et sa sortie jointe au dossier de livraison. Toutes les autres vérifications de ce document ont été faites par inspection statique reproductible (lecture de fichiers, scripts de cohérence).

### 1.4 Dette et écarts vérifiés (D1 → D11)

| # | Écart | Preuve | Impact |
| --- | --- | --- | --- |
| **D1** | **Suite de tests non compilable et périmée.** Elle importe deux pages **supprimées** du dépôt, attend l'ancienne icône du logo et les anciens libellés. | `test/widget_test.dart` **l.7-8** `import '…/pages/commande_page.dart'` + `import '…/pages/landing_page.dart'` alors que `git status` les marque `D` (fichiers supprimés) → **échec de compilation de `flutter test` avant toute assertion** ; **l.64** attend `Icons.rocket_launch_rounded` alors que `theme.dart` l.196 délègue à `LogoEbooklive` (CustomPainter) ; l.79/96 `'Notes & Avis de nos clients'` ; l.141 `'Composer mon kit'` | 🔴 `flutter test` ne compile pas ; **aucune** couverture boutique/studio/pays/paiement/routing |
| **D2** | **✅ Résolu pendant l'audit** : les pages legacy ont été supprimées. | `git status` : `D lib/pages/commande_page.dart`, `D lib/pages/landing_page.dart` (n'existent plus) | 🟢 — reste à supprimer leurs imports dans `test/widget_test.dart` (**D1**) |
| **D3** | **Deux sources de vérité pays/tarifs.** `config.dart` conserve `Pays`/`paysAfricains` (14 pays FCFA), `kitsMetiers` (6 métiers legacy), `offres`, `AppConfig.fcfa`. | `lib/core/config.dart` l.69-258 vs `countries.dart` (215 pays) / `pricing.dart` (8 secteurs) ; `offres` toujours source de `pricing.dart` `kitsBoutique` | 🟠 risque de divergence silencieuse (masquée par les alias `ALIAS_METIER`/`LIBELLES_LEGACY`) |
| **D4** | **Affichage du montant non unifié.** Le montant payé est formaté en FCFA même quand la devise réelle est NGN/KES/EUR. | `lib/core/models.dart` l.61 `montantAffiche => '$montant $devise'` (brut, sans symbole) ; `confirmation_page.dart` l.260 `_ligne('Montant payé', AppConfig.fcfa(montant))` ; `dashboard_page.dart` l.506 même défaut ; `paiement_en_attente_page.dart` l.120 transmet `checkout.montant` (montant **local**) | 🔴 incohérence visible en confirmation : « 23 040 FCFA » pour un paiement de 23 040 NGN |
| **D5** | **Aucun test unitaire Flutter prix/pays.** La parité front/back est prouvée côté backend (`.typecheck/verifier.mjs`) mais aucun test Dart ne la verrouille. | `test/` ne contient que `widget_test.dart` ; `.typecheck/verifier.mjs` compare `_shared/*.ts` **entre eux et au frontend** (via lecture de fichier) mais n'est pas lancé en CI | 🟠 une modification de taux d'un seul côté casse la promesse « prix affiché = prix facturé » sans test rouge |
| **D6** | **Price IDs Paddle absents du dépôt (attendu) mais bloquants.** | `_shared/paddle.ts` `priceIdPaddle` l.187-221 (erreur explicite si absent) ; `supabase/.env.example` (5 IDs + variantes `_EUR` commentées) | 🔴 paiement international KO tant que les secrets ne sont pas posés |
| **D7** | **Dépendance à deux scripts externes non versionnés.** Jitsi et Paddle.js sont chargés en `async`. | `web/index.html` l.558-559 (`meet.jit.si/external_api.js`, `cdn.paddle.com/paddle/v2/paddle.js`) ; ponts l.435 (`ebookliveJitsi`) et l.463 (`ebooklivePaddle`) | 🟠 si le CDN est lent/bloqué, la salle et l'overlay Paddle sont indisponibles (repli prévu, mais non testé) |
| **D8** | **URL du navigateur non synchronisée** avec la navigation interne (Navigator 1.0). | `app_header.dart` `_aller()` → `Navigator.pushNamedAndRemoveUntil` ; aucune API `routeInformationUpdated`/`go_router` | 🟠 une URL copiée après navigation peut ne pas refléter l'écran courant |
| **D9** | **Icônes PWA encore aux couleurs Flutter par défaut.** | `web/icons/Icon-192.png` / `Icon-512.png` (fichiers d'origine, jamais régénérés) ; `manifest.json` pointe encore dessus alors que `icons/logo-ebooklive.svg` existe | 🟠 installation PWA hors charte |
| **D10** | **`og:image` en SVG.** | `web/index.html` l.25-29 `icons/logo-ebooklive.svg` | 🟠 aperçus de partage vides sur WhatsApp/Facebook (SVG non supporté) |
| **D11** | **Espace client (`/mon-espace` → `dashboard_page.dart`) non refondu** : il propose encore les **14 pays FCFA** et les **6 métiers legacy**, et affiche les montants en FCFA. | `dashboard_page.dart` l.61 `Pays _pays = paysAfricains.first`, l.603 `for (final kit in kitsMetiers)`, l.638 `for (final pays in paysAfricains)`, l.506 `AppConfig.fcfa(...)` | 🔴 un client au Nigeria/Maroc ne peut pas déclarer son pays réel dans son espace, et voit un catalogue différent de La Boutique |

### 1.5 Ce qui manque encore, fonctionnellement

Rien de **structurel** dans les 6 exigences : chaque case a un fichier et un symbole identifiables (§ 3). Ce qui manque est de la **preuve** et de la **finition** :

1. Exécution effective de `flutter analyze`, `flutter test`, `flutter build web --release` hors sandbox.
2. Réécriture de la suite de tests (D1) + tests de parité prix/pays (D5).
3. Correction de l'affichage devise en confirmation / espace client (D4).
4. Nettoyage des doubles sources et mise à niveau de l'espace client (D3, D11).
5. Secrets Paddle + application de la migration sur le projet Supabase (D6).
6. Finition PWA/SEO : icônes 192/512 régénérées, `og:image` PNG 1200×630 (D9, D10).
7. Synchronisation d'URL si le client veut des liens partageables depuis n'importe quel écran (D8).

---

## 2. Plan par phases

> Convention : `P0` = bloquant (rien ne peut être déclaré « fait » avant), `P1` = pages publiques, `P2` = Studio Live & paiements, `P3` = qualité & release.
> Chaque phase se termine par une **porte de sortie** : tant qu'elle n'est pas franchie, on ne passe pas à la suivante.

### P0 — Fondations & vérifiabilité (bloquant)

**Objectif** : rendre l'état mesurable, supprimer les doubles sources, corriger les défauts de confiance (devise).

| # | Tâche | Fichiers concernés | Preuve attendue |
| --- | --- | --- | --- |
| P0.1 | Exécuter la chaîne de vérification **hors sandbox** et joindre les sorties | — (poste utilisateur/CI) | `flutter pub get`, `flutter analyze` → `No issues found!`, `flutter test` → `All tests passed!`, `flutter build web --release` → exit 0 |
| P0.2 | **Réécrire la suite de tests (bloquant : elle ne compile plus)** — retirer les imports des pages supprimées, tester le logo via `find.byType(LogoEbooklive)`, couvrir les pages réellement routées | `test/widget_test.dart`, `test/pricing_test.dart`, `test/countries_test.dart` (nouveaux) | `flutter test` compile et passe ; 0 référence à `LandingPage`/`CommandePage` |
| P0.3 | ~~Supprimer le code mort `landing_page.dart`, `commande_page.dart`~~ **fait pendant l'audit** (`git status` : `D`) — reste à vérifier qu'aucun import ne subsiste | `test/widget_test.dart` (imports l.7-8) | `grep -rn "LandingPage\|CommandePage" lib test` → 0 résultat |
| P0.4 | Purger les symboles legacy de `config.dart` (`Pays`, `paysAfricains`, `kitsMetiers`, `TypeOffre`/`Offre` si `kitsBoutique` migre vers `pricing.dart`) ; ne garder que `AppConfig` (URL, contacts, Supabase) | `lib/core/config.dart`, `lib/core/pricing.dart` (`kitsBoutique = offres`) | `grep -rn "paysAfricains\|kitsMetiers" lib` → 0 ; `offres` déplacé dans `pricing.dart` |
| P0.5 | Unifier l'affichage monétaire : utiliser `Prix.formater(montant, devise)` + devise réelle de la commande ; enrichir les modèles (`devise`, `montant_local`) | `lib/core/models.dart` (`ResultatCommande`, `CommandeResume`, `CheckoutCree.montantAffiche`), `lib/pages/confirmation_page.dart` (l.260), `lib/pages/dashboard_page.dart` (l.506), `lib/pages/paiement_en_attente_page.dart` | Paiement de test en NGN → confirmation affiche « 23 040 NGN », jamais « FCFA » |
| P0.6 | Appliquer la migration et prouver l'idempotence | `supabase/migrations/20260101000500_paddle_et_studio_live.sql` | `supabase db push` sur projet de test, **puis rejeu** → 0 erreur ; `\d public.studio_live_sessions` conforme |
| P0.7 | Poser les secrets et vérifier leur prise en compte | `supabase/.env` (hors git), `supabase/config.toml` | `supabase secrets list` montre `PADDLE_API_KEY`, `PADDLE_CLIENT_TOKEN`, `PADDLE_WEBHOOK_SECRET`, les 5 `PADDLE_PRICE_*`, `ADMIN_EMAILS`, `DEEPSEEK_API_KEY`, `GEMINI_API_KEY`, `RESEND_API_KEY` |
| P0.8 | **Mettre l'espace client au nouveau référentiel** : `PaysSelector`/`Prix` au lieu de `paysAfricains`/`kitsMetiers`/`AppConfig.fcfa` | `lib/pages/dashboard_page.dart` (l.61, l.506, l.603, l.638), `lib/core/config.dart` (suppression des symboles legacy) | Un client au Nigeria/Maroc voit et choisit son pays réel ; les montants de l'historique s'affichent dans la devise de la commande |

**Porte de sortie P0** : `flutter analyze` = 0 issue (hors `info` explicitement acceptés) **et** `flutter test` vert **et** 0 référence legacy **et** migration rejouable **et** confirmation de paiement dans la bonne devise.

---

### P1 — Pages publiques (identité, pays, boutique, assistant, guide)

**Objectif** : prouver les exigences 1, 2, 3 et 5 côté public, écran par écran.

| # | Tâche | Fichiers concernés | Preuve attendue |
| --- | --- | --- | --- |
| P1.1 | Vérifier la cohérence identité sur tous les supports : tokens `K.*`, dégradé de marque, zéro couleur héritée (`#14123A`, indigo) | `lib/core/theme.dart`, `web/index.html`, `web/manifest.json`, `web/favicon.svg`, `web/icons/logo-ebooklive.svg` | `grep -rn "14123A\|7C8CFF\|0175C2" lib web` → 0 ; captures splash web + splash Flutter |
| P1.2 | Régénérer les icônes PWA 192/512 + maskable depuis le SVG, ajouter une `og:image` PNG 1200×630 | `web/icons/*.png`, `web/index.html` (l.25-29) | Fichiers PNG non-Flutter ; `og:image` en `image/png` ; test WhatsApp/OpenGraph |
| P1.3 | Preuve du sélecteur de pays : 215 entrées, recherche par nom/code/devise/indicatif, insensible aux accents, drapeaux, persistance | `lib/widgets/country_picker.dart`, `lib/core/countries.dart`, `lib/core/app_state.dart` | Test unitaire `rechercherPays('cote')` → CI/SN ; test widget : saisie « nai » → Nigeria ; rechargement → pays mémorisé |
| P1.4 | Preuve de conversion : changement de pays → prix de la carte kit et du Studio Live recalculés (SasPay local, Paddle + indicatif) | `lib/core/pricing.dart`, `lib/pages/boutique_page.dart` (l.661), `lib/pages/studio_live_page.dart` | Test unitaire : `Prix.devisKit(9000, pays(NG))` = 23 040 NGN ; `pays(FR)` → EUR + indicatif ; test widget : sélection FR → texte `€` |
| P1.5 | Parcours Boutique 2 étapes : 8 secteurs + « Autre métier », garde de validation, 4 kits, récap, CTA fournisseur | `lib/pages/boutique_page.dart` | Test widget : étape 2 inaccessible sans secteur ; « Autre » < 3 car. bloqué ; capture desktop 1280 + mobile 390 |
| P1.6 | Assistant : bulle sur pages publiques, « Ouvrir en pleine interface » → `/assistant`, « Retour au site » → retour avec état | `lib/widgets/site_assistant_chat.dart` (l.71), `lib/pages/assistant_page.dart` (l.61/271) | Test widget de navigation ; vérif manuelle : ouvrir depuis `/boutique` → retour → secteur/offre conservés |
| P1.7 | Guide & Tutoriel 3 étapes navigables | `lib/pages/guide_page.dart` | Test widget : 3 pastilles, clic 02 → contenu « Configurer ma régie » |
| P1.8 | Vérifier qu'aucun formulaire « en vrac » n'est sur l'accueil (avis en dialogue) | `lib/pages/home_page.dart` (`_DialogueAvis`, `_SectionAvis`) | `grep -n "TextField" home_page.dart` → uniquement dans le dialogue |
| P1.9 | Deep links publics : `/boutique`, `/studio-live`, `/guide`, `/faq`, `/cgv` en accès direct et après refresh (Netlify) | `netlify.toml`, `lib/main.dart` | `curl -I https://…/boutique` → 200 ; navigation directe navigateur OK |

**Porte de sortie P1** : les 9 tâches prouvées, captures desktop/mobile jointes, tests widget des pages publiques verts.

---

### P2 — Studio Live & paiement international (bout en bout)

**Objectif** : prouver les exigences 2 (suite) et 4, plus le tunnel de paiement complet.

| # | Tâche | Fichiers concernés | Preuve attendue |
| --- | --- | --- | --- |
| P2.1 | Abonnement Studio 10 USD : page offre → checkout pays → attente → activation → régie | `lib/pages/studio_live_page.dart`, `lib/pages/paiement_en_attente_page.dart`, `lib/pages/studio_regie_page.dart`, `saspay-checkout`, `create-paddle-checkout` | Une ligne `studio_subscriptions` passe `EN_ATTENTE → ACTIF`, `expires_at ≈ now + 30 j`, `montant_usd = 10` |
| P2.2 | Régie 3 onglets : Préparer (fiche produit, plateformes, format SOLO/DUO, mode CAMERA/ECRAN) → Salle → Guide | `lib/pages/studio_regie_page.dart` (`_OngletPreparer` l.620, `_OngletDirect` l.906, `_OngletGuide` l.1609) | Session `BROUILLON → PRET → EN_DIRECT → TERMINE` en base |
| P2.3 | Jitsi : chargement du pont, salle intégrée, repli si l'API externe est indisponible | `web/index.html` (l.435/558), `lib/services/jitsi_view_web.dart`, `lib/services/jitsi_view_stub.dart` | Salle visible sur `/studio/regie` et `/live/<room>` ; message de repli si `JitsiMeetExternalAPI` absent |
| P2.4 | Chat IA temps réel : message visiteur → réponse assistant persistée → diffusion | `lib/pages/studio_regie_page.dart` (`ChatLivePanel` l.1181, `.stream` l.1218), `live-auto-chat/index.ts`, `_shared/studio.ts` | 2 lignes `studio_live_messages` (role `user` + `assistant`) ; réception < 3 s dans les 2 onglets |
| P2.5 | Invitation co-animateur : lien `/live/{room}?invite={token}`, accès token valide, refus token invalide | `lib/pages/live_room_page.dart`, `studio-room/index.ts`, `_shared/studio.ts` (`verifierAccesSession` l.220) | Token valide → lobby + Jitsi ; token falsifié → refus explicite (403/404) |
| P2.6 | Livre Guide : génération, statut, email, idempotence | `generate-live-guide/index.ts`, `_shared/studio.ts` (`genererGuidePourAbonnement` l.731) | `guide_status: EN_ATTENTE → PRET`, `studio_guides.contenu_html` non vide, email Resend reçu ; 2ᵉ appel → même guide (pas de doublon) |
| P2.7 | Paddle sandbox : overlay `paddle.js`, transaction créée, webhook signé, `verify-payment` en repli | `web/index.html` (l.463), `lib/services/paddle_checkout_web.dart`, `create-paddle-checkout`, `paddle-webhook`, `verify-payment` | Transaction sandbox `completed` → `orders.statut = PAYE` puis `LIVRE` ; webhook rejoué → **une seule** livraison |
| P2.8 | Sécurité montants : aucun montant client accepté, sous-paiement refusé | `saspay-checkout` l.110, `create-paddle-checkout` l.114, `verify-payment` (contrôle `montantVerifie + 1 < attendu`) | Appel direct avec `montant: 1` → montant serveur ignoré ; paiement partiel → 402 |
| P2.9 | RLS : tests SQL par rôle sur les 4 tables | `20260101000500_paddle_et_studio_live.sql` (l.302-351) | `anon` : lecture messages uniquement si session `PRET/EN_DIRECT` ; écriture refusée ; `authenticated` non propriétaire : 0 ligne ; `service_role` : OK |

**Porte de sortie P2** : un abonnement ACTIF + guide PRET + session EN_DIRECT + messages IA en base, obtenus **par l'interface** ; webhook Paddle idempotent ; RLS prouvée par 4 requêtes SQL.

---

### P3 — Qualité, durcissement, release

| # | Tâche | Fichiers concernés | Preuve attendue |
| --- | --- | --- | --- |
| P3.1 | Analyse statique propre | tout `lib/`, `test/` | `flutter analyze` → `No issues found!` (0 error, 0 warning) |
| P3.2 | Couverture de tests cible (≥ 40 tests) : prix, arrondis, pays, formatage, routing, widgets clés | `test/` (nouveaux fichiers `pricing_test.dart`, `countries_test.dart`, `routes_test.dart`, `widget_*.dart`) | `flutter test` → ≥ 40 tests, tous verts |
| P3.3 | Parité front/back verrouillée par test | `test/countries_test.dart` | Test : 215 pays, 23 SasPay, 152 devises, taux identiques à `_shared/countries.ts` (lecture du fichier ou fixture partagée) |
| P3.4 | Performance : poids du build, premier rendu, images | `web/index.html`, `pubspec.yaml`, `home_page.dart` | `build/web` < 4 Mo (hors assets), LCP < 2,5 s en 4G simulée, 0 image > 300 Ko |
| P3.5 | Accessibilité : contrastes AA, focus clavier, `Semantics`, cibles ≥ 44 px | `theme.dart`, `app_header.dart`, pages | Audit Lighthouse a11y ≥ 90 ; navigation clavier complète ; `grep` des `Icon` sans `Semantics` sur actions critiques |
| P3.6 | SEO / partage : titres, descriptions, JSON-LD, `og:image` PNG | `web/index.html`, `web/manifest.json` | Validateurs OpenGraph + Rich Results |
| P3.7 | Observabilité : erreurs Edge Functions loguées, messages utilisateur non techniques | `supabase/functions/_shared/*`, pages | `supabase functions logs` lisibles ; aucun `throw` brut affiché à l'écran |
| P3.8 | Documentation de déploiement à jour | `DEPLOIEMENT.md`, `docs/ARCHITECTURE_REFONTE.md`, ce plan | Procédure reproductible en < 30 min par un tiers |
| P3.9 | Release : déploiement Netlify + Supabase, vérification post-déploiement | `netlify.toml`, `supabase/config.toml` | Les 6 routes répondent 200 en direct ; paiement test réel (1 FCFA / 1 USD sandbox) livré |

**Porte de sortie P3** : § 5 Definition of Done entièrement cochée.

---

## 3. Matrice d'acceptation (case par case)

> Légende statut : ✅ en place (preuve statique vérifiée) · ⚠️ en place mais **non prouvé** (à exécuter) · ❌ écart ouvert.

### Exigence 1 — Identité visuelle premium, logo, splash, nav

| Case | Exigence client | Preuve attendue | Statut |
| --- | --- | --- | --- |
| 1.1 | Fond `#090D16`, cartes verre `#111827` | `theme.dart` `K.bg` (l.17), `K.surface` (l.18), `K.border` (l.24), `GlassCard` (l.213) | ✅ |
| 1.2 | Dégradé or → émeraude | `theme.dart` `K.marque = [#F6D98A, #E7B84B, #34D399]` (l.66-71) ; `K.or`/`K.emeraude` (l.33/36) | ✅ |
| 1.3 | Logo vectoriel livre ouvert + signal live | `logo_ebooklive.dart` `_PeintreLogo` (pages or l.170-186, ondes l.209-226, point émeraude l.235-241) ; SVG miroir dans `web/index.html` (l.365-381) + `web/icons/logo-ebooklive.svg` | ✅ |
| 1.4 | Splash/preloader web animé | `web/index.html` `#splash-screen` (l.335), barre `#splash-bar-fill`, messages, `splash-out` (l.518) | ✅ |
| 1.5 | Splash Flutter animé | `splash_page.dart` + `main.dart` overlay (l.120-132) avec progression réelle et `LogoEbookliveAnime` | ⚠️ (nécessite `flutter run/build`) |
| 1.6 | Nav minimaliste : logo, La Boutique, Studio Live, Guide & Tutoriel, Aide WhatsApp discrète, menu Compte | `app_header.dart` : `LogoLockup` (l.263), `_LienNav` × 3 (l.115-130), `AideWhatsApp(compact:true)` (l.134), `PaysSelector` (l.138), `_MenuCompte` (l.141) | ✅ |
| 1.7 | `/admin-videos` invisible sauf admin | `app_header.dart` l.52-65 + l.219/382 (condition `_admin` via `ApiService.estAdmin()`) | ✅ |
| 1.8 | `/admin-videos` route protégée | `admin_guard_page.dart` l.33 (`estAdmin`) → l.50 `AdminVideosPage`, sinon `_PageIntrouvable` | ✅ |
| 1.9 | Splash web + Flutter cohérents (même logo, mêmes couleurs) | Comparaison `web/index.html` (SVG 96×96) et `logo_ebooklive.dart` (viewBox 96×96, mêmes paths de livre) | ✅ |
| 1.10 | Manifest / favicon / OG à la marque | `web/manifest.json` (`e-booklive`, `#090D16`), `favicon.svg`, meta OG/Twitter, JSON-LD | ✅ sauf **D9** (icônes PWA) et **D10** (`og:image` SVG) ❌ |

### Exigence 2 — Pays du monde, drapeaux, conversion, SasPay/Paddle

| Case | Exigence client | Preuve attendue | Statut |
| --- | --- | --- | --- |
| 2.1 | Sélecteur de **tous** les pays (215) avec drapeaux | `countries.dart` (215 `PaysMonde`), `country_picker.dart` `_LignePays` (`pays.drapeau`, l.327) | ✅ |
| 2.2 | Recherche instantanée | `countries.dart` `rechercherPays()` (nom, code, devise, indicatif, `sansAccents`) ; `_DialoguePays` `_resultats` (l.166) | ✅ |
| 2.3 | 23 pays SasPay en devise locale | `countries.dart` `sasPay: true` × 23 ↔ `_shared/countries.ts` `CODES_SASPAY` (23, mêmes codes) + `deviseLocale()` | ✅ (parité vérifiée par script) |
| 2.4 | Devises locales exactes (XOF/XAF/CDF/GNF/NGN/GHS/SLE/KES/UGX/TZS/RWF/MWK/MZN/ZMW/INR) | `countries.dart` mapping pays→devise ; `_shared/countries.ts` colonne devise des 215 lignes (0 divergence) | ✅ |
| 2.5 | Reste du monde → Paddle EUR/USD + TVA | `devisePaddle()` (EUR si Europe/Maghreb, sinon USD) ; `Prix.explicationRoute()` mentionne la TVA ; `create-paddle-checkout` | ✅ |
| 2.6 | Conversion dynamique des prix | `Prix.devisKit`/`devisStudio` (l.148/171) + `CountryStore` (persistance) + recalcul UI au changement de pays | ⚠️ (logique ✅, preuve UI à faire) |
| 2.7 | Prix serveur seul juge (aucun montant client) | `saspay-checkout` l.110 (`montantSasPay`), `create-paddle-checkout` l.114 (`montantPaddle`), `pricing.ts` (aucune lecture de montant client) | ✅ |
| 2.8 | Parité des taux front/back (152 devises) | `countries.dart` `tauxXof` ↔ `_shared/countries.ts` `TAUX_XOF` — **0 divergence** (diff script) | ✅ |
| 2.9 | Affichage du montant payé dans la bonne devise | `confirmation_page.dart` l.260, `models.dart` l.61, `dashboard_page.dart` l.506 | ❌ **D4** |

### Exigence 3 — La Boutique : 8 secteurs + Autre métier, 2 étapes, kits, paiement

| Case | Exigence client | Preuve attendue | Statut |
| --- | --- | --- | --- |
| 3.1 | 8 secteurs en étape 1 | `pricing.dart` `secteurs` (l.35-92 : ecommerce, immobilier, restauration, beaute, formation, transport, services_b2b, sante) | ✅ |
| 3.2 | « Autre métier » avec champ libre | `pricing.dart` `secteurAutre` (l.95) ; `boutique_page.dart` `_autre` + `_etape1Valide` (l.82-86, ≥ 3 car.) ; validation serveur `codeMetier === "autre"` (saspay-checkout l.82) | ✅ |
| 3.3 | Parcours en 2 étapes | `boutique_page.dart` `_etape` (l.41), `_indicateurEtapes` (l.246), navigation (l.193-220) | ✅ |
| 3.4 | Kits existants (4 offres, prix FCFA inchangés) | `pricing.ts` `PRIX_KITS_XOF` = 3 000 / 3 500 / 5 000 / 9 000 ↔ `config.dart` `offres` ; `pricing.dart` `kitsBoutique` | ✅ |
| 3.5 | Récapitulatif + prix local / indicatif | `boutique_page.dart` `_LigneRecap` (l.1032), `Prix.devisKit` (l.661) | ✅ |
| 3.6 | Paiement routé selon le pays | `api.dart` `_fonctionCheckout` (l.60) ; bouton `Payer avec {fournisseur.libelle}` (l.736) | ✅ |
| 3.7 | Livraison après paiement (liens + email) | `paiement_en_attente_page.dart` (polling 5 s), `verify-payment`, `_shared/fulfillment.ts`, `delivery.ts` | ⚠️ (à prouver en sandbox SasPay) |

### Exigence 4 — Studio Live : abonnement 10 USD, régie 3 onglets, Jitsi + chat IA, invitation

| Case | Exigence client | Preuve attendue | Statut |
| --- | --- | --- | --- |
| 4.1 | Abonnement 10 USD / 30 jours | `pricing.dart` `studioUsd`/`studioJours` ; `pricing.ts` `PRIX_STUDIO_USD`/`DUREE_STUDIO_JOURS` ; `studio_live_page.dart` l.228 « 10 $ par mois » | ✅ |
| 4.2 | Régie 3 onglets « Préparer / Salle en direct / Livre Guide » | `studio_regie_page.dart` `_Onglets` (l.513-548), `_onglet` (l.51), `switch` (l.353) | ✅ |
| 4.3 | Salle en direct Jitsi | `jitsi_view_web.dart` `construireJitsi`, pont `ebookliveJitsi` (`web/index.html` l.435), script l.558 | ⚠️ (dépend CDN externe, **D7**) |
| 4.4 | Chat IA dans la salle | `ChatLivePanel` (l.1181), `.stream()` temps réel (l.1218) + polling (l.1242), `live-auto-chat/index.ts` | ⚠️ (à prouver bout en bout) |
| 4.5 | Livre Guide généré | `_OngletGuide` (l.1609), `generate-live-guide`, `studio.ts` l.731, email l.943 | ⚠️ (à prouver avec clés IA) |
| 4.6 | Lien d'invitation `/live/:roomId?invite=token` | `studio_regie_page.dart` l.79-85 (construction du lien), `main.dart` regex l.344, `live_room_page.dart` l.36/51, `studio-room/index.ts` | ✅ (construction + route) / ⚠️ (validation token à prouver) |
| 4.7 | Accès régie réservé à un abonné actif | `studio_regie_page.dart` `_Porte` (l.2076) + `studio_a_acces()` (migration l.222) + RLS sessions (l.333) | ✅ |
| 4.8 | Expiration à 30 jours | `expires_at` + `expirer_abonnements_studio()` (migration l.373) + `AbonnementStudio.joursRestants` | ⚠️ (job à planifier) |

### Exigence 5 — Assistant IA flottant + pleine page, « Retour au site », Guide 3 étapes

| Case | Exigence client | Preuve attendue | Statut |
| --- | --- | --- | --- |
| 5.1 | Assistant flottant sur les pages publiques | `SiteAssistantChat` monté sur `home_page.dart` (l.13), `boutique_page.dart`, `studio_live_page.dart` ; `site_assistant_chat.dart` `FloatingActionButton` (l.124) | ✅ |
| 5.2 | Bouton « Ouvrir en pleine interface » | `site_assistant_chat.dart` l.71 `Navigator.pushNamed(context, '/assistant')` ; route `main.dart` l.319 | ✅ |
| 5.3 | « Retour au site » conserve l'état | `assistant_page.dart` l.61 `Navigator.pop` (retour à la route précédente intacte), l.271 bouton | ✅ (logique) / ⚠️ (preuve manuelle) |
| 5.4 | Contexte assistant à jour (2 univers, tarifs, 23 pays, routes) | `_shared/assistant.ts` l.70-91 (`catalogueTexte`, `paysSasPayTexte`, `paysPaddleTexte`, `routesTexte`) | ✅ |
| 5.5 | CTA contextuel | `assistant.ts` `ctaUrl` (l.53-60) → `/boutique`, `/studio-live` ou `/guide` | ✅ |
| 5.6 | Guide & Tutoriel en 3 étapes | `guide_page.dart` `_etapes` (l.21-62), navigation (l.146) | ✅ |

### Exigence 6 — Migration SQL, config.toml, analyze/test/build 0 erreur

| Case | Exigence client | Preuve attendue | Statut |
| --- | --- | --- | --- |
| 6.1 | Migration SQL complète | `20260101000500_paddle_et_studio_live.sql` : colonnes, 4 tables, 3 fonctions, 4 policies, index, realtime, expiration | ✅ (fichier) / ⚠️ (application) |
| 6.2 | Migration idempotente | `add column if not exists`, `create table if not exists`, `drop policy if exists`, bloc `do $$ … exception …` (l.363) | ⚠️ (à rejouer) |
| 6.3 | `config.toml` à jour | 15 blocs `[functions.*]` pour 15 fonctions, `verify_jwt = false` documenté | ✅ |
| 6.4 | Aucun import cassé côté TypeScript | Script de vérification : 0 import `_shared` non résolu | ✅ |
| 6.5 | `flutter analyze` 0 erreur | `flutter analyze` | ⚠️ **non exécutable ici** (§ 1.3) |
| 6.6 | `flutter test` 0 échec | `flutter test` | ❌ **D1** : la suite **ne compile pas** (imports de pages supprimées l.7-8) + 1 assertion logo obsolète (l.64) + couverture nulle des 6 exigences |
| 6.7 | `flutter build web` 0 erreur | `flutter build web --release` | ⚠️ **non exécutable ici** (§ 1.3) |
| 6.8 | URL path (pas hash) + fallback SPA | `url_strategy_web.dart`, `main.dart` `_routeInitiale` (l.253), `netlify.toml` redirects | ✅ |
| 6.9 | Aucun secret commité | `git ls-files` : `supabase/.env` absent ; `.env.example` = placeholders | ✅ (la clé `sb_publishable_…` est publique par nature) |

---

## 4. Risques et mitigations

Classement par impact décroissant. `P` = probabilité, `I` = impact.

| # | Risque | P | I | Mitigation | Garde-fou (preuve) |
| --- | --- | --- | --- | --- | --- |
| **R1** | **Impossible de builder/analyser/tester le projet dans la sandbox** → « 0 erreur » non démontré, régressions non détectées avant déploiement | Certaine | 🔴 Critique | Exécuter la chaîne sur le poste utilisateur ou une CI (GitHub Actions `subosito/flutter-action`), joindre les logs ; ne jamais merger sur la foi d'une revue visuelle | Log `flutter analyze` (`No issues found!`), log `flutter test`, artefact `build/web` |
| **R2** | **Price IDs Paddle manquants ou devise incohérente** (un `pri_…` USD utilisé pour une transaction EUR → refus Paddle) | Élevée | 🔴 Critique | Renseigner les 5 IDs + variantes `_EUR` ; `priceIdPaddle()` choisit `_EUR` puis repli USD → **aligner la devise de transaction sur celle du price ID** ; tester en sandbox un achat EUR (FR) et un achat USD (MA→EUR, NG→USD) | `create-paddle-checkout` renvoie `devise` = devise du price ; transaction Paddle `completed` |
| **R3** | **RLS mal calibrée** (fuite de données ou écriture non autorisée sur `studio_*`) | Moyenne | 🔴 Critique | Rejouer les 4 requêtes de rôle (§ P2.9) ; vérifier que `studio_live_sessions` ne s'ouvre qu'avec un abonnement ACTIF **de l'appelant** ; ne jamais exposer `service_role` au client | Tests SQL : `anon`/`authenticated` non propriétaire → 0 ligne ; écriture messages → refus |
| **R4** | **Jitsi cross-origin / CDN indisponible** : `meet.jit.si` public = quotas, coupures, latence ; `external_api.js` en `async` peut ne pas être prêt au montage | Moyenne | 🟠 Élevé | Prévoir un domaine Jitsi dédié (JaaS ou auto-hébergé) ; attendre `window.JitsiMeetExternalAPI` avec retry + timeout ; message de repli explicite ; CSP autorisant `meet.jit.si` | Salle fonctionnelle dans les 2 onglets ; repli affiché si script bloqué |
| **R5** | **URL path vs hash** : navigation interne qui ne met pas à jour l'URL (D8), lien partagé qui ne pointe pas le bon écran, 404 si Netlify redirects régresse | Moyenne | 🟠 Élevé | Synchroniser l'URL (`SystemNavigator.routeInformationUpdated` ou migration `go_router`) ; tester `/boutique`, `/studio/regie`, `/live/x?invite=y` en direct + refresh ; garder le redirect Netlify sous test de fumée | `curl -I` 200 sur les 6 routes ; test « copier l'URL depuis la régie → ouvrir dans un autre onglet » |
| **R6** | **Tests dépendants du réseau / des IA** (DeepSeek, Gemini, Resend, Supabase, SasPay, Paddle) : suite instable, CI rouge aléatoire | Élevée | 🟠 Moyen | Aucun test unitaire ne doit appeler le réseau ; mocker `ApiService`/`http` ; réserver les appels réels à une suite « intégration » marquée et lancée manuellement | `flutter test` sans réseau → vert ; suite d'intégration séparée |
| **R7** | **Dérive des taux front/back** (« copie conforme » non testée) → prix affiché ≠ prix facturé | Moyenne | 🟠 Moyen | Test de parité obligatoire (P3.3) comparant `countries.dart` et `_shared/countries.ts` ; revue en binôme pour toute modification de `tauxXof` | Test vert : 152 devises identiques, 215 pays, 23 SasPay |
| **R8** | **Doubles sources pays/tarifs** (D3, D11) : l'espace client et La Boutique présentent des catalogues différents | Élevée | 🟡 Moyen | Exécuter P0.4 et P0.8 dans la même PR ; interdire tout nouvel import de `config.dart` hors `AppConfig` | `grep` 0 référence legacy ; `dart analyze` propre ; capture du dashboard avec pays NG |
| **R9** | **Cache / service worker** : anciens assets servis après déploiement (splash figé, ancienne marque) | Moyenne | 🟡 Moyen | `Cache-Control: no-cache` déjà posé sur `index.html` et `flutter_service_worker.js` (netlify.toml) ; vérifier en navigation privée après deploy ; bump `version` dans le service worker | Test post-deploy en cache vidé **et** en cache chaud |
| **R10** | **Secrets / clés exposées** (clé Supabase publishable OK, mais `service_role`, `SASPAY_*`, `PADDLE_API_KEY` jamais côté client) | Faible | 🔴 Critique | `grep` des secrets avant commit ; `.gitignore` sur `supabase/.env` ; rotation immédiate en cas de fuite | `git log -p` sans secret ; scan CI type `gitleaks` |

---

## 5. Definition of Done (mesurable)

La refonte est **livrable** lorsque **toutes** les lignes ci-dessous sont vraies et que leur preuve est archivée.

### 5.1 Build & analyse

- [ ] `flutter --version` exécuté et version consignée (↑ 3.x, Dart 3.13+).
- [ ] `flutter pub get` → exit 0, `pubspec.lock` inchangé sans justification.
- [ ] `flutter analyze` → **`No issues found!`** (0 error, 0 warning ; `info` tolérés = 0 par défaut).
- [ ] `flutter test` → **`All tests passed!`**, **≥ 40 tests**, 0 skip non justifié.
- [ ] `flutter build web --release` → exit 0 ; `build/web/main.dart.js` existe ; `build/web` < 4 Mo hors assets.
- [ ] Aucun `print()` de debug, aucun `TODO` bloquant, aucun `// ignore:` non justifié.

### 5.2 Base & backend

- [ ] `20260101000500_paddle_et_studio_live.sql` appliquée **deux fois** sans erreur (idempotence).
- [ ] 4 tables `studio_*` + colonnes `orders` conformes à `ARCHITECTURE_REFONTE.md` § 4.
- [ ] `studio_a_acces`, `mon_abonnement_studio`, `studio_session_publique` exécutables par les rôles prévus.
- [ ] 4 requêtes RLS de rôle (§ P2.9) exécutées avec le résultat attendu.
- [ ] `supabase/config.toml` : 15 fonctions déclarées, `deno check` (ou déploiement) sans erreur sur les 15.
- [ ] Secrets présents : `PADDLE_*` (dont 5 price IDs), `SASPAY_*`, `DEEPSEEK_API_KEY`, `GEMINI_API_KEY`, `RESEND_API_KEY`, `ADMIN_EMAILS`.

### 5.3 Parcours fonctionnels (preuves)

- [ ] **P1** Un visiteur non connecté ne voit **jamais** « Administration » ; un admin le voit et accède à `/admin-videos` ; un non-admin qui force l'URL voit la page « introuvable ».
- [ ] **P2** Sélection de 6 pays représentatifs (CI, CM, NG, KE, IN, FR) → le prix affiché change et la devise correspond (SasPay local, Paddle EUR/USD + indicatif).
- [ ] **P3** Un paiement SasPay sandbox livre un kit (liens + email) ; un paiement Paddle sandbox active un abonnement Studio.
- [ ] **P4** Studio Live : abonnement ACTIF → régie accessible → session `EN_DIRECT` → chat IA répond → Livre Guide `PRET` et reçu par email.
- [ ] **P5** Lien `/live/<room>?invite=<token>` ouvert en navigation privée → lobby + salle + chat ; token falsifié → refus.
- [ ] **P6** Assistant : bulle → « Ouvrir en pleine interface » → `/assistant` → « Retour au site » → **état de la page précédente conservé**.
- [ ] **P7** Guide & Tutoriel : 3 étapes navigables, contenu exact, mobile 390 px sans débordement.
- [ ] **P8** Confirmation de paiement en NGN affiche **NGN** (et non FCFA) — corrige D4.

### 5.4 Qualité web

- [ ] Splash web : logo vectoriel, barre de progression, disparition à `flutter-first-frame`, aucun flash blanc.
- [ ] Manifest : `name`, `theme_color #090D16`, icônes 192/512/maskable **à la marque** (D9 corrigé).
- [ ] `og:image` PNG 1200×630 (D10 corrigé) ; aperçu correct sur WhatsApp/OpenGraph.
- [ ] Lighthouse (mobile) : Performance ≥ 85, Accessibilité ≥ 90, Best-practices ≥ 90, SEO ≥ 90.
- [ ] Les 6 routes publiques répondent **200 en accès direct** et **après refresh**.
- [ ] Aucune erreur console au chargement des 6 pages ; aucun 404 de ressource.

### 5.5 Hygiène & documentation

- [ ] 0 référence à `LandingPage`/`CommandePage`/`paysAfricains`/`kitsMetiers` (D3, D11).
- [ ] Espace client : un utilisateur au Nigeria ou au Maroc peut sélectionner son pays et voit les 4 kits actuels.
- [ ] Aucun secret dans Git (`gitleaks` ou équivalent, 0 finding).
- [ ] `docs/ARCHITECTURE_REFONTE.md`, `DEPLOIEMENT.md` et ce plan à jour.
- [ ] Ce plan : toutes les cases des § 3 passées de ⚠️/❌ à ✅ avec un pointeur de preuve.

---

## 6. Annexes

### 6.1 Commandes de vérification (à exécuter hors sandbox)

```powershell
# 0. Environnement
flutter --version
flutter pub get

# 0 bis. Cohérence backend (exécutable ici, déjà vert pendant l'audit) — attendu : "TOUTES LES VÉRIFICATIONS PASSENT"
node .typecheck/verifier.mjs

# 1. Analyse statique — attendu : "No issues found!"
flutter analyze

# 2. Tests — attendu : "All tests passed!"
flutter test --reporter expanded

# 3. Build web — attendu : exit 0
flutter build web --release --dart-define=SITE_URL=https://e-booklive.offboard-hub.com `
  --dart-define=WHATSAPP_AIDE_NUMBER=22670123456

# 4. Base (projet de test, jamais la prod directement)
supabase db push --dry-run
supabase db push
supabase db push   # rejeu : doit être idempotent

# 5. Secrets + déploiement des fonctions
supabase secrets list
supabase functions deploy saspay-checkout create-paddle-checkout paddle-webhook verify-payment `
  generate-live-guide live-auto-chat studio-room

# 6. Fumée post-déploiement (attendu : 200 sur chacune)
curl.exe -I https://e-booklive.offboard-hub.com/
curl.exe -I https://e-booklive.offboard-hub.com/boutique
curl.exe -I https://e-booklive.offboard-hub.com/studio-live
curl.exe -I https://e-booklive.offboard-hub.com/guide
curl.exe -I https://e-booklive.offboard-hub.com/live/demo?invite=demo
```

> **Rappel d'audit** : dans cette session, les points 1 à 3 ont échoué pour cause de sandbox (`CreateFile failed 5` / `ProcessException: Accès refusé` au spawn du *frontend server* et de l'*analysis server*), et `flutter.bat` reste bloqué sans enfant `dart`. Ces commandes **doivent** être exécutées par l'agent responsable de la qualité sur un environnement non confiné.

### 6.2 Plan de tests à écrire (P0.2 + P3.2)

| Fichier cible | Contenu | Nombre indicatif |
| --- | --- | --- |
| `test/pricing_test.dart` | `Prix.arrondir` (devises entières vs décimales, seuils 1 000/10 000), `devisKit`/`devisStudio` pour 6 pays, `formater` (FCFA, €, $, NGN), `indicatif` | 12 |
| `test/countries_test.dart` | 215 pays, 23 SasPay (liste exacte), 152 devises, `rechercherPays` (accents, code, devise, indicatif), `paysParCode` défaut | 8 |
| `test/parite_backend_test.dart` | Lit `supabase/functions/_shared/countries.ts` et compare codes/devises/taux à `countries.dart` | 3 |
| `test/routes_test.dart` | Résolution `/`, `/boutique`, `/studio-live`, `/studio/regie`, `/guide`, `/assistant`, `/mon-espace`, `/admin-videos`, `/live/abc?invite=t` | 6 |
| `test/widget_public_test.dart` | `HomePage`, `BoutiquePage` (garde étape 1), `GuidePage` (3 étapes), `AssistantPage` (« Retour au site »), `AppHeader` (admin masqué) | 8 |
| `test/widget_studio_test.dart` | `StudioLivePage` (CTA 10 $), `StudioRegiePage` (3 onglets), `LiveRoomPage` (mode invité) | 6 |
| `test/widget_test.dart` (remplacé) | Logo (`find.byType(LogoEbooklive)`), splash, thème (`K.bg`/`K.or`), nav | 5 |

### 6.3 Invariants à ne jamais casser (revue de PR)

1. **Prix de référence** : kits 3 000 / 3 500 / 5 000 / 9 000 XOF ; Studio 10 USD / 30 jours.
2. **Aucun montant client** n'est accepté : tout est recalculé par `pricing.ts`.
3. **23 pays SasPay exactement** : ML, SN, CI, BF, BJ, TG, NE, CM, GA, CG, CD, GN, NG, GH, SL, KE, UG, TZ, RW, MW, MZ, ZM, IN.
4. **Taux front = taux back** (152 devises).
5. **Routes publiques** : `/`, `/boutique`, `/studio-live`, `/studio/regie`, `/guide`, `/assistant`, `/live/:roomId`, `/mon-espace`, `/admin-videos`, `/cgv`, `/mentions-legales`, `/faq`.
6. **`/admin-videos`** : invisible + protégé (jamais de simple masquage CSS).
7. **SasPay** = montant local recalculé ; **Paddle** = EUR (Europe/Maghreb) ou USD, conversion locale **indicative** uniquement.
8. **Idempotence** : webhooks et génération de guide ne livrent jamais deux fois.
9. **RLS** : aucune écriture client sur `studio_subscriptions`, `studio_guides`, `studio_live_messages`.
10. **Marque** : fond `#090D16`, surfaces `#111827`, dégradé or `#F7D488 → #E7B84B` puis émeraude `#34D399`.

### 6.4 Journal de l'audit

- `git status` (22:58) : 13 fichiers suivis modifiés (`config.dart`, `models.dart`, `theme.dart`, `main.dart`, `api.dart`, `app_header.dart`, `site_assistant_chat.dart`, `netlify.toml`, `web/index.html`, `web/manifest.json`, `supabase/.env.example`, `supabase/config.toml`, `DEPLOIEMENT.md`, plusieurs `_shared/*.ts` et 4 Edge Functions) + **2 suppressions** (`lib/pages/landing_page.dart`, `lib/pages/commande_page.dart`) + ~40 nouveaux fichiers (`countries.dart`, `pricing.dart`, `app_state.dart`, `url_strategy*`, `stockage_pays*`, `home_page`, `boutique_page`, `studio_live_page`, `studio_regie_page`, `guide_page`, `live_room_page`, `assistant_page`, `admin_guard_page`, `splash_page`, `paiement_en_attente_page`, `logo_ebooklive`, `country_picker`, `jitsi_view*`, `paddle_checkout*`, `checkout_ouverture`, `telechargement*`, 8 Edge Functions, migration `…000500`, `.typecheck/`).
- Compteurs : **53** fichiers Dart (17 343 lignes), **30** fichiers TS (7 067 lignes), **6** migrations (825 lignes), **215** pays, **23** SasPay, **152** devises, **15** Edge Functions.
- Vérifications **exécutées** : `dart.exe --version` → SDK 3.13.7 ; `node .typecheck/verifier.mjs` → **« TOUTES LES VÉRIFICATIONS PASSENT »** (prix kits/studio, arrondis, formats par devise, 8 secteurs, alias legacy, routage, 215 pays, 23 codes SasPay) ; scripts de diff pays/devises/taux front↔back → **0 divergence** ; imports Dart/TS locaux → **0 non résolu hors `test/widget_test.dart`** (D1).
- Vérifications **impossibles** : `flutter analyze`, `flutter test`, `flutter build web` et toute commande Dart nécessitant un sous-processus (`CreateFile failed 5` / `ProcessException: Accès refusé`) ; `flutter.bat` bloque sans enfant `dart`.

---

## 7. Résumé final — 5 risques majeurs par impact

| Rang | Risque | Impact | Mitigation immédiate |
| --- | --- | --- | --- |
| **1** | **Chaîne Flutter non exécutable ici** → `analyze`/`test`/`build web` non prouvés, **et `flutter test` ne compile déjà plus** (imports de pages supprimées) : déploiement à l'aveugle | 🔴 Critique | Rejouer les commandes § 6.1 sur un poste non confiné ou une CI, archiver les logs, **bloquer le merge sans eux** ; traiter D1 en priorité absolue |
| **2** | **Paddle mal configuré** (price IDs absents / devise du price ≠ devise facturée) → paiement international cassé en production | 🔴 Critique | Poser les 5 IDs + variantes EUR, tester un achat EUR (FR) et un USD (NG) en sandbox, vérifier l'alignement `pri_…` ↔ devise |
| **3** | **RLS studio non prouvée** → fuite de messages/abonnements ou écriture non autorisée | 🔴 Critique | Exécuter les 4 requêtes de rôle (anon / authenticated non propriétaire / propriétaire / service_role) avant release |
| **4** | **Jitsi via CDN public** (`meet.jit.si` en `async`) → salle indisponible ou non montée | 🟠 Élevé | Attendre l'API avec retry+timeout, message de repli, envisager un domaine Jitsi/JaaS dédié |
| **5** | **URL path non synchronisée + fallback SPA** → liens partagés erronés, 404 si Netlify régresse | 🟠 Élevé | Synchroniser l'URL (`routeInformationUpdated`/`go_router`), test de fumée `curl -I` sur les 6 routes, garder les redirects sous test |

> **Verdict planner** : la refonte est **fonctionnellement écrite à ~95 %**, **prouvée côté backend** (harness `node .typecheck/verifier.mjs` vert : prix, arrondis, formats, 215 pays, 23 SasPay) mais **non prouvée côté Flutter** — la suite de tests ne compile même plus. La priorité n'est pas d'ajouter des fonctionnalités mais de (1) rendre la vérification Flutter possible hors sandbox, (2) reconstruire la suite de tests, (3) corriger l'affichage devise (D4) et l'espace client legacy (D11), (4) poser les secrets Paddle. Le plan P0 → P3 ci-dessus est ordonné pour cela.
