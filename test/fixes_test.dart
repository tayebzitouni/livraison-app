import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/data/cloudflare_backend.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/main.dart';
import 'package:livraison_app/marketplace_store.dart';
import 'package:livraison_app/order_contact.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MarketplaceStore> pump(
  WidgetTester tester,
  String email,
  String password,
  UserRole role,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 900);
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

Future<void> nav(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(Key('nav-$label')).last);
  await tester.pumpAndSettle();
}

Future<void> closeSheet(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('4. support does not expose a private phone number', () {
    testWidgets('Aide et support shows e-mail but no phone number', (
      tester,
    ) async {
      await pump(tester, 'client@wasla.dz', 'Demo123!', UserRole.client);
      await nav(tester, 'Profil');
      await tester.tap(find.text('Aide et support'));
      await tester.pumpAndSettle();
      expect(find.text('support@wasla.dz'), findsOneWidget);
      expect(find.textContaining('0668'), findsNothing);
      expect(find.byIcon(Icons.phone_outlined), findsNothing);
    });
  });

  group('5. only kitchens register themselves', () {
    test('a kitchen can sign up and is signed in', () async {
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      final ok = await store.signup(
        name: 'Amel Cuisine',
        email: 'amel@cuisine.dz',
        password: 'Secret123',
        role: UserRole.restaurant,
        businessName: 'Chez Amel',
        phone: '0550123456',
      );
      expect(ok, true);
      expect(store.currentUser!.role, UserRole.restaurant);
      expect(store.currentUser!.businessName, 'Chez Amel');
    });

    test(
      'couriers, supermarkets and clients cannot sign up themselves',
      () async {
        final store = MarketplaceStore();
        addTearDown(store.dispose);
        for (final role in [
          UserRole.courier,
          UserRole.supermarket,
          UserRole.client,
        ]) {
          expect(
            await store.signup(
              name: 'Test User',
              email: '${role.name}@test.dz',
              password: 'Secret123',
              role: role,
              businessName: 'Shop',
            ),
            false,
            reason: role.name,
          );
          expect(store.lastError, contains('cuisines'));
        }
        expect(store.users.any((u) => u.email.endsWith('@test.dz')), false);
      },
    );

    test('invalid kitchen details are explained', () async {
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      expect(
        await store.signup(
          name: 'A',
          email: 'not-an-email',
          password: 'short',
          role: UserRole.restaurant,
          businessName: '',
        ),
        false,
      );
      expect(store.lastError, contains('8 caractères'));
      expect(
        await store.signup(
          name: 'Client Admin',
          email: 'client@wasla.dz',
          password: 'Secret123',
          role: UserRole.restaurant,
          businessName: 'Doublon',
        ),
        false,
      );
      expect(store.lastError, contains('déjà utilisée'));
    });

    testWidgets('the sign-in screen offers kitchen registration', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MarketplaceStore()..openAuth();
      addTearDown(store.dispose);
      await tester.pumpWidget(LivraisonApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth-mode-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Inscrire ma cuisine'), findsOneWidget);
      // Errors show inside the form.
      await tester.ensureVisible(find.byKey(const Key('signup-submit')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('8 caractères minimum'), findsWidgets);
      await tester.enterText(find.byKey(const Key('signup-name')), 'Amel B');
      await tester.enterText(
        find.byKey(const Key('signup-kitchen')),
        'Chez Amel',
      );
      await tester.enterText(
        find.byKey(const Key('signup-phone')),
        '0550123456',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Adresse e-mail'),
        'amel@cuisine.dz',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Mot de passe'),
        'Secret123',
      );
      await tester.ensureVisible(find.byKey(const Key('signup-submit')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(store.currentUser!.role, UserRole.restaurant);
      expect(find.text('Chez Amel'), findsWidgets);
    });
  });

  group('8. pricing control', () {
    testWidgets('the admin changes commission and delivery fee', (
      tester,
    ) async {
      final store = await pump(
        tester,
        'admin@wasla.dz',
        'Admin123!',
        UserRole.admin,
      );
      final button = find.textContaining('Commission 10%');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      // Out of range: explained inside the dialog.
      await tester.enterText(find.byKey(const Key('pricing-percent')), '150');
      await tester.tap(find.byKey(const Key('pricing-save')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Valeurs invalides'),
        ),
        findsOneWidget,
      );
      expect(store.commissionPercent, 10);
      await tester.enterText(find.byKey(const Key('pricing-percent')), '12');
      await tester.enterText(find.byKey(const Key('pricing-fee')), '250');
      await tester.tap(find.byKey(const Key('pricing-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.commissionPercent, 12);
      expect(store.deliveryFee, 250);
      expect(find.textContaining('Tarifs appliqués'), findsOneWidget);
      expect(find.textContaining('Commission 12%'), findsOneWidget);
    });

    test('new orders use the updated prices at once', () async {
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      await store.login('admin@wasla.dz', 'Admin123!');
      expect(await store.updateSettings(15, 300), true);
      expect(await store.updateSettings(101, 300), false);
      expect(store.lastError, contains('Valeurs invalides'));
      expect(store.deliveryFee, 300);
      await store.login('client@wasla.dz', 'Demo123!');
      store.addToCart(store.product('p1'));
      final order = await store.checkout('Rue 1', 'Paiement à la livraison');
      expect(order!.deliveryFee, 300);
      expect(order.commissionAmount, commissionForMerchantPrice(820, 15));
      expect(order.items.single.product.retailPrice, 943);
    });
  });

  group('9. partner accounts', () {
    testWidgets('the admin opens a courier account from the sheet', (
      tester,
    ) async {
      final store = await pump(
        tester,
        'admin@wasla.dz',
        'Admin123!',
        UserRole.admin,
      );
      await nav(tester, 'Comptes');
      await tester.tap(find.text('Ouvrir un compte partenaire'));
      await tester.pumpAndSettle();
      // Too short a password is explained inside the sheet.
      await tester.enterText(find.byKey(const Key('account-name')), 'Nadia B');
      await tester.enterText(
        find.byKey(const Key('account-email')),
        'nadia@wasla.dz',
      );
      await tester.enterText(find.byKey(const Key('account-password')), 'abc');
      await tester.ensureVisible(find.byKey(const Key('account-create')));
      await tester.tap(find.byKey(const Key('account-create')));
      await tester.pumpAndSettle();
      expect(
        find.text('Le mot de passe doit contenir au moins 8 caractères.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('account-password')),
        'Secret123',
      );
      await tester.tap(find.byKey(const Key('account-create')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Compte créé : nadia@wasla.dz'),
        findsOneWidget,
      );
      final created = store.users.singleWhere(
        (u) => u.email == 'nadia@wasla.dz',
      );
      expect(created.role, UserRole.courier);
      expect(created.active, true);
      // The new account can sign in.
      expect(await store.login('nadia@wasla.dz', 'Secret123'), true);
    });

    testWidgets('restaurants and supermarkets need a business name', (
      tester,
    ) async {
      final store = await pump(
        tester,
        'admin@wasla.dz',
        'Admin123!',
        UserRole.admin,
      );
      expect(
        await store.createManagedAccount(
          name: 'Chef',
          email: 'chef@wasla.dz',
          password: 'Secret123',
          role: UserRole.restaurant,
        ),
        false,
      );
      expect(store.lastError, contains('établissement'));
      expect(
        await store.createManagedAccount(
          name: 'Chef',
          email: 'client@wasla.dz',
          password: 'Secret123',
          role: UserRole.courier,
        ),
        false,
      );
      expect(store.lastError, contains('déjà utilisée'));
    });
  });

  group('10. categories', () {
    testWidgets('a new category of the chosen type shows at once', (
      tester,
    ) async {
      final store = await pump(
        tester,
        'admin@wasla.dz',
        'Admin123!',
        UserRole.admin,
      );
      await nav(tester, 'Gestion');
      await tester.tap(find.byKey(const Key('category-add')));
      await tester.pumpAndSettle();
      // A duplicate is refused with a visible reason.
      await tester.enterText(find.byKey(const Key('category-name')), 'Healthy');
      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();
      expect(
        find.text('Cette catégorie existe déjà pour ce type.'),
        findsOneWidget,
      );
      // Same name for the other type is a different category.
      await tester.tap(find.text('Supérette').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('category-name')), 'Pizza');
      await tester.tap(find.byKey(const Key('category-create')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        store.categoriesFor(ProductKind.grocery).map((c) => c.name),
        contains('Pizza'),
      );
      expect(
        store.categoriesFor(ProductKind.meal).map((c) => c.name),
        isNot(contains('Pizza')),
      );
      expect(find.text('Pizza'), findsOneWidget);
    });

    test('a merchant sees the new category in the product form data', () async {
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      await store.login('admin@wasla.dz', 'Admin123!');
      expect(await store.addCategory('Tacos', ProductKind.meal), true);
      expect(await store.addCategory(' ', ProductKind.meal), false);
      expect(store.lastError, contains('2 caractères'));
      await store.login('restaurant@wasla.dz', 'Demo123!');
      expect(
        store.categoriesFor(ProductKind.meal).map((c) => c.name),
        contains('Tacos'),
      );
    });
  });

  group('11. daily dashboard', () {
    test('statistics are computed for one chosen day', () async {
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      await store.login('admin@wasla.dz', 'Admin123!');
      final today = store.statsFor(DateTime.now());
      expect(today.orderCount, 2);
      expect(today.sales, 2103);
      expect(today.newUsers, 0);
      final yesterday = store.statsFor(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(yesterday.orderCount, 1);
      expect(yesterday.deliveredCount, 1);
      expect(yesterday.sales, 1160);
      expect(
        store.statsFor(DateTime.now().subtract(const Duration(days: 9))).orders,
        isEmpty,
      );
      await store.createManagedAccount(
        name: 'Nouveau',
        email: 'nouveau@wasla.dz',
        password: 'Secret123',
        role: UserRole.courier,
      );
      expect(store.statsFor(DateTime.now()).newUsers, 1);
      expect(yesterday.newUsers, 0);
    });

    testWidgets('the admin can move between days', (tester) async {
      await pump(tester, 'admin@wasla.dz', 'Admin123!', UserRole.admin);
      expect(find.text('Aujourd’hui'), findsOneWidget);
      expect(find.text('2103 DA'), findsWidgets);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('admin-day-next')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('admin-day-previous')));
      await tester.pumpAndSettle();
      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('1160 DA'), findsWidgets);
      await tester.tap(find.byKey(const Key('admin-day-today')));
      await tester.pumpAndSettle();
      expect(find.text('Aujourd’hui'), findsOneWidget);
    });

    testWidgets(
      'today sales opens partner credits and records a partial payment',
      (tester) async {
        final store = await pump(
          tester,
          'admin@wasla.dz',
          'Admin123!',
          UserRole.admin,
        );
        await tester.tap(find.byKey(const Key('admin-today-sales')));
        await tester.pumpAndSettle();
        expect(find.text('Crédits partenaires'), findsOneWidget);
        expect(find.byKey(const Key('partner-credits-total')), findsOneWidget);

        final payCourier = find.byKey(const Key('pay-partner-courier1'));
        await tester.ensureVisible(payCourier);
        await tester.tap(payCourier);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('partner-payment-amount')),
          '75',
        );
        await tester.pump();
        expect(find.textContaining('125 DA'), findsOneWidget);
        await tester.tap(find.byKey(const Key('partner-payment-confirm')));
        await tester.pumpAndSettle();
        expect(store.walletBalanceFor('courier1'), 125);
        expect(find.textContaining('Crédit : 125 DA'), findsOneWidget);
      },
    );

    testWidgets('a restaurant can review an earlier day', (tester) async {
      await pump(
        tester,
        'restaurant@wasla.dz',
        'Demo123!',
        UserRole.restaurant,
      );
      expect(find.byKey(const Key('merchant-day-previous')), findsOneWidget);
      await tester.tap(find.byKey(const Key('merchant-day-previous')));
      await tester.pumpAndSettle();
      expect(find.text('Hier'), findsOneWidget);
      expect(find.byKey(const Key('merchant-day-today')), findsOneWidget);
    });

    testWidgets('a courier can review an earlier day', (tester) async {
      await pump(tester, 'livreur@wasla.dz', 'Demo123!', UserRole.courier);
      expect(find.byKey(const Key('courier-day-previous')), findsOneWidget);
      await tester.tap(find.byKey(const Key('courier-day-previous')));
      await tester.pumpAndSettle();
      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('200 DA'), findsWidgets);
      expect(find.byKey(const Key('courier-day-today')), findsOneWidget);
    });
  });

  group('13 and 15. courier earnings day by day', () {
    test('earnings are grouped per day', () async {
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      await store.login('livreur@wasla.dz', 'Demo123!');
      final days = store.dailyEarnings;
      expect(days, hasLength(1));
      expect(days.single.amount, 200);
      expect(days.single.deliveries, 1);
      expect(sameDay(days.single.day, DateTime.now()), false);
    });

    testWidgets('the screen lists days and says delivery rights', (
      tester,
    ) async {
      await pump(tester, 'livreur@wasla.dz', 'Demo123!', UserRole.courier);
      await nav(tester, 'Revenus');
      expect(find.text('Droits de livraison'), findsOneWidget);
      expect(find.text('Gains par jour'), findsOneWidget);
      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('Pourboires'), findsNothing);
      expect(find.textContaining('820'), findsNothing);
      expect(find.textContaining('12 h 40'), findsNothing);
    });

    testWidgets('Arabic says «حقوق التوصيل», never «إكراميات»', (tester) async {
      final store = await pump(
        tester,
        'livreur@wasla.dz',
        'Demo123!',
        UserRole.courier,
      );
      await store.setLanguage('ar');
      await tester.pumpAndSettle();
      await nav(tester, 'الإيرادات');
      expect(find.text('حقوق التوصيل'), findsWidgets);
      expect(find.textContaining('إكرام'), findsNothing);
      expect(find.textContaining('اكرام'), findsNothing);
    });
  });

  group('16 and 17. adding products', () {
    test('only name, description, price and category are required', () async {
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      await store.login('superette@wasla.dz', 'Demo123!');
      expect(
        await store.addProduct(
          name: 'Lait',
          description: 'Lait frais',
          category: 'Frais',
          wholesale: 120,
          emoji: '🥛',
        ),
        true,
      );
      final product = store.products.first;
      expect(product.name, 'Lait');
      expect(product.ingredients, isEmpty);
      expect(product.allergens, isEmpty);
      expect(product.mediaUrl, isNull);
      expect(product.approvalStatus, 'pending');
    });

    testWidgets('a dish is saved without ingredients, allergens or photo', (
      tester,
    ) async {
      final store = await pump(
        tester,
        'restaurant@wasla.dz',
        'Demo123!',
        UserRole.restaurant,
      );
      await tester.tap(find.text('Nouveau plat'));
      await tester.pumpAndSettle();
      // Missing required fields: shown on each field and in a summary.
      final submit = find.byKey(const Key('product-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Champ obligatoire'), findsWidgets);
      expect(
        find.textContaining('Complétez les champs obligatoires'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('product-name')), 'Couscous');
      await tester.enterText(
        find.byKey(const Key('product-description')),
        'Semoule et légumes',
      );
      await tester.enterText(find.byKey(const Key('product-wholesale')), '900');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-submit')), findsNothing);
      expect(store.products.first.name, 'Couscous');
      expect(store.products.first.wholesalePrice, 900);
      expect(find.textContaining('Envoyé pour validation'), findsOneWidget);
    });

    testWidgets('allergens and ingredients are marked optional', (
      tester,
    ) async {
      await pump(
        tester,
        'superette@wasla.dz',
        'Demo123!',
        UserRole.supermarket,
      );
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Allergènes (facultatif)'), findsOneWidget);
      expect(find.text('Ingrédients (facultatif)'), findsOneWidget);
      expect(find.text('Photo ou vidéo facultative.'), findsOneWidget);
      expect(find.text('Nom *'), findsOneWidget);
      expect(find.text('Description complète *'), findsOneWidget);
      expect(find.text('Votre prix de vente *'), findsOneWidget);
      expect(find.text('Catégorie *'), findsOneWidget);
      expect(find.textContaining('sans pourcentage'), findsOneWidget);
      expect(find.textContaining('commission Wasla'), findsNothing);
      await tester.enterText(find.byKey(const Key('product-wholesale')), '300');
      await tester.pump();
      expect(find.textContaining('choisit librement'), findsOneWidget);
      expect(find.textContaining('commission Wasla'), findsNothing);
    });
  });

  group('1. confirming an order', () {
    testWidgets('the phone error is visible inside the sheet', (tester) async {
      final store = await pump(
        tester,
        'client@wasla.dz',
        'Demo123!',
        UserRole.client,
      );
      store.addToCart(store.product('p1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('order-phone-field')), '');
      await tester.tap(find.byKey(const Key('confirm-whatsapp-order')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Ajoutez un numéro de téléphone.'),
        ),
        findsOneWidget,
      );
      expect(store.orders.length, 3);
      await tester.enterText(find.byKey(const Key('order-phone-field')), '12');
      await tester.tap(find.byKey(const Key('confirm-whatsapp-order')));
      await tester.pumpAndSettle();
      expect(find.text('Numéro de téléphone invalide.'), findsOneWidget);
    });

    testWidgets('the order is saved even when WhatsApp cannot open', (
      tester,
    ) async {
      final store = await pump(
        tester,
        'client@wasla.dz',
        'Demo123!',
        UserRole.client,
      );
      store.addToCart(store.product('p1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('order-phone-field')),
        '0550123456',
      );
      await tester.tap(find.byKey(const Key('confirm-whatsapp-order')));
      await tester.pumpAndSettle(const Duration(seconds: 6));
      // No WhatsApp in the test host: the customer is told, nothing is lost.
      expect(find.text('WhatsApp indisponible'), findsOneWidget);
      expect(find.text('Copier le message'), findsOneWidget);
      final order = store.orders.first;
      expect(order.note, contains('Tél. 0550123456'));
      expect(store.cart, isEmpty);
      expect(find.textContaining(order.id), findsWidgets);
    });

    test('WhatsApp numbers are normalised', () {
      expect(whatsAppNumber('0668813239'), '213668813239');
      expect(whatsAppNumber('+213 668 81 32 39'), '213668813239');
      expect(whatsAppNumber('00213668813239'), '213668813239');
      expect(whatsAppNumber('12'), isNull);
      expect(whatsAppNumber(''), isNull);
    });

    test('the message carries the order code and the route', () async {
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      await store.login('client@wasla.dz', 'Demo123!');
      final order = store.orders.first;
      final message = orderUpdateMessage(
        order: order,
        merchant: store.orderMerchant(order),
        status: 'En route',
        arabic: false,
      );
      expect(message, contains(order.id));
      expect(message, contains('google.com/maps/dir'));
      expect(message, contains('Bowl poulet du jardin'));
      final arabic = orderUpdateMessage(
        order: order,
        merchant: store.orderMerchant(order),
        status: 'في الطريق',
        arabic: true,
      );
      expect(arabic, contains('المسار'));
    });
  });

  group('2 and 3. saved orders and the tracking line', () {
    testWidgets('the client keeps a history and can follow each order', (
      tester,
    ) async {
      await pump(tester, 'client@wasla.dz', 'Demo123!', UserRole.client);
      await nav(tester, 'Commandes');
      expect(find.text('Mes commandes'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
      // The active order is expanded: every stage is listed.
      expect(find.text('En route avec le livreur'), findsWidgets);
      expect(find.text('Commande envoyée'), findsWidgets);
      expect(find.text('Cuisine'), findsWidgets);
      expect(find.text('Livreur'), findsWidgets);
      expect(find.text('Destination'), findsWidgets);
      // Older orders are kept and can be expanded.
      await tester.ensureVisible(find.text('Historique'));
      final toggle = find.byKey(const Key('tracking-toggle-#WS1046'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Réception confirmée'), findsWidgets);
    });

    test('guest orders survive a restart', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final first = MarketplaceStore();
      addTearDown(first.dispose);
      await first.bootstrap();
      first.addToCart(first.product('p1'));
      final placed = await first.checkout(
        '12 rue Didouche',
        'Paiement à la livraison',
        phone: '0550123456',
      );
      expect(placed, isNotNull);
      final second = MarketplaceStore();
      addTearDown(second.dispose);
      await second.bootstrap();
      final history = second.ordersFor(second.currentUser!);
      expect(history.single.id, placed!.id);
      expect(history.single.items.single.product.name, 'Bowl poulet du jardin');
      expect(second.currentUser!.phone, '0550123456');
    });
  });

  group('orders default to today with full history available', () {
    testWidgets('courier starts on today and can switch to all orders', (
      tester,
    ) async {
      await pump(tester, 'livreur@wasla.dz', 'Demo123!', UserRole.courier);
      await nav(tester, 'Livraisons');
      final filter = tester.widget<SegmentedButton<bool>>(
        find.byKey(const Key('orders-period-filter')),
      );
      expect(filter.selected, {false});
      expect(find.textContaining('#WS1047'), findsOneWidget);
      expect(find.textContaining('#WS1046'), findsNothing);

      await tester.tap(find.text('Toutes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('#WS1046'), findsOneWidget);
    });

    testWidgets('restaurant order history also starts on today', (
      tester,
    ) async {
      await pump(
        tester,
        'restaurant@wasla.dz',
        'Demo123!',
        UserRole.restaurant,
      );
      await nav(tester, 'Commandes');
      final filter = tester.widget<SegmentedButton<bool>>(
        find.byKey(const Key('orders-period-filter')),
      );
      expect(filter.selected, {false});
      expect(find.text('Aujourd’hui'), findsOneWidget);
      expect(find.text('Toutes'), findsOneWidget);
    });
  });

  group('14. notifications', () {
    testWidgets('tapping a new-order banner opens that exact order', (
      tester,
    ) async {
      final store = await pump(
        tester,
        'livreur@wasla.dz',
        'Demo123!',
        UserRole.courier,
      );
      final order = store.orders.firstWhere(
        (candidate) => candidate.status == OrderStatus.placed,
      );
      store.debugAnnounce(
        AppNotification(
          id: 'n-live',
          title: 'Nouvelle livraison disponible',
          message: 'Commande ${order.id} · ${order.total} DA',
          type: 'order',
          orderId: order.id,
          createdAt: DateTime.now(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('in-app-banner')), findsOneWidget);
      expect(find.text('Nouvelle livraison disponible'), findsWidgets);
      await tester.tap(find.byKey(const Key('in-app-banner')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-details-page')), findsOneWidget);
      expect(find.text('Commande ${order.id}'), findsOneWidget);
      expect(find.byKey(Key('order-details-${order.id}')), findsOneWidget);
    });

    testWidgets('tapping an order notification opens its order page', (
      tester,
    ) async {
      final store = await pump(
        tester,
        'livreur@wasla.dz',
        'Demo123!',
        UserRole.courier,
      );
      final notification = store.notifications.firstWhere(
        (item) => item.orderId != null,
      );
      final order = store.orderForNotification(notification)!;
      await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(notification.title));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-details-page')), findsOneWidget);
      expect(find.text('Commande ${order.id}'), findsOneWidget);
    });

    testWidgets('courier can call the client and message order contacts', (
      tester,
    ) async {
      final store = await pump(
        tester,
        'livreur@wasla.dz',
        'Demo123!',
        UserRole.courier,
      );
      final order = store.orders.firstWhere(
        (o) => o.status == OrderStatus.pickedUp,
      );
      // The server only fills phone numbers for people who must reach each
      // other, so give the demo order some.
      final withPhones = MarketOrder(
        id: order.id,
        clientId: order.clientId,
        merchantId: order.merchantId,
        items: order.items,
        address: order.address,
        createdAt: order.createdAt,
        courierId: order.courierId,
        status: order.status,
        customerPhone: '0550123456',
        merchantPhone: '0661000000',
      );
      store.orders
        ..remove(order)
        ..add(withPhones);
      store.notifyListeners();
      await tester.pumpAndSettle();
      await nav(tester, 'Livraisons');
      expect(find.byKey(Key('whatsapp-client-${order.id}')), findsOneWidget);
      expect(find.byKey(Key('whatsapp-merchant-${order.id}')), findsOneWidget);
      expect(find.byKey(Key('call-client-${order.id}')), findsOneWidget);
      expect(find.byKey(Key('route-${order.id}')), findsOneWidget);
      expect(find.textContaining('0550123456'), findsOneWidget);
    });

    test('contacts follow who needs to reach whom', () {
      MarketOrder build({String courierPhone = '', String customer = ''}) =>
          MarketOrder(
            id: 'WS-1',
            clientId: 'c',
            merchantId: 'm',
            items: const [],
            address: 'Rue',
            createdAt: DateTime.now(),
            courierId: 'd',
            courierPhone: courierPhone,
            customerPhone: customer,
            merchantPhone: '0661000000',
          );
      final order = build(courierPhone: '0771000000', customer: '0550123456');
      List<OrderContactKind> kinds(UserRole role) => orderContacts(
        order,
        role,
        merchantName: 'M',
      ).map((c) => c.kind).toList();
      expect(kinds(UserRole.client), [
        OrderContactKind.courier,
        OrderContactKind.merchant,
      ]);
      expect(kinds(UserRole.courier), [
        OrderContactKind.client,
        OrderContactKind.merchant,
      ]);
      expect(kinds(UserRole.restaurant), [OrderContactKind.courier]);
      // No phone sent by the server, no button.
      expect(
        orderContacts(build(), UserRole.restaurant, merchantName: 'M'),
        isEmpty,
      );
    });
  });

  group('6. the session is kept', () {
    test('the offline build never needs a saved session', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({
        'session_token': 'stale',
        'session_user': '{"id":"x"}',
      });
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      await store.bootstrap();
      expect(store.initializing, false);
      expect(CloudflareBackend.configured, false);
      expect(store.currentUser!.id, 'guest-local');
    });
  });
}
