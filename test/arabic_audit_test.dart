import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livraison_app/domain.dart';
import 'package:livraison_app/main.dart';
import 'package:livraison_app/marketplace_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every text on screen must be Arabic when the language is Arabic. Names and
/// descriptions typed by partners (demo data here) stay as they were written.
final _latinWord = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿŒœ]{2,}');
const _brand = {'wasla', 'WhatsApp', 'PDF', 'OK', 'WS', 'Tél', 'Cloudflare'};

Set<String> _dataWords(MarketplaceStore store) {
  final words = <String>{};
  void add(String? value) {
    for (final match in _latinWord.allMatches(value ?? '')) {
      words.add(match.group(0)!.toLowerCase());
    }
  }

  for (final p in store.products) {
    add(p.name);
    add(p.description);
    add(p.category);
    for (final i in p.ingredients) {
      add(i);
    }
    for (final a in p.allergens) {
      add(a);
    }
  }
  for (final u in store.users) {
    add(u.name);
    add(u.businessName);
    add(u.address);
    add(u.email);
  }
  for (final c in store.categories) {
    add(c.name);
  }
  for (final o in store.orders) {
    add(o.address);
    add(o.note);
    add(o.paymentMethod);
    add(o.clientName);
    add(o.merchantName);
  }
  for (final n in store.notifications) {
    add(n.title);
    add(n.message);
  }
  return words;
}

List<String> _leftovers(WidgetTester tester, Set<String> allowed) {
  final found = <String>[];
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    var text = rich.text.toPlainText();
    text = text
        .replaceAll(RegExp(r'\S+@\S+'), '')
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'#?WS-?\d+'), '');
    final words = _latinWord
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((w) => !_brand.contains(w) && !allowed.contains(w.toLowerCase()))
        .toList();
    if (words.isNotEmpty) found.add(text.trim());
  }
  return found;
}

Future<MarketplaceStore> _boot(
  WidgetTester tester,
  String email,
  String password,
  UserRole role,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = MarketplaceStore();
  addTearDown(store.dispose);
  await store.login(email, password, role);
  store.language = 'ar';
  await tester.pumpWidget(LivraisonApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

Future<void> _tapNav(WidgetTester tester, int index) async {
  final nav = find.byType(FloatingNav);
  final items = find.descendant(of: nav, matching: find.byType(InkWell));
  await tester.tap(items.at(index));
  await tester.pumpAndSettle();
}

Future<void> _scrollThrough(
  WidgetTester tester,
  void Function(String) check,
) async {
  check('top');
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  for (var i = 0; i < 6; i++) {
    await tester.drag(scrollables.first, const Offset(0, -500));
    await tester.pumpAndSettle();
    check('scroll $i');
  }
}

void main() {
  void audit(
    String name,
    String email,
    String password,
    UserRole role,
    int tabs,
  ) {
    testWidgets('Arabic has no French left: $name', (tester) async {
      final store = await _boot(tester, email, password, role);
      final allowed = _dataWords(store);
      final problems = <String, String>{};
      for (var tab = 0; tab < tabs; tab++) {
        await _tapNav(tester, tab);
        await _scrollThrough(tester, (where) {
          for (final text in _leftovers(tester, allowed)) {
            problems.putIfAbsent(text, () => 'tab $tab');
          }
        });
      }
      expect(
        problems,
        isEmpty,
        reason: problems.entries.map((e) => '${e.value}: ${e.key}').join('\n'),
      );
    });
  }

  audit('client', 'client@wasla.dz', 'Demo123!', UserRole.client, 4);
  audit('courier', 'livreur@wasla.dz', 'Demo123!', UserRole.courier, 4);
  audit(
    'restaurant',
    'restaurant@wasla.dz',
    'Demo123!',
    UserRole.restaurant,
    4,
  );
  audit(
    'supermarket',
    'superette@wasla.dz',
    'Demo123!',
    UserRole.supermarket,
    4,
  );
  audit('admin', 'admin@wasla.dz', 'Admin123!', UserRole.admin, 5);
  _flows();
}

/// Sheets, dialogs, error messages and forms, which the tab walk above never
/// opens.
void _flows() {
  Future<void> closeTop(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('Arabic has no French left: client sheets and cart', (
    tester,
  ) async {
    final store = await _boot(
      tester,
      'client@wasla.dz',
      'Demo123!',
      UserRole.client,
    );
    final allowed = _dataWords(store);
    final problems = <String, String>{};
    void check(String where) {
      for (final text in _leftovers(tester, allowed)) {
        problems.putIfAbsent(text, () => where);
      }
    }

    // product details
    await _tapNav(tester, 1);
    await tester.ensureVisible(find.byType(ProductCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProductCard).first);
    await tester.pumpAndSettle();
    check('product details');
    await closeTop(tester);

    // cart, with the validation error showing
    store.addToCart(store.product('p1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
    await tester.pumpAndSettle();
    check('cart');
    await tester.enterText(find.byKey(const Key('order-phone-field')), '');
    await tester.tap(find.byKey(const Key('confirm-whatsapp-order')));
    await tester.pumpAndSettle();
    check('cart error');
    await closeTop(tester);

    // profile entries
    await _tapNav(tester, 3);
    for (final entry in [
      Icons.person_outline_rounded,
      Icons.notifications_none_rounded,
      Icons.location_on_outlined,
      Icons.credit_card_rounded,
      Icons.help_outline_rounded,
      Icons.privacy_tip_outlined,
      Icons.gavel_outlined,
      Icons.replay_outlined,
      Icons.assessment_outlined,
    ]) {
      final tile = find.widgetWithIcon(ListTile, entry).first;
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      check('profile ${entry.codePoint}');
      await closeTop(tester);
    }
    expect(
      problems,
      isEmpty,
      reason: problems.entries.map((e) => '${e.value}: ${e.key}').join('\n'),
    );
  });

  testWidgets('Arabic has no French left: admin dialogs', (tester) async {
    final store = await _boot(
      tester,
      'admin@wasla.dz',
      'Admin123!',
      UserRole.admin,
    );
    final allowed = _dataWords(store);
    final problems = <String, String>{};
    void check(String where) {
      for (final text in _leftovers(tester, allowed)) {
        problems.putIfAbsent(text, () => where);
      }
    }

    // pricing dialog with an invalid value
    final pricing = find.textContaining('العمولة 10');
    await tester.ensureVisible(pricing);
    await tester.tap(pricing);
    await tester.pumpAndSettle();
    check('pricing');
    await tester.enterText(find.byKey(const Key('pricing-percent')), '150');
    await tester.tap(find.byKey(const Key('pricing-save')));
    await tester.pumpAndSettle();
    check('pricing error');
    await closeTop(tester);

    // account creation with an invalid password
    final partners = find.text('حسابات الشركاء');
    await tester.ensureVisible(partners);
    await tester.tap(partners);
    await tester.pumpAndSettle();
    check('accounts');
    await tester.enterText(find.byKey(const Key('account-name')), 'Nadia');
    await tester.enterText(
      find.byKey(const Key('account-email')),
      'nadia@wasla.dz',
    );
    await tester.enterText(find.byKey(const Key('account-password')), 'abc');
    await tester.ensureVisible(find.byKey(const Key('account-create')));
    await tester.tap(find.byKey(const Key('account-create')));
    await tester.pumpAndSettle();
    check('accounts error');
    await closeTop(tester);

    // catalogue: duplicate category and product review
    await _tapNav(tester, 3);
    check('catalogue');
    await tester.tap(find.byKey(const Key('category-add')));
    await tester.pumpAndSettle();
    check('category dialog');
    await tester.enterText(find.byKey(const Key('category-name')), 'Healthy');
    await tester.tap(find.byKey(const Key('category-create')));
    await tester.pumpAndSettle();
    check('category error');
    await closeTop(tester);

    // an account page
    await _tapNav(tester, 1);
    await tester.tap(find.text('Sofia Benali'));
    await tester.pumpAndSettle();
    check('account page');
    expect(
      problems,
      isEmpty,
      reason: problems.entries.map((e) => '${e.value}: ${e.key}').join('\n'),
    );
  });

  testWidgets('Arabic has no French left: partner forms', (tester) async {
    final store = await _boot(
      tester,
      'superette@wasla.dz',
      'Demo123!',
      UserRole.supermarket,
    );
    final allowed = _dataWords(store);
    final problems = <String, String>{};
    void check(String where) {
      for (final text in _leftovers(tester, allowed)) {
        problems.putIfAbsent(text, () => where);
      }
    }

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    check('product editor');
    final submit = find.byKey(const Key('product-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    check('product editor errors');
    await closeTop(tester);
    expect(
      problems,
      isEmpty,
      reason: problems.entries.map((e) => '${e.value}: ${e.key}').join('\n'),
    );
  });

  testWidgets('Arabic has no French left: sign-in and kitchen sign-up', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MarketplaceStore()
      ..language = 'ar'
      ..openAuth();
    addTearDown(store.dispose);
    await tester.pumpWidget(LivraisonApp(store: store));
    await tester.pumpAndSettle();
    final problems = <String, String>{};
    void check(String where) {
      for (final text in _leftovers(tester, _dataWords(store))) {
        problems.putIfAbsent(text, () => where);
      }
    }

    check('sign-in');
    await tester.tap(find.byKey(const Key('auth-mode-toggle')));
    await tester.pumpAndSettle();
    check('sign-up');
    await tester.ensureVisible(find.byKey(const Key('signup-submit')));
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();
    check('sign-up error');
    expect(
      problems,
      isEmpty,
      reason: problems.entries.map((e) => '${e.value}: ${e.key}').join('\n'),
    );
  });
}
