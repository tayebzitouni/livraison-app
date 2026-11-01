import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/marketplace_store.dart';

void main() {
  test('completed orders split into merchant, platform and courier shares', () {
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    final completed = store.orders
        .where((order) => order.status == OrderStatus.clientConfirmed)
        .toList();
    final amounts = PartnerAmounts(store.orders);
    expect(completed, isNotEmpty);
    expect(amounts.total, completed.fold<int>(0, (sum, o) => sum + o.total));
    expect(
      amounts.commission,
      completed.fold<int>(0, (sum, o) => sum + o.commissionAmount),
    );
    expect(
      amounts.total,
      amounts.merchantNet + amounts.commission + amounts.delivery,
    );
    expect(
      PartnerAmounts(
        store.orders.where((o) => o.status != OrderStatus.clientConfirmed),
      ).total,
      0,
    );
  });

  test(
    'partial payment reduces remaining credit without changing sales',
    () async {
      final store = MarketplaceStore();
      addTearDown(store.dispose);
      await store.login('admin@wasla.dz', 'Admin123!', UserRole.admin);
      final courier = store.user('courier1');
      final before = PartnerAmounts(store.orders).total;
      expect(store.walletBalanceFor(courier.id), 200);
      expect(await store.settleAccount(courier, amount: 80), isTrue);
      expect(store.walletBalanceFor(courier.id), 120);
      expect(PartnerAmounts(store.orders).total, before);
    },
  );
}
