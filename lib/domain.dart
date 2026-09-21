enum UserRole { client, courier, restaurant, supermarket, admin }

enum ProductKind { meal, grocery }

enum ProductMediaType { image, video }

enum OrderStatus {
  placed,
  courierValidated,
  merchantAccepted,
  preparing,
  ready,
  pickedUp,
  delivered,
  clientConfirmed,
  cancelled,
}

extension UserRoleUi on UserRole {
  String get label => switch (this) {
    UserRole.client => 'Client',
    UserRole.courier => 'Livreur',
    UserRole.restaurant => 'Restaurant',
    UserRole.supermarket => 'Supérette',
    UserRole.admin => 'Administrateur',
  };
  String get plural => switch (this) {
    UserRole.client => 'Clients',
    UserRole.courier => 'Livreurs',
    UserRole.restaurant => 'Restaurants',
    UserRole.supermarket => 'Supérettes',
    UserRole.admin => 'Administrateurs',
  };
}

extension OrderStatusUi on OrderStatus {
  String get label => switch (this) {
    OrderStatus.placed => 'En attente du livreur',
    OrderStatus.courierValidated => 'Livreur confirmé',
    OrderStatus.merchantAccepted => 'Acceptée',
    OrderStatus.preparing => 'En préparation',
    OrderStatus.ready => 'Prête à récupérer',
    OrderStatus.pickedUp => 'En route',
    OrderStatus.delivered => 'Livré · confirmation requise',
    OrderStatus.clientConfirmed => 'Réception confirmée',
    OrderStatus.cancelled => 'Annulée',
  };
  double get progress => switch (this) {
    OrderStatus.placed => .1,
    OrderStatus.courierValidated => .25,
    OrderStatus.merchantAccepted => .4,
    OrderStatus.preparing => .56,
    OrderStatus.ready => .72,
    OrderStatus.pickedUp => .88,
    OrderStatus.delivered => .96,
    OrderStatus.clientConfirmed => 1,
    OrderStatus.cancelled => 0,
  };
  String get api => switch (this) {
    OrderStatus.placed => 'placed',
    OrderStatus.courierValidated => 'courier_validated',
    OrderStatus.merchantAccepted => 'merchant_accepted',
    OrderStatus.preparing => 'preparing',
    OrderStatus.ready => 'ready',
    OrderStatus.pickedUp => 'picked_up',
    OrderStatus.delivered => 'delivered',
    OrderStatus.clientConfirmed => 'client_confirmed',
    OrderStatus.cancelled => 'cancelled',
  };
}

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.password,
    this.businessName,
    this.phone = '',
    this.address = '',
    this.avatarUrl,
    this.active = true,
  });
  final String id, password;
  String name, email, phone, address;
  final UserRole role;
  String? businessName, avatarUrl;
  bool active;
}

class Product {
  Product({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.kind,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.emoji,
    required this.category,
    this.mediaUrl,
    this.mediaType = ProductMediaType.image,
    this.ingredients = const [],
    this.allergens = const [],
    this.preparationMinutes = 15,
    this.calories,
    this.merchantName,
    this.available = true,
    this.approvalStatus = 'approved',
    this.rating = 4.8,
  });
  final String id, ownerId, name, description, emoji, category;
  final String? mediaUrl;
  final ProductMediaType mediaType;
  final List<String> ingredients, allergens;
  final int preparationMinutes;
  final int? calories;
  final String? merchantName;
  final ProductKind kind;
  int retailPrice, wholesalePrice;
  bool available;
  String approvalStatus;
  double rating;
}

class AppCategory {
  AppCategory({
    required this.id,
    required this.name,
    required this.kind,
    this.active = true,
  });

  final String id, name;
  final ProductKind kind;
  bool active;
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.orderId,
    this.read = false,
  });

  final String id, title, message, type;
  final String? orderId;
  final DateTime createdAt;
  bool read;
}

class OrderItem {
  OrderItem(this.product, this.quantity);
  final Product product;
  int quantity;
  int get total => product.retailPrice * quantity;
}

class MarketOrder {
  MarketOrder({
    required this.id,
    required this.clientId,
    required this.merchantId,
    required this.items,
    required this.address,
    required this.createdAt,
    this.merchantName,
    this.clientName,
    this.courierName,
    this.courierId,
    this.status = OrderStatus.placed,
    this.note = '',
    this.paymentMethod = 'Paiement à la livraison',
    this.paid = false,
    this.deliveryFee = 200,
    this.commissionAmount = 0,
  });
  final String id, clientId, merchantId, address, note;
  final String? merchantName;
  final String? clientName;
  final String? courierName;
  final List<OrderItem> items;
  final DateTime createdAt;
  String? courierId;
  OrderStatus status;
  String paymentMethod;
  bool paid;
  final int deliveryFee, commissionAmount;
  int get subtotal => items.fold(0, (s, i) => s + i.total);
  int get total => subtotal + deliveryFee;
}

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.orderId,
  });

  final String id, ownerId, type;
  final String? orderId;
  final int amount;
  final DateTime createdAt;
}
