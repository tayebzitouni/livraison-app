import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/marketplace_store.dart';
import 'package:livraison_app/reports.dart';

void main() {
  testWidgets('admin report produces a PDF in French and Arabic', (
    tester,
  ) async {
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    expect(
      await store.login('admin@wasla.dz', 'Admin123!', UserRole.admin),
      true,
    );
    await tester.pumpWidget(MaterialApp(home: ReportsScreen(store: store)));
    final dynamic state = tester.state(find.byType(ReportsScreen));
    final french = await state.buildPdf() as List<int>;
    expect(ascii.decode(french.take(4).toList()), '%PDF');
    store.language = 'ar';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: ReportsScreen(store: store),
      ),
    );
    final dynamic arabicState = tester.state(find.byType(ReportsScreen));
    final arabic = await arabicState.buildPdf() as List<int>;
    expect(ascii.decode(arabic.take(4).toList()), '%PDF');
  });

  testWidgets('admin can export a full PDF for one compte', (tester) async {
    final store = MarketplaceStore();
    addTearDown(store.dispose);
    expect(
      await store.login('admin@wasla.dz', 'Admin123!', UserRole.admin),
      true,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    final merchant = store.users.firstWhere(
      (u) => u.role == UserRole.restaurant,
    );
    final pdf = await buildAccountReportPdf(store, merchant);
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
  });
}
