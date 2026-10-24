import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/main.dart';
import 'package:livraison_app/marketplace_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every screen must lay out without overflowing on a 320 px wide phone, in
/// both languages (Arabic also mirrors the layout).
void main() {
  const roles = [
    ('client@wasla.dz', 'Demo123!', UserRole.client, 4),
    ('livreur@wasla.dz', 'Demo123!', UserRole.courier, 4),
    ('restaurant@wasla.dz', 'Demo123!', UserRole.restaurant, 4),
    ('superette@wasla.dz', 'Demo123!', UserRole.supermarket, 4),
    ('admin@wasla.dz', 'Admin123!', UserRole.admin, 5),
  ];
  for (final language in ['fr', 'ar']) {
    for (final role in roles) {
      testWidgets('${role.$3.name} fits a small phone in $language', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MarketplaceStore();
        addTearDown(store.dispose);
        await store.login(role.$1, role.$2, role.$3);
        store.language = language;
        await tester.pumpWidget(LivraisonApp(store: store));
        await tester.pumpAndSettle();
        for (var tab = 0; tab < role.$4; tab++) {
          final items = find.descendant(
            of: find.byType(FloatingNav),
            matching: find.byType(InkWell),
          );
          await tester.tap(items.at(tab));
          await tester.pumpAndSettle();
          final scrollable = find.byType(Scrollable);
          for (var i = 0; i < 8; i++) {
            expect(tester.takeException(), isNull, reason: 'tab $tab step $i');
            if (scrollable.evaluate().isEmpty) break;
            await tester.drag(scrollable.first, const Offset(0, -450));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: 'tab $tab end');
        }
      });
    }
  }
}
