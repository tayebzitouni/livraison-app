import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/build_expiry.dart';
import 'package:livraison_app/order_contact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/marketplace_store.dart';

void main() {
  test('admin can sign in without choosing a special admin card', () async {
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    expect(await store.login('admin@wasla.dz', 'Admin123!'), isTrue);
    expect(store.currentUser!.role, UserRole.admin);
  });

  test('whatsapp message lists the order for the Wasla number', () async {
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    await store.login('client@wasla.dz', 'Demo123!', UserRole.client);
    store.addToCart(store.product('p4'));
    final order = await store.checkout(
      '28 rue des Oliviers',
      'Paiement à la livraison',
      note: 'Sans oignons',
    );
    expect(order, isNotNull);
    final message = waslaWhatsAppMessage(
      order: order!,
      clientName: store.currentUser!.name,
      phone: '0550123456',
      merchant: store.orderMerchant(order),
    );
    final uri = waslaWhatsAppUri(message);
    expect(uri.host, 'wa.me');
    expect(uri.path, '/$waslaWhatsAppE164');
    expect(message, contains(order.id));
    expect(message, contains('Sans oignons'));
    expect(message, contains('0550123456'));
    expect(waslaWhatsAppLocal, '0554917545');
  });

  test('guest can keep an order without registering', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final first = MarketplaceStore();
    addTearDown(first.dispose);
    await first.enableGuestPersistence();
    first.addToCart(first.product('p4'));
    final placed = await first.checkout(
      'Rue des Oliviers',
      'Paiement à la livraison',
      note: 'Sans oignons',
    );
    expect(placed, isNotNull);
    final reopened = MarketplaceStore();
    addTearDown(reopened.dispose);
    await reopened.enableGuestPersistence();
    expect(reopened.currentUser!.role, UserRole.client);
    expect(reopened.currentUser!.address, 'Rue des Oliviers');
    final order = reopened.ordersFor(reopened.currentUser!).single;
    expect(order.id, placed!.id);
    expect(order.note, 'Sans oignons');
  });

  test('admin chooses retail price and platform fees', () async {
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    await store.login('superette@wasla.dz', 'Demo123!', UserRole.supermarket);
    await store.addProduct(
      name: 'Test grocery',
      description: 'Fresh grocery item',
      category: 'Frais',
      wholesale: 300,
      emoji: '🥑',
    );
    final product = store.products.first;
    expect(product.approvalStatus, 'pending');
    expect(store.availableProducts, isNot(contains(product)));
    await store.login('admin@wasla.dz', 'Admin123!', UserRole.admin);
    expect(
      await store.reviewProduct(product, approve: true, retailPrice: 520),
      true,
    );
    expect(await store.updateSettings(10, 150), true);
    expect(store.availableProducts, contains(product));
    await store.login('client@wasla.dz', 'Demo123!', UserRole.client);
    store.addToCart(product);
    final order = await store.checkout(
      'Rue des Oliviers',
      'Paiement à la livraison',
    );
    expect(order!.deliveryFee, 150);
    expect(order.commissionAmount, 52);
  });
  test('admin requires correct private credentials', () async {
    final s = MarketplaceStore();
    expect(await s.login('admin@wasla.dz', 'wrong12', UserRole.client), false);
    expect(await s.login('admin@wasla.dz', 'Admin123!', UserRole.client), true);
    expect(s.currentUser!.role, UserRole.admin);
  });
  test('cart is restricted to one merchant', () {
    final s = MarketplaceStore();
    s.addToCart(s.product('p1'));
    s.addToCart(s.product('p2'));
    expect(s.cartCount, 2);
    s.addToCart(s.product('p4'));
    expect(s.cartCount, 1);
    expect(s.cart.keys.single, 'p4');
  });
  test('checkout records address, totals and payment state', () async {
    final s = MarketplaceStore();
    addTearDown(s.dispose);
    await s.login('client@wasla.dz', 'Demo123!', UserRole.client);
    s.addToCart(s.product('p1'));
    s.addToCart(s.product('p1'));
    final order = await s.checkout(
      '12 avenue Didouche',
      'Paiement à la livraison',
      note: 'Appeler à l’arrivée',
    );
    expect(order, isNotNull);
    expect(order!.address, '12 avenue Didouche');
    expect(order.note, 'Appeler à l’arrivée');
    expect(order.subtotal, 2980);
    expect(order.total, 3180);
    expect(order.paid, false);
    expect(s.cart, isEmpty);
  });
  test('admin creates and controls partner accounts', () async {
    final s = MarketplaceStore();
    addTearDown(s.dispose);
    expect(
      await s.createManagedAccount(
        name: 'Nadia Coursier',
        email: 'nadia.courier@wasla.dz',
        password: 'Demo123!',
        role: UserRole.courier,
      ),
      false,
    );
    await s.login('admin@wasla.dz', 'Admin123!', UserRole.admin);
    expect(
      await s.createManagedAccount(
        name: 'Nadia Coursier',
        email: 'nadia.courier@wasla.dz',
        password: 'Demo123!',
        role: UserRole.courier,
        phone: '0555000000',
      ),
      true,
    );
    final user = s.users.singleWhere(
      (u) => u.email == 'nadia.courier@wasla.dz',
    );
    expect(user.role, UserRole.courier);
    expect(user.active, true);
    expect(await s.toggleUser(user), true);
    expect(user.active, false);
    expect(
      await s.login('nadia.courier@wasla.dz', 'Demo123!', UserRole.courier),
      false,
    );
  });
  test('order follows courier merchant courier client sequence', () async {
    final s = MarketplaceStore();
    final o = s.orders.firstWhere((x) => x.status == OrderStatus.placed);
    await s.login('livreur@wasla.dz', 'Demo123!', UserRole.courier);
    await s.advance(o, UserRole.courier);
    expect(o.status, OrderStatus.courierValidated);
    await s.logout();
    await s.login('bistro@wasla.dz', 'Demo123!', UserRole.restaurant);
    await s.advance(o, UserRole.restaurant);
    await s.advance(o, UserRole.restaurant);
    await s.advance(o, UserRole.restaurant);
    expect(o.status, OrderStatus.ready);
    await s.logout();
    await s.login('livreur@wasla.dz', 'Demo123!', UserRole.courier);
    await s.advance(o, UserRole.courier);
    await s.advance(o, UserRole.courier);
    expect(o.status, OrderStatus.delivered);
    expect(o.paid, false);
    await s.logout();
    await s.login('client@wasla.dz', 'Demo123!', UserRole.client);
    await s.advance(o, UserRole.client);
    expect(o.status, OrderStatus.clientConfirmed);
    expect(o.paid, true);
  });
  test('merchant sees an order only after courier validation', () async {
    final s = MarketplaceStore();
    addTearDown(s.dispose);
    final order = s.orders.firstWhere((o) => o.status == OrderStatus.placed);
    final merchant = s.user(order.merchantId);
    expect(s.ordersFor(merchant), isNot(contains(order)));
    await s.login('livreur@wasla.dz', 'Demo123!', UserRole.courier);
    await s.advance(order, UserRole.courier);
    expect(s.ordersFor(merchant), contains(order));
  });

  test('delivery settles percentage commission and courier fee', () async {
    final s = MarketplaceStore();
    addTearDown(s.dispose);
    final order = s.orders.firstWhere((o) => o.status == OrderStatus.placed);
    await s.login('livreur@wasla.dz', 'Demo123!', UserRole.courier);
    final courierBefore = s.walletBalance;
    await s.advance(order, UserRole.courier);
    await s.logout();
    await s.login('bistro@wasla.dz', 'Demo123!', UserRole.restaurant);
    await s.advance(order, UserRole.restaurant);
    await s.advance(order, UserRole.restaurant);
    await s.advance(order, UserRole.restaurant);
    await s.logout();
    await s.login('livreur@wasla.dz', 'Demo123!', UserRole.courier);
    await s.advance(order, UserRole.courier);
    await s.advance(order, UserRole.courier);
    expect(s.walletBalance - courierBefore, 0);
    await s.logout();
    await s.login('client@wasla.dz', 'Demo123!', UserRole.client);
    await s.advance(order, UserRole.client);
    await s.logout();
    await s.login('livreur@wasla.dz', 'Demo123!', UserRole.courier);
    expect(s.walletBalance - courierBefore, order.deliveryFee);
    final merchantSale = s.walletEntries.singleWhere(
      (entry) => entry.orderId == order.id && entry.type == 'sale',
    );
    final commission = s.walletEntries.singleWhere(
      (entry) => entry.orderId == order.id && entry.type == 'commission',
    );
    expect(merchantSale.amount, 2484);
    expect(commission.amount, 276);
  });

  test('withdrawal consumes the available courier balance once', () async {
    final s = MarketplaceStore();
    addTearDown(s.dispose);
    await s.login('livreur@wasla.dz', 'Demo123!', UserRole.courier);
    expect(s.walletBalance, 200);
    expect(await s.requestWithdrawal(), true);
    expect(s.walletBalance, 0);
    expect(await s.requestWithdrawal(), false);
  });

  test('wrong merchant cannot advance another merchant order', () async {
    final s = MarketplaceStore();
    addTearDown(s.dispose);
    final order = s.orders.firstWhere((o) => o.status == OrderStatus.placed);
    await s.login('restaurant@wasla.dz', 'Demo123!', UserRole.restaurant);
    expect(await s.advance(order, UserRole.restaurant), false);
    expect(order.status, OrderStatus.placed);
  });
  test('merchant product types are role restricted', () async {
    final s = MarketplaceStore();
    await s.login('superette@wasla.dz', 'Demo123!', UserRole.supermarket);
    await s.addProduct(
      name: 'Poires',
      description: '',
      category: 'Frais',
      retail: 400,
      wholesale: 250,
      emoji: 'P',
    );
    expect(s.products.first.kind, ProductKind.grocery);
    expect(s.products.first.approvalStatus, 'pending');
    expect(s.availableProducts, isNot(contains(s.products.first)));
    await s.logout();
    await s.login('restaurant@wasla.dz', 'Demo123!', UserRole.restaurant);
    await s.addProduct(
      name: 'Soupe',
      description: '',
      category: 'Plats',
      retail: 800,
      wholesale: 500,
      emoji: 'S',
    );
    expect(s.products.first.kind, ProductKind.meal);
  });

  test('profile, categories and notifications are dynamic', () async {
    final s = MarketplaceStore();
    addTearDown(s.dispose);
    await s.login('client@wasla.dz', 'Demo123!', UserRole.client);
    expect(s.categoriesFor(ProductKind.meal), isNotEmpty);
    expect(s.unreadNotifications, greaterThan(0));
    final first = s.notifications.first;
    await s.markNotificationRead(first);
    expect(first.read, true);
    expect(
      await s.updateProfile(
        name: 'Sofia Mise à jour',
        email: 'sofia@wasla.dz',
        phone: '+213 555 00 11 22',
        address: 'Alger Centre',
      ),
      true,
    );
    expect(s.currentUser!.address, 'Alger Centre');
  });
}
