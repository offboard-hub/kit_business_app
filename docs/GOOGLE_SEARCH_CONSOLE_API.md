# Obtenir l’accès API Google Search Console

Une **clé API simple ne suffit pas** pour Search Console. Il faut un **compte de
service Google** (service account) et l’ajouter comme utilisateur de la propriété.

## 1. Créer le projet et activer l’API

1. Ouvrir <https://console.cloud.google.com/>.
2. Créer un projet (ou sélectionner un projet existant).
3. Ouvrir <https://console.cloud.google.com/apis/library/searchconsole.googleapis.com>
   et cliquer **Activer**.

## 2. Créer le compte de service

1. **IAM & Admin → Service Accounts → Create service account**.
2. Nom : `gsc-e-booklive`.
3. Rôle : aucun rôle IAM nécessaire.
4. Créer, puis ouvrir le compte → **Keys → Add key → Create new key → JSON**.
5. Télécharger le fichier JSON.

Le fichier contient :

```json
{
  "type": "service_account",
  "project_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----...",
  "client_email": "gsc-e-booklive@....iam.gserviceaccount.com",
  "client_id": "...",
  ...
}
```

## 3. Donner accès dans Search Console

1. Ouvrir <https://search.google.com/search-console>.
2. Sélectionner la propriété :
   - `https://e-booklive.offboard-hub.com/` (propriété Préfixe d’URL), ou
   - `sc-domain:e-booklive.offboard-hub.com` (propriété Domaine).
3. **Paramètres → Utilisateurs et autorisations → Ajouter un utilisateur**.
4. Coller l’adresse `client_email` du JSON.
5. Autorisation : **Complet** (ou **Propriétaire**).
   - Complet est nécessaire pour soumettre/supprimer un sitemap.
   - L’inspection d’URL refuse les accès « Restreint ».

## 4. Déposer le fichier sans le commit

Placez le JSON ici :

```text
.secrets/gsc-service-account.json
```

`.secrets/` et `*service-account*.json` sont déjà ignorés par `.gitignore`.
Ne collez jamais la clé privée dans une conversation ou dans Git.

## 5. Ce que l’API permet

Avec le compte de service, on peut :

- lister les propriétés Search Console ;
- soumettre `https://e-booklive.offboard-hub.com/sitemap.xml` ;
- lire les données Search Analytics ;
- inspecter une URL (URL Inspection API).

**Ce que l’API ne permet pas :** demander l’indexation d’une page normale.
L’Indexing API est réservée aux offres d’emploi et aux événements en direct.
L’action « Demander une indexation » reste une action manuelle dans Search
Console. L’indexation et le classement restent décidés par Google.

## 6. Alternative OAuth

Si le compte de service est refusé, créer un **ID client OAuth** de type
« Application de bureau », puis utiliser OAuth 2.0 Playground avec le scope :

```text
https://www.googleapis.com/auth/webmasters
```

et fournir `client_id`, `client_secret` et `refresh_token`.
