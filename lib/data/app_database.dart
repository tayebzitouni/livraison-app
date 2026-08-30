import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_backend.dart';

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

  bool get isRemote => SupabaseBackend.configured;

  Future<void> refreshFromRemote() async {
    final client = SupabaseBackend.client;
    if (client == null) return;
    try {
      final productRows = await client
          .from('products')
          .select()
          .eq('active', true);
      final orderRows = await client
          .from('orders')
          .select()
          .order('created_at', ascending: false);
      if (productRows.isNotEmpty) {
        products
          ..clear()
          ..addAll(
            productRows.map(
              (row) => {
                'id': row['id'],
                'title': row['name'],
                'price': row['retail_price'],
                'emoji': '🍽️',
              },
            ),
          );
      }
      orders
        ..clear()
        ..addAll(
          orderRows.map(
            (row) => {
              'dbId': row['id'],
              'id': row['code'],
              'status': row['status'],
              'foodTotal': row['food_total'],
              'deliveryFee': row['delivery_fee'],
              'total': row['total'],
              'customer': 'زبون وصلة',
            },
          ),
        );
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        final walletRows = await client
            .from('wallet_entries')
            .select()
            .eq('owner_id', userId)
            .order('created_at', ascending: false);
        walletEntries
          ..clear()
          ..addAll(
            walletRows.map(
              (row) => {
                'orderId': row['order_id'],
                'type': row['entry_type'],
                'amount': row['amount'],
                'createdAt': DateTime.tryParse(
                  row['created_at'] as String? ?? '',
                ),
              },
            ),
          );
      }
      notifyListeners();
    } catch (_) {
      // Keep the seeded offline data if the remote service is unavailable.
    }
  }

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
    unawaited(_createRemoteOrder(id, foodTotal, itemCount, deliveryFee));
  }

  Future<void> _createRemoteOrder(
    String code,
    int foodTotal,
    int itemCount,
    int deliveryFee,
  ) async {
    final client = SupabaseBackend.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      final created = await client
          .from('orders')
          .insert({
            'code': code,
            'customer_id': user.id,
            'status': 'draft',
            'food_total': foodTotal,
            'delivery_fee': deliveryFee,
          })
          .select('id')
          .single();
      final product = await client
          .from('products')
          .select('id, retail_price, wholesale_price')
          .eq('active', true)
          .limit(1)
          .single();
      await client.from('order_items').insert({
        'order_id': created['id'],
        'product_id': product['id'],
        'quantity': itemCount,
        'retail_unit_price': product['retail_price'],
        'wholesale_unit_price': product['wholesale_price'],
      });
      await refreshFromRemote();
    } catch (_) {}
  }

  void confirmOrder(String id) {
    final order = orders.firstWhere((item) => item['id'] == id);
    if (order['status'] == 'draft') {
      order['status'] = 'confirmed';
      notifyListeners();
      unawaited(_updateRemoteStatus(order, 'confirmed', assignDriver: true));
    }
  }

  void advanceOrder(String id) {
    final order = orders.firstWhere((item) => item['id'] == id);
    final status = order['status'];
    if (status == 'confirmed') {
      order['status'] = 'picked_up';
      unawaited(_updateRemoteStatus(order, 'picked_up'));
    } else if (status == 'picked_up') {
      order['status'] = 'delivered';
      unawaited(_updateRemoteStatus(order, 'delivered'));
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

  Future<void> _updateRemoteStatus(
    Map<String, dynamic> order,
    String status, {
    bool assignDriver = false,
  }) async {
    final client = SupabaseBackend.client;
    if (client == null) return;
    try {
      final payload = <String, dynamic>{'status': status};
      if (assignDriver && client.auth.currentUser != null) {
        payload['driver_id'] = client.auth.currentUser!.id;
      }
      final dbId = order['dbId'];
      var query = client.from('orders').update(payload);
      if (dbId != null) {
        await query.eq('id', dbId);
      } else {
        await query.eq('code', order['id']);
      }
      await refreshFromRemote();
    } catch (_) {}
  }

  int get todayCash => walletEntries.fold<int>(
    0,
    (sum, entry) => sum + (entry['amount'] as int),
  );
}
