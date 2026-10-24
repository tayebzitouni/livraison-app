import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/data/cloudflare_backend.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/marketplace_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end checks against a running Worker (for example
/// `wrangler dev --local` with the demo seed). They do nothing unless the app
/// is built with `--dart-define=API_BASE_URL=...`:
///
/// ```
/// flutter test --dart-define=API_BASE_URL=http://127.0.0.1:8787 \
///   --dart-define=LIVE_ADMIN_PASSWORD=... test/live_flows_test.dart
/// ```
///
/// The app talks to the server with one session at a time, so each test uses a
/// single store and switches role with login / logout, as a person would.
void main() {
  const adminPassword = String.fromEnvironment('LIVE_ADMIN_PASSWORD');
  final live = CloudflareBackend.configured;
  final stamp = DateTime.now().microsecondsSinceEpoch;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null; // allow real sockets in the test binding
  });

  test(
    'guest orders reach the server, survive a restart and are tracked',
    () async {
      if (!live) return;
      SharedPreferences.setMockInitialValues({});
      final first = MarketplaceStore();
      addTearDown(first.dispose);
      await first.bootstrap();
      expect(first.currentUser!.id, isNot('guest-local'));
      expect(first.isGuest, true);
      expect(first.availableProducts, isNotEmpty);

      first.addToCart(first.availableProducts.first);
      final placed = await first.checkout(
        '5 rue Larbi Ben M’Hidi',
        'Paiement à la livraison',
        note: 'Sans oignons',
        phone: '0550123456',
      );
      expect(placed, isNotNull, reason: first.lastError);
      expect(placed!.id, startsWith('WS-'));
      expect(
        first.ordersFor(first.currentUser!).map((o) => o.id),
        contains(placed.id),
      );
      final guestId = first.currentUser!.id;

      // "Restart": a new store reading the same saved session.
      final second = MarketplaceStore();
      addTearDown(second.dispose);
      await second.bootstrap();
      expect(second.currentUser!.id, guestId);
      final history = second.ordersFor(second.currentUser!);
      expect(history.map((o) => o.id), contains(placed.id));
      expect(
        history.firstWhere((o) => o.id == placed.id).status,
        OrderStatus.placed,
      );

      // A revoked session: the device signs in to its own account again.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_token', 'revoked-token');
      final third = MarketplaceStore();
      addTearDown(third.dispose);
      await third.bootstrap();
      expect(third.currentUser!.id, guestId);
      expect(
        third.ordersFor(third.currentUser!).map((o) => o.id),
        contains(placed.id),
      );
    },
  );

  test('the catalogue can be browsed before any account exists', () async {
    if (!live) return;
    CloudflareBackend.token = null;
    final products = await CloudflareBackend.get('/api/products');
    final categories = await CloudflareBackend.get('/api/categories');
    expect((products as Map)['results'], isNotEmpty);
    expect((categories as Map)['results'], isNotEmpty);
    // Orders and accounts stay private.
    await expectLater(
      CloudflareBackend.get('/api/orders'),
      throwsA(
        isA<ApiException>().having((e) => e.unauthorized, 'unauthorized', true),
      ),
    );
  });

  test('a partner signing in is not overridden by the guest account', () async {
    if (!live) return;
    SharedPreferences.setMockInitialValues({});
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    // The guest account is still connecting when the partner signs in.
    final booting = store.bootstrap();
    final signedIn = await store.login(
      'livreur@wasla.dz',
      'Demo123!',
      UserRole.courier,
    );
    await booting;
    expect(signedIn, true, reason: store.lastError);
    expect(store.currentUser!.role, UserRole.courier);
    final me = await CloudflareBackend.me();
    expect(me['role'], 'courier');
  });

  test('a courier takes the order and the whole chain completes', () async {
    if (!live) return;
    SharedPreferences.setMockInitialValues({});
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    await store.bootstrap();
    final product = store.availableProducts.firstWhere(
      (p) => p.ownerId == 'demo-restaurant',
    );
    store.addToCart(product);
    final order = await store.checkout(
      'Rue 8',
      'Paiement à la livraison',
      phone: '0551000001',
    );
    expect(order, isNotNull, reason: store.lastError);
    final code = order!.id;
    MarketOrder find() => store.orders.firstWhere((o) => o.id == code);

    // The courier accepts; phone numbers are only shared from that moment.
    expect(
      await store.login('livreur@wasla.dz', 'Demo123!', UserRole.courier),
      true,
    );
    expect(
      await store.updateProfile(
        name: store.currentUser!.name,
        email: store.currentUser!.email,
        phone: '0770000001',
        address: '',
      ),
      true,
    );
    expect(find().customerPhone, '', reason: 'hidden before accepting');
    final before = store.dailyEarnings.fold<int>(0, (s, d) => s + d.amount);
    expect(
      await store.advance(find(), UserRole.courier),
      true,
      reason: store.lastError,
    );
    expect(find().status, OrderStatus.courierValidated);
    expect(find().courierId, store.currentUser!.id);
    expect(find().customerPhone, '0551000001');
    await store.logout();

    // The kitchen prepares it.
    expect(
      await store.login('restaurant@wasla.dz', 'Demo123!', UserRole.restaurant),
      true,
    );
    for (var i = 0; i < 3; i++) {
      expect(
        await store.advance(find(), UserRole.restaurant),
        true,
        reason: store.lastError,
      );
    }
    expect(find().status, OrderStatus.ready);
    expect(find().courierPhone, '0770000001');
    await store.logout();

    // The courier collects and delivers.
    expect(
      await store.login('livreur@wasla.dz', 'Demo123!', UserRole.courier),
      true,
    );
    for (var i = 0; i < 2; i++) {
      expect(
        await store.advance(find(), UserRole.courier),
        true,
        reason: store.lastError,
      );
    }
    expect(find().status, OrderStatus.delivered);
    await store.logout();

    // The customer (the same guest account) confirms and sees the courier.
    expect(store.isGuest, true);
    await store.refresh();
    expect(find().courierPhone, '0770000001');
    expect(
      await store.advance(find(), UserRole.client),
      true,
      reason: store.lastError,
    );
    expect(find().status, OrderStatus.clientConfirmed);
    await store.logout();

    // The courier's delivery rights appear under today.
    expect(
      await store.login('livreur@wasla.dz', 'Demo123!', UserRole.courier),
      true,
    );
    final days = store.dailyEarnings;
    expect(days, isNotEmpty);
    expect(sameDay(days.first.day, DateTime.now()), true);
    expect(
      days.fold<int>(0, (s, d) => s + d.amount),
      before + find().deliveryFee,
    );
  });

  test(
    'a kitchen registers itself and publishes a dish without a photo',
    () async {
      if (!live) return;
      SharedPreferences.setMockInitialValues({});
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      expect(
        await store.signup(
          name: 'Amel Test',
          email: 'kitchen$stamp@test.dz',
          password: 'Secret123',
          role: UserRole.courier,
          businessName: 'Pas une cuisine',
        ),
        false,
      );
      expect(
        await store.signup(
          name: 'Amel Test',
          email: 'kitchen$stamp@test.dz',
          password: 'Secret123',
          role: UserRole.restaurant,
          businessName: 'Cuisine $stamp',
          phone: '0550123456',
        ),
        true,
        reason: store.lastError,
      );
      expect(store.currentUser!.role, UserRole.restaurant);
      expect(store.categoriesFor(ProductKind.meal), isNotEmpty);
      expect(
        await store.addProduct(
          name: 'Plat test $stamp',
          description: 'Fait maison',
          category: store.categoriesFor(ProductKind.meal).first.name,
          wholesale: 800,
          emoji: '🍽️',
        ),
        true,
        reason: store.lastError,
      );
      final saved = store.products.firstWhere(
        (p) => p.name == 'Plat test $stamp',
      );
      expect(saved.approvalStatus, 'pending');
      expect(saved.mediaUrl, anyOf(isNull, isEmpty));
      // A duplicate e-mail is refused with an explanation.
      await store.logout();
      expect(
        await store.signup(
          name: 'Amel Test',
          email: 'kitchen$stamp@test.dz',
          password: 'Secret123',
          role: UserRole.restaurant,
          businessName: 'Cuisine bis',
        ),
        false,
      );
      expect(store.lastError, contains('déjà utilisée'));
    },
  );

  test('the administrator controls prices, accounts and categories', () async {
    if (!live || adminPassword.isEmpty) return;
    SharedPreferences.setMockInitialValues({});
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    await store.bootstrap();
    expect(
      await store.login('admin@wasla.dz', adminPassword),
      true,
      reason: store.lastError,
    );

    expect(await store.updateSettings(12, 250), true, reason: store.lastError);
    expect(await store.updateSettings(120, 250), false);
    // The customer space follows the new fee without any action.
    await store.logout();
    expect(store.deliveryFee, 250);
    expect(store.commissionPercent, 12);
    expect(
      await store.login('admin@wasla.dz', adminPassword),
      true,
      reason: store.lastError,
    );

    final email = 'courier$stamp@test.dz';
    expect(
      await store.createManagedAccount(
        name: 'Nadia Test',
        email: email,
        password: 'Secret123',
        role: UserRole.courier,
        phone: '0550999999',
      ),
      true,
      reason: store.lastError,
    );
    expect(
      await store.createManagedAccount(
        name: 'Nadia Test',
        email: email,
        password: 'Secret123',
        role: UserRole.courier,
      ),
      false,
    );
    expect(store.lastError, contains('déjà utilisée'));
    expect(store.users.any((u) => u.email == email), true);

    final category = 'Cat$stamp';
    expect(
      await store.addCategory(category, ProductKind.grocery),
      true,
      reason: store.lastError,
    );
    expect(await store.addCategory(category, ProductKind.grocery), false);
    expect(store.lastError, contains('existe déjà'));
    expect(
      store.categoriesFor(ProductKind.grocery).map((c) => c.name),
      contains(category),
    );

    final today = store.statsFor(DateTime.now());
    expect(today.newUsers, greaterThanOrEqualTo(1));
    expect(today.orderCount, greaterThanOrEqualTo(1));
    // Put the prices back for the next run.
    expect(await store.updateSettings(10, 200), true);
  });

  test('the sign-in is restored after a restart and ends on logout', () async {
    if (!live) return;
    SharedPreferences.setMockInitialValues({});
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    await store.bootstrap();
    expect(
      await store.login('livreur@wasla.dz', 'Demo123!', UserRole.courier),
      true,
    );
    final restored = MarketplaceStore();
    addTearDown(restored.dispose);
    await restored.bootstrap();
    expect(restored.currentUser!.role, UserRole.courier);
    expect(restored.currentUser!.email, 'livreur@wasla.dz');
    await restored.logout();
    // The next start opens the customer space, not the courier account.
    final after = MarketplaceStore();
    addTearDown(after.dispose);
    await after.bootstrap();
    expect(after.currentUser!.role, UserRole.client);
    expect(after.isGuest, true);
  });
}
