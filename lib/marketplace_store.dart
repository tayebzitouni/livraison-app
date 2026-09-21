import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/cloudflare_backend.dart';
import 'domain.dart';

class MarketplaceStore extends ChangeNotifier {
  MarketplaceStore() {
    _seed();
    currentUser = _guestUser;
  }
  AppUser? currentUser;
  bool guestPersistence = false;
  Future<void> enableGuestPersistence() async {
    guestPersistence = true;
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

  Future<void> initializeGuest() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') == 'ar' ? 'ar' : 'fr';
    if (isGuest) {
      currentUser?.address = prefs.getString('guest_delivery_address') ?? '';
    }
    for (final row in prefs.getStringList('guest_cart') ?? <String>[]) {
      final parts = row.split(':');
      if (parts.length == 2) {
        cart[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }
    if (!CloudflareBackend.configured && currentUser?.id == 'guest-local') {
      for (final raw in prefs.getStringList('guest_orders') ?? <String>[]) {
        try {
          final row = jsonDecode(raw) as Map<String, dynamic>;
          if (orders.any((o) => o.id == row['id'])) continue;
          final items = (row['items'] as List<dynamic>).map((entry) {
            final item = entry as Map<String, dynamic>;
            final source = product(item['id'] as String);
            final snapshot = Product(
              id: source.id,
              ownerId: source.ownerId,
              name: source.name,
              description: source.description,
              kind: source.kind,
              retailPrice: (item['price'] as num).toInt(),
              wholesalePrice: source.wholesalePrice,
              emoji: source.emoji,
              category: source.category,
            );
            return OrderItem(snapshot, (item['quantity'] as num).toInt());
          }).toList();
          orders.insert(
            0,
            MarketOrder(
              id: row['id'] as String,
              clientId: 'guest-local',
              merchantId: row['merchantId'] as String,
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
    notifyListeners();
    if (!CloudflareBackend.configured || currentUser?.id != 'guest-local') {
      return;
    }
    var email = prefs.getString('guest_email');
    var password = prefs.getString('guest_password');
    if (email == null || password == null) {
      final random = Random.secure();
      email =
          'guest-${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}@wasla.local';
      password =
          '${random.nextInt(1 << 32)}${random.nextInt(1 << 32)}${random.nextInt(1 << 32)}';
      await prefs.setString('guest_email', email);
      await prefs.setString('guest_password', password);
    }
    try {
      var data = await CloudflareBackend.login(email, password);
      if (data != null && currentUser?.id == 'guest-local') {
        currentUser = AppUser(
          id: data['id'] as String,
          name: 'Invité',
          email: email,
          password: '',
          role: UserRole.client,
          address: prefs.getString('guest_delivery_address') ?? '',
        );
        await refresh();
        _startPolling();
      }
    } catch (_) {
      // Guest stays local if the live account cannot be created.
    }
    notifyListeners();
  }

  final users = <AppUser>[], products = <Product>[], orders = <MarketOrder>[];
  final walletEntries = <WalletEntry>[];
  final categories = <AppCategory>[];
  final notifications = <AppNotification>[];
  final cart = <String, int>{};
  final processingOrders = <String>{};
  Timer? _poller;
  Future<void>? _refreshTask;
  bool refreshing = false;
  String? lastError;
  List<WalletEntry> get currentWalletEntries =>
      walletEntries.where((entry) => entry.ownerId == currentUser?.id).toList();
  int get walletBalance =>
      currentWalletEntries.fold<int>(0, (sum, entry) => sum + entry.amount);
  int get unreadNotifications => notifications.where((n) => !n.read).length;
  List<AppCategory> categoriesFor(ProductKind kind) => categories
      .where((category) => category.active && category.kind == kind)
      .toList();
  AppUser user(String id) => users.firstWhere((u) => u.id == id);
  Product product(String id) => products.firstWhere((p) => p.id == id);
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
  List<Product> get cartProducts =>
      products.where((p) => cart.containsKey(p.id)).toList();
  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  int get cartSubtotal =>
      cartProducts.fold(0, (s, p) => s + p.retailPrice * cart[p.id]!);

  Future<bool> login(
    String email,
    String password, [
    UserRole? selected,
  ]) async {
    lastError = null;
    final normalized = email.trim().toLowerCase();
    if (CloudflareBackend.configured) {
      try {
        final data = await CloudflareBackend.login(normalized, password);
        if (data == null) {
          lastError = 'E-mail ou mot de passe incorrect.';
          return false;
        }
        final role = _role(data['role'] as String?);
        if (selected != null && role != UserRole.admin && role != selected) {
          await CloudflareBackend.logout();
          lastError = 'Ce compte ne correspond pas à ce rôle.';
          return false;
        }
        currentUser = AppUser(
          id: data['id'] as String,
          name: (data['name'] ?? normalized) as String,
          email: normalized,
          password: '',
          role: role,
          businessName: data['business_name'] as String?,
          phone: data['phone'] as String? ?? '',
          address: data['address'] as String? ?? '',
          avatarUrl: CloudflareBackend.absoluteUrl(
            data['avatar_url'] as String?,
          ),
        );
        await refresh();
        _startPolling();
        showAuth = false;
        notifyListeners();
        return true;
      } catch (_) {
        lastError = 'Connexion au serveur impossible.';
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

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? businessName,
    String phone = '',
    String adminSetupToken = '',
  }) async {
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
        lastError = 'Code administrateur invalide ou compte déjà créé.';
        return false;
      }
    }
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.post('/api/auth/signup', {
          'name': name,
          'email': email,
          'password': password,
          'role': role.name,
          'businessName': businessName,
          'phone': phone,
        });
        return login(email, password, role);
      } catch (_) {
        lastError = 'Ce compte existe déjà ou les données sont invalides.';
        return false;
      }
    }
    if (users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return false;
    }
    currentUser = AppUser(
      id: 'u${users.length + 1}',
      name: name,
      email: email,
      password: password,
      role: role,
      businessName: businessName,
      phone: phone,
    );
    users.add(currentUser!);
    showAuth = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _poller?.cancel();
    if (CloudflareBackend.configured) await CloudflareBackend.logout();
    currentUser = _guestUser;
    showAuth = false;
    cart.clear();
    pendingOrderNote = '';
    notifyListeners();
    if (guestPersistence) await initializeGuest();
  }

  Future<void> refresh({bool afterMutation = false}) async {
    if (!CloudflareBackend.configured || currentUser == null) return;
    final activeRefresh = _refreshTask;
    if (activeRefresh != null) {
      await activeRefresh;
      if (!afterMutation) return;
    }
    _refreshTask = _performRefresh();
    try {
      await _refreshTask;
    } finally {
      _refreshTask = null;
    }
  }

  Future<void> _performRefresh() async {
    final activeUser = currentUser;
    if (activeUser == null) return;
    refreshing = true;
    try {
      final role = activeUser.role;
      final responses = await Future.wait<dynamic>([
        CloudflareBackend.get('/api/products'),
        CloudflareBackend.get('/api/orders'),
        CloudflareBackend.get(
          role == UserRole.admin ? '/api/wallet?owner=all' : '/api/wallet',
        ),
        CloudflareBackend.get('/api/categories'),
        CloudflareBackend.get('/api/notifications'),
        CloudflareBackend.get('/api/settings'),
        if (role == UserRole.admin) CloudflareBackend.get('/api/users'),
      ]);
      if (currentUser?.id != activeUser.id) return;
      final productRows = _results(responses[0]);
      products
        ..clear()
        ..addAll(productRows.map(_productFromJson));
      cart.removeWhere((id, _) => !products.any((p) => p.id == id));

      final orderRows = _results(responses[1]);
      orders
        ..clear()
        ..addAll(orderRows.map(_orderFromJson));

      final walletRows = _results(responses[2]);
      walletEntries
        ..clear()
        ..addAll(walletRows.map(_walletFromJson));

      final categoryRows = _results(responses[3]);
      categories
        ..clear()
        ..addAll(categoryRows.map(_categoryFromJson));

      final notificationRows = _results(responses[4]);
      notifications
        ..clear()
        ..addAll(notificationRows.map(_notificationFromJson));
      final settings = responses[5] as Map<String, dynamic>;
      commissionPercent =
          (settings['commission_percent'] as num?)?.toInt() ?? 10;
      deliveryFee = (settings['delivery_fee'] as num?)?.toInt() ?? 200;

      if (role == UserRole.admin) {
        final userRows = _results(responses[6]);
        users
          ..clear()
          ..addAll(userRows.map(_userFromJson));
      }
      lastError = null;
      notifyListeners();
    } catch (_) {
      lastError = 'Actualisation impossible. Vérifiez votre connexion.';
    } finally {
      refreshing = false;
    }
  }

  List<Map<String, dynamic>> _results(dynamic response) =>
      ((response as Map<String, dynamic>)['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

  Product _productFromJson(Map<String, dynamic> r) => Product(
    id: r['id'] as String,
    ownerId: r['owner_id'] as String,
    name: r['name'] as String,
    description: r['description'] as String? ?? '',
    kind: r['kind'] == 'grocery' ? ProductKind.grocery : ProductKind.meal,
    retailPrice: (r['retail_price'] as num).toInt(),
    wholesalePrice: (r['wholesale_price'] as num?)?.toInt() ?? 0,
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

  MarketOrder _orderFromJson(Map<String, dynamic> r) {
    final rawItems = (r['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final items = rawItems.map((item) {
      final id = item['product_id'] as String;
      final existing = products.where((p) => p.id == id);
      final p = existing.isNotEmpty
          ? existing.first
          : Product(
              id: id,
              ownerId: r['merchant_id'] as String,
              name: item['product_name'] as String? ?? 'Article',
              description: item['description'] as String? ?? '',
              kind: item['kind'] == 'grocery'
                  ? ProductKind.grocery
                  : ProductKind.meal,
              retailPrice: (item['retail_unit_price'] as num).toInt(),
              wholesalePrice: (item['wholesale_unit_price'] as num).toInt(),
              emoji: item['emoji'] as String? ?? '🍽️',
              category: item['category'] as String? ?? 'Commande',
              mediaUrl: CloudflareBackend.absoluteUrl(
                item['media_url'] as String?,
              ),
              mediaType: item['media_type'] == 'video'
                  ? ProductMediaType.video
                  : ProductMediaType.image,
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
      id: r['code'] as String,
      clientId: r['customer_id'] as String,
      merchantId: r['merchant_id'] as String,
      courierId: r['courier_id'] as String?,
      items: items,
      address: r['address'] as String? ?? '',
      note: r['customer_note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
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
    );
  }

  WalletEntry _walletFromJson(Map<String, dynamic> r) => WalletEntry(
    id: r['id'] as String,
    ownerId: r['owner_id'] as String,
    type: r['entry_type'] as String,
    amount: (r['amount'] as num).toInt(),
    orderId: r['order_id'] as String?,
    createdAt:
        DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
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
        createdAt:
            DateTime.tryParse(r['created_at'] as String? ?? '') ??
            DateTime.now(),
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
    if (CloudflareBackend.configured) {
      _poller = Timer.periodic(const Duration(seconds: 12), (_) => refresh());
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
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
    if (!guestPersistence || CloudflareBackend.configured) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'guest_orders',
      orders
          .where((o) => o.clientId == 'guest-local')
          .map(
            (o) => jsonEncode({
              'id': o.id,
              'merchantId': o.merchantId,
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
                      'price': i.product.retailPrice,
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
        .map((e) => OrderItem(product(e.key), e.value))
        .toList();
    return MarketOrder(
      id: '#WS${1048 + orders.length}',
      clientId: currentUser!.id,
      merchantId: product(cart.keys.first).ownerId,
      items: items,
      address: address,
      note: note.trim(),
      createdAt: DateTime.now(),
      paymentMethod: 'Paiement à la livraison',
      deliveryFee: deliveryFee,
      commissionAmount:
          (items.fold<int>(0, (s, i) => s + i.total) * commissionPercent / 100)
              .round(),
    );
  }

  Future<MarketOrder?> checkout(
    String address,
    String payment, {
    String note = '',
  }) async {
    if (cart.isEmpty || currentUser?.role != UserRole.client) return null;
    final items = cart.entries
        .map((e) => OrderItem(product(e.key), e.value))
        .toList();
    if (CloudflareBackend.configured && currentUser?.id != 'guest-local') {
      try {
        final response = await CloudflareBackend.post('/api/orders', {
          'address': address,
          'paymentMethod': payment,
          'note': note.trim(),
          'items': items
              .map((i) => {'productId': i.product.id, 'quantity': i.quantity})
              .toList(),
        });
        cart.clear();
        pendingOrderNote = '';
        if (isGuest && guestPersistence) await _saveGuestCart();
        await refresh(afterMutation: true);
        final code = response['code'] as String?;
        final matches = orders.where((o) => o.id == code);
        await saveDeliveryAddress(address);
        notifyListeners();
        if (matches.isNotEmpty) return matches.first;
      } catch (_) {
        lastError = null;
      }
    }
    return _completeLocalCheckout(address, payment, note, items);
  }

  MarketOrder _completeLocalCheckout(
    String address,
    String payment,
    String note,
    List<OrderItem> items,
  ) {
    final order = MarketOrder(
      id: '#WS${1048 + orders.length}',
      clientId: currentUser!.id,
      merchantId: product(cart.keys.first).ownerId,
      items: items,
      address: address,
      note: note.trim(),
      createdAt: DateTime.now(),
      paymentMethod: payment,
      paid: payment != 'Paiement à la livraison',
      deliveryFee: deliveryFee,
      commissionAmount:
          (items.fold<int>(0, (s, i) => s + i.total) * commissionPercent / 100)
              .round(),
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
    UserRole.client => orders.where((o) => o.clientId == u.id).toList(),
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
  String? action(MarketOrder o, UserRole r) => switch ((r, o.status)) {
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
  Future<bool> advance(MarketOrder o, UserRole r) async {
    if (processingOrders.contains(o.id)) return false;
    if ((r == UserRole.restaurant || r == UserRole.supermarket) &&
        currentUser?.id != o.merchantId) {
      return false;
    }
    if (r == UserRole.courier &&
        o.status != OrderStatus.placed &&
        o.courierId != currentUser?.id) {
      return false;
    }
    final previous = o.status;
    final previousCourier = o.courierId;
    processingOrders.add(o.id);
    switch ((r, o.status)) {
      case (UserRole.courier, OrderStatus.placed):
        o.courierId = currentUser!.id;
        o.status = OrderStatus.courierValidated;
      case (
        UserRole.restaurant || UserRole.supermarket,
        OrderStatus.courierValidated,
      ):
        o.status = OrderStatus.merchantAccepted;
      case (
        UserRole.restaurant || UserRole.supermarket,
        OrderStatus.merchantAccepted,
      ):
        o.status = OrderStatus.preparing;
      case (UserRole.restaurant || UserRole.supermarket, OrderStatus.preparing):
        o.status = OrderStatus.ready;
      case (UserRole.courier, OrderStatus.ready):
        o.status = OrderStatus.pickedUp;
      case (UserRole.courier, OrderStatus.pickedUp):
        o.status = OrderStatus.delivered;
      case (UserRole.client, OrderStatus.delivered):
        o.status = OrderStatus.clientConfirmed;
        o.paid = true;
      default:
        processingOrders.remove(o.id);
        return false;
    }
    if (CloudflareBackend.configured) {
      try {
        final code = Uri.encodeComponent(o.id.replaceFirst('#', ''));
        if (o.status == OrderStatus.clientConfirmed) {
          await CloudflareBackend.post(
            '/api/orders/$code/confirm-delivery',
            const {},
          );
        } else {
          await CloudflareBackend.post('/api/orders/$code/status', {
            'status': o.status.api,
          });
        }
        await refresh(afterMutation: true);
        processingOrders.remove(o.id);
        notifyListeners();
        return true;
      } catch (_) {
        o.status = previous;
        o.courierId = previousCourier;
        lastError = 'Cette action a échoué. La commande a été actualisée.';
        await refresh(afterMutation: true);
        processingOrders.remove(o.id);
        notifyListeners();
        return false;
      }
    }
    if (o.status == OrderStatus.clientConfirmed) _recordOfflineSettlement(o);
    if (o.clientId == 'guest-local') await _saveGuestOrders();
    processingOrders.remove(o.id);
    notifyListeners();
    return true;
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
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.post('/api/products', {
          'name': name,
          'description': description,
          'category': category,
          'retailPrice': wholesale,
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
      } catch (_) {
        lastError = 'Le produit n’a pas pu être publié.';
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
      retailPrice: wholesale,
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
    if (currentUser?.role != UserRole.admin ||
        (approve &&
            (retailPrice == null || retailPrice < product.wholesalePrice))) {
      return false;
    }
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.patch('/api/products/${product.id}/approval', {
          'status': approve ? 'approved' : 'rejected',
          'retailPrice': retailPrice,
        });
        await refresh(afterMutation: true);
        return true;
      } catch (_) {
        lastError = 'Validation du produit impossible.';
        return false;
      }
    }
    product.approvalStatus = approve ? 'approved' : 'rejected';
    product.available = approve;
    if (approve) product.retailPrice = retailPrice!;
    notifyListeners();
    return true;
  }

  Future<bool> updateSettings(int percent, int fee) async {
    if (currentUser?.role != UserRole.admin ||
        percent < 0 ||
        percent > 100 ||
        fee < 0) {
      return false;
    }
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.patch('/api/settings', {
          'commissionPercent': percent,
          'deliveryFee': fee,
        });
      } catch (_) {
        lastError = 'Paramètres non enregistrés.';
        return false;
      }
    }
    commissionPercent = percent;
    deliveryFee = fee;
    notifyListeners();
    return true;
  }

  Future<String?> uploadMedia({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (!CloudflareBackend.configured) return 'assets/marketplace_hero.png';
    try {
      final result = await CloudflareBackend.upload(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
      return CloudflareBackend.absoluteUrl(result['url'] as String?);
    } catch (_) {
      lastError = 'Le média n’a pas pu être envoyé.';
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
      notifyListeners();
      return true;
    } catch (_) {
      lastError = 'Les informations n’ont pas pu être enregistrées.';
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
    if (currentUser?.role != UserRole.admin || name.trim().isEmpty) {
      return false;
    }
    try {
      if (CloudflareBackend.configured) {
        await CloudflareBackend.post('/api/categories', {
          'name': name.trim(),
          'kind': kind.name,
        });
        await refresh(afterMutation: true);
      } else {
        categories.add(
          AppCategory(
            id: 'category-${categories.length + 1}',
            name: name.trim(),
            kind: kind,
          ),
        );
        notifyListeners();
      }
      return true;
    } catch (_) {
      lastError = 'La catégorie n’a pas pu être créée.';
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
      } catch (_) {
        category.active = !category.active;
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
      } catch (_) {
        p.available = !p.available;
        lastError = 'La disponibilité n’a pas pu être modifiée.';
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
      } catch (_) {
        u.active = !u.active;
        lastError = 'Le compte n’a pas pu être modifié.';
        notifyListeners();
        return false;
      }
    }
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
    if (currentUser?.role != UserRole.admin ||
        role == UserRole.admin ||
        name.trim().length < 2 ||
        !email.contains('@') ||
        password.length < 8 ||
        ((role == UserRole.restaurant || role == UserRole.supermarket) &&
            (businessName?.trim().isEmpty ?? true))) {
      lastError = 'Informations de compte invalides.';
      return false;
    }
    final normalized = email.trim().toLowerCase();
    if (CloudflareBackend.configured) {
      try {
        await CloudflareBackend.post('/api/users', {
          'name': name.trim(),
          'email': normalized,
          'password': password,
          'role': role.name,
          'businessName': businessName?.trim(),
          'phone': phone.trim(),
        });
        await refresh(afterMutation: true);
        return true;
      } catch (_) {
        lastError = 'Ce compte existe déjà ou les données sont invalides.';
        notifyListeners();
        return false;
      }
    }
    if (users.any((u) => u.email.toLowerCase() == normalized)) {
      lastError = 'Cette adresse e-mail est déjà utilisée.';
      return false;
    }
    users.add(
      AppUser(
        id: 'u${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        email: normalized,
        password: password,
        role: role,
        businessName: businessName?.trim().isEmpty ?? true
            ? null
            : businessName!.trim(),
        phone: phone.trim(),
      ),
    );
    notifyListeners();
    return true;
  }

  Future<bool> requestWithdrawal() async {
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
    } catch (_) {
      lastError = 'La demande de retrait n’a pas pu être envoyée.';
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
        retailPrice: 1490,
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
        retailPrice: 1650,
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
        retailPrice: 1380,
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
        retailPrice: 640,
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
        retailPrice: 480,
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
        items: [OrderItem(products[0], 1), OrderItem(products[1], 1)],
        address: '28 rue des Oliviers',
        createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
        status: OrderStatus.pickedUp,
        paymentMethod: 'Carte',
        paid: true,
      ),
      MarketOrder(
        id: '#WS1046',
        clientId: 'client1',
        merchantId: 'market1',
        courierId: 'courier1',
        items: [OrderItem(products[3], 2)],
        address: '28 rue des Oliviers',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        status: OrderStatus.clientConfirmed,
        paid: true,
        commissionAmount: 500,
      ),
      MarketOrder(
        id: '#WS1045',
        clientId: 'client1',
        merchantId: 'restaurant2',
        items: [OrderItem(products[2], 2)],
        address: '28 rue des Oliviers',
        createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
        commissionAmount: 276,
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
        amount: 500,
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
