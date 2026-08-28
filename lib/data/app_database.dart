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
        'status': 'قيد التحضير',
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

  void createOrder({required int total, required int itemCount}) {
    final id = 'TJ-${104 + orders.length}';
    orders.insert(0, {
      'id': id,
      'status': 'قيد التحضير',
      'total': total,
      'items': itemCount,
      'customer': 'فتحي',
    });
    walletEntries.add({
      'orderId': id,
      'type': 'order',
      'amount': total,
      'createdAt': DateTime.now(),
    });
    notifyListeners();
  }

  int get todayCash => walletEntries.fold<int>(
    0,
    (sum, entry) => sum + (entry['amount'] as int),
  );
}
