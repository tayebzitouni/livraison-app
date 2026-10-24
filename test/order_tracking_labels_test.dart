import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/marketplace_store.dart';
import 'package:livraison_app/order_tracking.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Arabic detailed tracking uses the five requested milestones', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'ar'});
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    await store.setLanguage('ar');
    final order = store.orders.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderStepList(order: order, store: store),
        ),
      ),
    );

    expect(find.text('تم ارسال الطلب'), findsOneWidget);
    expect(find.text('تم تأكيد الطلب'), findsOneWidget);
    expect(
      find.text('الموصل استلم الطلب من ${store.orderMerchant(order)}'),
      findsOneWidget,
    );
    expect(find.text('في الطريق مع الموصل'), findsOneWidget);
    expect(find.text('تم تأكيد الاستلام'), findsOneWidget);
    expect(find.text('تم تأكيد الموصل'), findsNothing);
    expect(find.text('قيد التحضير'), findsNothing);
  });
}
