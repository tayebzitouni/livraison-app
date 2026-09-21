# Backend Cloudflare de production

API : `https://livraison-api.story-trends-dz.workers.dev`

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

Pour créer le premier compte administrateur sur le backend, choisir **Créer un compte → Administrateur** dans l'application, saisir un mot de passe d'au moins 12 caractères et le code enregistré dans `ADMIN_SETUP_TOKEN`. La création est désactivée dès qu'un administrateur existe. Les bases neuves doivent recevoir `schema.sql` avant `seed.sql` ; les bases existantes reçoivent la migration `0005_admin_pricing.sql`.
