import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/cloudflare_backend.dart';
import 'domain.dart';

/// Numbers shown on the administrator dashboard for a single day.
class DayStats {
  const DayStats({
    required this.day,
    required this.sales,
    required this.orderCount,
    required this.deliveredCount,
    required this.newUsers,
    required this.commission,
    required this.orders,
  });
  final DateTime day;
  final int sales, orderCount, deliveredCount, newUsers, commission;
  final List<MarketOrder> orders;
}

/// Delivery fees earned by a courier on a single day.
class DailyEarning {
  const DailyEarning({
    required this.day,
    required this.amount,
    required this.entries,
  });
  final DateTime day;
  final int amount;
  final List<WalletEntry> entries;
  int get deliveries => entries.length;
}

DateTime dayOf(DateTime value) => DateTime(value.year, value.month, value.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The restaurant chooses the amount it must receive. Wasla's commission is
/// added on top of that amount to obtain the price shown to the customer.
int commissionForMerchantPrice(int merchantPrice, int percent) =>
    (merchantPrice * percent / 100).round();

int customerPriceFor(int merchantPrice, int percent) =>
    merchantPrice + commissionForMerchantPrice(merchantPrice, percent);

class MarketplaceStore extends ChangeNotifier {
  MarketplaceStore() {
    // Demo data only exists for the offline build; with a backend the real
    // catalogue, orders and accounts come from the server.
    if (!CloudflareBackend.configured) _seed();
    currentUser = _guestUser;
  }
  static const _tokenKey = 'session_token';
  static const _userKey = 'session_user';
  static const _addressPlaceholder = 'À confirmer par téléphone';

  AppUser? currentUser;
  bool guestPersistence = false;

  /// True while a saved session is being restored at startup.
  bool initializing = false;

  /// Set when the last background refresh could not reach the server.
  String? refreshError;
  bool connecting = false;
  Future<void> enableGuestPersistence() => bootstrap();

  /// Restores a saved sign-in, or falls back to the guest customer space.
  Future<void> bootstrap() async {
    guestPersistence = true;
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') == 'ar' ? 'ar' : 'fr';
    if (await _restoreSession(prefs)) return;
    await initializeGuest();
  }

  bool showAuth = false;
  int commissionPercent = 10;
  int deliveryFee = 200;
  String language = 'fr';
  String pendingOrderNote = '';
  String tr(String french, String arabic) => language == 'ar' ? arabic : french;
  Future<void> setLanguage(String value) async {
    if (value != 'fr' && value != 'ar') return;
    language = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
    notifyListeners();
  }

  AppUser get _guestUser => AppUser(
    id: 'guest-local',
    name: 'Invité',
    email: '',
    password: '',
    role: UserRole.client,
  );
  bool get isGuest =>
      currentUser?.id == 'guest-local' ||
      (currentUser?.email.startsWith('guest-') ?? false);
  void openAuth() {
    showAuth = true;
    notifyListeners();
  }

  void closeAuth() {
    showAuth = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------

  Future<void> _saveSession() async {
    final user = currentUser;
    final token = CloudflareBackend.token;
    if (!CloudflareBackend.configured ||
        !guestPersistence ||
        user == null ||
        user.id == 'guest-local' ||
        token == null) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(
        _userKey,
        jsonEncode({
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'role': user.role.name,
          'business_name': user.businessName,
          'phone': user.phone,
          'address': user.address,
          'avatar_url': user.avatarUrl,
        }),
      );
    } catch (_) {
      // A storage problem must never block the sign-in itself.
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (_) {}
  }

  Future<bool> _restoreSession(SharedPreferences prefs) async {
    if (!CloudflareBackend.configured) return false;
    final token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_userKey);
    if (token == null || token.isEmpty || raw == null) return false;
    AppUser? cached;
    try {
      cached = _userFromLogin(
        jsonDecode(raw) as Map<String, dynamic>,
        fallbackEmail: '',
      );
    } catch (_) {
      await _clearSession();
      return false;
    }
    CloudflareBackend.token = token;
    initializing = true;
    notifyListeners();
    try {
      try {
        final data = await CloudflareBackend.me();
        currentUser = _userFromLogin(data, fallbackEmail: cached.email);
        await _saveSession();
      } on ApiException catch (error) {
        if (error.unauthorized) {
          CloudflareBackend.token = null;
          await _clearSession();
          return false;
        }
        // Offline at startup: keep the saved account, data syncs later.
        currentUser = cached;
      }
      if (isGuest) {
        currentUser!.address =
            prefs.getString('guest_delivery_address') ?? currentUser!.address;
        currentUser!.phone =
            prefs.getString('guest_phone') ?? currentUser!.phone;
      }
      await _loadGuestCart(prefs);
      showAuth = false;
      await refresh();
      _startPolling();
      return true;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  AppUser _userFromLogin(
    Map<String, dynamic> data, {
    required String fallbackEmail,
  }) {
    final email = (data['email'] as String?)?.toLowerCase() ?? fallbackEmail;
    return AppUser(
      id: data['id'] as String,
      name: (data['name'] ?? data['full_name'] ?? email) as String,
      email: email,
      password: '',
      role: _role(data['role'] as String?),
      businessName: data['business_name'] as String?,
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      avatarUrl: CloudflareBackend.absoluteUrl(data['avatar_url'] as String?),
    );
  }

  Future<void> _loadGuestCart(SharedPreferences prefs) async {
    for (final row in prefs.getStringList('guest_cart') ?? <String>[]) {
      final parts = row.split(':');
      if (parts.length == 2) {
        cart[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }
  }

  Future<void> initializeGuest() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') == 'ar' ? 'ar' : 'fr';
    if (isGuest) {
      currentUser?.address = prefs.getString('guest_delivery_address') ?? '';
      currentUser?.phone = prefs.getString('guest_phone') ?? '';
    }
    await _loadGuestCart(prefs);
    if (currentUser?.id == 'guest-local') _loadLocalGuestOrders(prefs);
    notifyListeners();
    if (!CloudflareBackend.configured || currentUser?.id != 'guest-local') {
      return;
    }
    _startPolling();
    unawaited(_syncCatalog());
    await _connectGuestAccount();
  }

  /// Orders saved on this device by earlier versions, before orders were kept
  /// on the server. They stay visible in the history.
  final _legacyOrders = <MarketOrder>[];

  void _loadLocalGuestOrders(SharedPreferences prefs) {
    for (final raw in prefs.getStringList('guest_orders') ?? <String>[]) {
      try {
        final row = jsonDecode(raw) as Map<String, dynamic>;
        if (orders.any((o) => o.id == row['id']) ||
            _legacyOrders.any((o) => o.id == row['id'])) {
          continue;
        }
        final items = (row['items'] as List<dynamic>).map((entry) {
          final item = entry as Map<String, dynamic>;
          final known = products.where((p) => p.id == item['id']);
          final source = known.isEmpty ? null : known.first;
          final snapshot = Product(
            id: item['id'] as String,
            ownerId:
                item['ownerId'] as String? ??
                source?.ownerId ??
                row['merchantId'] as String,
            name: item['name'] as String? ?? source?.name ?? 'Article',
            description:
                item['description'] as String? ?? source?.description ?? '',
            kind: item['kind'] == 'grocery'
                ? ProductKind.grocery
                : (source?.kind ?? ProductKind.meal),
            retailPrice: (item['price'] as num).toInt(),
            wholesalePrice:
                (item['wholesale'] as num?)?.toInt() ??
                source?.wholesalePrice ??
                0,
            emoji: item['emoji'] as String? ?? source?.emoji ?? '🍽️',
            category: item['category'] as String? ?? source?.category ?? '',
            mediaUrl: item['mediaUrl'] as String? ?? source?.mediaUrl,
            merchantName:
                row['merchantName'] as String? ?? source?.merchantName,
          );
          return OrderItem(snapshot, (item['quantity'] as num).toInt());
        }).toList();
        (CloudflareBackend.configured ? _legacyOrders : orders).insert(
          0,
          MarketOrder(
            id: row['id'] as String,
            clientId: 'guest-local',
            merchantId: row['merchantId'] as String,
            merchantName: row['merchantName'] as String?,
            items: items,
            address: row['address'] as String,
            note: row['note'] as String? ?? '',
            createdAt: DateTime.parse(row['createdAt'] as String),
            status: OrderStatus.values.byName(row['status'] as String),
            paid: row['paid'] as bool? ?? false,
            deliveryFee: (row['deliveryFee'] as num).toInt(),
            commissionAmount: (row['commissionAmount'] as num).toInt(),
            courierId: row['courierId'] as String?,
          ),
        );
      } catch (_) {
        /* Ignore an invalid local snapshot. */
      }
    }
  }

  /// Signs the device in to its own customer account (creating it the first
  /// time) so orders are stored on the server and reach the couriers.
  Future<void> _connectGuestAccount() async {
    if (connecting || currentUser?.id != 'guest-local') return;
    connecting = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      var email = prefs.getString('guest_email');
      var password = prefs.getString('guest_password');
      if (email == null || password == null) {
        final random = Random.secure();
        String part() => random.nextInt(1 << 32).toRadixString(36);
        email =
            'guest-${DateTime.now().microsecondsSinceEpoch}-${part()}@wasla.local';
        password = '${part()}${part()}${part()}${part()}${part()}';
        await prefs.setString('guest_email', email);
        await prefs.setString('guest_password', password);
      }
      final session =
          await CloudflareBackend.login(email, password) ??
          await CloudflareBackend.createGuest(email, password);
      // A partner may have signed in while this request was in flight: their
      // session must not be replaced by the guest one.
      if (currentUser?.id != 'guest-local') return;
      CloudflareBackend.token = session.token;
      final data = session.user;
      currentUser = AppUser(
        id: data['id'] as String,
        name: 'Invité',
        email: email,
        password: '',
        role: UserRole.client,
        address: prefs.getString('guest_delivery_address') ?? '',
        phone: prefs.getString('guest_phone') ?? '',
      );
      refreshError = null;
      await _saveSession();
      // Reuse the catalogue request already started before the account
      // handshake, and fetch only live account data after authentication.
      await Future.wait<void>([
        _syncCatalog(),
        _syncSettings(),
        refresh(includeStatic: false),
      ]);
      _startPolling();
    } on ApiException {
      // The guest stays local until the server answers; retried by the poller.
      await _syncSettings();
    } catch (_) {
      await _syncSettings();
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<void> reconnect() => refresh().then((_) async {
    if (currentUser?.id == 'guest-local') await _connectGuestAccount();
  });

  /// The catalogue is public, so a device that has not connected its customer
  /// account yet can still browse it.
  Future<void> _syncCatalog() async {
    if (!CloudflareBackend.configured) return;
    final active = _catalogTask;
    if (active != null) return active;
    final task = _performCatalogSync();
    _catalogTask = task;
    try {
      await task;
    } finally {
      if (identical(_catalogTask, task)) _catalogTask = null;
    }
  }

  Future<void> _performCatalogSync() async {
    try {
      final responses = await Future.wait<dynamic>([
        CloudflareBackend.get('/api/products'),
        CloudflareBackend.get('/api/categories'),
      ]);
      products
        ..clear()
        ..addAll(_parse(_results(responses[0]), _productFromJson));
      categories
        ..clear()
        ..addAll(_parse(_results(responses[1]), _categoryFromJson));
      notifyListeners();
    } catch (_) {}
  }

  /// Delivery fee and commission are public, so even a device that has not
  /// signed in yet follows the administrator's latest prices.
  Future<void> _syncSettings() async {
    if (!CloudflareBackend.configured) return;
    try {
      final settings = await CloudflareBackend.get('/api/settings');
      if (settings is Map<String, dynamic>) _applySettings(settings);
      notifyListeners();
    } catch (_) {}
  }

  void _applySettings(Map<String, dynamic> settings) {
    commissionPercent =
        (settings['commission_percent'] as num?)?.toInt() ?? commissionPercent;
    deliveryFee = (settings['delivery_fee'] as num?)?.toInt() ?? deliveryFee;
    for (final product in products) {
      if (product.kind == ProductKind.meal) {
        product.retailPrice = customerPriceFor(
          product.wholesalePrice,
          commissionPercent,
        );
      }
    }
  }

  /// Lightweight price refresh used before checkout; it avoids downloading
  /// orders, notifications and the whole catalogue just to verify two values.
  Future<void> refreshPricing() => _syncSettings();

  final users = <AppUser>[], products = <Product>[], orders = <MarketOrder>[];
  final walletEntries = <WalletEntry>[];
  final categories = <AppCategory>[];
  final notifications = <AppNotification>[];
  final cart = <String, int>{};
  final processingOrders = <String>{};
  final _incoming = StreamController<AppNotification>.broadcast();
  final _knownNotifications = <String>{};
  var _notificationsPrimed = false;
  Timer? _poller;
  int _pollTick = 0;
  Future<void>? _refreshTask;
  Future<void>? _catalogTask;
  String? _lastDynamicPayload;
  bool refreshing = false;
  String? lastError;

  /// Notifications that arrived while the app was open, for in-app banners.
  Stream<AppNotification> get incomingNotifications => _incoming.stream;
  List<WalletEntry> get currentWalletEntries =>
      walletEntries.where((entry) => entry.ownerId == currentUser?.id).toList();
  int get walletBalance =>
      currentWalletEntries.fold<int>(0, (sum, entry) => sum + entry.amount);
  int walletBalanceFor(String ownerId) => walletEntries
      .where((entry) => entry.ownerId == ownerId)
      .fold<int>(0, (sum, entry) => sum + entry.amount);
  int get unreadNotifications => notifications.where((n) => !n.read).length;
  List<AppCategory> categoriesFor(ProductKind kind) => categories
      .where((category) => category.active && category.kind == kind)
      .toList();
  AppUser user(String id) => users.firstWhere((u) => u.id == id);
  Product product(String id) => products.firstWhere((p) => p.id == id);
  Product _snapshotProduct(Product source) => Product(
    id: source.id,
    ownerId: source.ownerId,
    name: source.name,
    description: source.description,
    kind: source.kind,
    retailPrice: source.retailPrice,
    wholesalePrice: source.wholesalePrice,
    emoji: source.emoji,
    category: source.category,
    mediaUrl: source.mediaUrl,
    mediaType: source.mediaType,
    ingredients: List<String>.of(source.ingredients),
    allergens: List<String>.of(source.allergens),
    preparationMinutes: source.preparationMinutes,
    calories: source.calories,
    merchantName: source.merchantName,
    available: source.available,
    approvalStatus: source.approvalStatus,
    rating: source.rating,
  );
  String merchantName(Product p) {
    final matches = users.where((u) => u.id == p.ownerId);
    if (matches.isNotEmpty) {
      return matches.first.businessName ?? matches.first.name;
    }
    return p.merchantName ?? 'Partenaire Wasla';
  }

  String orderMerchant(MarketOrder order) {
    final matches = users.where((u) => u.id == order.merchantId);
    if (matches.isNotEmpty) {
      return matches.first.businessName ?? matches.first.name;
    }
    return order.merchantName ?? 'Partenaire Wasla';
  }

  List<Product> get availableProducts => products.where((p) {
    final owners = users.where((u) => u.id == p.ownerId);
    return p.available &&
        p.approvalStatus == 'approved' &&
        (owners.isEmpty || owners.first.active);
  }).toList();
  List<Product> get clientProducts => products.where((p) {
    final owners = users.where((u) => u.id == p.ownerId);
    return p.approvalStatus == 'approved' &&
        (owners.isEmpty || owners.first.active);
  }).toList();
  List<Product> get cartProducts =>
      products.where((p) => cart.containsKey(p.id)).toList();
  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  int get cartSubtotal =>
      cartProducts.fold(0, (s, p) => s + p.retailPrice * cart[p.id]!);
  int get cartCommission => cartProducts.fold(
    0,
    (sum, product) =>
        sum +
        (product.retailPrice - product.wholesalePrice) * cart[product.id]!,
  );

  /// Turns a failed call into a message in the current language.
  String apiMessage(Object error) {
    if (error is! ApiException) {
      return tr(
        'Une erreur est survenue. Réessayez.',
        'حدث خطأ. حاول مرة أخرى.',
      );
    }
    if (error.network) {
      return tr(
        'Connexion au serveur impossible. Vérifiez votre connexion et réessayez.',
        'تعذر الاتصال بالخادم. تحقق من اتصالك وحاول مرة أخرى.',
      );
    }
    return switch (error.code) {
      'email_exists' => tr(
        'Cette adresse e-mail est déjà utilisée.',
        'هذا البريد الإلكتروني مستخدم بالفعل.',
      ),
      'account_creation_failed' => tr(
        'Le serveur n’a pas pu créer le compte. Réessayez dans un instant.',
        'تعذر على الخادم إنشاء الحساب. حاول مرة أخرى بعد قليل.',
      ),
      'invalid_account' => tr(
        'Informations invalides : nom, e-mail valide et mot de passe de 8 caractères minimum.',
        'معلومات غير صالحة: الاسم، بريد صحيح وكلمة مرور من 8 أحرف على الأقل.',
      ),
      'kitchen_only' => tr(
        'Seules les cuisines peuvent s’inscrire. Les livreurs et supérettes sont créés par l’administrateur.',
        'يمكن للمطابخ فقط التسجيل بنفسها. حسابات الموصلين والبقالات ينشئها المدير.',
      ),
      'category_exists' => tr(
        'Cette catégorie existe déjà pour ce type.',
        'هذا التصنيف موجود بالفعل لهذا النوع.',
      ),
      'invalid_category' => tr(
        'Catégorie invalide ou désactivée.',
        'تصنيف غير صالح أو معطل.',
      ),
      'name_required' => tr('Le nom est obligatoire.', 'الاسم إلزامي.'),
      'category_required' => tr('Choisissez une catégorie.', 'اختر تصنيفاً.'),
      'price_required' => tr(
        'Indiquez un prix de gros supérieur à 0.',
        'أدخل سعر جملة أكبر من 0.',
      ),
      'description_required' => tr(
        'La description est obligatoire.',
        'الوصف إلزامي.',
      ),
      'media_too_large' => tr(
        'Fichier trop volumineux (image 8 Mo, vidéo 25 Mo maximum).',
        'الملف كبير جداً (صورة حتى 8 م.ب، فيديو حتى 25 م.ب).',
      ),
      'unsupported_media' => tr(
        'Format de fichier non pris en charge.',
        'صيغة الملف غير مدعومة.',
      ),
      'invalid_settings' => tr(
        'Valeurs invalides : commission de 0 à 100 % et frais de livraison positifs.',
        'قيم غير صالحة: عمولة من 0 إلى 100٪ ورسوم توصيل موجبة.',
      ),
      'product_not_found' => tr(
        'Un article du panier n’est plus disponible. Actualisez votre panier.',
        'منتج في السلة لم يعد متوفراً. حدّث سلتك.',
      ),
      'product_out_of_stock' => tr(
        'Un article du panier est épuisé. Retirez-le avant de commander.',
        'أحد منتجات السلة نفد. أزله قبل تأكيد الطلب.',
      ),
      'invalid_retail_price' => tr(
        'Le prix client doit être égal ou supérieur au prix de la supérette.',
        'يجب أن يكون سعر الزبون مساوياً أو أكبر من سعر البقالة.',
      ),
      'settlement_forbidden' => tr(
        'Ce solde ne peut pas être réglé depuis ce compte.',
        'لا يمكن تسوية هذا الرصيد من هذا الحساب.',
      ),
      'invalid_payment_amount' => tr(
        'Le montant doit être supérieur à zéro et ne peut pas dépasser le crédit restant.',
        'يجب أن يكون المبلغ أكبر من صفر وألا يتجاوز الرصيد المتبقي.',
      ),
      'single_merchant_required' => tr(
        'Une commande ne peut contenir que les articles d’un seul commerce.',
        'لا يمكن أن يحتوي الطلب إلا على منتجات متجر واحد.',
      ),
      'invalid_transition' || 'order_changed' => tr(
        'Cette commande n’est plus disponible ou a déjà été prise.',
        'هذا الطلب لم يعد متاحاً أو تم أخذه بالفعل.',
      ),
      'unauthorized' => tr(
        'Votre session a expiré. Reconnectez-vous.',
        'انتهت جلستك. سجّل الدخول من جديد.',
      ),
      'admin_only' || 'forbidden' || 'merchant_only' || 'client_only' => tr(
        'Cette action n’est pas autorisée pour ce compte.',
        'هذا الإجراء غير مسموح لهذا الحساب.',
      ),
      _ => tr(
        'Le serveur a refusé la demande (${error.code}).',
        'رفض الخادم الطلب (${error.code}).',
      ),
    };
  }

  Future<bool> login(
    String email,
    String password, [
    UserRole? selected,
  ]) async {
    lastError = null;
    final normalized = email.trim().toLowerCase();
    if (CloudflareBackend.configured) {
      try {
        final session = await CloudflareBackend.login(normalized, password);
        if (session == null) {
          lastError = tr(
            'E-mail ou mot de passe incorrect.',
            'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
          );
          return false;
        }
        return _activateSession(
          session,
          fallbackEmail: normalized,
          selected: selected,
        );
      } catch (error) {
        lastError = apiMessage(error);
        return false;
      }
    }
    final matches = users.where(
      (u) =>
          u.active &&
          u.email.toLowerCase() == normalized &&
          u.password == password &&
          (selected == null || u.role == UserRole.admin || u.role == selected),
    );
    currentUser = matches.isEmpty ? null : matches.first;
    if (currentUser != null) showAuth = false;
    notifyListeners();
    return currentUser != null;
  }

  Future<bool> _activateSession(
    AuthSession session, {
    required String fallbackEmail,
    UserRole? selected,
  }) async {
    final data = session.user;
    final role = _role(data['role'] as String?);
    if (selected != null && role != UserRole.admin && role != selected) {
      await CloudflareBackend.revoke(session.token);
      lastError = tr(
        'Ce compte ne correspond pas à ce rôle.',
        'هذا الحساب لا يطابق هذا الدور.',
      );
      return false;
    }
    _poller?.cancel();
    CloudflareBackend.token = session.token;
    _resetLiveData();
    currentUser = _userFromLogin(data, fallbackEmail: fallbackEmail);
    await _saveSession();
    await refresh();
    _startPolling();
    showAuth = false;
    notifyListeners();
    return true;
  }

  /// Drops the previous account's data so it never shows for the next one.
  void _resetLiveData() {
    if (!CloudflareBackend.configured) return;
    orders.clear();
    walletEntries.clear();
    notifications.clear();
    users.clear();
    _knownNotifications.clear();
    _notificationsPrimed = false;
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? businessName,
    String phone = '',
    String adminSetupToken = '',
  }) async {
    lastError = null;
    if (role == UserRole.admin) {
      if (!CloudflareBackend.configured || adminSetupToken.isEmpty) {
        return false;
      }
      try {
        await CloudflareBackend.bootstrapAdmin(
          name: name,
          email: email,
          password: password,
          setupToken: adminSetupToken,
        );
        return login(email, password, role);
      } catch (_) {
        lastError = tr(
          'Code administrateur invalide ou compte déjà créé.',
          'رمز المدير غير صالح أو الحساب موجود مسبقاً.',
        );
        return false;
      }
    }
    // Only kitchens register themselves; every other partner is opened by the
    // administrator.
    if (role != UserRole.restaurant) {
      lastError = apiMessage(const ApiException('kitchen_only'));
      return false;
    }
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.length < 2 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail) ||
        password.length < 8 ||
        (businessName?.trim().length ?? 0) < 2) {
      lastError = apiMessage(const ApiException('invalid_account'));
      return false;
    }
    if (CloudflareBackend.configured) {
      try {
        final response = await CloudflareBackend.post('/api/auth/signup', {
          'name': cleanName,
          'email': cleanEmail,
          'password': password,
          'role': role.name,
          'businessName': businessName!.trim(),
          'phone': phone.trim(),
        });
        final token = response['token'];
        final user = response['user'];
        if (token is String && user is Map<String, dynamic>) {
          return _activateSession(
            AuthSession(token, user),
            fallbackEmail: cleanEmail,
            selected: role,
          );
        }
      } catch (error) {
        // If account creation succeeded but its response was lost, retrying
        // legitimately returns email_exists. Signing in recovers that account
        // instead of trapping the user on the registration form.
        if (error is! ApiException || error.code != 'email_exists') {
          lastError = apiMessage(error);
          return false;
        }
      }
      final recovered = await login(cleanEmail, password, role);
      if (!recovered) {
        lastError = apiMessage(const ApiException('email_exists'));
      }
      return recovered;
    }
    if (users.any((u) => u.email.toLowerCase() == cleanEmail)) {
      lastError = apiMessage(const ApiException('email_exists'));
      return false;
    }
    currentUser = AppUser(
      id: 'u${users.length + 1}',
      name: cleanName,
      email: cleanEmail,
      password: password,
      role: role,
      businessName: businessName!.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
    );
    users.add(currentUser!);
    showAuth = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _poller?.cancel();
    if (CloudflareBackend.configured) await CloudflareBackend.logout();
    await _clearSession();
    currentUser = _guestUser;
    showAuth = false;
    cart.clear();
    pendingOrderNote = '';
    _resetLiveData();
    notifyListeners();
    if (guestPersistence) await initializeGuest();
  }

  Future<void> refresh({
    bool afterMutation = false,
    bool includeStatic = true,
  }) async {
    if (!CloudflareBackend.configured || currentUser == null) return;
    if (currentUser!.id == 'guest-local') {
      await _syncSettings();
      await _syncCatalog();
      return;
    }
    final activeRefresh = _refreshTask;
    if (activeRefresh != null) {
      await activeRefresh;
      if (!afterMutation) return;
    }
    _refreshTask = _performRefresh(includeStatic: includeStatic);
    try {
      await _refreshTask;
    } finally {
      _refreshTask = null;
    }
  }

  Future<void> _performRefresh({required bool includeStatic}) async {
    final activeUser = currentUser;
    if (activeUser == null) return;
    refreshing = true;
    try {
      final role = activeUser.role;
      // Full loads still start every request together. Background polls omit
      // the stable resources and transfer only the three live collections.
      final responses = await Future.wait<dynamic>([
        CloudflareBackend.get('/api/orders'),
        role == UserRole.client
            ? Future<dynamic>.value(<String, dynamic>{'results': []})
            : CloudflareBackend.get(
                role == UserRole.admin
                    ? '/api/wallet?owner=all'
                    : '/api/wallet',
              ),
        CloudflareBackend.get('/api/notifications'),
        if (includeStatic) CloudflareBackend.get('/api/products'),
        if (includeStatic) CloudflareBackend.get('/api/categories'),
        if (includeStatic) CloudflareBackend.get('/api/settings'),
        if (includeStatic && role == UserRole.admin)
          CloudflareBackend.get('/api/users'),
      ]);
      if (currentUser?.id != activeUser.id) return;
      final dynamicResponses = responses.take(3).toList(growable: false);

      final dynamicPayload = jsonEncode(dynamicResponses);
      final unchanged =
          !includeStatic &&
          refreshError == null &&
          dynamicPayload == _lastDynamicPayload;
      _lastDynamicPayload = dynamicPayload;
      if (unchanged) return;

      orders
        ..clear()
        ..addAll(_parse(_results(dynamicResponses[0]), _orderFromJson));

      walletEntries
        ..clear()
        ..addAll(_parse(_results(dynamicResponses[1]), _walletFromJson));

      notifications
        ..clear()
        ..addAll(_parse(_results(dynamicResponses[2]), _notificationFromJson));
      _announceNewNotifications();

      if (includeStatic) {
        // Apply the percentage first because catalogue prices are derived from
        // the restaurant price, even if an older Worker still returns a stale
        // retail_price value.
        if (responses[5] is Map<String, dynamic>) {
          _applySettings(responses[5] as Map<String, dynamic>);
        }
        products
          ..clear()
          ..addAll(_parse(_results(responses[3]), _productFromJson));
        cart.removeWhere(
          (id, _) => !products.any((p) => p.id == id && p.available),
        );
        categories
          ..clear()
          ..addAll(_parse(_results(responses[4]), _categoryFromJson));
        if (role == UserRole.admin) {
          users
            ..clear()
            ..addAll(_parse(_results(responses[6]), _userFromJson));
        }
      }
      refreshError = null;
      notifyListeners();
    } on ApiException catch (error) {
      if (error.unauthorized && currentUser?.id == activeUser.id) {
        await _sessionExpired();
        return;
      }
      refreshError = apiMessage(error);
      notifyListeners();
    } catch (_) {
      refreshError = tr(
        'Actualisation impossible. Vérifiez votre connexion.',
        'تعذر التحديث. تحقق من اتصالك.',
      );
      notifyListeners();
    } finally {
      refreshing = false;
    }
  }

  Future<void> _sessionExpired() async {
    final wasGuest = isGuest;
    _poller?.cancel();
    CloudflareBackend.token = null;
    await _clearSession();
    currentUser = _guestUser;
    cart.clear();
    _resetLiveData();
    lastError = tr(
      'Votre session a expiré. Reconnectez-vous.',
      'انتهت جلستك. سجّل الدخول من جديد.',
    );
    notifyListeners();
    if (wasGuest || guestPersistence) await initializeGuest();
  }

  /// One malformed row must not hide every other order or product.
  List<T> _parse<T>(
    List<Map<String, dynamic>> rows,
    T Function(Map<String, dynamic>) read,
  ) {
    final parsed = <T>[];
    for (final row in rows) {
      try {
        parsed.add(read(row));
      } catch (error) {
        debugPrint('Skipped an unreadable row: $error');
      }
    }
    return parsed;
  }

  /// Pushes a notification to the in-app banner as a refresh would.
  @visibleForTesting
  void debugAnnounce(AppNotification notification) {
    notifications.insert(0, notification);
    _incoming.add(notification);
    notifyListeners();
  }

  void _announceNewNotifications() {
    final fresh = notifications
        .where((n) => !n.read && !_knownNotifications.contains(n.id))
        .toList();
    if (_notificationsPrimed) {
      for (final item in fresh.reversed) {
        if (!_incoming.isClosed) _incoming.add(item);
      }
    }
    _knownNotifications.addAll(notifications.map((n) => n.id));
    _notificationsPrimed = true;
  }

  List<Map<String, dynamic>> _results(dynamic response) =>
      ((response as Map<String, dynamic>)['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

  /// The Worker stores UTC timestamps without a zone suffix.
  DateTime _time(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DateTime.now();
    var value = raw.trim();
    if (!RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(value)) {
      value = '${value.replaceFirst(' ', 'T')}Z';
    }
    return (DateTime.tryParse(value) ?? DateTime.now()).toLocal();
  }

  Product _productFromJson(Map<String, dynamic> r) {
    final merchantPrice = (r['wholesale_price'] as num?)?.toInt() ?? 0;
    final kind = r['kind'] == 'grocery'
        ? ProductKind.grocery
        : ProductKind.meal;
    return Product(
      id: r['id'] as String,
      ownerId: r['owner_id'] as String,
      name: r['name'] as String,
      description: r['description'] as String? ?? '',
      kind: kind,
      retailPrice: kind == ProductKind.grocery
          ? (r['retail_price'] as num?)?.toInt() ?? merchantPrice
          : customerPriceFor(merchantPrice, commissionPercent),
      wholesalePrice: merchantPrice,
      emoji: r['emoji'] as String? ?? '🍽️',
      category: r['category'] as String? ?? 'Autre',
      mediaUrl: CloudflareBackend.absoluteUrl(r['media_url'] as String?),
      mediaType: r['media_type'] == 'video'
          ? ProductMediaType.video
          : ProductMediaType.image,
      ingredients: _csv(r['ingredients'] as String?),
      allergens: _csv(r['allergens'] as String?),
      preparationMinutes: (r['preparation_minutes'] as num?)?.toInt() ?? 15,
      calories: (r['calories'] as num?)?.toInt(),
      merchantName: r['business_name'] as String?,
      available: (r['active'] as num?)?.toInt() != 0,
      approvalStatus: r['approval_status'] as String? ?? 'approved',
    );
  }

  MarketOrder _orderFromJson(Map<String, dynamic> r) {
    final rawItems = (r['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final items = rawItems.map((item) {
      final id = item['product_id'] as String;
      final existing = products.where((p) => p.id == id);
      final source = existing.isEmpty ? null : existing.first;
      // Orders are immutable price snapshots. Reusing the live catalogue
      // product here made old totals change whenever commission was updated.
      final p = Product(
        id: id,
        ownerId: r['merchant_id'] as String,
        name: item['product_name'] as String? ?? source?.name ?? 'Article',
        description:
            item['description'] as String? ?? source?.description ?? '',
        kind: item['kind'] == 'grocery'
            ? ProductKind.grocery
            : source?.kind ?? ProductKind.meal,
        retailPrice: (item['retail_unit_price'] as num).toInt(),
        wholesalePrice: (item['wholesale_unit_price'] as num).toInt(),
        emoji: item['emoji'] as String? ?? source?.emoji ?? '🍽️',
        category: item['category'] as String? ?? source?.category ?? 'Commande',
        mediaUrl: CloudflareBackend.absoluteUrl(
          item['media_url'] as String? ?? source?.mediaUrl,
        ),
        mediaType: item['media_type'] == 'video'
            ? ProductMediaType.video
            : source?.mediaType ?? ProductMediaType.image,
        ingredients: _csv(item['ingredients'] as String?),
        allergens: _csv(item['allergens'] as String?),
        preparationMinutes:
            (item['preparation_minutes'] as num?)?.toInt() ?? 15,
        calories: (item['calories'] as num?)?.toInt(),
        merchantName: r['merchant_name'] as String?,
      );
      return OrderItem(p, (item['quantity'] as num).toInt());
    }).toList();
    return MarketOrder(
      id: orderReference(r['code'] as String),
      serverId: r['id'] as String?,
      clientId: r['customer_id'] as String,
      merchantId: r['merchant_id'] as String,
      courierId: r['courier_id'] as String?,
      items: items,
      address: r['address'] as String? ?? '',
      note: r['customer_note'] as String? ?? '',
      createdAt: _time(r['created_at'] as String?),
      status: r['status'] == 'delivered' && r['client_confirmed_at'] != null
          ? OrderStatus.clientConfirmed
          : _status(r['status'] as String?),
      paymentMethod: r['payment_method'] as String? ?? 'Espèces',
      paid: r['payment_status'] == 'paid',
      deliveryFee: (r['delivery_fee'] as num?)?.toInt() ?? 200,
      commissionAmount: (r['commission_amount'] as num?)?.toInt() ?? 0,
      merchantName: r['merchant_name'] as String?,
      clientName: r['customer_name'] as String?,
      courierName: r['courier_name'] as String?,
      customerPhone: r['customer_phone'] as String? ?? '',
      merchantPhone: r['merchant_phone'] as String? ?? '',
      merchantAddress: r['merchant_address'] as String? ?? '',
      courierPhone: r['courier_phone'] as String? ?? '',
    );
  }

  WalletEntry _walletFromJson(Map<String, dynamic> r) => WalletEntry(
    id: r['id'] as String,
    ownerId: r['owner_id'] as String,
    type: r['entry_type'] as String,
    amount: (r['amount'] as num).toInt(),
    orderId: r['order_id'] as String?,
    createdAt: _time(r['created_at'] as String?),
  );

  AppCategory _categoryFromJson(Map<String, dynamic> r) => AppCategory(
    id: r['id'] as String,
    name: r['name'] as String,
    kind: r['kind'] == 'grocery' ? ProductKind.grocery : ProductKind.meal,
    active: (r['active'] as num?)?.toInt() != 0,
  );

  AppNotification _notificationFromJson(Map<String, dynamic> r) =>
      AppNotification(
        id: r['id'] as String,
        title: r['title'] as String,
        message: r['message'] as String,
        type: r['type'] as String? ?? 'info',
        orderId: r['order_id'] as String?,
        createdAt: _time(r['created_at'] as String?),
        read: (r['read'] as num?)?.toInt() != 0,
      );

  List<String> _csv(String? value) => (value ?? '')
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  AppUser _userFromJson(Map<String, dynamic> r) => AppUser(
    id: r['id'] as String,
    name: r['full_name'] as String,
    email: r['email'] as String,
    password: '',
    role: _role(r['role'] as String?),
    businessName: r['business_name'] as String?,
    phone: r['phone'] as String? ?? '',
    address: r['address'] as String? ?? '',
    avatarUrl: CloudflareBackend.absoluteUrl(r['avatar_url'] as String?),
    active: (r['active'] as num?)?.toInt() != 0,
    createdAt: r['created_at'] == null
        ? null
        : _time(r['created_at'] as String?),
  );

  OrderStatus _status(String? value) => switch (value) {
    'courier_validated' => OrderStatus.courierValidated,
    'merchant_accepted' => OrderStatus.merchantAccepted,
    'preparing' => OrderStatus.preparing,
    'ready' => OrderStatus.ready,
    'picked_up' => OrderStatus.pickedUp,
    'delivered' => OrderStatus.delivered,
    'client_confirmed' => OrderStatus.clientConfirmed,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.placed,
  };

  void _startPolling() {
    _poller?.cancel();
    _pollTick = 0;
    if (CloudflareBackend.configured) {
      _poller = Timer.periodic(const Duration(seconds: 15), (_) {
        if (currentUser?.id == 'guest-local') {
          unawaited(_connectGuestAccount());
          unawaited(_syncSettings());
          if (products.isEmpty) unawaited(_syncCatalog());
        } else {
          // Orders, balances and notifications are live. Catalogue,
          // categories, settings and users need only one refresh per minute.
          _pollTick++;
          unawaited(refresh(includeStatic: _pollTick % 4 == 0));
        }
      });
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _incoming.close();
    super.dispose();
  }

  UserRole _role(String? r) => switch (r) {
    'courier' || 'driver' => UserRole.courier,
    'restaurant' => UserRole.restaurant,
    'supermarket' || 'supplier' => UserRole.supermarket,
    'admin' => UserRole.admin,
    _ => UserRole.client,
  };
  void addToCart(Product p, {String note = ''}) {
    if (!p.available || p.approvalStatus != 'approved') return;
    final first = cart.isEmpty
        ? <Product>[]
        : products.where((item) => item.id == cart.keys.first).toList();
    if (cart.isNotEmpty &&
        (first.isEmpty || first.first.ownerId != p.ownerId)) {
      cart.clear();
      pendingOrderNote = '';
    }
    cart[p.id] = (cart[p.id] ?? 0) + 1;
    final extra = note.trim();
    if (extra.isNotEmpty) {
      final line = '${p.name} : $extra';
      pendingOrderNote = pendingOrderNote.isEmpty
          ? line
          : '$pendingOrderNote\n$line';
    }
    notifyListeners();
    if (isGuest && guestPersistence) unawaited(_saveGuestCart());
  }

  void quantity(Product p, int d) {
    final n = (cart[p.id] ?? 0) + d;
    if (n < 1) {
      cart.remove(p.id);
    } else {
      cart[p.id] = n;
    }
    if (cart.isEmpty) pendingOrderNote = '';
    notifyListeners();
    if (isGuest && guestPersistence) unawaited(_saveGuestCart());
  }

  Future<void> _saveGuestCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'guest_cart',
      cart.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
  }

  Future<void> _saveGuestOrders() async {
    if (!guestPersistence) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'guest_orders',
      orders
          .where((o) => o.clientId == 'guest-local')
          .map(
            (o) => jsonEncode({
              'id': o.id,
              'merchantId': o.merchantId,
              'merchantName': o.merchantName,
              'address': o.address,
              'note': o.note,
              'createdAt': o.createdAt.toIso8601String(),
              'status': o.status.name,
              'paid': o.paid,
              'deliveryFee': o.deliveryFee,
              'commissionAmount': o.commissionAmount,
              'courierId': o.courierId,
              'items': o.items
                  .map(
                    (i) => {
                      'id': i.product.id,
                      'name': i.product.name,
                      'description': i.product.description,
                      'ownerId': i.product.ownerId,
                      'kind': i.product.kind.name,
                      'emoji': i.product.emoji,
                      'category': i.product.category,
                      'mediaUrl': i.product.mediaUrl,
                      'price': i.product.retailPrice,
                      'wholesale': i.product.wholesalePrice,
                      'quantity': i.quantity,
                    },
                  )
                  .toList(),
            }),
          )
          .toList(),
    );
  }

  MarketOrder? previewOrder({required String address, String note = ''}) {
    if (cart.isEmpty || currentUser?.role != UserRole.client) return null;
    final items = cart.entries
        .map((e) => OrderItem(_snapshotProduct(product(e.key)), e.value))
        .toList();
    return MarketOrder(
      id: '#${1048 + orders.length}',
      clientId: currentUser!.id,
      merchantId: product(cart.keys.first).ownerId,
      items: items,
      address: address,
      note: note.trim(),
      createdAt: DateTime.now(),
      paymentMethod: 'Paiement à la livraison',
      deliveryFee: deliveryFee,
      commissionAmount: items.fold<int>(
        0,
        (sum, item) =>
            sum +
            (item.product.retailPrice - item.product.wholesalePrice) *
                item.quantity,
      ),
    );
  }

  /// Places the cart as an order. Returns `null` and sets [lastError] when the
  /// server refused it or could not be reached, leaving the cart untouched so
  /// the customer can simply retry.
  Future<MarketOrder?> checkout(
    String address,
    String payment, {
    String note = '',
    String phone = '',
  }) async {
    if (cart.isEmpty || currentUser?.role != UserRole.client) return null;
    if (cart.keys.any(
      (id) => !products.any((p) => p.id == id && p.available),
    )) {
      lastError = apiMessage(const ApiException('product_out_of_stock'));
      notifyListeners();
      return null;
    }
    lastError = null;
    final items = cart.entries
        .map((e) => OrderItem(_snapshotProduct(product(e.key)), e.value))
        .toList();
    final cleanPhone = phone.trim();
    if (cleanPhone.isNotEmpty && isGuest) {
      unawaited(_saveGuestPhone(cleanPhone));
    }
    if (CloudflareBackend.configured && currentUser?.id != 'guest-local') {
      try {
        final response = await CloudflareBackend.post('/api/orders', {
          'address': address.trim().isEmpty
              ? _addressPlaceholder
              : address.trim(),
          'paymentMethod': payment,
          'note': note.trim(),
          'phone': cleanPhone,
          'items': items
              .map((i) => {'productId': i.product.id, 'quantity': i.quantity})
              .toList(),
        });
        final merchantId = items.first.product.ownerId;
        cart.clear();
        pendingOrderNote = '';
        if (isGuest && guestPersistence) await _saveGuestCart();
        if (address.trim().isNotEmpty) {
          unawaited(saveDeliveryAddress(address));
        }
        await refresh(afterMutation: true);
        final rawCode = response['code'] as String?;
        final code = rawCode == null ? null : orderReference(rawCode);
        final matches = orders.where((o) => o.id == code);
        if (matches.isNotEmpty) {
          notifyListeners();
          return matches.first;
        }
        // The order exists on the server; show it even if the refresh failed.
        final placed = MarketOrder(
          id: code ?? '#${1048 + orders.length}',
          clientId: currentUser!.id,
          merchantId: merchantId,
          items: items,
          address: address.trim(),
          note: note.trim(),
          createdAt: DateTime.now(),
          paymentMethod: payment,
          deliveryFee: deliveryFee,
          commissionAmount: items.fold<int>(
            0,
            (sum, item) =>
                sum +
                (item.product.retailPrice - item.product.wholesalePrice) *
                    item.quantity,
          ),
          customerPhone: cleanPhone,
        );
        orders.insert(0, placed);
        notifyListeners();
        return placed;
      } catch (error) {
        lastError = apiMessage(error);
        notifyListeners();
        return null;
      }
    }
    return _completeLocalCheckout(address, payment, note, items, cleanPhone);
  }

  Future<void> _saveGuestPhone(String phone) async {
    currentUser?.phone = phone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_phone', phone);
  }

  MarketOrder _completeLocalCheckout(
    String address,
    String payment,
    String note,
    List<OrderItem> items,
    String phone,
  ) {
    final order = MarketOrder(
      id: '#${1048 + orders.length}',
      clientId: currentUser!.id,
      merchantId: product(cart.keys.first).ownerId,
      items: items,
      address: address,
      note: note.trim(),
      createdAt: DateTime.now(),
      paymentMethod: payment,
      paid: payment != 'Paiement à la livraison',
      deliveryFee: deliveryFee,
      commissionAmount: items.fold<int>(
        0,
        (sum, item) =>
            sum +
            (item.product.retailPrice - item.product.wholesalePrice) *
                item.quantity,
      ),
      customerPhone: phone,
    );
    orders.insert(0, order);
    cart.clear();
    pendingOrderNote = '';
    notifyListeners();
    if (isGuest && guestPersistence) unawaited(_saveGuestCart());
    if (isGuest) unawaited(_saveGuestOrders());
    unawaited(saveDeliveryAddress(address));
    return order;
  }

  Future<bool> saveDeliveryAddress(String address) async {
    final value = address.trim();
    final user = currentUser;
    if (value.isEmpty || user == null) return false;
    if (isGuest) {
      user.address = value;
      if (guestPersistence) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('guest_delivery_address', value);
      }
      notifyListeners();
      return true;
    }
    return updateProfile(
      name: user.name,
      email: user.email,
      phone: user.phone,
      address: value,
      businessName: user.businessName,
      avatarUrl: user.avatarUrl,
    );
  }

  List<MarketOrder> ordersFor(AppUser u) => switch (u.role) {
    UserRole.client => [
      ...orders.where((o) => o.clientId == u.id),
      if (isGuest) ..._legacyOrders,
    ],
    UserRole.courier =>
      orders
          .where(
            (o) =>
                o.courierId == u.id ||
                (o.courierId == null && o.status == OrderStatus.placed),
          )
          .toList(),
    UserRole.restaurant || UserRole.supermarket =>
      orders
          .where((o) => o.merchantId == u.id && o.status != OrderStatus.placed)
          .toList(),
    UserRole.admin => orders,
  };
  String? action(MarketOrder o, UserRole r) {
    // Orders kept only on the device cannot be confirmed on the server.
    if (CloudflareBackend.configured && _legacyOrders.contains(o)) return null;
    return _action(o, r);
  }

  String? _action(MarketOrder o, UserRole r) => switch ((r, o.status)) {
    (UserRole.courier, OrderStatus.placed) => 'Valider et prendre',
    (
      UserRole.restaurant || UserRole.supermarket,
      OrderStatus.courierValidated,
    ) =>
      'Accepter la commande',
    (
      UserRole.restaurant || UserRole.supermarket,
      OrderStatus.merchantAccepted,
    ) =>
      'Commencer la préparation',
    (UserRole.restaurant || UserRole.supermarket, OrderStatus.preparing) =>
      'Marquer comme prête',
    (UserRole.courier, OrderStatus.ready) => 'Confirmer la récupération',
    (UserRole.courier, OrderStatus.pickedUp) => 'Confirmer la livraison',
    (UserRole.client, OrderStatus.delivered) => 'Confirmer la réception',
    _ => null,
  };

  OrderStatus? _nextStatus(MarketOrder o, UserRole r) =>
      switch ((r, o.status)) {
        (UserRole.courier, OrderStatus.placed) => OrderStatus.courierValidated,
        (
          UserRole.restaurant || UserRole.supermarket,
          OrderStatus.courierValidated,
        ) =>
          OrderStatus.merchantAccepted,
        (
          UserRole.restaurant || UserRole.supermarket,
          OrderStatus.merchantAccepted,
        ) =>
          OrderStatus.preparing,
        (UserRole.restaurant || UserRole.supermarket, OrderStatus.preparing) =>
          OrderStatus.ready,
        (UserRole.courier, OrderStatus.ready) => OrderStatus.pickedUp,
        (UserRole.courier, OrderStatus.pickedUp) => OrderStatus.delivered,
        (UserRole.client, OrderStatus.delivered) => OrderStatus.clientConfirmed,
        _ => null,
      };

  void _applyStatus(MarketOrder o, OrderStatus next, UserRole r) {
    if (r == UserRole.courier && o.status == OrderStatus.placed) {
      o.courierId = currentUser!.id;
    }
    o.status = next;
    if (next == OrderStatus.clientConfirmed) o.paid = true;
  }

  MarketOrder? _orderByCode(String code) {
    for (final candidate in orders) {
      if (candidate.id == code) return candidate;
    }
    return null;
  }

  /// Moves an order to its next step. Returns `false` with [lastError] set when
  /// the step could not be completed; an order already being processed is
  /// reported as success so a double tap never shows a misleading error.
  Future<bool> advance(MarketOrder o, UserRole r) async {
    if (processingOrders.contains(o.id)) return true;
    lastError = null;
    if ((r == UserRole.restaurant || r == UserRole.supermarket) &&
        currentUser?.id != o.merchantId) {
      return false;
    }
    if (r == UserRole.courier &&
        o.status != OrderStatus.placed &&
        o.courierId != currentUser?.id) {
      return false;
    }
    final next = _nextStatus(o, r);
    if (next == null) return false;
    processingOrders.add(o.id);
    notifyListeners();
    try {
      if (CloudflareBackend.configured) {
        final code = Uri.encodeComponent(o.id.replaceFirst('#', ''));
        try {
          if (next == OrderStatus.clientConfirmed) {
            await CloudflareBackend.post(
              '/api/orders/$code/confirm-delivery',
              const {},
            );
          } else {
            await CloudflareBackend.post('/api/orders/$code/status', {
              'status': next.api,
            });
          }
        } on ApiException catch (error) {
          // The answer may simply have been lost on a slow network: check what
          // the server really holds before reporting a failure.
          final id = o.id;
          await refresh(afterMutation: true);
          final fresh = _orderByCode(id);
          final done =
              fresh != null &&
              fresh.status == next &&
              (r != UserRole.courier || fresh.courierId == currentUser?.id);
          if (done) return true;
          lastError = apiMessage(error);
          return false;
        }
        _applyStatus(o, next, r);
        await refresh(afterMutation: true);
        return true;
      }
      _applyStatus(o, next, r);
      if (o.status == OrderStatus.clientConfirmed) {
        _recordOfflineSettlement(o);
      }
      if (o.clientId == 'guest-local') await _saveGuestOrders();
      return true;
    } finally {
      processingOrders.remove(o.id);
      notifyListeners();
    }
  }

  void _recordOfflineSettlement(MarketOrder order) {
    if (walletEntries.any(
      (entry) => entry.orderId == order.id && entry.type == 'delivery_fee',
    )) {
      return;
    }
    final commission = order.commissionAmount;
    final admin = users.where((user) => user.role == UserRole.admin);
    walletEntries.addAll([
      WalletEntry(
        id: 'sale-${order.id}',
        ownerId: order.merchantId,
        type: 'sale',
        amount: order.subtotal - commission,
        orderId: order.id,
        createdAt: DateTime.now(),
      ),
      WalletEntry(
        id: 'delivery-${order.id}',
        ownerId: order.courierId!,
        type: 'delivery_fee',
        amount: order.deliveryFee,
        orderId: order.id,
        createdAt: DateTime.now(),
      ),
      if (admin.isNotEmpty)
        WalletEntry(
          id: 'commission-${order.id}',
          ownerId: admin.first.id,
          type: 'commission',
          amount: commission,
          orderId: order.id,
          createdAt: DateTime.now(),
        ),
    ]);
  }

  // ---------------------------------------------------------------------
  // Dashboards
  // ---------------------------------------------------------------------

  /// Platform activity for one calendar day (administrator dashboard).
  DayStats statsFor(DateTime day) {
    final dayOrders = orders.where((o) => sameDay(o.createdAt, day)).toList();
    final live = dayOrders.where((o) => o.status != OrderStatus.cancelled);
    return DayStats(
      day: dayOf(day),
      orders: dayOrders,
      orderCount: live.length,
      deliveredCount: dayOrders
          .where((o) => o.status == OrderStatus.clientConfirmed)
          .length,
      sales: dayOrders.where((o) => o.paid).fold<int>(0, (s, o) => s + o.total),
      commission: dayOrders
          .where((o) => o.paid)
          .fold<int>(0, (s, o) => s + o.commissionAmount),
      newUsers: users
          .where((u) => u.createdAt != null && sameDay(u.createdAt!, day))
          .length,
    );
  }

  /// Delivery fees earned by the signed-in courier, one entry per day,
  /// newest first.
  List<DailyEarning> get dailyEarnings {
    final byDay = <DateTime, List<WalletEntry>>{};
    for (final entry in currentWalletEntries) {
      if (entry.type != 'delivery_fee') continue;
      byDay.putIfAbsent(dayOf(entry.createdAt), () => []).add(entry);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        DailyEarning(
          day: day,
          entries: byDay[day]!,
          amount: byDay[day]!.fold<int>(0, (s, e) => s + e.amount),
        ),
    ];
  }

  MarketOrder? orderForEntry(WalletEntry entry) {
    final reference = entry.orderId;
    return reference == null ? null : orderByReference(reference);
  }

  /// Finds an order from either its short display code or its server UUID.
  /// Notification payloads use the UUID while cards show the short code.
  MarketOrder? orderByReference(String reference) {
    for (final candidate in orders) {
      if (candidate.id == reference || candidate.serverId == reference) {
        return candidate;
      }
    }
    return null;
  }

  MarketOrder? orderForNotification(AppNotification notification) {
    final reference = notification.orderId;
    return reference == null ? null : orderByReference(reference);
  }

  Future<bool> addProduct({
    required String name,
    required String description,
    required String category,
    int? retail,
    required int wholesale,
    required String emoji,
    String? mediaUrl,
    ProductMediaType mediaType = ProductMediaType.image,
    List<String> ingredients = const [],
    List<String> allergens = const [],
    int preparationMinutes = 15,
    int? calories,
  }) async {
    final r = currentUser!.role;
    if (r != UserRole.restaurant && r != UserRole.supermarket) return false;
    lastError = null;
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.post('/api/products', {
          'name': name,
          'description': description,
          'category': category,
          'wholesalePrice': wholesale,
          'emoji': emoji,
          'mediaUrl': mediaUrl,
          'mediaType': mediaType.name,
          'ingredients': ingredients.join(', '),
          'allergens': allergens.join(', '),
          'preparationMinutes': preparationMinutes,
          'calories': calories,
          'kind': r == UserRole.supermarket ? 'grocery' : 'meal',
        });
        await refresh(afterMutation: true);
        return true;
      } catch (error) {
        lastError = apiMessage(error);
        notifyListeners();
        return false;
      }
    }
    final p = Product(
      id: 'p${products.length + 1}',
      ownerId: currentUser!.id,
      name: name,
      description: description,
      kind: r == UserRole.supermarket ? ProductKind.grocery : ProductKind.meal,
      retailPrice: r == UserRole.supermarket
          ? wholesale
          : customerPriceFor(wholesale, commissionPercent),
      wholesalePrice: wholesale,
      emoji: emoji,
      category: category,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      ingredients: ingredients,
      allergens: allergens,
      preparationMinutes: preparationMinutes,
      calories: calories,
      available: false,
      approvalStatus: 'pending',
    );
    products.insert(0, p);
    notifyListeners();
    return true;
  }

  Future<bool> reviewProduct(
    Product product, {
    required bool approve,
    int? retailPrice,
  }) async {
    lastError = null;
    if (currentUser?.role != UserRole.admin) return false;
    final calculatedPrice = product.kind == ProductKind.grocery
        ? retailPrice
        : customerPriceFor(product.wholesalePrice, commissionPercent);
    if (approve &&
        product.kind == ProductKind.grocery &&
        (calculatedPrice == null || calculatedPrice < product.wholesalePrice)) {
      lastError = apiMessage(const ApiException('invalid_retail_price'));
      return false;
    }
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.patch('/api/products/${product.id}/approval', {
          'status': approve ? 'approved' : 'rejected',
          if (product.kind == ProductKind.grocery && approve)
            'retailPrice': calculatedPrice,
        });
        await refresh(afterMutation: true);
        return true;
      } catch (error) {
        lastError = apiMessage(error);
        return false;
      }
    }
    final wasApproved = product.approvalStatus == 'approved';
    product.approvalStatus = approve ? 'approved' : 'rejected';
    if (!approve) {
      product.available = false;
    } else if (!wasApproved) {
      product.available = true;
    }
    if (approve) product.retailPrice = calculatedPrice!;
    notifyListeners();
    return true;
  }

  /// Saves the commission and the delivery fee. Every new order uses the new
  /// values immediately; open apps pick them up at their next refresh.
  Future<bool> updateSettings(int percent, int fee) async {
    lastError = null;
    if (currentUser?.role != UserRole.admin) return false;
    if (percent < 0 || percent > 100 || fee < 0) {
      lastError = apiMessage(const ApiException('invalid_settings'));
      return false;
    }
    if (CloudflareBackend.configured) {
      try {
        final saved = await CloudflareBackend.patch('/api/settings', {
          'commissionPercent': percent,
          'deliveryFee': fee,
        });
        _applySettings(saved);
      } catch (error) {
        lastError = apiMessage(error);
        return false;
      }
    }
    commissionPercent = percent;
    deliveryFee = fee;
    for (final product in products) {
      if (product.kind == ProductKind.meal) {
        product.retailPrice = customerPriceFor(product.wholesalePrice, percent);
      }
    }
    notifyListeners();
    return true;
  }

  Future<String?> uploadMedia({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    lastError = null;
    if (!CloudflareBackend.configured) return 'assets/marketplace_hero.png';
    try {
      final result = await CloudflareBackend.upload(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
      return CloudflareBackend.absoluteUrl(result['url'] as String?);
    } catch (error) {
      lastError = error is ApiException && error.code.startsWith('http_5')
          ? tr(
              'Le média n’a pas pu être envoyé. Réessayez.',
              'تعذر رفع الملف. حاول مرة أخرى.',
            )
          : apiMessage(error);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
    String? businessName,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) return false;
    lastError = null;
    try {
      if (CloudflareBackend.configured) {
        await CloudflareBackend.patch('/api/profile', {
          'name': name,
          'email': email,
          'phone': phone,
          'address': address,
          'businessName': businessName,
          'avatarUrl': avatarUrl,
        });
      }
      user
        ..name = name
        ..email = email
        ..phone = phone
        ..address = address
        ..businessName = businessName
        ..avatarUrl = avatarUrl;
      await _saveSession();
      notifyListeners();
      return true;
    } catch (error) {
      lastError = error is ApiException && error.code == 'email_exists'
          ? apiMessage(error)
          : tr(
              'Les informations n’ont pas pu être enregistrées.',
              'تعذر حفظ المعلومات.',
            );
      notifyListeners();
      return false;
    }
  }

  Future<void> markNotificationRead(AppNotification notification) async {
    if (notification.read) return;
    notification.read = true;
    notifyListeners();
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.patch(
          '/api/notifications/${notification.id}/read',
          const {'read': true},
        );
      } catch (_) {
        notification.read = false;
        notifyListeners();
      }
    }
  }

  Future<void> markAllNotificationsRead() async {
    final unread = notifications.where((n) => !n.read).toList();
    for (final notification in unread) {
      notification.read = true;
    }
    notifyListeners();
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.patch('/api/notifications/read-all', const {
          'read': true,
        });
      } catch (_) {
        for (final notification in unread) {
          notification.read = false;
        }
        notifyListeners();
      }
    }
  }

  Future<bool> addCategory(String name, ProductKind kind) async {
    lastError = null;
    final clean = name.trim();
    if (currentUser?.role != UserRole.admin) return false;
    if (clean.length < 2) {
      lastError = tr(
        'Le nom de la catégorie doit contenir au moins 2 caractères.',
        'يجب أن يحتوي اسم التصنيف على حرفين على الأقل.',
      );
      return false;
    }
    if (categories.any(
      (c) => c.kind == kind && c.name.toLowerCase() == clean.toLowerCase(),
    )) {
      lastError = apiMessage(const ApiException('category_exists'));
      return false;
    }
    try {
      if (CloudflareBackend.configured) {
        await CloudflareBackend.post('/api/categories', {
          'name': clean,
          'kind': kind.name,
        });
        await refresh(afterMutation: true);
        // Shown at once even if the follow-up refresh was slow.
        if (!categories.any((c) => c.name == clean && c.kind == kind)) {
          categories.add(
            AppCategory(
              id: 'new-${categories.length}',
              name: clean,
              kind: kind,
            ),
          );
        }
        notifyListeners();
      } else {
        categories.add(
          AppCategory(
            id: 'category-${categories.length + 1}',
            name: clean,
            kind: kind,
          ),
        );
        notifyListeners();
      }
      return true;
    } catch (error) {
      lastError = apiMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleCategory(AppCategory category) async {
    if (currentUser?.role != UserRole.admin) return false;
    category.active = !category.active;
    notifyListeners();
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.patch('/api/categories/${category.id}/active', {
          'active': category.active,
        });
      } catch (error) {
        category.active = !category.active;
        lastError = apiMessage(error);
        notifyListeners();
        return false;
      }
    }
    return true;
  }

  Future<bool> toggleProduct(Product p) async {
    if (p.approvalStatus != 'approved') return false;
    p.available = !p.available;
    notifyListeners();
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.patch('/api/products/${p.id}/active', {
          'active': p.available,
        });
      } catch (error) {
        p.available = !p.available;
        lastError = apiMessage(error);
        notifyListeners();
        return false;
      }
    }
    return true;
  }

  Future<bool> toggleUser(AppUser u) async {
    if (u.role == UserRole.admin) return false;
    u.active = !u.active;
    notifyListeners();
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.patch('/api/users/${u.id}/active', {
          'active': u.active,
        });
      } catch (error) {
        u.active = !u.active;
        lastError = apiMessage(error);
        notifyListeners();
        return false;
      }
    }
    return true;
  }

  /// Records a full or partial payment made by the administrator to a partner.
  /// The negative wallet entry preserves the audit trail and makes the
  /// remaining credit available immediately through [walletBalanceFor].
  Future<bool> settleAccount(AppUser user, {int? amount}) async {
    lastError = null;
    if (currentUser?.role != UserRole.admin ||
        ![
          UserRole.courier,
          UserRole.restaurant,
          UserRole.supermarket,
        ].contains(user.role)) {
      lastError = apiMessage(const ApiException('settlement_forbidden'));
      return false;
    }
    final balance = walletBalanceFor(user.id);
    if (balance <= 0) return true;
    final paidAmount = amount ?? balance;
    if (paidAmount <= 0 || paidAmount > balance) {
      lastError = apiMessage(const ApiException('invalid_payment_amount'));
      return false;
    }
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.post('/api/wallet/${user.id}/settle', {
          'amount': paidAmount,
        });
        await refresh(afterMutation: true);
        return true;
      } catch (error) {
        lastError = apiMessage(error);
        notifyListeners();
        return false;
      }
    }
    walletEntries.insert(
      0,
      WalletEntry(
        id: 'admin-payment-${DateTime.now().microsecondsSinceEpoch}',
        ownerId: user.id,
        type: 'admin_payment',
        amount: -paidAmount,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  Future<bool> createManagedAccount({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? businessName,
    String phone = '',
  }) async {
    lastError = null;
    final cleanName = name.trim();
    final normalized = email.trim().toLowerCase();
    if (currentUser?.role != UserRole.admin || role == UserRole.admin) {
      lastError = apiMessage(const ApiException('forbidden'));
      return false;
    }
    if (cleanName.length < 2) {
      lastError = tr(
        'Saisissez le nom complet (2 caractères minimum).',
        'أدخل الاسم الكامل (حرفان على الأقل).',
      );
      return false;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      lastError = tr(
        'Saisissez une adresse e-mail valide.',
        'أدخل بريداً إلكترونياً صحيحاً.',
      );
      return false;
    }
    if (password.length < 8) {
      lastError = tr(
        'Le mot de passe doit contenir au moins 8 caractères.',
        'يجب أن تحتوي كلمة المرور على 8 أحرف على الأقل.',
      );
      return false;
    }
    if ((role == UserRole.restaurant || role == UserRole.supermarket) &&
        (businessName?.trim().isEmpty ?? true)) {
      lastError = tr(
        'Saisissez le nom de l’établissement.',
        'أدخل اسم المؤسسة.',
      );
      return false;
    }
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.post('/api/users', {
          'name': cleanName,
          'email': normalized,
          'password': password,
          'role': role.name,
          'businessName': businessName?.trim(),
          'phone': phone.trim(),
        });
        await refresh(afterMutation: true);
        return true;
      } catch (error) {
        lastError = apiMessage(error);
        notifyListeners();
        return false;
      }
    }
    if (users.any((u) => u.email.toLowerCase() == normalized)) {
      lastError = apiMessage(const ApiException('email_exists'));
      return false;
    }
    users.add(
      AppUser(
        id: 'u${DateTime.now().microsecondsSinceEpoch}',
        name: cleanName,
        email: normalized,
        password: password,
        role: role,
        businessName: businessName?.trim().isEmpty ?? true
            ? null
            : businessName!.trim(),
        phone: phone.trim(),
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  Future<bool> requestWithdrawal() async {
    lastError = null;
    if (walletBalance <= 0) return false;
    if (!CloudflareBackend.configured) {
      walletEntries.insert(
        0,
        WalletEntry(
          id: 'withdrawal-${DateTime.now().millisecondsSinceEpoch}',
          ownerId: currentUser!.id,
          type: 'withdrawal_pending',
          amount: -walletBalance,
          createdAt: DateTime.now(),
        ),
      );
      notifyListeners();
      return true;
    }
    try {
      await CloudflareBackend.post('/api/withdrawals', {
        'amount': walletBalance,
      });
      await refresh(afterMutation: true);
      return true;
    } catch (error) {
      lastError = error is ApiException && error.network
          ? apiMessage(error)
          : tr(
              'La demande de retrait n’a pas pu être envoyée.',
              'تعذر إرسال طلب السحب.',
            );
      notifyListeners();
      return false;
    }
  }

  void _seed() {
    users.addAll([
      AppUser(
        id: 'client1',
        name: 'Sofia Benali',
        email: 'client@wasla.dz',
        password: 'Demo123!',
        role: UserRole.client,
        phone: '+213 555 12 34 56',
        address: '28 rue des Oliviers',
      ),
      AppUser(
        id: 'courier1',
        name: 'Yacine Amari',
        email: 'livreur@wasla.dz',
        password: 'Demo123!',
        role: UserRole.courier,
      ),
      AppUser(
        id: 'restaurant1',
        name: 'Maya Chen',
        email: 'restaurant@wasla.dz',
        password: 'Demo123!',
        role: UserRole.restaurant,
        businessName: 'Maison Sage',
      ),
      AppUser(
        id: 'restaurant2',
        name: 'Omar Saadi',
        email: 'bistro@wasla.dz',
        password: 'Demo123!',
        role: UserRole.restaurant,
        businessName: 'Ember & Grain',
      ),
      AppUser(
        id: 'market1',
        name: 'Nora James',
        email: 'superette@wasla.dz',
        password: 'Demo123!',
        role: UserRole.supermarket,
        businessName: 'Marché Quotidien',
      ),
      AppUser(
        id: 'admin1',
        name: 'Administrateur',
        email: 'admin@wasla.dz',
        password: 'Admin123!',
        role: UserRole.admin,
      ),
    ]);
    for (final seeded in users) {
      seeded.createdAt = DateTime.now().subtract(const Duration(days: 30));
    }
    categories.addAll([
      AppCategory(id: 'cat-healthy', name: 'Healthy', kind: ProductKind.meal),
      AppCategory(id: 'cat-pasta', name: 'Pâtes', kind: ProductKind.meal),
      AppCategory(id: 'cat-burgers', name: 'Burgers', kind: ProductKind.meal),
      AppCategory(id: 'cat-fresh', name: 'Frais', kind: ProductKind.grocery),
      AppCategory(
        id: 'cat-bakery',
        name: 'Boulangerie',
        kind: ProductKind.grocery,
      ),
    ]);
    products.addAll([
      Product(
        id: 'p1',
        ownerId: 'restaurant1',
        name: 'Bowl poulet du jardin',
        description: 'Poulet aux herbes, quinoa et houmous',
        kind: ProductKind.meal,
        retailPrice: customerPriceFor(820, commissionPercent),
        wholesalePrice: 820,
        emoji: '🥗',
        category: 'Healthy',
        mediaUrl: 'assets/marketplace_hero.png',
        ingredients: const ['Poulet', 'Quinoa', 'Houmous', 'Herbes fraîches'],
        allergens: const ['Sésame'],
        preparationMinutes: 18,
        calories: 540,
        rating: 4.9,
      ),
      Product(
        id: 'p2',
        ownerId: 'restaurant1',
        name: 'Pâtes aux champignons',
        description: 'Crème, parmesan et champignons rôtis',
        kind: ProductKind.meal,
        retailPrice: customerPriceFor(910, commissionPercent),
        wholesalePrice: 910,
        emoji: '🍝',
        category: 'Pâtes',
        mediaUrl: 'assets/products/mushroom-pasta.png',
        ingredients: const ['Pâtes', 'Champignons', 'Crème', 'Parmesan'],
        allergens: const ['Gluten', 'Lait'],
        preparationMinutes: 20,
        calories: 680,
      ),
      Product(
        id: 'p3',
        ownerId: 'restaurant2',
        name: 'Smash burger',
        description: 'Double bœuf, cheddar et relish maison',
        kind: ProductKind.meal,
        retailPrice: customerPriceFor(740, commissionPercent),
        wholesalePrice: 740,
        emoji: '🍔',
        category: 'Burgers',
        mediaUrl: 'assets/products/smash-burger.png',
        ingredients: const ['Bœuf', 'Cheddar', 'Pain brioché', 'Relish'],
        allergens: const ['Gluten', 'Lait'],
        preparationMinutes: 16,
        calories: 790,
      ),
      Product(
        id: 'p4',
        ownerId: 'market1',
        name: 'Pack avocats bio',
        description: 'Quatre avocats mûrs',
        kind: ProductKind.grocery,
        retailPrice: 480,
        wholesalePrice: 390,
        emoji: '🥑',
        category: 'Frais',
        mediaUrl: 'assets/products/organic-avocados.png',
        ingredients: const ['Avocats bio'],
      ),
      Product(
        id: 'p5',
        ownerId: 'market1',
        name: 'Pain artisanal',
        description: 'Pain au levain du jour',
        kind: ProductKind.grocery,
        retailPrice: 320,
        wholesalePrice: 260,
        emoji: '🍞',
        category: 'Boulangerie',
        mediaUrl: 'assets/products/artisan-bread.png',
        ingredients: const ['Farine', 'Levain', 'Eau', 'Sel'],
        allergens: const ['Gluten'],
      ),
    ]);
    orders.addAll([
      MarketOrder(
        id: '#WS1047',
        clientId: 'client1',
        merchantId: 'restaurant1',
        courierId: 'courier1',
        items: [
          OrderItem(_snapshotProduct(products[0]), 1),
          OrderItem(_snapshotProduct(products[1]), 1),
        ],
        address: '28 rue des Oliviers',
        createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
        status: OrderStatus.pickedUp,
        paymentMethod: 'Carte',
        paid: true,
        commissionAmount:
            commissionForMerchantPrice(820, commissionPercent) +
            commissionForMerchantPrice(910, commissionPercent),
      ),
      MarketOrder(
        id: '#WS1046',
        clientId: 'client1',
        merchantId: 'market1',
        courierId: 'courier1',
        items: [OrderItem(_snapshotProduct(products[3]), 2)],
        address: '28 rue des Oliviers',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        status: OrderStatus.clientConfirmed,
        paid: true,
        commissionAmount: (480 - 390) * 2,
      ),
      MarketOrder(
        id: '#WS1045',
        clientId: 'client1',
        merchantId: 'restaurant2',
        items: [OrderItem(_snapshotProduct(products[2]), 2)],
        address: '28 rue des Oliviers',
        createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
        commissionAmount:
            commissionForMerchantPrice(740, commissionPercent) * 2,
      ),
    ]);
    walletEntries.addAll([
      WalletEntry(
        id: 'wallet-courier-1',
        ownerId: 'courier1',
        type: 'delivery_fee',
        amount: 200,
        orderId: '#WS1046',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      WalletEntry(
        id: 'wallet-market-1',
        ownerId: 'market1',
        type: 'sale',
        amount: 780,
        orderId: '#WS1046',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      WalletEntry(
        id: 'wallet-admin-1',
        ownerId: 'admin1',
        type: 'commission',
        amount: (480 - 390) * 2,
        orderId: '#WS1046',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
    notifications.addAll([
      AppNotification(
        id: 'notification-1',
        title: 'Commande en route',
        message: 'Votre livreur arrive avec la commande #WS1047.',
        type: 'order',
        orderId: '#WS1047',
        createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
      AppNotification(
        id: 'notification-2',
        title: 'Bienvenue sur Wasla',
        message: 'Votre espace est prêt. Découvrez les partenaires locaux.',
        type: 'account',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        read: true,
      ),
    ]);
  }
}
