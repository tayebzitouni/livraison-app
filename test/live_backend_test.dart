import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/data/cloudflare_backend.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/marketplace_store.dart';

void main() {
  test('live backend hydrates shared role data', () async {
    if (!CloudflareBackend.configured) return;

    final store = MarketplaceStore();
    addTearDown(store.dispose);

    expect(
      await store.login('client@wasla.dz', 'Demo123!', UserRole.client),
      true,
    );
    expect(store.products, isNotEmpty);
    expect(store.categories, isNotEmpty);
    expect(store.orders, isNotEmpty);
    expect(store.orders.every((order) => order.items.isNotEmpty), true);

    await store.logout();
    expect(
      await store.login('livreur@wasla.dz', 'Demo123!', UserRole.courier),
      true,
    );
    expect(store.orders, isNotEmpty);
    expect(store.categories, isNotEmpty);
    expect(store.walletBalance, greaterThanOrEqualTo(0));

    const adminPassword = String.fromEnvironment('LIVE_ADMIN_PASSWORD');
    if (adminPassword.isEmpty) return;
    await store.logout();
    expect(
      await store.login('admin@wasla.dz', adminPassword, UserRole.client),
      true,
    );
    expect(store.users.any((user) => user.role == UserRole.client), true);
    expect(store.categories, isNotEmpty);
    expect(store.orders, isNotEmpty);
  });
}
