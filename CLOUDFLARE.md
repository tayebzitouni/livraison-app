# Backend Cloudflare de production

API : `https://livraison-api.story-trends-dz.workers.dev`

Politiques publiques :

- https://livraison-api.story-trends-dz.workers.dev/privacy
- https://livraison-api.story-trends-dz.workers.dev/terms
- https://livraison-api.story-trends-dz.workers.dev/refund

Le Worker utilise D1 pour les données et R2 pour les images/vidéos. Les commerçants proposent un prix de gros ; l'administrateur fixe le prix client et approuve le produit. Il règle aussi le pourcentage de commission et les frais de livraison. Chaque commande conserve les tarifs appliqués au moment de sa création. La comptabilisation des portefeuilles a lieu après confirmation de la réception par le client.

## Déploiement

Depuis `cloudflare/worker` :

```bash
npm install
npx wrangler d1 migrations apply livraison-prod --remote
npx wrangler d1 execute livraison-prod --remote --file=seed.sql
npx wrangler secret put ADMIN_SETUP_TOKEN
npx wrangler deploy
```

Puis construire l'application connectée :

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://livraison-api.story-trends-dz.workers.dev
```

Les comptes de démonstration sont listés dans `README.md`.

Pour créer le premier compte administrateur sur le backend, choisir **Créer un compte → Administrateur** dans l'application, saisir un mot de passe d'au moins 12 caractères et le code enregistré dans `ADMIN_SETUP_TOKEN`. La création est désactivée dès qu'un administrateur existe. Les bases neuves doivent recevoir `schema.sql` avant `seed.sql` ; les bases existantes reçoivent toutes les migrations jusqu’à `0008_commission_markup_and_indexes.sql`.

## Mise à jour 1.6

Appliquer la migration **avant** de déployer le Worker (le Worker écrit le téléphone du client dans les commandes) :

```bash
cd cloudflare/worker
npx wrangler d1 migrations apply livraison-prod --remote   # jusqu’à 0008_commission_markup_and_indexes.sql
npx wrangler deploy
```

Nouveautés de l'API :

- `POST /api/auth/guest` crée le compte client invité d'un appareil (rôle `client`, aucun droit supplémentaire).
- `GET /api/auth/me` valide la session enregistrée par l'application.
- `POST /api/auth/signup` accepte uniquement le rôle `restaurant` (une cuisine s'inscrit seule) ; les autres rôles reçoivent `kitchen_only`.
- `GET /api/products` et `GET /api/categories` sans session renvoient le catalogue public (produits approuvés et actifs).
- Photo, ingrédients et allergènes sont facultatifs à la création d'un produit.
- `GET /api/orders` renvoie les numéros de téléphone uniquement aux personnes qui doivent se joindre : le client et le livreur assigné s'échangent leurs numéros, la cuisine voit celui du livreur, le livreur voit celui de la cuisine.
