import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/main.dart';
import 'package:livraison_app/marketplace_store.dart';

void main() {
  testWidgets('client home visual reference', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MarketplaceStore();
    addTearDown(store.dispose);
    expect(
      await store.login('client@wasla.dz', 'Demo123!', UserRole.client),
      true,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('visual-reference'),
        child: LivraisonApp(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('visual-reference')),
      matchesGoldenFile('goldens/client_home.png'),
    );
  });

  testWidgets('partner sign-in visual reference', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MarketplaceStore()..openAuth();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('partner-sign-in'),
        child: LivraisonApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('partner-sign-in')),
      matchesGoldenFile('goldens/partner_auth.png'),
    );
  });
}
