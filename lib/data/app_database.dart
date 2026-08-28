import 'package:flutter/foundation.dart';

/// Central data source used by the prototype. Replace the in-memory adapter
/// with a REST/Supabase/Firebase implementation without changing the widgets.
class AppDatabase extends ChangeNotifier {
  AppDatabase._() {
    products = [
      {
        'id': 'tajine-olive',
        'title': 'طاجين زيتون بالدجاج',
        'price': 800,
        'emoji': '🍲',
      },
      {
        'id': 'bourek-meat',
        'title': 'بوراك باللحم (3 حبات)',
        'price': 300,
        'emoji': '🥟',
      },
      {'id': 'matlou3', 'title': 'مطلوع الدار', 'price': 50, 'emoji': '🫓'},
      {'id': 'chorba', 'title': 'شربة فريك', 'price': 250, 'emoji': '🍜'},
    ];
    orders = [
      {
        'id': 'TJ-104',
        'status': 'draft',
        'foodTotal': 1100,
        'deliveryFee': 200,
        'total': 1300,
        'customer': 'فتحي',
      },
    ];
    walletEntries = [
      {
        'orderId': 'TJ-104',
        'type': 'delivery_fee',
        'amount': 200,
        'createdAt': DateTime.now(),
      },
    ];
  }

  static final AppDatabase instance = AppDatabase._();
  late final List<Map<String, dynamic>> products;
  late final List<Map<String, dynamic>> orders;
  late final List<Map<String, dynamic>> walletEntries;

  void createOrder({
    required int foodTotal,
    required int itemCount,
    int deliveryFee = 200,
  }) {
    final id = 'TJ-${104 + orders.length}';
    orders.insert(0, {
      'id': id,
      'status': 'draft',
      'foodTotal': foodTotal,
      'deliveryFee': deliveryFee,
      'total': foodTotal + deliveryFee,
      'items': itemCount,
      'customer': 'فتحي',
    });
    notifyListeners();
  }

  void confirmOrder(String id) {
    final order = orders.firstWhere((item) => item['id'] == id);
    if (order['status'] == 'draft') {
      order['status'] = 'confirmed';
      notifyListeners();
    }
  }

  void advanceOrder(String id) {
    final order = orders.firstWhere((item) => item['id'] == id);
    final status = order['status'];
    if (status == 'confirmed') {
      order['status'] = 'picked_up';
    } else if (status == 'picked_up') {
      order['status'] = 'delivered';
      final foodTotal = order['foodTotal'] as int;
      walletEntries.addAll([
        {
          'orderId': id,
          'type': 'provider_credit',
          'amount': (foodTotal * .8).round(),
          'createdAt': DateTime.now(),
        },
        {
          'orderId': id,
          'type': 'admin_commission',
          'amount': (foodTotal * .2).round(),
          'createdAt': DateTime.now(),
        },
        {
          'orderId': id,
          'type': 'delivery_fee',
          'amount': order['deliveryFee'],
          'createdAt': DateTime.now(),
        },
      ]);
    }
    notifyListeners();
  }

  int get todayCash => walletEntries.fold<int>(
    0,
    (sum, entry) => sum + (entry['amount'] as int),
  );
}
