# Vérification Google Search Console & SEO technique

**Date** : 24/11/2026

## 1. Fichier de vérification Google

Fichier : `web/googleac9a31c15af6fc38.html`  
Contenu exact (53 octets, sans newline) :

```text
google-site-verification: googleac9a31c15af6fc38.html
```

- ✅ Présent dans `web/`.
- ✅ Copié dans `build/web/googleac9a31c15af6fc38.html`.
- ✅ Servi en local avec `Content-Type: text/html` et le contenu exact.
- ❌ **Sur le site en ligne actuel**, `https://e-booklive.offboard-hub.com/googleac9a31c15af6fc38.html`
  renvoie **le HTML de l'application** (index SPA), pas le fichier de vérification.

**Cause** : le site Netlify n'a pas encore été redéployé avec le nouveau build.
Le fichier est présent dans `build/web`, mais l'ancien déploiement ne le contient pas.
La règle Netlify `/* -> /index.html` ne doit pas masquer un fichier statique existant ;
Netlify sert normalement les fichiers existants avant les redirects non forcés.

**À faire** : déployer le nouveau `build/web` sur Netlify, puis vérifier :

```bash
curl -i https://e-booklive.offboard-hub.com/googleac9a31c15af6fc38.html
```

Attendu : `200`, `Content-Type: text/html`, corps exact du fichier.
Ensuite, dans Search Console : **Vérifier** la propriété par fichier HTML.

> Si Netlify injecte le script « Netlify Drawer » dans ce fichier, le corps ne sera
> plus exact. Vérifiez le corps après déploiement ; si c'est le cas, désactivez
> l'injection de snippet ou servez le fichier via une règle dédiée.

## 2. Problèmes SEO trouvés et corrigés

| Problème | État |
|---|---|
| `robots.txt` absente (retournait le HTML SPA) | ✅ créée : `web/robots.txt` |
| `sitemap.xml` absent (retournait le HTML SPA) | ✅ créé : `web/sitemap.xml` (4 URLs) |
| Fichier Google non déployé | ❌ à redéployer sur Netlify |
| Pages privées indexables | ✅ `robots.txt` bloque `/admin-videos`, `/mon-espace`, `/kit.html`, `/live/`, `/paiement-en-attente`, `/confirmation` |
| Canonical / description / OG | ✅ dynamiques par route dans `web/index.html` (accueil, boutique, studio-live, guide) |
| Image sociale `Icon-512.png` | ✅ présente dans `web/icons/` |

Robots :

```text
User-agent: *
Allow: /
Disallow: /admin-videos
Disallow: /mon-espace
Disallow: /studio/regie
Disallow: /kit.html
Disallow: /live/
Disallow: /paiement-en-attente
Disallow: /confirmation
Sitemap: https://e-booklive.offboard-hub.com/sitemap.xml
```

Sitemap : accueil, `/boutique`, `/studio-live`, `/guide`.

## 3. Vérification locale

```text
googleac9a31c15af6fc38.html 200 text/html "google-site-verification: googleac9a31c15af6fc38.html"
robots.txt                   200 text/plain
sitemap.xml                  200 text/xml, 4 URLs, XML valide
```

## 4. Après déploiement Netlify

1. Tester l'URL du fichier Google (contenu exact + 200).
2. Tester `https://e-booklive.offboard-hub.com/robots.txt`.
3. Tester `https://e-booklive.offboard-hub.com/sitemap.xml`.
4. Dans Search Console : vérifier la propriété, puis soumettre le sitemap.
5. Vérifier que Netlify ne réécrit pas le fichier Google avec un script injecté.
6. Attendre l'exploration ; les routes Flutter sont rendues côté client, donc
   l'indexation peut prendre plus de temps qu'un site statique classique.
