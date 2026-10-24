import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'cart_sheet.dart';
import 'data/cloudflare_backend.dart';
import 'in_app_banner.dart';
import 'marketplace_store.dart';
import 'domain.dart';
import 'dynamic_ui.dart';
import 'reports.dart';
import 'localized_text.dart';
import 'build_expiry.dart';
import 'order_contact.dart';
import 'order_tracking.dart';
import 'legal.dart';

const ink = Color(0xFF181C19),
    brown = Color(0xFFFF6B35),
    cream = Color(0xFFF7F7F4),
    paper = Color(0xFFFFFFFF),
    green = Color(0xFF145A42),
    orange = Color(0xFFFFC857),
    muted = Color(0xFF6A746E);
String dzd(num n) => '${n.toStringAsFixed(0)} DA';
String categoryAsset(AppCategory category) {
  final value = category.name.toLowerCase();
  if (value.contains('pâte') || value.contains('pasta')) {
    return 'assets/products/mushroom-pasta.png';
  }
  if (value.contains('burger')) return 'assets/products/smash-burger.png';
  if (value.contains('frais') || value.contains('fruit')) {
    return 'assets/products/organic-avocados.png';
  }
  if (value.contains('pain') || value.contains('boulanger')) {
    return 'assets/products/artisan-bread.png';
  }
  return 'assets/marketplace_hero.png';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LivraisonApp());
}

class LivraisonApp extends StatefulWidget {
  const LivraisonApp({super.key, this.store});
  final MarketplaceStore? store;
  @override
  State<LivraisonApp> createState() => _LivraisonAppState();
}

class _LivraisonAppState extends State<LivraisonApp> {
  late final store = widget.store ?? MarketplaceStore();
  late String _language = store.language;
  bool _expired = false;
  void _syncLanguage() {
    if (_language != store.language) {
      setState(() => _language = store.language);
    }
  }

  @override
  void initState() {
    super.initState();
    store.addListener(_syncLanguage);
    if (widget.store == null) store.bootstrap();
    _watchExpiry();
  }

  Future<void> _watchExpiry() async {
    if (!BuildExpiry.enabled) return;
    final expired = await BuildExpiry.isExpired();
    if (!mounted) return;
    if (expired) {
      setState(() => _expired = true);
      return;
    }
    Future<void>.delayed(const Duration(minutes: 5), _watchExpiry);
  }

  @override
  void dispose() {
    store.removeListener(_syncLanguage);
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: rootNavigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'Wasla Livraison',
    locale: Locale(_language),
    supportedLocales: const [Locale('fr'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => Directionality(
      textDirection: store.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: child ?? const SizedBox.shrink(),
    ),
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brown,
        primary: brown,
        secondary: green,
        tertiary: orange,
        surface: paper,
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          height: 1.05,
          letterSpacing: -1.4,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -.7,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: ink),
        bodyMedium: TextStyle(fontSize: 13, height: 1.4, color: muted),
        labelLarge: TextStyle(fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        shadowColor: ink.withValues(alpha: .06),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE9EAE6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEAE2D8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: brown, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ),
    home: _expired
        ? const ExpiredPreviewScreen()
        : AnimatedBuilder(
            animation: store,
            builder: (_, _) => store.initializing
                ? const SplashScreen()
                : store.showAuth || store.currentUser == null
                ? AuthScreen(store: store)
                : AppShell(store: store),
          ),
  );
}

class ExpiredPreviewScreen extends StatelessWidget {
  const ExpiredPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Brand(),
            const Spacer(),
            const Icon(Icons.lock_clock_rounded, size: 46, color: brown),
            const SizedBox(height: 18),
            const Text(
              'Cette version a expiré',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1.1,
                color: ink,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cette copie n’est valable que 24 heures. Demandez une nouvelle version à Wasla.',
            ),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: light ? Colors.white : ink,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          Icons.delivery_dining_rounded,
          color: light ? ink : Colors.white,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'wasla',
        style: TextStyle(
          fontSize: 24,
          letterSpacing: -1,
          fontWeight: FontWeight.w900,
          color: light ? Colors.white : ink,
        ),
      ),
    ],
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: cream,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Brand(),
          SizedBox(height: 26),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3, color: brown),
          ),
        ],
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.store});
  final MarketplaceStore store;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool obscure = true, loading = false, registering = false;
  String? formError;
  final email = TextEditingController(), password = TextEditingController();
  final name = TextEditingController(),
      kitchen = TextEditingController(),
      phone = TextEditingController();
  @override
  void dispose() {
    for (final c in [email, password, name, kitchen, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  MarketplaceStore get store => widget.store;

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (email.text.trim().isEmpty || password.text.length < 8) {
      toast('Complétez les champs obligatoires.');
      return;
    }
    setState(() => loading = true);
    final ok = await widget.store.login(email.text, password.text);
    if (!mounted) return;
    setState(() => loading = false);
    if (!ok) {
      toast(
        widget.store.lastError ??
            'Informations incorrectes ou compte introuvable.',
      );
    }
  }

  /// Kitchens (restaurants) open their own account; it is signed in at once.
  Future<void> register() async {
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      formError = null;
    });
    final ok = await store.signup(
      name: name.text,
      email: email.text,
      password: password.text,
      role: UserRole.restaurant,
      businessName: kitchen.text,
      phone: phone.text,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      if (!ok) {
        formError =
            store.lastError ??
            store.tr('Inscription impossible.', 'تعذر التسجيل.');
      }
    });
  }

  void toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? type,
    Key? key,
    TextCapitalization capitalization = TextCapitalization.none,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      key: key,
      controller: controller,
      keyboardType: type,
      textCapitalization: capitalization,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Brand(),
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: widget.store.tr(
                        'Voir les produits',
                        'عرض المنتجات',
                      ),
                      onPressed: widget.store.closeAuth,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  height: 178,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(27),
                    image: const DecorationImage(
                      image: AssetImage('assets/marketplace_hero.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [Color(0xE815201A), Color(0x2215201A)],
                      ),
                    ),
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: brown,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text(
                            'ESPACE PARTENAIRE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Votre activité avance avec Wasla.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  registering
                      ? store.tr('Inscrire ma cuisine', 'سجّل مطبخك')
                      : 'Bon retour !',
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 6),
                Text(
                  registering
                      ? store.tr(
                          'Créez le compte de votre cuisine ou restaurant. Vos plats seront visibles après validation.',
                          'أنشئ حساب مطبخك أو مطعمك. تظهر أطباقك بعد الموافقة عليها.',
                        )
                      : 'Retrouvez vos commandes et votre activité.',
                ),
                const SizedBox(height: 22),
                if (registering) ...[
                  _field(
                    name,
                    store.tr('Nom complet', 'الاسم الكامل'),
                    Icons.person_outline_rounded,
                    key: const Key('signup-name'),
                    capitalization: TextCapitalization.words,
                  ),
                  _field(
                    kitchen,
                    store.tr('Nom de la cuisine', 'اسم المطبخ'),
                    Icons.storefront_outlined,
                    key: const Key('signup-kitchen'),
                  ),
                  _field(
                    phone,
                    store.tr('Téléphone', 'الهاتف'),
                    Icons.phone_outlined,
                    type: TextInputType.phone,
                    key: const Key('signup-phone'),
                  ),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: widget.store.tr(
                      'Adresse e-mail',
                      'البريد الإلكتروني',
                    ),
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => registering ? register() : submit(),
                  decoration: InputDecoration(
                    labelText: widget.store.tr('Mot de passe', 'كلمة المرور'),
                    helperText: registering
                        ? store.tr('8 caractères minimum', '8 أحرف على الأقل')
                        : null,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 12),
                  FormMessage(formError!),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: Key(registering ? 'signup-submit' : 'login-submit'),
                    onPressed: loading
                        ? null
                        : registering
                        ? register
                        : submit,
                    icon: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      registering
                          ? store.tr(
                              'Créer le compte de ma cuisine',
                              'إنشاء حساب مطبخي',
                            )
                          : 'Se connecter',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    key: const Key('auth-mode-toggle'),
                    onPressed: loading
                        ? null
                        : () => setState(() {
                            registering = !registering;
                            formError = null;
                          }),
                    child: Text(
                      registering
                          ? store.tr(
                              'J’ai déjà un compte · Se connecter',
                              'لدي حساب · تسجيل الدخول',
                            )
                          : store.tr(
                              'Vous avez une cuisine ? Inscrivez-vous',
                              'لديك مطبخ؟ سجّل الآن',
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    store.tr(
                      'Les comptes livreur et supérette sont ouverts par l’administrateur.',
                      'حسابات الموصل والبقالة يفتحها المدير.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      TextButton(
                        onPressed: () => openLegalPage(
                          context,
                          widget.store,
                          LegalPageKind.privacy,
                        ),
                        child: Text(
                          widget.store.tr('Confidentialité', 'الخصوصية'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => openLegalPage(
                          context,
                          widget.store,
                          LegalPageKind.terms,
                        ),
                        child: Text(widget.store.tr('Conditions', 'الشروط')),
                      ),
                      TextButton(
                        onPressed: () => openLegalPage(
                          context,
                          widget.store,
                          LegalPageKind.refund,
                        ),
                        child: Text(
                          widget.store.tr('Remboursement', 'الاسترجاع'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class Dest {
  const Dest(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final MarketplaceStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  String? clientCategory;
  StreamSubscription<AppNotification>? _notices;

  @override
  void initState() {
    super.initState();
    _notices = widget.store.incomingNotifications.listen(_announce);
  }

  @override
  void dispose() {
    _notices?.cancel();
    dismissInAppBanner();
    super.dispose();
  }

  /// First channel: a banner inside the app as soon as something happens.
  void _announce(AppNotification notice) {
    if (!mounted) return;
    final ar = widget.store.language == 'ar';
    showInAppBanner(
      title: ar ? translateNotice(notice.title) : notice.title,
      message: ar ? translateNotice(notice.message) : notice.message,
      icon: switch (notice.type) {
        'payment' => Icons.account_balance_wallet_rounded,
        'catalog' => Icons.inventory_2_rounded,
        'account' => Icons.person_add_alt_rounded,
        _ => Icons.delivery_dining_rounded,
      },
      onTap: () => _openNotification(notice),
    );
  }

  int _ordersTab(UserRole role) => switch (role) {
    UserRole.client || UserRole.admin => 2,
    UserRole.courier || UserRole.restaurant || UserRole.supermarket => 1,
  };

  Future<void> _openNotification(AppNotification notice) async {
    unawaited(widget.store.markNotificationRead(notice));
    final reference = notice.orderId;
    if (reference == null) {
      if (mounted) {
        showNotifications(
          context,
          widget.store,
          onOpenOrder: _openNotification,
        );
      }
      return;
    }

    final role = widget.store.currentUser!.role;
    // Move to the order list immediately so the tap always has visible
    // feedback, even if an unusually fresh notification needs one refresh.
    setState(() => index = _ordersTab(role));
    var order = widget.store.orderForNotification(notice);
    if (order == null) {
      await widget.store.refresh(includeStatic: false);
      order = widget.store.orderForNotification(notice);
    }
    if (!mounted) return;

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.tr(
              'Cette commande n’est plus disponible.',
              'هذا الطلب لم يعد متاحًا.',
            ),
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsScreen(
          store: widget.store,
          orderReference: reference,
          initialOrder: order!,
        ),
      ),
    );
  }

  List<Dest> destinations(UserRole r) => switch (r) {
    UserRole.client => [
      Dest(widget.store.tr('Accueil', 'الرئيسية'), Icons.home_rounded),
      Dest(widget.store.tr('Explorer', 'استكشاف'), Icons.search_rounded),
      Dest(widget.store.tr('Commandes', 'الطلبات'), Icons.receipt_long_rounded),
      Dest(widget.store.tr('Profil', 'الملف الشخصي'), Icons.person_rounded),
    ],
    UserRole.courier => [
      Dest(widget.store.tr('Aperçu', 'نظرة عامة'), Icons.grid_view_rounded),
      Dest(
        widget.store.tr('Livraisons', 'التوصيلات'),
        Icons.delivery_dining_rounded,
      ),
      Dest(widget.store.tr('Revenus', 'الإيرادات'), Icons.wallet_rounded),
      Dest(widget.store.tr('Profil', 'الملف الشخصي'), Icons.person_rounded),
    ],
    UserRole.restaurant || UserRole.supermarket => [
      Dest(widget.store.tr('Aperçu', 'نظرة عامة'), Icons.grid_view_rounded),
      Dest(widget.store.tr('Commandes', 'الطلبات'), Icons.receipt_long_rounded),
      Dest(widget.store.tr('Produits', 'المنتجات'), Icons.inventory_2_rounded),
      Dest(widget.store.tr('Profil', 'الملف الشخصي'), Icons.person_rounded),
    ],
    UserRole.admin => [
      Dest(widget.store.tr('Aperçu', 'نظرة عامة'), Icons.grid_view_rounded),
      Dest(
        widget.store.tr('Comptes', 'الحسابات'),
        Icons.manage_accounts_rounded,
      ),
      Dest(widget.store.tr('Commandes', 'الطلبات'), Icons.receipt_long_rounded),
      Dest(widget.store.tr('Gestion', 'الإدارة'), Icons.tune_rounded),
      Dest(widget.store.tr('Profil', 'الملف الشخصي'), Icons.person_rounded),
    ],
  };
  Widget body(UserRole r) => switch (r) {
    UserRole.client => switch (index) {
      0 => ClientHome(
        store: widget.store,
        explore: (category) => setState(() {
          clientCategory = category;
          index = 1;
        }),
      ),
      1 => Catalog(store: widget.store, initialCategory: clientCategory),
      2 => OrdersView(store: widget.store),
      _ => Profile(store: widget.store),
    },
    UserRole.courier => switch (index) {
      0 => CourierHome(store: widget.store),
      1 => OrdersView(store: widget.store),
      2 => Earnings(store: widget.store),
      _ => Profile(store: widget.store),
    },
    UserRole.restaurant || UserRole.supermarket => switch (index) {
      0 => MerchantHome(
        store: widget.store,
        products: () => setState(() => index = 2),
      ),
      1 => OrdersView(store: widget.store),
      2 => ProductsView(store: widget.store),
      _ => Profile(store: widget.store),
    },
    UserRole.admin => switch (index) {
      0 => AdminHome(store: widget.store),
      1 => UsersView(store: widget.store),
      2 => OrdersView(store: widget.store),
      3 => GlobalCatalog(store: widget.store),
      _ => Profile(store: widget.store),
    },
  };
  @override
  Widget build(BuildContext context) {
    final u = widget.store.currentUser!, ds = destinations(u.role);
    return NotificationNavigationScope(
      openOrder: _openNotification,
      child: LayoutBuilder(
        builder: (context, c) {
          final desktop = c.maxWidth >= 920;
          return Scaffold(
            extendBody: !desktop,
            body: SafeArea(
              child: Row(
                children: [
                  if (desktop)
                    SideNav(
                      user: u,
                      items: ds,
                      index: index,
                      tap: (i) => setState(() => index = i),
                      logout: widget.store.logout,
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        if (widget.store.refreshError != null)
                          ConnectionBar(store: widget.store),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey('${u.role}-$index'),
                              child: body(u.role),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: desktop
                ? null
                : FloatingNav(
                    items: ds,
                    selected: index,
                    onSelect: (i) => setState(() => index = i),
                  ),
            floatingActionButton:
                u.role == UserRole.client && widget.store.cartCount > 0
                ? FloatingActionButton.extended(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    onPressed: () => cartSheet(context, widget.store),
                    icon: const Icon(Icons.shopping_bag_rounded),
                    label: Text(
                      '${widget.store.cartCount} · ${dzd(widget.store.cartSubtotal + widget.store.deliveryFee)}',
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// Shown when the last refresh failed, so stale data is never mistaken for live.
class ConnectionBar extends StatelessWidget {
  const ConnectionBar({super.key, required this.store});
  final MarketplaceStore store;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF4E5),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: Color(0xFF9A5D1D),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              store.tr(
                'Connexion instable : données non actualisées.',
                'الاتصال ضعيف: لم يتم تحديث البيانات.',
              ),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A5D1D),
              ),
            ),
          ),
          TextButton(
            key: const Key('connection-retry'),
            onPressed: () => store.refresh(),
            child: Text(store.tr('Réessayer', 'إعادة المحاولة')),
          ),
        ],
      ),
    ),
  );
}

class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });
  final List<Dest> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      heightFactor: 1,
      child: Container(
        height: 74,
        constraints: const BoxConstraints(maxWidth: 470),
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: const Color(0xFFEAE8E2)),
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: .16),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  selected: selected == i,
                  button: true,
                  label: items[i].label,
                  child: InkWell(
                    key: Key('nav-${items[i].label}'),
                    onTap: () => onSelect(i),
                    borderRadius: BorderRadius.circular(22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(0, selected == i ? -10 : 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: selected == i ? 50 : 34,
                            height: selected == i ? 50 : 34,
                            decoration: BoxDecoration(
                              color: selected == i ? paper : Colors.transparent,
                              shape: BoxShape.circle,
                              border: selected == i
                                  ? Border.all(
                                      color: const Color(0xFFF2EDE7),
                                      width: 2,
                                    )
                                  : null,
                              boxShadow: selected == i
                                  ? [
                                      BoxShadow(
                                        color: ink.withValues(alpha: .18),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              items[i].icon,
                              size: 23,
                              color: selected == i ? brown : muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: items.length == 5 ? 9 : 10,
                            fontWeight: selected == i
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: selected == i ? ink : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.user,
    required this.items,
    required this.index,
    required this.tap,
    required this.logout,
  });
  final AppUser user;
  final List<Dest> items;
  final int index;
  final ValueChanged<int> tap;
  final VoidCallback logout;
  @override
  Widget build(BuildContext context) => Container(
    width: 250,
    margin: const EdgeInsets.all(14),
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Brand(light: true),
        ),
        const SizedBox(height: 38),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Material(
              color: i == index
                  ? Colors.white.withValues(alpha: .13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => tap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        items[i].icon,
                        size: 20,
                        color: i == index
                            ? Colors.white
                            : const Color(0xFFB7AAA0),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: i == index
                              ? Colors.white
                              : const Color(0xFFB7AAA0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Avatar(user.name, light: true, imageUrl: user.avatarUrl),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.businessName ?? user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      user.role.label,
                      style: const TextStyle(
                        color: Color(0xFFB7AAA0),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: logout,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 25, 22, 0),
        sliver: SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!),
                    ],
                  ],
                ),
              ),
              ?action,
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 23, 22, 110),
        sliver: SliverToBoxAdapter(child: child),
      ),
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final String? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null)
        Text(
          action!,
          style: const TextStyle(color: brown, fontWeight: FontWeight.w800),
        ),
    ],
  );
}

class Stat {
  const Stat(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.onTap,
    this.key,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Key? key;
}

class Stats extends StatelessWidget {
  const Stats(this.items, {super.key, this.compact = false});
  final List<Stat> items;

  /// Two tiles per row on phones, for dashboards with many figures.
  final bool compact;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final n = c.maxWidth > 850
          ? items.length.clamp(1, 4)
          : c.maxWidth > 480 || compact
          ? 2
          : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: n,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: compact && c.maxWidth <= 480 ? 120 : 126,
        ),
        itemBuilder: (_, i) {
          final x = items[i];
          if (compact && c.maxWidth <= 480) {
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: x.key,
                onTap: x.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: x.color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(x.icon, color: x.color, size: 19),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          x.value,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                      ),
                      Text(
                        x.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: x.key,
              onTap: x.onTap,
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: x.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(x.icon, color: x.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            x.value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: ink,
                            ),
                          ),
                          Text(
                            x.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (x.onTap != null)
                      const Icon(Icons.chevron_right_rounded, color: muted),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class Avatar extends StatelessWidget {
  const Avatar(
    this.name, {
    super.key,
    this.light = false,
    this.large = false,
    this.imageUrl,
  });
  final String name;
  final bool light, large;
  final String? imageUrl;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: large ? 31 : 20,
    backgroundColor: light
        ? Colors.white.withValues(alpha: .15)
        : const Color(0xFFE5D8CB),
    foregroundColor: light ? Colors.white : brown,
    backgroundImage: !light && imageUrl?.isNotEmpty == true
        ? NetworkImage(imageUrl!)
        : null,
    child: !light && imageUrl?.isNotEmpty == true
        ? null
        : Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(
              fontSize: large ? 22 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.icon, this.title, this.message, {super.key});
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Icon(icon, size: 38, color: brown),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class ClientHome extends StatelessWidget {
  const ClientHome({super.key, required this.store, required this.explore});
  final MarketplaceStore store;
  final ValueChanged<String?> explore;
  @override
  Widget build(BuildContext context) {
    final u = store.currentUser!,
        os = store.ordersFor(u),
        latest = os.isEmpty ? null : os.first;
    final byMerchant = <String, List<Product>>{};
    for (final product in store.clientProducts) {
      byMerchant.putIfAbsent(product.ownerId, () => []).add(product);
    }
    final merchants = byMerchant.entries.toList();
    final categories = store.categories
        .where((item) => item.active)
        .take(8)
        .map((item) => (item.name, categoryAsset(item)))
        .toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: paper,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    NotificationButton(store: store),
                    const Spacer(),
                    IconButton.outlined(
                      key: const Key('partner-space-trigger'),
                      tooltip: store.tr('Espace partenaire', 'فضاء الشركاء'),
                      onPressed: store.openAuth,
                      icon: const Icon(Icons.storefront_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Text(
                  'Bonjour ${u.name.split(' ').first} 👋',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 19),
                Material(
                  color: const Color(0xFFF3F3F0),
                  borderRadius: BorderRadius.circular(19),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(19),
                    onTap: () => explore(null),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: ink),
                          SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Restaurant, plat ou produit…',
                              style: TextStyle(color: muted, fontSize: 14),
                            ),
                          ),
                          Icon(Icons.tune_rounded, color: brown, size: 21),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 115),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 94,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 17),
                    itemBuilder: (_, index) => FoodCategory(
                      label: categories[index].$1,
                      asset: categories[index].$2,
                      onTap: () => explore(categories[index].$1),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 246,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    image: const DecorationImage(
                      image: AssetImage('assets/products/smash-burger.png'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ink.withValues(alpha: .13),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xF21A201C),
                          Color(0x9A1A201C),
                          Colors.transparent,
                        ],
                        stops: [0, .48, 1],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 185,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: brown,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'OFFRE DU JOUR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            const Text(
                              'Un vrai repas,\nlivré chaud.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 13),
                            SizedBox(
                              height: 41,
                              child: FilledButton(
                                onPressed: () => explore(null),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: ink,
                                  minimumSize: const Size(0, 41),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                child: const Text('Commander'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (latest != null &&
                    latest.status != OrderStatus.clientConfirmed) ...[
                  const SizedBox(height: 25),
                  ActiveOrder(latest, store),
                ],
                const SizedBox(height: 30),
                HomeSectionHeader(
                  title: 'Restaurants près de vous',
                  onTap: () => explore(null),
                ),
                const SizedBox(height: 14),
                if (merchants.isEmpty && CloudflareBackend.configured)
                  CatalogLoading(store: store),
                ...merchants.map((entry) {
                  final products = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: RestaurantCard(
                      store: store,
                      name: store.merchantName(products.first),
                      products: products,
                      onTap: () => explore(null),
                    ),
                  );
                }),
                const SizedBox(height: 30),
                HomeSectionHeader(
                  title: 'Les plus commandés',
                  onTap: () => explore(null),
                ),
                const SizedBox(height: 14),
                ...store.clientProducts
                    .take(6)
                    .map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SizedBox(
                          height: 250,
                          child: ProductCard(product, store),
                        ),
                      ),
                    ),
                const SizedBox(height: 30),
                const SectionTitle('Votre activité'),
                const SizedBox(height: 13),
                Stats([
                  Stat(
                    'Commandes',
                    '${os.length}',
                    Icons.receipt_long_rounded,
                    brown,
                  ),
                  Stat(
                    'Livrées',
                    '${os.where((o) => o.status == OrderStatus.clientConfirmed).length}',
                    Icons.check_circle_rounded,
                    green,
                  ),
                  Stat(
                    'Dépenses',
                    dzd(
                      os
                          .where((o) => o.paid)
                          .fold<int>(0, (s, o) => s + o.total),
                    ),
                    Icons.wallet_rounded,
                    orange,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FoodCategory extends StatelessWidget {
  const FoodCategory({
    super.key,
    required this.label,
    required this.asset,
    required this.onTap,
  });
  final String label, asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(40),
    child: SizedBox(
      width: 67,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE3E4DE)),
            ),
            child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.onTap,
  });
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(onPressed: onTap, child: const Text('Voir tout')),
    ],
  );
}

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.store,
    required this.name,
    required this.products,
    required this.onTap,
  });
  final String name;
  final MarketplaceStore store;
  final List<Product> products;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = products.first;
    final categories = products
        .map((item) => item.category)
        .toSet()
        .take(2)
        .join(' · ');
    return SizedBox(
      width: double.infinity,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 132,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductMedia(product, borderRadius: 0),
                    Positioned(
                      top: 11,
                      left: 11,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'OUVERT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 11,
                      bottom: 11,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '20–30 min',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Icon(Icons.star_rounded, color: orange, size: 17),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      categories,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.delivery_dining_rounded,
                          size: 16,
                          color: brown,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Livraison ${dzd(store.deliveryFee)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading / retry card shown while the catalogue has not arrived yet.
class CatalogLoading extends StatelessWidget {
  const CatalogLoading({super.key, required this.store});
  final MarketplaceStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final loading = store.connecting || store.refreshing;
      return Column(
        children: [
          EmptyState(
            loading ? Icons.hourglass_top_rounded : Icons.cloud_off_rounded,
            loading
                ? store.tr('Chargement…', 'جارٍ التحميل…')
                : store.tr('Catalogue indisponible', 'الكتالوج غير متاح'),
            loading
                ? store.tr(
                    'Nous récupérons les restaurants et produits.',
                    'نجلب المطاعم والمنتجات.',
                  )
                : store.tr(
                    'Vérifiez votre connexion puis réessayez.',
                    'تحقق من اتصالك ثم أعد المحاولة.',
                  ),
          ),
          if (!loading) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('catalog-retry'),
              onPressed: store.reconnect,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(store.tr('Réessayer', 'إعادة المحاولة')),
            ),
          ],
        ],
      );
    },
  );
}

class ActiveOrder extends StatelessWidget {
  const ActiveOrder(this.order, this.store, {super.key});
  final MarketOrder order;
  final MarketplaceStore store;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: green,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.delivery_dining_rounded, color: Colors.white),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                order.status.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              order.id,
              style: const TextStyle(
                color: Color(0xFFC9D8D1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        OrderRouteTracker(order: order, store: store, onDark: true),
        const SizedBox(height: 9),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${order.items.length} articles · ${store.orderMerchant(order)}',
            style: const TextStyle(color: Color(0xFFDDE7E2)),
          ),
        ),
      ],
    ),
  );
}

class Catalog extends StatefulWidget {
  const Catalog({super.key, required this.store, this.initialCategory});
  final MarketplaceStore store;
  final String? initialCategory;
  @override
  State<Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<Catalog> {
  String search = '';
  ProductKind? kind;
  String? category;

  @override
  void initState() {
    super.initState();
    category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.store.clientProducts
        .where(
          (p) =>
              (kind == null || p.kind == kind) &&
              (category == null || p.category == category) &&
              (p.name.toLowerCase().contains(search.toLowerCase()) ||
                  p.category.toLowerCase().contains(search.toLowerCase()) ||
                  p.description.toLowerCase().contains(search.toLowerCase()) ||
                  widget.store
                      .merchantName(p)
                      .toLowerCase()
                      .contains(search.toLowerCase())),
        )
        .toList();
    final byMerchant = <String, List<Product>>{};
    for (final product in items) {
      byMerchant.putIfAbsent(product.ownerId, () => []).add(product);
    }
    return PageFrame(
      title: 'Restaurants & menus',
      subtitle: 'Tout ce qui vous fait envie, livré maintenant.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => setState(() => search = v),
            decoration: InputDecoration(
              hintText: widget.store.tr(
                'Rechercher un plat, produit ou catégorie',
                'ابحث عن طبق أو منتج أو تصنيف',
              ),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Tout'),
                selected: kind == null,
                onSelected: (_) => setState(() {
                  kind = null;
                  category = null;
                }),
              ),
              FilterChip(
                label: const Text('Repas'),
                selected: kind == ProductKind.meal,
                onSelected: (_) => setState(() {
                  kind = ProductKind.meal;
                  category = null;
                }),
              ),
              FilterChip(
                label: const Text('Courses'),
                selected: kind == ProductKind.grocery,
                onSelected: (_) => setState(() {
                  kind = ProductKind.grocery;
                  category = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Toutes catégories'),
                    selected: category == null,
                    onSelected: (_) => setState(() => category = null),
                  ),
                ),
                ...widget.store.categories
                    .where(
                      (item) =>
                          item.active && (kind == null || item.kind == kind),
                    )
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(item.name),
                          selected: category == item.name,
                          onSelected: (_) =>
                              setState(() => category = item.name),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (search.isEmpty && category == null && byMerchant.isNotEmpty) ...[
            const SectionTitle('Commerces populaires'),
            const SizedBox(height: 13),
            ...byMerchant.values.map(
              (products) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: RestaurantCard(
                  store: widget.store,
                  name: widget.store.merchantName(products.first),
                  products: products,
                  onTap: () =>
                      showProductDetails(context, products.first, widget.store),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('Tous les menus'),
            const SizedBox(height: 13),
          ],
          if (items.isEmpty &&
              widget.store.clientProducts.isEmpty &&
              CloudflareBackend.configured)
            CatalogLoading(store: widget.store)
          else if (items.isEmpty)
            const EmptyState(
              Icons.search_off_rounded,
              'Aucun résultat',
              'Essayez une autre recherche.',
            )
          else
            LayoutBuilder(
              builder: (_, c) {
                final n = c.maxWidth > 950
                    ? 4
                    : c.maxWidth > 650
                    ? 3
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: n,
                    crossAxisSpacing: 13,
                    mainAxisSpacing: 13,
                    mainAxisExtent: 290,
                  ),
                  itemBuilder: (_, i) => ProductCard(items[i], widget.store),
                );
              },
            ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard(this.product, this.store, {super.key});
  final Product product;
  final MarketplaceStore store;
  @override
  Widget build(BuildContext context) {
    final unavailable = !product.available;
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showProductDetails(context, product, store),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductMedia(product, borderRadius: 0),
                  if (unavailable)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Tag(
                        store.tr('Épuisé', 'نفد المخزون'),
                        const Color(0xFF555555),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: orange,
                            size: 15,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (product.mediaType == ProductMediaType.video)
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white,
                        foregroundColor: ink,
                        child: Icon(Icons.play_arrow_rounded),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    store.merchantName(product),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dzd(product.retailPrice),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: IconButton.filled(
                          padding: EdgeInsets.zero,
                          onPressed: unavailable
                              ? null
                              : () {
                                  final switched =
                                      store.cart.isNotEmpty &&
                                      store
                                              .product(store.cart.keys.first)
                                              .ownerId !=
                                          product.ownerId;
                                  store.addToCart(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        switched
                                            ? 'Panier remplacé : un commerce par commande.'
                                            : '${product.name} ajouté',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                          style: IconButton.styleFrom(
                            backgroundColor: brown,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            unavailable
                                ? Icons.block_rounded
                                : Icons.add_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Opacity(
      opacity: unavailable ? .58 : 1,
      child: unavailable
          ? ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.grey,
                BlendMode.saturation,
              ),
              child: card,
            )
          : card,
    );
  }
}

class OrdersView extends StatefulWidget {
  const OrdersView({super.key, required this.store});
  final MarketplaceStore store;

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final u = store.currentUser!;
    final filterable = [
      UserRole.courier,
      UserRole.restaurant,
      UserRole.supermarket,
    ].contains(u.role);
    final allOrders = store.ordersFor(u);
    final os = filterable && !showAll
        ? allOrders.where((o) => sameDay(o.createdAt, DateTime.now())).toList()
        : allOrders;
    final isClient = u.role == UserRole.client;
    final ongoing = os
        .where(
          (o) =>
              o.status != OrderStatus.clientConfirmed &&
              o.status != OrderStatus.cancelled,
        )
        .toList();
    final past = os.where((o) => !ongoing.contains(o)).toList();
    Widget card(MarketOrder o) => Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: OrderCard(o, store, u.role),
    );
    final content = os.isEmpty
        ? EmptyState(
            Icons.receipt_long_rounded,
            filterable && !showAll
                ? store.tr('Aucune commande aujourd’hui', 'لا توجد طلبات اليوم')
                : store.tr('Aucune commande', 'لا توجد طلبات'),
            filterable && !showAll
                ? store.tr(
                    'Choisissez « Toutes » pour consulter l’historique.',
                    'اختر « الكل » لعرض السجل.',
                  )
                : store.tr(
                    'Les nouvelles commandes apparaîtront ici.',
                    'ستظهر الطلبات الجديدة هنا.',
                  ),
          )
        : !isClient
        ? Column(children: os.map(card).toList())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ongoing.isNotEmpty) ...[
                SectionTitle(
                  store.tr('En cours', 'قيد التنفيذ'),
                  action: '${ongoing.length}',
                ),
                const SizedBox(height: 12),
                ...ongoing.map(card),
              ],
              if (past.isNotEmpty) ...[
                if (ongoing.isNotEmpty) const SizedBox(height: 14),
                SectionTitle(
                  store.tr('Historique', 'السجل'),
                  action: '${past.length}',
                ),
                const SizedBox(height: 12),
                ...past.map(card),
              ],
            ],
          );
    return PageFrame(
      title: u.role == UserRole.courier
          ? 'Livraisons'
          : isClient
          ? store.tr('Mes commandes', 'طلباتي')
          : 'Commandes',
      subtitle: u.role == UserRole.admin
          ? 'Toutes les commandes de la plateforme.'
          : isClient
          ? store.tr(
              'Toutes vos commandes sont conservées ici, avec leur suivi.',
              'جميع طلباتك محفوظة هنا مع تتبعها.',
            )
          : 'Suivi en direct et historique complet.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (filterable) ...[
            SegmentedButton<bool>(
              key: const Key('orders-period-filter'),
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.today_rounded),
                  label: Text(store.tr('Aujourd’hui', 'اليوم')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.history_rounded),
                  label: Text(store.tr('Toutes', 'الكل')),
                ),
              ],
              selected: {showAll},
              onSelectionChanged: (selection) =>
                  setState(() => showAll = selection.first),
            ),
            const SizedBox(height: 16),
          ],
          content,
        ],
      ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({
    super.key,
    required this.store,
    required this.orderReference,
    required this.initialOrder,
  });

  final MarketplaceStore store;
  final String orderReference;
  final MarketOrder initialOrder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final order = store.orderByReference(orderReference) ?? initialOrder;
      final role = store.currentUser!.role;
      return Scaffold(
        key: const Key('order-details-page'),
        backgroundColor: cream,
        appBar: AppBar(
          backgroundColor: cream,
          surfaceTintColor: Colors.transparent,
          title: Text(
            store.tr('Commande ${order.id}', 'الطلب ${order.id}'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            child: OrderCard(
              order,
              store,
              role,
              key: Key('order-details-${order.id}'),
            ),
          ),
        ),
      );
    },
  );
}

class OrderCard extends StatelessWidget {
  const OrderCard(this.order, this.store, this.role, {super.key});
  final MarketOrder order;
  final MarketplaceStore store;
  final UserRole role;

  MarketOrder get _fresh {
    for (final candidate in store.orders) {
      if (candidate.id == order.id) return candidate;
    }
    return order;
  }

  String _statusLabel(OrderStatus status) =>
      store.tr(status.label, switch (status) {
        OrderStatus.placed => 'بانتظار الموصل',
        OrderStatus.courierValidated => 'تم تأكيد الموصل',
        OrderStatus.merchantAccepted => 'مقبول',
        OrderStatus.preparing => 'قيد التحضير',
        OrderStatus.ready => 'جاهز للاستلام',
        OrderStatus.pickedUp => 'في الطريق',
        OrderStatus.delivered => 'تم التسليم · يرجى التأكيد',
        OrderStatus.clientConfirmed => 'تم تأكيد الاستلام',
        OrderStatus.cancelled => 'ملغى',
      });

  Future<void> _sendWhatsApp(
    BuildContext context,
    OrderContact contact,
    MarketOrder current,
  ) async {
    final message = orderUpdateMessage(
      order: current,
      merchant: store.orderMerchant(current),
      status: _statusLabel(current.status),
      arabic: store.language == 'ar',
    );
    final opened = await openWhatsAppChat(contact.phone, message);
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          store.tr('WhatsApp n’a pas pu s’ouvrir.', 'تعذر فتح واتساب.'),
        ),
      ),
    );
  }

  Future<void> _callClient(BuildContext context, OrderContact contact) async {
    final opened = await openPhoneCall(contact.phone);
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          store.tr('Impossible d’ouvrir le téléphone.', 'تعذر فتح الهاتف.'),
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await store.advance(order, role);
    if (!context.mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(store.lastError ?? 'Action impossible.'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    // Second channel: the people involved can be told on WhatsApp too, with the
    // order and the route already written.
    final current = _fresh;
    final contacts = orderContacts(
      current,
      role,
      merchantName: store.orderMerchant(current),
    ).where((c) => c.kind != OrderContactKind.merchant).toList();
    if (role == UserRole.client || contacts.isEmpty) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(store.tr('Statut mis à jour.', 'تم تحديث الحالة.')),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: store.tr('Prévenir sur WhatsApp', 'إبلاغ عبر واتساب'),
            onPressed: () => _sendWhatsApp(context, contacts.first, current),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final action = store.action(order, role),
        merchant = store.orderMerchant(order),
        processing = store.processingOrders.contains(order.id),
        finished =
            order.status == OrderStatus.clientConfirmed ||
            order.status == OrderStatus.cancelled,
        contacts = orderContacts(order, role, merchantName: merchant),
        showRoute =
            role == UserRole.courier &&
            order.courierId == store.currentUser?.id &&
            !finished &&
            order.address.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    color: order.status == OrderStatus.clientConfirmed
                        ? const Color(0xFFE2EEE8)
                        : const Color(0xFFF5E8D7),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    order.status == OrderStatus.clientConfirmed
                        ? Icons.check_rounded
                        : Icons.receipt_long_rounded,
                    color: order.status == OrderStatus.clientConfirmed
                        ? green
                        : brown,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$merchant · ${order.id}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        [
                          if (role != UserRole.client &&
                              order.clientName != null)
                            order.clientName!,
                          '${order.items.fold<int>(0, (s, i) => s + i.quantity)} articles',
                          order.paymentMethod,
                        ].join(' · '),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: StatusPill(order.status),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ...order.items.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: ProductMedia(i.product, borderRadius: 9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${i.quantity}× ${i.product.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(dzd(i.total)),
                  ],
                ),
              ),
            ),
            if (order.note.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.edit_note_rounded, color: brown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${store.tr('Note client', 'ملاحظة العميل')} : ${order.note}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 23),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: muted),
                const SizedBox(width: 5),
                Expanded(child: Text(order.address)),
                Text(
                  dzd(order.total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(
                  order.paid ? Icons.verified_rounded : Icons.schedule_rounded,
                  size: 17,
                  color: order.paid ? green : orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.paid ? 'Paiement reçu' : 'Paiement à la livraison',
                    style: TextStyle(
                      color: order.paid ? green : brown,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OrderTracking(
              order: order,
              store: store,
              initiallyExpanded: role == UserRole.client && !finished,
            ),
            if (contacts.isNotEmpty || showRoute) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (role == UserRole.courier)
                    for (final contact in contacts.where(
                      (item) => item.kind == OrderContactKind.client,
                    ))
                      FilledButton.icon(
                        key: Key('call-client-${order.id}'),
                        onPressed: () => _callClient(context, contact),
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: Text(
                          store.tr(
                            'Appeler ${contact.phone}',
                            'اتصل ${contact.phone}',
                          ),
                        ),
                      ),
                  for (final contact in contacts)
                    OutlinedButton.icon(
                      key: Key('whatsapp-${contact.kind.name}-${order.id}'),
                      onPressed: () => _sendWhatsApp(context, contact, order),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: Text(switch (contact.kind) {
                        OrderContactKind.client => store.tr(
                          'WhatsApp client',
                          'واتساب الزبون',
                        ),
                        OrderContactKind.merchant => store.tr(
                          'WhatsApp commerce',
                          'واتساب المتجر',
                        ),
                        OrderContactKind.courier => store.tr(
                          'WhatsApp livreur',
                          'واتساب الموصل',
                        ),
                      }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF128C4A),
                        side: const BorderSide(color: Color(0xFF25D366)),
                      ),
                    ),
                  if (showRoute)
                    OutlinedButton.icon(
                      key: Key('route-${order.id}'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await openRoute(
                          from: order.merchantAddress.trim().isEmpty
                              ? merchant
                              : '$merchant, ${order.merchantAddress.trim()}',
                          to: order.address,
                        );
                        if (!ok) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                store.tr(
                                  'Impossible d’ouvrir l’itinéraire.',
                                  'تعذر فتح المسار.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: Text(store.tr('Itinéraire', 'المسار')),
                    ),
                ],
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: processing ? null : () => _run(context),
                  child: processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(action),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final OrderStatus status;
  @override
  Widget build(BuildContext context) {
    final done = status == OrderStatus.clientConfirmed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE4F0E9) : const Color(0xFFF8EAD7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: done ? green : const Color(0xFF9A5D1D),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class MerchantHome extends StatefulWidget {
  const MerchantHome({super.key, required this.store, required this.products});
  final MarketplaceStore store;
  final VoidCallback products;

  @override
  State<MerchantHome> createState() => _MerchantHomeState();
}

class _MerchantHomeState extends State<MerchantHome> {
  DateTime day = dayOf(DateTime.now());

  MarketplaceStore get store => widget.store;

  void _shift(int amount) {
    final next = dayOf(day.add(Duration(days: amount, hours: 12)));
    if (next.isAfter(dayOf(DateTime.now()))) return;
    setState(() => day = next);
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: Locale(store.language),
    );
    if (picked != null) setState(() => day = dayOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final u = store.currentUser!,
        os = store
            .ordersFor(u)
            .where((order) => sameDay(order.createdAt, day))
            .toList(),
        own = store.products.where((p) => p.ownerId == u.id).toList(),
        revenue = os
            .where((o) => o.status == OrderStatus.clientConfirmed)
            .fold<int>(
              0,
              (sum, order) =>
                  sum +
                  order.items.fold<int>(
                    0,
                    (itemSum, item) =>
                        itemSum + item.product.wholesalePrice * item.quantity,
                  ),
            );
    return PageFrame(
      title: u.businessName ?? u.name,
      subtitle: store.tr(
        'Vos statistiques par jour et vos commandes.',
        'إحصاءاتك اليومية وطلباتك.',
      ),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotificationButton(store: store),
          const SizedBox(width: 8),
          if (MediaQuery.sizeOf(context).width < 380)
            IconButton.filled(
              tooltip: u.role == UserRole.supermarket
                  ? store.tr('Nouveau produit', 'منتج جديد')
                  : store.tr('Nouveau plat', 'طبق جديد'),
              onPressed: () => showProductEditor(context, store),
              icon: const Icon(Icons.add_rounded),
            )
          else
            FilledButton.icon(
              onPressed: () => showProductEditor(context, store),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                u.role == UserRole.supermarket
                    ? 'Nouveau produit'
                    : 'Nouveau plat',
              ),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DayNavigator(
            store: store,
            day: day,
            keyPrefix: 'merchant',
            previous: () => _shift(-1),
            next: sameDay(day, DateTime.now()) ? null : () => _shift(1),
            pick: _pick,
            today: sameDay(day, DateTime.now())
                ? null
                : () => setState(() => day = dayOf(DateTime.now())),
          ),
          const SizedBox(height: 16),
          Stats([
            Stat('Revenus', dzd(revenue), Icons.trending_up_rounded, green),
            Stat(
              'Commandes',
              '${os.length}',
              Icons.receipt_long_rounded,
              brown,
            ),
            Stat(
              'Produits actifs',
              '${own.where((p) => p.available).length}',
              Icons.inventory_2_rounded,
              orange,
            ),
            Stat(
              'À préparer',
              '${os.where((o) => [OrderStatus.courierValidated, OrderStatus.merchantAccepted, OrderStatus.preparing].contains(o.status)).length}',
              Icons.timer_rounded,
              const Color(0xFF9B5B55),
            ),
          ]),
          const SizedBox(height: 27),
          SectionTitle(
            store.tr('Commandes du jour choisi', 'طلبات اليوم المختار'),
            action: '${os.length}',
          ),
          const SizedBox(height: 12),
          if (os.isEmpty)
            const EmptyState(
              Icons.room_service_outlined,
              'Rien pour le moment',
              'Les commandes validées par un livreur apparaîtront ici.',
            )
          else
            ...os
                .take(3)
                .map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OrderCard(o, store, u.role),
                  ),
                ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gardez votre catalogue à jour',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        store.tr(
                          u.role == UserRole.supermarket
                              ? 'Disponibilité, votre prix et prix client fixé par l’administrateur.'
                              : 'Disponibilité, votre prix et prix client avec commission.',
                          u.role == UserRole.supermarket
                              ? 'التوفر، سعرك وسعر الزبون الذي يحدده المدير.'
                              : 'التوفر، سعرك وسعر الزبون مع العمولة.',
                        ),
                        style: const TextStyle(color: Color(0xFFC9BDB2)),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: widget.products,
                  style: IconButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: ink,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductsView extends StatelessWidget {
  const ProductsView({super.key, required this.store});
  final MarketplaceStore store;
  @override
  Widget build(BuildContext context) {
    final u = store.currentUser!,
        own = store.products.where((p) => p.ownerId == u.id).toList();
    return PageFrame(
      title: u.role == UserRole.supermarket
          ? 'Produits de supérette'
          : 'Carte du restaurant',
      subtitle: u.role == UserRole.supermarket
          ? 'Votre compte publie uniquement des produits de courses.'
          : 'Votre compte publie uniquement des plats préparés.',
      action: IconButton.filled(
        onPressed: () => showProductEditor(context, store),
        icon: const Icon(Icons.add_rounded),
      ),
      child: own.isEmpty
          ? const EmptyState(
              Icons.inventory_2_outlined,
              'Catalogue vide',
              'Ajoutez votre premier article.',
            )
          : Column(
              children: own
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 62,
                                height: 62,
                                child: ProductMedia(p, borderRadius: 18),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      p.approvalStatus == 'approved'
                                          ? store.tr(
                                              '${p.category} · Vous ${dzd(p.wholesalePrice)} · Client ${dzd(p.retailPrice)}',
                                              '${p.category} · أنت ${dzd(p.wholesalePrice)} · الزبون ${dzd(p.retailPrice)}',
                                            )
                                          : store.tr(
                                              '${p.category} · Votre prix ${dzd(p.wholesalePrice)} · ${p.approvalStatus == 'pending' ? 'En attente de validation' : 'Refusé'}',
                                              '${p.category} · سعرك ${dzd(p.wholesalePrice)} · ${p.approvalStatus == 'pending' ? 'في انتظار الموافقة' : 'مرفوض'}',
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    tooltip: store.tr(
                                      'Voir les détails',
                                      'عرض التفاصيل',
                                    ),
                                    onPressed: () =>
                                        showProductDetails(context, p, store),
                                    icon: const Icon(Icons.visibility_outlined),
                                  ),
                                  Switch(
                                    value:
                                        p.approvalStatus == 'approved' &&
                                        p.available,
                                    activeThumbColor: green,
                                    onChanged: p.approvalStatus != 'approved'
                                        ? null
                                        : (_) async {
                                            final ok = await store
                                                .toggleProduct(p);
                                            if (!context.mounted || ok) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  store.lastError ??
                                                      'Action impossible.',
                                                ),
                                              ),
                                            );
                                          },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class CourierHome extends StatefulWidget {
  const CourierHome({super.key, required this.store});
  final MarketplaceStore store;

  @override
  State<CourierHome> createState() => _CourierHomeState();
}

class _CourierHomeState extends State<CourierHome> {
  DateTime day = dayOf(DateTime.now());

  MarketplaceStore get store => widget.store;

  void _shift(int amount) {
    final next = dayOf(day.add(Duration(days: amount, hours: 12)));
    if (next.isAfter(dayOf(DateTime.now()))) return;
    setState(() => day = next);
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: Locale(store.language),
    );
    if (picked != null) setState(() => day = dayOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final u = store.currentUser!,
        os = store.ordersFor(u),
        dayOrders = os
            .where(
              (order) =>
                  order.courierId == u.id && sameDay(order.createdAt, day),
            )
            .toList(),
        done = dayOrders
            .where((o) => o.status == OrderStatus.clientConfirmed)
            .length,
        active = os
            .where(
              (o) =>
                  o.courierId == u.id &&
                  o.status != OrderStatus.clientConfirmed,
            )
            .toList(),
        offers = os
            .where((o) => o.courierId == null && o.status == OrderStatus.placed)
            .toList();
    final dayWallet = store.currentWalletEntries
        .where(
          (entry) =>
              entry.type == 'delivery_fee' && sameDay(entry.createdAt, day),
        )
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final revenue = store.currentWalletEntries.isEmpty
        ? dayOrders
              .where((order) => order.status == OrderStatus.clientConfirmed)
              .fold<int>(0, (sum, order) => sum + order.deliveryFee)
        : dayWallet;
    return PageFrame(
      title: 'Prêt à livrer ?',
      subtitle: 'Restez en ligne et faites avancer les commandes.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotificationButton(store: store),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE2EEE8),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: green),
                SizedBox(width: 6),
                Text(
                  'En ligne',
                  style: TextStyle(color: green, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DayNavigator(
            store: store,
            day: day,
            keyPrefix: 'courier',
            previous: () => _shift(-1),
            next: sameDay(day, DateTime.now()) ? null : () => _shift(1),
            pick: _pick,
            today: sameDay(day, DateTime.now())
                ? null
                : () => setState(() => day = dayOf(DateTime.now())),
          ),
          const SizedBox(height: 16),
          Stats([
            Stat('Revenus', dzd(revenue), Icons.wallet_rounded, green),
            Stat('Terminées', '$done', Icons.check_circle_rounded, brown),
            Stat(
              store.tr('Prises', 'المقبولة'),
              '${dayOrders.length}',
              Icons.delivery_dining_rounded,
              orange,
            ),
          ]),
          const SizedBox(height: 27),
          if (active.isNotEmpty) ...[
            const SectionTitle('Livraison active'),
            const SizedBox(height: 12),
            ...active.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OrderCard(o, store, u.role),
              ),
            ),
            const SizedBox(height: 15),
          ],
          SectionTitle(
            'Disponibles à proximité',
            action: '${offers.length} offres',
          ),
          const SizedBox(height: 12),
          if (offers.isEmpty)
            const EmptyState(
              Icons.route_rounded,
              'Vous êtes à jour',
              'Les nouvelles offres apparaîtront automatiquement.',
            )
          else
            ...offers.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OrderCard(o, store, u.role),
              ),
            ),
        ],
      ),
    );
  }
}

String shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String dayLabel(MarketplaceStore store, DateTime day) {
  final today = dayOf(DateTime.now());
  if (sameDay(day, today)) return store.tr('Aujourd’hui', 'اليوم');
  if (sameDay(day, today.subtract(const Duration(days: 1)))) {
    return store.tr('Hier', 'أمس');
  }
  return shortDate(day);
}

/// Shared day controls for restaurant and courier dashboards.
class DayNavigator extends StatelessWidget {
  const DayNavigator({
    super.key,
    required this.store,
    required this.day,
    required this.keyPrefix,
    required this.previous,
    required this.next,
    required this.pick,
    required this.today,
  });

  final MarketplaceStore store;
  final DateTime day;
  final String keyPrefix;
  final VoidCallback previous;
  final VoidCallback? next, today;
  final Future<void> Function() pick;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: Key('$keyPrefix-day-previous'),
            tooltip: store.tr('Jour précédent', 'اليوم السابق'),
            onPressed: previous,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              key: Key('$keyPrefix-day-picker'),
              borderRadius: BorderRadius.circular(14),
              onTap: pick,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      dayLabel(store, day),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(shortDate(day), style: const TextStyle(color: muted)),
                  ],
                ),
              ),
            ),
          ),
          if (today != null)
            TextButton(
              key: Key('$keyPrefix-day-today'),
              onPressed: today,
              child: Text(store.tr('Aujourd’hui', 'اليوم')),
            ),
          IconButton(
            key: Key('$keyPrefix-day-next'),
            tooltip: store.tr('Jour suivant', 'اليوم التالي'),
            onPressed: next,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    ),
  );
}

String timeOfDay(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class Earnings extends StatelessWidget {
  const Earnings({super.key, required this.store});
  final MarketplaceStore store;
  @override
  Widget build(BuildContext context) {
    final days = store.dailyEarnings;
    final total = days.fold<int>(0, (s, d) => s + d.amount);
    final todayEarned = days
        .where((d) => sameDay(d.day, DateTime.now()))
        .fold<int>(0, (s, d) => s + d.amount);
    final deliveries = days.fold<int>(0, (s, d) => s + d.deliveries);
    final balance = store.currentWalletEntries.isEmpty
        ? store
              .ordersFor(store.currentUser!)
              .where((o) => o.status == OrderStatus.clientConfirmed)
              .fold<int>(0, (s, o) => s + o.deliveryFee)
        : store.walletBalance;
    return PageFrame(
      title: 'Revenus',
      subtitle: 'Vos droits de livraison, jour par jour.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOLDE DISPONIBLE',
                  style: TextStyle(
                    color: Color(0xFFC9D8D1),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  dzd(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: store.walletBalance <= 0
                      ? null
                      : () async {
                          final ok = await store.requestWithdrawal();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Demande de retrait enregistrée.'
                                    : store.lastError ?? 'Retrait impossible.',
                              ),
                            ),
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: green,
                  ),
                  child: const Text('Demander un retrait'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Stats(compact: true, [
            Stat('Aujourd’hui', dzd(todayEarned), Icons.today_rounded, brown),
            Stat(
              'Droits de livraison',
              dzd(total),
              Icons.favorite_rounded,
              const Color(0xFF9B5B55),
            ),
            Stat(
              'Livraisons',
              '$deliveries',
              Icons.check_circle_rounded,
              green,
            ),
          ]),
          const SizedBox(height: 27),
          const SectionTitle('Gains par jour'),
          const SizedBox(height: 12),
          if (days.isEmpty)
            const EmptyState(
              Icons.event_note_rounded,
              'Aucun gain pour le moment',
              'Vos droits de livraison apparaîtront ici après la confirmation du client.',
            )
          else
            ...days.indexed.map(
              (indexed) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EarningDay(
                  key: ValueKey('earning-${indexed.$2.day}'),
                  store: store,
                  earning: indexed.$2,
                  initiallyExpanded: indexed.$1 == 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EarningDay extends StatelessWidget {
  const _EarningDay({
    super.key,
    required this.store,
    required this.earning,
    required this.initiallyExpanded,
  });
  final MarketplaceStore store;
  final DailyEarning earning;
  final bool initiallyExpanded;

  Widget _entryRow(WalletEntry entry) {
    final linked = store.orderForEntry(entry);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.delivery_dining_rounded, color: brown),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linked?.id ?? entry.orderId ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  [
                    timeOfDay(entry.createdAt),
                    if (linked != null) store.orderMerchant(linked),
                  ].join(' · '),
                ),
              ],
            ),
          ),
          Text(
            '+${dzd(entry.amount)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        title: Text(
          dayLabel(store, earning.day),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        subtitle: Text(
          '${earning.deliveries} ${store.tr(earning.deliveries > 1 ? 'livraisons' : 'livraison', 'توصيلات')} · ${shortDate(earning.day)}',
        ),
        trailing: Text(
          '+${dzd(earning.amount)}',
          style: const TextStyle(
            color: green,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        children: [for (final entry in earning.entries) _entryRow(entry)],
      ),
    ),
  );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.store});
  final MarketplaceStore store;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  DateTime day = dayOf(DateTime.now());

  MarketplaceStore get store => widget.store;
  bool get isToday => sameDay(day, DateTime.now());

  void _shift(int days) {
    final next = dayOf(day.add(Duration(days: days, hours: 12)));
    if (next.isAfter(dayOf(DateTime.now()))) return;
    setState(() => day = next);
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: Locale(store.language),
    );
    if (picked != null) setState(() => day = dayOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final stats = store.statsFor(day);
    final volume = store.orders
        .where((o) => o.paid)
        .fold<int>(0, (s, o) => s + o.total);
    final partners = store.users.where((u) => !u.isGuestAccount);
    return PageFrame(
      title: 'Vue administrateur',
      subtitle: 'Santé en direct de toute la plateforme.',
      action: NotificationButton(store: store),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('admin-day-previous'),
                    tooltip: store.tr('Jour précédent', 'اليوم السابق'),
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: InkWell(
                      key: const Key('admin-day-picker'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pick,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Text(
                              dayLabel(store, day),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              shortDate(day),
                              style: const TextStyle(color: muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isToday)
                    TextButton(
                      key: const Key('admin-day-today'),
                      onPressed: () =>
                          setState(() => day = dayOf(DateTime.now())),
                      child: Text(store.tr('Aujourd’hui', 'اليوم')),
                    ),
                  IconButton(
                    key: const Key('admin-day-next'),
                    tooltip: store.tr('Jour suivant', 'اليوم التالي'),
                    onPressed: isToday ? null : () => _shift(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Stats(compact: true, [
            Stat(
              'Ventes du jour',
              dzd(stats.sales),
              Icons.payments_rounded,
              green,
              key: const Key('admin-today-sales'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PartnerCreditsScreen(store: store),
                ),
              ),
            ),
            Stat(
              'Commandes du jour',
              '${stats.orderCount}',
              Icons.receipt_long_rounded,
              brown,
            ),
            Stat(
              'Nouveaux utilisateurs',
              '${stats.newUsers}',
              Icons.person_add_alt_1_rounded,
              orange,
            ),
            Stat(
              'Commission du jour',
              dzd(stats.commission),
              Icons.percent_rounded,
              const Color(0xFF9B5B55),
            ),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showAdminPricing(context, store),
            icon: const Icon(Icons.percent_rounded),
            label: Text(
              'Commission ${store.commissionPercent}% · Livraison ${dzd(store.deliveryFee)}',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => showAdminAccounts(context, store),
            icon: const Icon(Icons.manage_accounts_rounded),
            label: const Text('Comptes partenaires'),
          ),
          const SizedBox(height: 27),
          SectionTitle('Activité du jour', action: '${stats.orders.length}'),
          const SizedBox(height: 12),
          if (stats.orders.isEmpty)
            const EmptyState(
              Icons.event_busy_rounded,
              'Aucune activité ce jour',
              'Les commandes de la date choisie apparaîtront ici.',
            )
          else
            ...stats.orders
                .take(10)
                .map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OrderCard(o, store, UserRole.admin),
                  ),
                ),
          const SizedBox(height: 27),
          const SectionTitle('Cumul de la plateforme'),
          const SizedBox(height: 12),
          Stats([
            Stat(
              'Volume brut',
              dzd(volume),
              Icons.account_balance_rounded,
              green,
            ),
            Stat(
              'Commandes',
              '${store.orders.length}',
              Icons.receipt_long_rounded,
              brown,
            ),
            Stat(
              'Utilisateurs',
              '${partners.where((u) => u.active).length}',
              Icons.group_rounded,
              orange,
            ),
            Stat(
              'Articles',
              '${store.products.length}',
              Icons.inventory_2_rounded,
              const Color(0xFF9B5B55),
            ),
          ]),
          const SizedBox(height: 27),
          const SectionTitle('Acteurs de la plateforme'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: UserRole.values
                    .where((r) => r != UserRole.admin)
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFF0E8DF),
                              foregroundColor: brown,
                              child: Icon(roleIcon(r), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                r.plural,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${store.users.where((u) => u.role == r).length}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<int?> showPartnerPaymentDialog(
  BuildContext context,
  MarketplaceStore store,
  AppUser partner,
  int balance,
) => showDialog<int>(
  context: context,
  builder: (_) =>
      _PartnerPaymentDialog(store: store, partner: partner, balance: balance),
);

class _PartnerPaymentDialog extends StatefulWidget {
  const _PartnerPaymentDialog({
    required this.store,
    required this.partner,
    required this.balance,
  });
  final MarketplaceStore store;
  final AppUser partner;
  final int balance;

  @override
  State<_PartnerPaymentDialog> createState() => _PartnerPaymentDialogState();
}

class _PartnerPaymentDialogState extends State<_PartnerPaymentDialog> {
  late final TextEditingController amount = TextEditingController(
    text: '${widget.balance}',
  );

  int? get parsed => int.tryParse(amount.text.trim());
  bool get valid => parsed != null && parsed! > 0 && parsed! <= widget.balance;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final remaining = valid ? widget.balance - parsed! : widget.balance;
    return AlertDialog(
      title: Text(store.tr('Payer un partenaire', 'دفع مستحقات شريك')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partner.businessName ?? widget.partner.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              store.tr(
                'Crédit actuel : ${dzd(widget.balance)}',
                'الرصيد الحالي: ${dzd(widget.balance)}',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('partner-payment-amount'),
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: store.tr('Montant payé', 'المبلغ المدفوع'),
                suffixText: 'DA',
                errorText: amount.text.isNotEmpty && !valid
                    ? store.tr(
                        'Entrez un montant de 1 à ${widget.balance} DA.',
                        'أدخل مبلغاً من 1 إلى ${widget.balance} دج.',
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              store.tr(
                'Crédit restant après paiement : ${dzd(remaining)}',
                'الرصيد المتبقي بعد الدفع: ${dzd(remaining)}',
              ),
              key: const Key('partner-payment-remaining'),
              style: const TextStyle(color: green, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(store.tr('Annuler', 'إلغاء')),
        ),
        FilledButton.icon(
          key: const Key('partner-payment-confirm'),
          onPressed: valid ? () => Navigator.pop(context, parsed) : null,
          icon: const Icon(Icons.price_check_rounded),
          label: Text(store.tr('Enregistrer', 'تسجيل')),
        ),
      ],
    );
  }
}

class PartnerCreditsScreen extends StatefulWidget {
  const PartnerCreditsScreen({super.key, required this.store});
  final MarketplaceStore store;

  @override
  State<PartnerCreditsScreen> createState() => _PartnerCreditsScreenState();
}

class _PartnerCreditsScreenState extends State<PartnerCreditsScreen> {
  String? _payingUserId;

  Future<void> _pay(AppUser partner, int balance) async {
    final amount = await showPartnerPaymentDialog(
      context,
      widget.store,
      partner,
      balance,
    );
    if (amount == null || !mounted) return;
    setState(() => _payingUserId = partner.id);
    final ok = await widget.store.settleAccount(partner, amount: amount);
    if (!mounted) return;
    setState(() => _payingUserId = null);
    final remaining = widget.store.walletBalanceFor(partner.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? widget.store.tr(
                  'Paiement de ${dzd(amount)} enregistré. Crédit restant : ${dzd(remaining)}.',
                  'تم تسجيل دفع ${dzd(amount)}. الرصيد المتبقي: ${dzd(remaining)}.',
                )
              : widget.store.lastError ??
                    widget.store.tr(
                      'Action impossible.',
                      'تعذر تنفيذ العملية.',
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final partners =
          store.users
              .where(
                (user) => [
                  UserRole.courier,
                  UserRole.restaurant,
                  UserRole.supermarket,
                ].contains(user.role),
              )
              .toList()
            ..sort(
              (a, b) => store
                  .walletBalanceFor(b.id)
                  .compareTo(store.walletBalanceFor(a.id)),
            );
      final totalCredit = partners.fold<int>(0, (sum, partner) {
        final balance = store.walletBalanceFor(partner.id);
        return sum + (balance > 0 ? balance : 0);
      });
      return Scaffold(
        backgroundColor: cream,
        appBar: AppBar(
          title: Text(store.tr('Crédits partenaires', 'أرصدة الشركاء')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
          children: [
            Card(
              color: green,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.tr(
                        'Total restant à payer',
                        'إجمالي المبلغ المتبقي',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dzd(totalCredit),
                      key: const Key('partner-credits-total'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.tr(
                        'Choisissez un partenaire, saisissez le montant payé et le solde restant sera calculé automatiquement.',
                        'اختر شريكاً وأدخل المبلغ المدفوع وسيُحسب الرصيد المتبقي تلقائياً.',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (partners.isEmpty)
              EmptyState(
                Icons.account_balance_wallet_outlined,
                store.tr('Aucun partenaire', 'لا يوجد شركاء'),
                store.tr(
                  'Les comptes partenaires apparaîtront ici.',
                  'ستظهر حسابات الشركاء هنا.',
                ),
              )
            else
              ...partners.map((partner) {
                final balance = store.walletBalanceFor(partner.id);
                final paying = _payingUserId == partner.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Avatar(partner.name, imageUrl: partner.avatarUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  partner.businessName ?? partner.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  partner.role.label,
                                  style: const TextStyle(color: muted),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  store.tr(
                                    'Crédit : ${dzd(balance)}',
                                    'الرصيد: ${dzd(balance)}',
                                  ),
                                  style: TextStyle(
                                    color: balance > 0 ? green : muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (balance > 0)
                            FilledButton(
                              key: Key('pay-partner-${partner.id}'),
                              onPressed: paying
                                  ? null
                                  : () => _pay(partner, balance),
                              child: paying
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(store.tr('Payer', 'دفع')),
                            )
                          else
                            Tag(store.tr('Réglé', 'مدفوع'), muted),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    },
  );
}

class UsersView extends StatelessWidget {
  const UsersView({super.key, required this.store});
  final MarketplaceStore store;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Comptes',
    subtitle: 'Créez les comptes partenaires et contrôlez leurs accès.',
    child: Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showAdminAccounts(context, store),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Ouvrir un compte partenaire'),
          ),
        ),
        const SizedBox(height: 14),
        ...store.users
            .where((u) => !u.isGuestAccount)
            .map(
              (u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AccountDetailScreen(store: store, userId: u.id),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Avatar(u.name, imageUrl: u.avatarUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.businessName ?? u.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text('${u.email} · ${u.role.label}'),
                              ],
                            ),
                          ),
                          if (u.role == UserRole.admin)
                            const Tag('Protégé', brown)
                          else
                            Switch(
                              value: u.active,
                              activeThumbColor: green,
                              onChanged: (_) async {
                                final ok = await store.toggleUser(u);
                                if (!context.mounted || ok) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      store.lastError ?? 'Action impossible.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: muted.withValues(alpha: .8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    ),
  );
}

class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({
    super.key,
    required this.store,
    required this.userId,
  });
  final MarketplaceStore store;
  final String userId;
  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  bool _printing = false, _settling = false;

  AppUser? get user {
    for (final u in widget.store.users) {
      if (u.id == widget.userId) return u;
    }
    return null;
  }

  Future<void> _toggle(AppUser u) async {
    final ok = await widget.store.toggleUser(u);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.store.lastError ?? 'Action impossible.')),
    );
  }

  Future<void> _print(AppUser u) async {
    setState(() => _printing = true);
    try {
      await printAccountReport(widget.store, u);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.tr(
              'Le rapport n’a pas pu être imprimé.',
              'تعذر طباعة التقرير.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _settle(AppUser u, int balance) async {
    final amount = await showPartnerPaymentDialog(
      context,
      widget.store,
      u,
      balance,
    );
    if (amount == null || !mounted) return;
    setState(() => _settling = true);
    final ok = await widget.store.settleAccount(u, amount: amount);
    if (!mounted) return;
    setState(() => _settling = false);
    final remaining = widget.store.walletBalanceFor(u.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? widget.store.tr(
                  'Paiement de ${dzd(amount)} enregistré. Crédit restant : ${dzd(remaining)}.',
                  'تم تسجيل دفع ${dzd(amount)}. الرصيد المتبقي: ${dzd(remaining)}.',
                )
              : widget.store.lastError ??
                    widget.store.tr(
                      'Action impossible.',
                      'تعذر تنفيذ العملية.',
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final u = user;
        if (u == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Compte')),
            body: const Center(child: Text('Compte introuvable.')),
          );
        }
        final ledger = AccountLedger(store, u);
        final recent = ledger.orders.take(8).toList();
        return Scaffold(
          backgroundColor: cream,
          appBar: AppBar(
            title: Text(u.businessName ?? u.name),
            actions: [
              IconButton(
                tooltip: store.tr('Imprimer le rapport', 'طباعة التقرير'),
                onPressed: _printing ? null : () => _print(u),
                icon: const Icon(Icons.print_outlined),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Avatar(u.name, imageUrl: u.avatarUrl),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.businessName ?? u.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 2),
                              Text('${u.email} · ${u.role.label}'),
                              if (u.phone.isNotEmpty) Text(u.phone),
                              if (u.address.isNotEmpty)
                                Text(
                                  u.address,
                                  style: const TextStyle(color: muted),
                                ),
                            ],
                          ),
                        ),
                        Tag(
                          u.active
                              ? store.tr('Actif', 'نشط')
                              : store.tr('Inactif', 'غير نشط'),
                          u.active ? green : brown,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  store.tr('Gérer le compte', 'إدارة الحساب'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(store.tr('Compte actif', 'الحساب نشط')),
                          subtitle: Text(
                            u.role == UserRole.admin
                                ? store.tr(
                                    'Le compte administrateur est protégé.',
                                    'حساب المدير محمي.',
                                  )
                                : store.tr(
                                    'Désactivez l’accès de ce compte à Wasla.',
                                    'أوقف وصول هذا الحساب إلى وصلة.',
                                  ),
                          ),
                          value: u.active,
                          activeThumbColor: green,
                          onChanged: u.role == UserRole.admin
                              ? null
                              : (_) => _toggle(u),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.badge_outlined),
                          title: Text(store.tr('Identifiant', 'المعرف')),
                          subtitle: Text(u.id),
                        ),
                        if (u.businessName != null &&
                            u.businessName!.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.storefront_outlined),
                            title: Text(store.tr('Établissement', 'المؤسسة')),
                            subtitle: Text(u.businessName!),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _printing ? null : () => _print(u),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(
                      store.tr(
                        'Imprimer le rapport complet',
                        'طباعة التقرير الكامل',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  store.tr('Statistiques', 'الإحصائيات'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Stats([
                  Stat(
                    store.tr('Commandes', 'الطلبات'),
                    '${ledger.orderCount}',
                    Icons.receipt_long_outlined,
                    brown,
                  ),
                  Stat(
                    store.tr('En cours', 'قيد التنفيذ'),
                    '${ledger.inProgressCount}',
                    Icons.timelapse_rounded,
                    orange,
                  ),
                  Stat(
                    store.tr('Livrées', 'تم التسليم'),
                    '${ledger.deliveredCount}',
                    Icons.check_circle_outline_rounded,
                    green,
                  ),
                  Stat(
                    store.tr('Annulées', 'ملغاة'),
                    '${ledger.cancelledCount}',
                    Icons.cancel_outlined,
                    const Color(0xFFB42318),
                  ),
                  Stat(
                    store.tr('Total', 'المجموع'),
                    dzd(ledger.orderTotal),
                    Icons.payments_outlined,
                    brown,
                  ),
                  Stat(
                    store.tr('Solde', 'الرصيد'),
                    dzd(ledger.walletBalance),
                    Icons.account_balance_wallet_outlined,
                    green,
                  ),
                  if (u.role == UserRole.restaurant ||
                      u.role == UserRole.supermarket)
                    Stat(
                      store.tr('Produits', 'المنتجات'),
                      '${ledger.catalog.length}',
                      Icons.inventory_2_outlined,
                      orange,
                    ),
                ]),
                if ([
                      UserRole.courier,
                      UserRole.restaurant,
                      UserRole.supermarket,
                    ].contains(u.role) &&
                    ledger.walletBalance > 0) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('admin-settle-balance'),
                      onPressed: _settling
                          ? null
                          : () => _settle(u, ledger.walletBalance),
                      icon: _settling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.price_check_rounded),
                      label: Text(
                        store.tr(
                          'Enregistrer un paiement · ${dzd(ledger.walletBalance)} dû',
                          'تسجيل دفعة · المستحق ${dzd(ledger.walletBalance)}',
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  store.tr('Commandes récentes', 'الطلبات الأخيرة'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  Text(
                    store.tr(
                      'Aucune commande pour ce compte.',
                      'لا توجد طلبات لهذا الحساب.',
                    ),
                    style: const TextStyle(color: muted),
                  ),
                ...recent.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text('${o.id} · ${dzd(o.total)}'),
                        subtitle: Text(
                          '${reportDate(o.createdAt)} · ${o.status.label}',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _generatePassword() {
  const alphabet = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(
    10,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

Future<void> showAdminAccounts(BuildContext context, MarketplaceStore store) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: .94,
        child: _AdminAccountsSheet(store: store),
      ),
    );

class _AdminAccountsSheet extends StatefulWidget {
  const _AdminAccountsSheet({required this.store});
  final MarketplaceStore store;

  @override
  State<_AdminAccountsSheet> createState() => _AdminAccountsSheetState();
}

class _AdminAccountsSheetState extends State<_AdminAccountsSheet> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final business = TextEditingController();
  final phone = TextEditingController();
  UserRole role = UserRole.courier;
  bool creating = false, showPassword = false;
  String? error, success;

  MarketplaceStore get store => widget.store;

  @override
  void dispose() {
    for (final controller in [name, email, password, business, phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      creating = true;
      error = success = null;
    });
    final created = email.text.trim();
    final ok = await store.createManagedAccount(
      name: name.text,
      email: email.text,
      password: password.text,
      role: role,
      businessName: business.text,
      phone: phone.text,
    );
    if (!mounted) return;
    setState(() {
      creating = false;
      if (ok) {
        success = store.tr(
          'Compte créé : $created. Communiquez-lui son mot de passe provisoire.',
          'تم إنشاء الحساب: $created. سلّمه كلمة المرور المؤقتة.',
        );
        for (final c in [name, email, password, business, phone]) {
          c.clear();
        }
      } else {
        error =
            store.lastError ??
            store.tr('Création impossible.', 'تعذر الإنشاء.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final merchant =
        role == UserRole.restaurant || role == UserRole.supermarket;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => ListView(
        padding: EdgeInsets.fromLTRB(
          22,
          16,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8D0C7),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Comptes partenaires',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 5),
          Text(
            store.tr(
              'Ouvrez ici les comptes livreur, restaurant et supérette. Les cuisines peuvent aussi s’inscrire seules.',
              'افتح هنا حسابات الموصل والمطعم والبقالة. يمكن للمطابخ أيضاً التسجيل بنفسها.',
            ),
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 17),
          DropdownButtonFormField<UserRole>(
            key: const Key('account-type'),
            initialValue: role,
            decoration: InputDecoration(
              labelText: store.tr('Type de compte', 'نوع الحساب'),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            items: [
              DropdownMenuItem(
                value: UserRole.courier,
                child: Text(store.tr('Livreur', 'موصل')),
              ),
              DropdownMenuItem(
                value: UserRole.restaurant,
                child: Text(store.tr('Restaurant', 'مطعم')),
              ),
              DropdownMenuItem(
                value: UserRole.supermarket,
                child: Text(store.tr('Supérette', 'بقالة')),
              ),
            ],
            onChanged: (value) => setState(() => role = value!),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('account-name'),
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: store.tr('Nom complet', 'الاسم الكامل'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          if (merchant) ...[
            const SizedBox(height: 10),
            TextField(
              key: const Key('account-business'),
              controller: business,
              decoration: InputDecoration(
                labelText: store.tr('Nom de l’établissement', 'اسم المؤسسة'),
                prefixIcon: const Icon(Icons.storefront_outlined),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            key: const Key('account-email'),
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: store.tr('Adresse e-mail', 'البريد الإلكتروني'),
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('account-password'),
            controller: password,
            obscureText: !showPassword,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: store.tr(
                'Mot de passe provisoire (8 caractères min.)',
                'كلمة مرور مؤقتة (8 أحرف على الأقل)',
              ),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: store.tr('Générer', 'توليد'),
                    onPressed: () => setState(() {
                      password.text = _generatePassword();
                      showPassword = true;
                    }),
                    icon: const Icon(Icons.auto_fix_high_rounded),
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('account-phone'),
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: store.tr('Téléphone', 'الهاتف'),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            FormMessage(error!),
          ],
          if (success != null) ...[
            const SizedBox(height: 12),
            FormMessage(success!, error: false),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('account-create'),
              onPressed: creating ? null : _create,
              icon: creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: Text(store.tr('Créer le compte', 'إنشاء الحساب')),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            store.tr('Contrôle des comptes', 'التحكم في الحسابات'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          ...store.users
              .where(
                (user) => user.role != UserRole.admin && !user.isGuestAccount,
              )
              .map(
                (user) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(user.name, imageUrl: user.avatarUrl),
                  title: Text(user.businessName ?? user.name),
                  subtitle: Text('${user.role.label} · ${user.email}'),
                  trailing: Switch(
                    value: user.active,
                    activeThumbColor: green,
                    onChanged: (_) => store.toggleUser(user),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class GlobalCatalog extends StatelessWidget {
  const GlobalCatalog({super.key, required this.store});
  final MarketplaceStore store;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Gestion du catalogue',
    subtitle: 'Catégories dynamiques, médias, prix et disponibilité.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryManagementPanel(store: store),
        if (store.products.any((p) => p.approvalStatus == 'pending')) ...[
          const SizedBox(height: 22),
          Text(
            '${store.products.where((p) => p.approvalStatus == 'pending').length} produit(s) en attente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
        const SizedBox(height: 28),
        Text(
          'Tous les produits',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...store.products.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: ProductMedia(p, borderRadius: 15),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (p.approvalStatus != 'approved')
                            Text(
                              p.approvalStatus == 'pending'
                                  ? 'À valider'
                                  : 'Refusé',
                              style: const TextStyle(
                                color: brown,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Text(
                            '${store.merchantName(p)} · ${p.kind == ProductKind.meal ? 'Repas' : 'Courses'}',
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 112),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (p.approvalStatus == 'approved')
                            Text(
                              '${dzd(p.retailPrice)} client',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          Text(
                            store.tr(
                              '${dzd(p.wholesalePrice)} partenaire',
                              '${dzd(p.wholesalePrice)} للشريك',
                            ),
                          ),
                          if (p.approvalStatus == 'pending')
                            TextButton(
                              onPressed: () =>
                                  showProductReview(context, store, p),
                              child: const Text(
                                'Valider / refuser',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (p.kind == ProductKind.grocery &&
                              p.approvalStatus == 'approved')
                            TextButton(
                              onPressed: () =>
                                  showProductReview(context, store, p),
                              child: Text(
                                store.tr('Modifier le prix', 'تعديل السعر'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> showAdminPricing(BuildContext context, MarketplaceStore store) =>
    showDialog<void>(
      context: context,
      builder: (_) => _PricingDialog(store: store),
    );

class _PricingDialog extends StatefulWidget {
  const _PricingDialog({required this.store});
  final MarketplaceStore store;

  @override
  State<_PricingDialog> createState() => _PricingDialogState();
}

class _PricingDialogState extends State<_PricingDialog> {
  late final percent = TextEditingController(
    text: '${widget.store.commissionPercent}',
  );
  late final fee = TextEditingController(text: '${widget.store.deliveryFee}');
  bool saving = false;
  String? error;

  MarketplaceStore get store => widget.store;

  @override
  void dispose() {
    percent.dispose();
    fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = int.tryParse(percent.text.trim());
    final f = int.tryParse(fee.text.trim());
    if (p == null || f == null || p < 0 || p > 100 || f < 0) {
      setState(
        () => error = store.tr(
          'Valeurs invalides : commission de 0 à 100 % et frais de livraison positifs.',
          'قيم غير صالحة: عمولة من 0 إلى 100٪ ورسوم توصيل موجبة.',
        ),
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final ok = await store.updateSettings(p, f);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        saving = false;
        error =
            store.lastError ??
            store.tr('Enregistrement impossible.', 'تعذر الحفظ.');
      });
      return;
    }
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          store.tr(
            'Tarifs appliqués : commission $p % · livraison ${dzd(f)}. Les nouvelles commandes les utilisent déjà.',
            'تم تطبيق التعريفة: عمولة $p٪ · توصيل ${dzd(f)}. الطلبات الجديدة تستخدمها الآن.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = int.tryParse(percent.text.trim());
    final f = int.tryParse(fee.text.trim());
    final example = p == null || f == null || p < 0 || p > 100 || f < 0
        ? null
        : store.tr(
            'Exemple : prix restaurant 1 000 DA + commission ${dzd(commissionForMerchantPrice(1000, p))} = ${dzd(customerPriceFor(1000, p))} pour le plat ; avec livraison, le client paie ${dzd(customerPriceFor(1000, p) + f)}.',
            'مثال: سعر المطعم 1000 دج + عمولة ${dzd(commissionForMerchantPrice(1000, p))} = ${dzd(customerPriceFor(1000, p))} للطبق؛ ومع التوصيل يدفع الزبون ${dzd(customerPriceFor(1000, p) + f)}.',
          );
    return AlertDialog(
      title: const Text('Tarifs de la plateforme'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('pricing-percent'),
              controller: percent,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => error = null),
              decoration: InputDecoration(
                labelText: store.tr(
                  'Commission sur le prix des plats (%)',
                  'عمولة سعر الطبق (%)',
                ),
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pricing-fee'),
              controller: fee,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => error = null),
              decoration: InputDecoration(
                labelText: store.tr(
                  'Frais de livraison (DA)',
                  'رسوم التوصيل (دج)',
                ),
                suffixText: store.tr('DA', 'دج'),
              ),
            ),
            if (example != null) ...[
              const SizedBox(height: 12),
              Text(
                example,
                style: const TextStyle(color: muted, fontSize: 12.5),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              FormMessage(error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('pricing-save'),
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}

Future<void> showProductReview(
  BuildContext context,
  MarketplaceStore store,
  Product product,
) => showDialog<void>(
  context: context,
  builder: (_) => _ProductReviewDialog(store: store, product: product),
);

class _ProductReviewDialog extends StatefulWidget {
  const _ProductReviewDialog({required this.store, required this.product});
  final MarketplaceStore store;
  final Product product;

  @override
  State<_ProductReviewDialog> createState() => _ProductReviewDialogState();
}

class _ProductReviewDialogState extends State<_ProductReviewDialog> {
  String? error;
  bool busy = false;
  late final TextEditingController clientPrice = TextEditingController(
    text:
        widget.product.kind == ProductKind.grocery &&
            widget.product.retailPrice >= widget.product.wholesalePrice
        ? '${widget.product.retailPrice}'
        : '',
  );

  MarketplaceStore get store => widget.store;

  @override
  void dispose() {
    clientPrice.dispose();
    super.dispose();
  }

  Future<void> _decide({required bool approve}) async {
    final retail = int.tryParse(clientPrice.text.trim());
    if (approve &&
        widget.product.kind == ProductKind.grocery &&
        (retail == null || retail < widget.product.wholesalePrice)) {
      setState(
        () => error = store.tr(
          'Saisissez un prix client égal ou supérieur au prix de la supérette.',
          'أدخل سعر زبون مساوياً أو أكبر من سعر البقالة.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final ok = await store.reviewProduct(
      widget.product,
      approve: approve,
      retailPrice: retail,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        busy = false;
        error =
            store.lastError ??
            store.tr('Action impossible.', 'الإجراء غير ممكن.');
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product.name),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            store.tr(
              'Prix du partenaire : ${dzd(widget.product.wholesalePrice)}',
              'سعر الشريك: ${dzd(widget.product.wholesalePrice)}',
            ),
          ),
          const SizedBox(height: 12),
          if (widget.product.kind == ProductKind.meal)
            FormMessage(
              store.tr(
                'Commission ${store.commissionPercent} % : ${dzd(commissionForMerchantPrice(widget.product.wholesalePrice, store.commissionPercent))} · Prix client : ${dzd(customerPriceFor(widget.product.wholesalePrice, store.commissionPercent))}',
                'العمولة ${store.commissionPercent}٪: ${dzd(commissionForMerchantPrice(widget.product.wholesalePrice, store.commissionPercent))} · سعر الزبون: ${dzd(customerPriceFor(widget.product.wholesalePrice, store.commissionPercent))}',
              ),
              error: false,
            )
          else
            TextField(
              key: const Key('grocery-retail-price'),
              controller: clientPrice,
              enabled: !busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => error = null),
              decoration: InputDecoration(
                labelText: store.tr(
                  'Prix de vente au client (DA)',
                  'سعر البيع للزبون (دج)',
                ),
                helperText: store.tr(
                  'Aucun pourcentage : vous fixez directement le prix client.',
                  'بدون نسبة: حدد سعر الزبون مباشرة.',
                ),
              ),
            ),
          if (error != null) ...[
            const SizedBox(height: 12),
            FormMessage(error!),
          ],
        ],
      ),
    ),
    actions: [
      if (widget.product.approvalStatus != 'approved')
        TextButton(
          onPressed: busy ? null : () => _decide(approve: false),
          child: const Text('Refuser'),
        ),
      FilledButton(
        onPressed: busy ? null : () => _decide(approve: true),
        child: Text(
          widget.product.approvalStatus == 'approved'
              ? store.tr('Enregistrer', 'حفظ')
              : store.tr('Approuver', 'موافقة'),
        ),
      ),
    ],
  );
}

class Profile extends StatelessWidget {
  const Profile({super.key, required this.store});
  final MarketplaceStore store;
  @override
  Widget build(BuildContext context) {
    final u = store.currentUser!;
    return PageFrame(
      title: store.tr('Profil', 'الملف الشخصي'),
      subtitle: store.tr(
        'Compte, préférences et assistance.',
        'الحساب والتفضيلات والمساعدة.',
      ),
      action: NotificationButton(store: store),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(21),
              child: Row(
                children: [
                  Avatar(u.name, large: true, imageUrl: u.avatarUrl),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.businessName ?? u.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (!store.isGuest) Text(u.email),
                        const SizedBox(height: 7),
                        Tag(u.role.label, green),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Card(
            child: Column(
              children: [
                if (store.isGuest)
                  Setting(
                    Icons.login_rounded,
                    store.tr(
                      'Connexion / inscription partenaire',
                      'دخول أو تسجيل شريك',
                    ),
                    store.openAuth,
                  ),
                Setting(
                  Icons.language_rounded,
                  store.tr(
                    'Langue : ${store.language == 'ar' ? 'العربية' : 'Français'}',
                    'اللغة: ${store.language == 'ar' ? 'العربية' : 'Français'}',
                  ),
                  () => store.setLanguage(store.language == 'ar' ? 'fr' : 'ar'),
                ),
                Setting(
                  Icons.assessment_outlined,
                  store.tr('Rapports et PDF', 'التقارير و PDF'),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportsScreen(store: store),
                    ),
                  ),
                ),
                if (!store.isGuest) ...[
                  Setting(
                    Icons.person_outline_rounded,
                    store.tr('Informations personnelles', 'المعلومات الشخصية'),
                    () => showProfileEditor(context, store),
                  ),
                ],
                Setting(
                  Icons.notifications_none_rounded,
                  '${store.tr('Notifications', 'الإشعارات')} (${store.unreadNotifications})',
                  () => showNotifications(context, store),
                ),
                Setting(
                  Icons.location_on_outlined,
                  store.tr('Adresses', 'العناوين'),
                  () => addressesSheet(context, store),
                ),
                Setting(
                  Icons.credit_card_rounded,
                  store.tr('Paiements', 'المدفوعات'),
                  () => paymentsSheet(context, store),
                ),
                Setting(
                  Icons.help_outline_rounded,
                  store.tr('Aide et support', 'المساعدة والدعم'),
                  () => supportSheet(context, store),
                ),
                Setting(
                  Icons.privacy_tip_outlined,
                  store.tr('Politique de confidentialité', 'سياسة الخصوصية'),
                  () => openLegalPage(context, store, LegalPageKind.privacy),
                ),
                Setting(
                  Icons.gavel_outlined,
                  store.tr('Conditions d’utilisation', 'شروط الخدمة'),
                  () => openLegalPage(context, store, LegalPageKind.terms),
                ),
                Setting(
                  Icons.replay_outlined,
                  store.tr('Politique de remboursement', 'سياسة الاسترجاع'),
                  () => openLegalPage(context, store, LegalPageKind.refund),
                ),
                if (!store.isGuest)
                  Setting(
                    Icons.logout_rounded,
                    store.tr('Se déconnecter', 'تسجيل الخروج'),
                    store.logout,
                    danger: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Setting extends StatelessWidget {
  const Setting(
    this.icon,
    this.title,
    this.tap, {
    super.key,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback tap;
  final bool danger;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: tap,
    leading: Icon(icon, color: danger ? Colors.red : brown),
    title: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: danger ? Colors.red : ink,
      ),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, color: muted),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, this.color, {super.key});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
    ),
  );
}

void detailSheet(BuildContext context, String title, Widget child) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 13, 22, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D0C7),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              child,
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void notificationsSheet(BuildContext context, MarketplaceStore store) {
  final orders = store.ordersFor(store.currentUser!).take(5).toList();
  detailSheet(
    context,
    'Notifications',
    orders.isEmpty
        ? const Text('Aucune nouvelle notification.')
        : Column(
            children: orders
                .map(
                  (order) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE7EEE8),
                      foregroundColor: green,
                      child: Icon(Icons.receipt_long_rounded),
                    ),
                    title: Text('${order.id} · ${order.status.label}'),
                    subtitle: Text(store.orderMerchant(order)),
                  ),
                )
                .toList(),
          ),
  );
}

void informationSheet(BuildContext context, AppUser user) {
  detailSheet(
    context,
    'Informations personnelles',
    Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline_rounded, color: brown),
          title: const Text('Nom'),
          subtitle: Text(user.name),
        ),
        if (user.businessName != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront_outlined, color: brown),
            title: const Text('Commerce'),
            subtitle: Text(user.businessName!),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mail_outline_rounded, color: brown),
          title: const Text('E-mail'),
          subtitle: Text(user.email),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined, color: brown),
          title: const Text('Type de compte'),
          subtitle: Text(user.role.label),
        ),
      ],
    ),
  );
}

Future<void> addressesSheet(
  BuildContext context,
  MarketplaceStore store,
) async {
  final saved = store.currentUser?.address ?? '';
  final controller = TextEditingController(text: saved);
  final recent = store
      .ordersFor(store.currentUser!)
      .map((order) => order.address.trim())
      .where((address) => address.isNotEmpty && address != saved)
      .toSet()
      .take(3)
      .toList();
  ModalRoute<String>? sheetRoute;
  final chosen = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      sheetRoute = ModalRoute.of<String>(sheetContext);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          13,
          22,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D0C7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Adresse de livraison',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Indiquez où vous souhaitez recevoir vos commandes.',
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('delivery-address-field'),
                  controller: controller,
                  autofocus: saved.isEmpty,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: store.tr(
                      'Rue, quartier et ville',
                      'الشارع والحي والمدينة',
                    ),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Adresses utilisées récemment'),
                  for (final address in recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded, color: brown),
                      title: Text(address),
                      onTap: () => controller.text = address,
                    ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        Navigator.pop(sheetContext, controller.text.trim());
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Enregistrer cette adresse'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (chosen != null) {
    final savedSuccessfully = await store.saveDeliveryAddress(chosen);
    if (context.mounted && !savedSuccessfully) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.lastError ?? 'Adresse non enregistrée.')),
      );
    }
  }
  await sheetRoute?.completed;
  controller.dispose();
}

void paymentsSheet(BuildContext context, MarketplaceStore store) {
  final user = store.currentUser!;
  final paidOrders = store
      .ordersFor(user)
      .where((order) => order.paid)
      .toList();
  final clientTotal = paidOrders.fold<int>(
    0,
    (sum, order) => sum + order.total,
  );
  detailSheet(
    context,
    'Paiements',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stats([
          Stat(
            user.role == UserRole.client ? 'Total payé' : 'Solde disponible',
            dzd(
              user.role == UserRole.client ? clientTotal : store.walletBalance,
            ),
            Icons.account_balance_wallet_rounded,
            green,
          ),
          Stat(
            user.role == UserRole.client ? 'Paiements' : 'Mouvements',
            '${user.role == UserRole.client ? paidOrders.length : store.currentWalletEntries.length}',
            Icons.receipt_long_rounded,
            brown,
          ),
        ]),
        if (user.role == UserRole.client)
          ...paidOrders
              .take(5)
              .map(
                (order) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(order.id),
                  subtitle: Text(order.paymentMethod),
                  trailing: Text(
                    dzd(order.total),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
        else
          ...store.currentWalletEntries
              .take(5)
              .map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.type.replaceAll('_', ' ')),
                  subtitle: Text(entry.orderId ?? 'Retrait'),
                  trailing: Text(
                    '${entry.amount >= 0 ? '+' : ''}${dzd(entry.amount)}',
                    style: TextStyle(
                      color: entry.amount >= 0 ? green : Colors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ],
    ),
  );
}

void supportSheet(BuildContext context, MarketplaceStore store) {
  detailSheet(
    context,
    store.tr('Aide et support', 'المساعدة والدعم'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          store.tr(
            'Une question sur une commande ou un paiement ?',
            'لديك سؤال عن طلب أو دفع؟',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 12),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.mail_outline_rounded, color: brown),
          title: Text('support@wasla.dz'),
          subtitle: Text('Réponse sous 24 heures'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined, color: brown),
          title: Text(
            store.tr('Politique de confidentialité', 'سياسة الخصوصية'),
          ),
          onTap: () {
            Navigator.pop(context);
            openLegalPage(context, store, LegalPageKind.privacy);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gavel_outlined, color: brown),
          title: Text(store.tr('Conditions d’utilisation', 'شروط الخدمة')),
          onTap: () {
            Navigator.pop(context);
            openLegalPage(context, store, LegalPageKind.terms);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.replay_outlined, color: brown),
          title: Text(
            store.tr('Politique de remboursement', 'سياسة الاسترجاع'),
          ),
          onTap: () {
            Navigator.pop(context);
            openLegalPage(context, store, LegalPageKind.refund);
          },
        ),
      ],
    ),
  );
}

IconData roleIcon(UserRole r) => switch (r) {
  UserRole.client => Icons.person_rounded,
  UserRole.courier => Icons.delivery_dining_rounded,
  UserRole.restaurant => Icons.restaurant_rounded,
  UserRole.supermarket => Icons.local_grocery_store_rounded,
  UserRole.admin => Icons.admin_panel_settings_rounded,
};
