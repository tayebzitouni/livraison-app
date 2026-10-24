# Wasla — fiche Google Play / App Store

Envoyez ce fichier avec les captures d’écran. Les politiques publiques sont déjà dans l’application **et** en ligne.

## Liens publics (obligatoires Play Console)

- Politique de confidentialité : https://livraison-api.story-trends-dz.workers.dev/privacy
- Conditions d’utilisation : https://livraison-api.story-trends-dz.workers.dev/terms
- Politique de remboursement : https://livraison-api.story-trends-dz.workers.dev/refund
- Version arabe : ajoutez `?lang=ar` à la fin de chaque URL.

Dans l’app : **Profil → Politique de confidentialité / Conditions d’utilisation / Politique de remboursement**.

## Informations application

| Champ | Valeur |
| --- | --- |
| Nom | Wasla |
| Package | `dz.wasla.livraison` |
| Version | 1.5.0 (versionCode 15) |
| Fichier Play | `Wasla-Livraison-v1.5.0.aab` |
| Signature | Release (pas debug) |
| Icône | Tajine — `graphics/app-icon-512.png` |
| Catégorie | Food & Drink |
| E-mail contact | support@wasla.dz |
| Téléphone | 0554 91 75 45 |
| Site | https://livraison-api.story-trends-dz.workers.dev/privacy |
| Pays | Algérie |

## Description courte (80 caractères max)

FR : Commandez repas et courses en Algérie. Livraison locale avec Wasla.

AR : اطلب وجباتك ومشترياتك في الجزائر. توصيل محلي مع وصلة.

## Description longue FR

Wasla est l’application de commande et de livraison locale.

- Parcourez les restaurants et supérettes partenaires.
- Consultez photos, ingrédients et allergènes.
- Ajoutez des notes pour le restaurant ou le livreur.
- Confirmez votre commande par WhatsApp ou par appel. Seul le téléphone est obligatoire.
- Suivez la commande jusqu’à la confirmation de réception.

Les partenaires (livreurs, restaurants, supérettes) sont créés par l’administrateur Wasla. Paiement à la livraison. Français et arabe.

Politique de confidentialité, conditions d’utilisation et politique de remboursement : disponibles dans Profil, et sur les liens ci-dessus.

## وصف طويل AR

وصلة تطبيق الطلب والتوصيل المحلي.

- تصفّح المطاعم والبقالات الشريكة.
- اطّلع على الصور والمكونات ومسببات الحساسية.
- أضف ملاحظات للمطعم أو الموصل.
- أكّد طلبك عبر واتساب أو مكالمة. رقم الهاتف فقط إلزامي.
- تابع الطلب حتى تأكيد الاستلام.

يفتح المسؤول حسابات الشركاء. الدفع عند الاستلام. العربية والفرنسية.

سياسة الخصوصية وشروط الخدمة وسياسة الاسترجاع داخل الملف الشخصي وعلى الروابط أعلاه.

## Captures d’écran à joindre (téléphone)

Joindre 4 à 8 captures du téléphone, sans barre de debug :

1. Accueil client (catalogue / partenaires)
2. Fiche produit (photo, ingrédients, notes)
3. Panier / confirmation WhatsApp et appel
4. Profil (cette page doit montrer les 3 politiques)
5. Connexion partenaire
6. Suivi d’une commande

Fichiers de référence déjà dans le projet :

- `test/goldens/client_home.png`
- `test/goldens/partner_auth.png`
- `assets/marketplace_hero.png`
- `assets/products/`

## Icône / graphisme

- Icône : `play-store-pack/graphics/app-icon-512.png` (tajine, sans texte). Le nom affiché reste Wasla.
- Image mise en avant : `play-store-pack/graphics/feature-graphic-1024x500.png` — 1024 × 500 px.
