// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:livraison_app/main.dart';

void main() {
  testWidgets('Arabic marketplace renders', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1');
    await tester.enterText(fields.at(1), '1');
    await tester.tap(find.text('دخول إلى التطبيق'));
    await tester.pumpAndSettle();
    expect(find.text('مرحبا، فتحي 👋'), findsOneWidget);
    expect(find.text('الأكثر شعبية'), findsOneWidget);
  });
}
