# Wasla Livraison

Application Flutter multi-rôles pour commander des repas et des produits de supérette, suivre la livraison et gérer l'activité de chaque partenaire.

La version 1.4 ajoute l'accès client sans inscription, l'approbation des prix par l'administrateur, les tarifs configurables, les rapports PDF et l'interface en français et en arabe.

La version 1.4.1 place la navigation dans une barre flottante, rend l'adresse de livraison modifiable et mémorisée, et simplifie la connexion des partenaires. L'accès administrateur se trouve sur un lien séparé de la sélection des rôles ; le client utilise directement l'accueil sans connexion.

## Parcours métier

`Client passe la commande → Livreur valide → Restaurant/Supérette accepte et prépare → Livreur récupère → Livreur livre → Client confirme la réception`

- Client : catalogue dynamique, fiches produit complètes, panier mono-partenaire, paiement, suivi, confirmation de réception et statistiques.
- Livreur : missions disponibles, validation, collecte, livraison et gains.
- Restaurant : plats uniquement, photo ou vidéo, composition, allergènes, prix de gros, commandes et chiffre d'affaires. Les nouveaux plats attendent la validation de l'administrateur.
- Supérette : produits d'épicerie uniquement, photo, détails et prix de gros. Les nouveaux produits attendent la validation de l'administrateur.
- Administrateur : utilisateurs, commandes, catalogue, validation et prix client des produits, pourcentage de commission, frais de livraison et statistiques globales. Le premier compte admin se crée avec le code de configuration du Worker.

L'application s'ouvre sur l'espace client sans inscription. Un accès en haut de l'accueil permet la connexion ou l'inscription des partenaires. Les commandes et le panier du client invité restent liés à son appareil. Chaque rôle peut consulter un rapport quotidien, hebdomadaire ou mensuel et exporter un PDF. Le français et l'arabe sont disponibles dans le profil. Les médias sont stockés dans Cloudflare R2. Le paiement d'une commande n'est distribué aux portefeuilles qu'après la confirmation finale du client.

## Comptes de démonstration hors ligne

| Rôle | E-mail | Mot de passe |
| --- | --- | --- |
| Client | `client@wasla.dz` | `Demo123!` |
| Livreur | `livreur@wasla.dz` | `Demo123!` |
| Restaurant | `restaurant@wasla.dz` | `Demo123!` |
| Supérette | `superette@wasla.dz` | `Demo123!` |
| Admin | `admin@wasla.dz` | `Admin123!` |

Sans URL d'API, l'application utilise automatiquement les données de démonstration intégrées.
Le mot de passe de l'administrateur en production est volontairement différent et ne doit jamais être enregistré dans le code de l'application.

## Lancer Flutter

```bash
flutter pub get
flutter run
```

Pour connecter le Worker Cloudflare :

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR-WORKER.workers.dev
```

## API Cloudflare Workers + D1

```bash
cd cloudflare/worker
npm install
npx wrangler d1 execute livraison-prod --remote --file=schema.sql
npx wrangler d1 execute livraison-prod --remote --file=seed.sql
npx wrangler secret put ADMIN_SETUP_TOKEN
npx wrangler deploy
```

Pour une base existante, appliquer la migration avant le déploiement :

```bash
npx wrangler d1 migrations apply livraison-prod --remote
```

Le Worker applique les permissions et transitions côté serveur, utilise des requêtes D1 préparées, PBKDF2 pour les nouveaux mots de passe et crée les mouvements de portefeuille après la confirmation du client.
Après le déploiement, créer le premier administrateur depuis l'écran d'inscription avec le code `ADMIN_SETUP_TOKEN`.
