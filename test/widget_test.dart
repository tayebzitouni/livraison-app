import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/main.dart';
import 'package:livraison_app/marketplace_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MarketplaceStore> pumpRole(
  WidgetTester tester,
  String email,
  String password,
  UserRole role,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = MarketplaceStore();
  addTearDown(store.dispose);
  expect(await store.login(email, password, role), true);
  await tester.pumpWidget(LivraisonApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> closeSheet(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Arabic switches navigation and layout direction', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await pumpRole(
      tester,
      'client@wasla.dz',
      'Demo123!',
      UserRole.client,
    );
    await store.setLanguage('ar');
    await tester.pumpAndSettle();
    expect(find.text('الرئيسية'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.text('الرئيسية').first)),
      TextDirection.rtl,
    );
  });

  testWidgets('authentication is role aware at phone width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const LivraisonApp());
    expect(find.text('Voir les produits'), findsNothing);
    await tester.tap(find.byKey(const Key('partner-space-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('wasla'), findsOneWidget);
    expect(find.text('Bon retour !'), findsOneWidget);
    expect(find.text('Client'), findsNothing);
    expect(find.text('Administrateur'), findsNothing);
    expect(find.text('Livreur'), findsNothing);
    expect(find.text('Restaurant'), findsNothing);
    expect(find.text('Supérette'), findsNothing);
    expect(find.text('Accès administrateur'), findsNothing);
    expect(find.text('Accès administrateur sécurisé'), findsNothing);
    await tester.ensureVisible(
      find.text('Votre compte partenaire est créé par l’administrateur.'),
    );
    expect(
      find.text('Votre compte partenaire est créé par l’administrateur.'),
      findsOneWidget,
    );
    expect(find.text('Créer un compte'), findsNothing);
  });

  testWidgets('administrator signs in with the partner form', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MarketplaceStore()..openAuth();
    addTearDown(store.dispose);
    await tester.pumpWidget(LivraisonApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Accès administrateur'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'admin@wasla.dz');
    await tester.enterText(find.byType(TextField).last, 'Admin123!');
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(store.currentUser!.role, UserRole.admin);
    expect(find.text('Vue administrateur'), findsOneWidget);
  });

  testWidgets('client can use notifications, catalog, cart and profile tools', (
    tester,
  ) async {
    final store = await pumpRole(
      tester,
      'client@wasla.dz',
      'Demo123!',
      UserRole.client,
    );
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    await closeSheet(tester);

    await tester.tap(find.text('Healthy').first);
    await tester.pumpAndSettle();
    expect(find.text('Restaurants & menus'), findsOneWidget);
    await tester.ensureVisible(find.text('Bowl poulet du jardin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bowl poulet du jardin'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.ensureVisible(
      find.text('Poulet aux herbes, quinoa et houmous'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('kcal'), findsNothing);
    expect(find.textContaining('Calorie'), findsNothing);
    expect(find.byKey(const Key('product-note-field')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('product-note-field')));
    await tester.enterText(
      find.byKey(const Key('product-note-field')),
      'Sans oignons',
    );
    await tester.tap(find.text('Ajouter au panier'));
    await tester.pumpAndSettle();
    expect(store.cartCount, 1);
    await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Votre commande'), findsOneWidget);
    expect(find.byKey(const Key('order-note-field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('order-phone-field')), '');
    await tester.enterText(find.byKey(const Key('order-address-field')), '');
    await tester.tap(find.byKey(const Key('confirm-phone-order')));
    await tester.pumpAndSettle();
    expect(find.text('Ajoutez un numéro de téléphone.'), findsOneWidget);
    expect(store.cartCount, 1);
    await tester.enterText(
      find.byKey(const Key('order-phone-field')),
      '0550123456',
    );
    await tester.enterText(
      find.byKey(const Key('order-note-field')),
      '${store.pendingOrderNote}\nSonner à l’arrivée',
    );
    await tester.tap(find.byKey(const Key('confirm-phone-order')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Le livreur vous contactera bientôt pour confirmer la commande.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(store.orders.first.address, isEmpty);
    expect(store.orders.first.note, contains('Tél. 0550123456'));
    expect(store.orders.first.note, contains('Sans oignons'));
    expect(store.orders.first.note, contains('Sonner à l’arrivée'));

    await tapNav(tester, 'Commandes');
    expect(find.textContaining('Paiement reçu'), findsWidgets);
    await tapNav(tester, 'Profil');
    await tester.tap(find.text('Informations personnelles'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier mon profil'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Sofia Mobile');
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();
    expect(store.currentUser!.name, 'Sofia Mobile');
    for (final label in ['Adresses', 'Paiements', 'Aide et support']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsWidgets);
      await closeSheet(tester);
    }
  });

  testWidgets('client can open partner access and profile from the header', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(LivraisonApp(store: store));
    await tester.pumpAndSettle();
    final shell = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(shell.extendBody, true);
    expect(find.byType(FloatingNav), findsOneWidget);
    expect(find.byKey(const Key('delivery-address-trigger')), findsNothing);
    expect(find.textContaining('ماذا تشتهي'), findsNothing);
    expect(find.textContaining('Qu’est-ce qui vous'), findsNothing);
    expect(find.byTooltip('Ouvrir le profil'), findsNothing);
    expect(find.textContaining('LIVRER À'), findsNothing);
    expect(find.textContaining('التوصيل إلى'), findsNothing);
    expect(find.textContaining('kcal'), findsNothing);
    await tester.tap(find.byKey(const Key('partner-space-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('Bon retour !'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tapNav(tester, 'Profil');
    expect(find.text('Compte, préférences et assistance.'), findsOneWidget);
  });

  testWidgets('courier can accept an offer, navigate and request withdrawal', (
    tester,
  ) async {
    final store = await pumpRole(
      tester,
      'livreur@wasla.dz',
      'Demo123!',
      UserRole.courier,
    );
    final offer = store.orders.firstWhere(
      (order) => order.status == OrderStatus.placed,
    );
    await tester.ensureVisible(find.text('Valider et prendre').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider et prendre').first);
    await tester.pumpAndSettle();
    expect(offer.status, OrderStatus.courierValidated);
    await tapNav(tester, 'Livraisons');
    expect(find.text('Livraisons'), findsWidgets);
    await tapNav(tester, 'Revenus');
    await tester.ensureVisible(find.text('Demander un retrait'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demander un retrait'));
    await tester.pumpAndSettle();
    expect(store.walletBalance, 0);
    expect(find.text('Demande de retrait enregistrée.'), findsOneWidget);
  });

  testWidgets('restaurant can publish and toggle a meal', (tester) async {
    final store = await pumpRole(
      tester,
      'restaurant@wasla.dz',
      'Demo123!',
      UserRole.restaurant,
    );
    await tester.tap(find.text('Nouveau plat'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter une photo ou une vidéo'), findsOneWidget);
    expect(find.text('Description complète *'), findsOneWidget);
    await tester.ensureVisible(find.text('Envoyer pour validation'));
    await tester.tap(find.text('Envoyer pour validation'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ajoutez le média et complétez tous les détails obligatoires.'),
      findsWidgets,
    );
    await closeSheet(tester);
    await store.addProduct(
      name: 'Couscous royal',
      description: 'Légumes de saison, poulet et semoule fine.',
      category: 'Healthy',
      retail: 1200,
      wholesale: 700,
      emoji: 'C',
      mediaUrl: 'assets/marketplace_hero.png',
      ingredients: const ['Semoule', 'Poulet', 'Légumes'],
    );
    expect(store.products.first.name, 'Couscous royal');
    expect(store.products.first.kind, ProductKind.meal);
    await tapNav(tester, 'Produits');
    expect(store.products.first.approvalStatus, 'pending');
    await store.login('admin@wasla.dz', 'Admin123!', UserRole.admin);
    expect(
      await store.reviewProduct(
        store.products.first,
        approve: true,
        retailPrice: 1200,
      ),
      true,
    );
    await store.login('restaurant@wasla.dz', 'Demo123!', UserRole.restaurant);
    final before = store.products.first.available;
    expect(await store.toggleProduct(store.products.first), true);
    expect(store.products.first.available, !before);
  });

  testWidgets('supermarket and admin dashboards render every destination', (
    tester,
  ) async {
    await pumpRole(
      tester,
      'superette@wasla.dz',
      'Demo123!',
      UserRole.supermarket,
    );
    for (final label in ['Commandes', 'Produits', 'Profil']) {
      await tapNav(tester, label);
    }

    final admin = MarketplaceStore();
    addTearDown(admin.dispose);
    expect(
      await admin.login('admin@wasla.dz', 'Admin123!', UserRole.client),
      true,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(LivraisonApp(store: admin));
    await tester.pumpAndSettle();
    for (final label in ['Comptes', 'Commandes', 'Gestion', 'Profil']) {
      await tapNav(tester, label);
    }
    expect(find.text('Profil'), findsWidgets);
  });

  testWidgets('admin can open a compte to see stats and print a report', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpRole(tester, 'admin@wasla.dz', 'Admin123!', UserRole.admin);
    await tapNav(tester, 'Comptes');
    await tester.tap(find.text('Sofia Benali'));
    await tester.pumpAndSettle();
    expect(find.text('Statistiques'), findsOneWidget);
    expect(find.text('Gérer le compte'), findsOneWidget);
    expect(find.text('Imprimer le rapport complet'), findsOneWidget);
    expect(find.text('Commandes récentes'), findsOneWidget);
  });
}
