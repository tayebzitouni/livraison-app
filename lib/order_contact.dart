import 'package:url_launcher/url_launcher.dart';

import 'domain.dart';

const waslaWhatsAppLocal = '0668813239';
const waslaWhatsAppE164 = '213668813239';

String waslaWhatsAppMessage({
  required MarketOrder order,
  required String clientName,
  required String phone,
  required String merchant,
}) {
  final items = order.items
      .map(
        (item) => '- ${item.quantity}× ${item.product.name} (${item.total} DA)',
      )
      .join('\n');
  final note = order.note.trim().isEmpty ? 'Aucune' : order.note.trim();
  final address = order.address.trim().isEmpty
      ? 'À confirmer'
      : order.address.trim();
  return '''
Commande Wasla ${order.id}
Client: $clientName
Téléphone: $phone
Adresse: $address
Commerce: $merchant
Articles:
$items
Notes: $note
Livraison: ${order.deliveryFee} DA
Total: ${order.total} DA
Paiement: à la livraison
'''
      .trim();
}

/// Turns a phone number typed by a person into the digits WhatsApp expects.
/// Algerian local numbers (05…, 06…, 07…) get the 213 country code.
String? whatsAppNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('+')) {
    digits = digits.substring(1);
  } else if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = '213${digits.substring(1)}';
  }
  digits = digits.replaceAll('+', '');
  return digits.length >= 9 && digits.length <= 15 ? digits : null;
}

List<Uri> whatsAppUrisFor(String e164, String message) {
  final encoded = Uri.encodeComponent(message);
  return [
    Uri.parse('whatsapp://send?phone=$e164&text=$encoded'),
    Uri.parse('https://api.whatsapp.com/send?phone=$e164&text=$encoded'),
    Uri.parse('https://wa.me/$e164?text=$encoded'),
  ];
}

List<Uri> waslaWhatsAppUris(String message) =>
    whatsAppUrisFor(waslaWhatsAppE164, message);

String waslaCartWhatsAppMessage({
  required String clientName,
  required String phone,
  required String address,
  required String merchant,
  required String items,
  required String note,
  required int deliveryFee,
  required int total,
}) {
  final cleanNote = note.trim().isEmpty ? 'Aucune' : note.trim();
  final cleanAddress = address.trim().isEmpty ? 'À confirmer' : address.trim();
  return '''
Commande Wasla
Client: $clientName
Téléphone: $phone
Adresse: $cleanAddress
Commerce: $merchant
Articles:
$items
Notes: $cleanNote
Livraison: $deliveryFee DA
Total: $total DA
Paiement: à la livraison
'''
      .trim();
}

Uri waslaWhatsAppUri(String message) => waslaWhatsAppUris(message).last;

Future<bool> _openFirst(List<Uri> uris) async {
  for (final uri in uris) {
    for (final mode in [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        final launched = await launchUrl(
          uri,
          mode: mode,
        ).timeout(const Duration(seconds: 4));
        if (launched) return true;
      } catch (_) {}
    }
  }
  return false;
}

/// Opens a WhatsApp chat with Wasla, message prefilled.
Future<bool> openWaslaWhatsApp(String message) =>
    _openFirst(waslaWhatsAppUris(message));

/// Opens a WhatsApp chat with [phone], message prefilled.
Future<bool> openWhatsAppChat(String phone, String message) async {
  final number = whatsAppNumber(phone);
  if (number == null) return false;
  return _openFirst(whatsAppUrisFor(number, message));
}

/// Opens the device dialer with the number ready to call.
Future<bool> openPhoneCall(String phone) async {
  final clean = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
  if (clean.length < 8) return false;
  try {
    return await launchUrl(
      Uri(scheme: 'tel', path: clean),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Google Maps directions from the pick-up point to the customer.
Uri routeUri({required String from, required String to}) {
  final cleanFrom = from.trim(), cleanTo = to.trim();
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    if (cleanFrom.isNotEmpty) 'origin': cleanFrom,
    'destination': cleanTo,
    'travelmode': 'driving',
  });
}

Future<bool> openRoute({required String from, required String to}) async {
  if (to.trim().isEmpty) return false;
  try {
    return await launchUrl(
      routeUri(from: from, to: to),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Order details and the route, ready to be sent to the next person.
String orderUpdateMessage({
  required MarketOrder order,
  required String merchant,
  required String status,
  required bool arabic,
}) {
  final items = order.items
      .map((i) => '- ${i.quantity}× ${i.product.name}')
      .join('\n');
  final from = order.merchantAddress.trim().isEmpty
      ? merchant
      : '$merchant, ${order.merchantAddress.trim()}';
  final to = order.address.trim().isEmpty ? '-' : order.address.trim();
  final route = order.address.trim().isEmpty
      ? ''
      : routeUri(from: from, to: order.address).toString();
  final lines = arabic
      ? [
          'وصلة · الطلب ${order.id}',
          'الحالة: $status',
          'المتجر: $merchant',
          'من: $from',
          'إلى: $to',
          'المنتجات:',
          items,
          'المجموع: ${order.total} دج',
          if (route.isNotEmpty) 'المسار: $route',
        ]
      : [
          'Wasla · Commande ${order.id}',
          'Statut : $status',
          'Commerce : $merchant',
          'Départ : $from',
          'Livraison : $to',
          'Articles :',
          items,
          'Total : ${order.total} DA',
          if (route.isNotEmpty) 'Itinéraire : $route',
        ];
  return lines.join('\n');
}

/// One person the signed-in user can reach about an order.
class OrderContact {
  const OrderContact(this.kind, this.name, this.phone);
  final OrderContactKind kind;
  final String name, phone;
}

enum OrderContactKind { client, merchant, courier }

/// Who the signed-in [role] may write to about [order] (phone numbers only
/// arrive from the server for people who need them).
List<OrderContact> orderContacts(
  MarketOrder order,
  UserRole role, {
  required String merchantName,
}) {
  final contacts = <OrderContact>[];
  void add(OrderContactKind kind, String name, String phone) {
    if (whatsAppNumber(phone) != null) {
      contacts.add(OrderContact(kind, name, phone));
    }
  }

  switch (role) {
    case UserRole.client:
      add(
        OrderContactKind.courier,
        order.courierName ?? '',
        order.courierPhone,
      );
      add(OrderContactKind.merchant, merchantName, order.merchantPhone);
    case UserRole.courier:
      add(OrderContactKind.client, order.clientName ?? '', order.customerPhone);
      add(OrderContactKind.merchant, merchantName, order.merchantPhone);
    case UserRole.restaurant || UserRole.supermarket:
      add(
        OrderContactKind.courier,
        order.courierName ?? '',
        order.courierPhone,
      );
    case UserRole.admin:
      add(OrderContactKind.client, order.clientName ?? '', order.customerPhone);
      add(OrderContactKind.merchant, merchantName, order.merchantPhone);
      add(
        OrderContactKind.courier,
        order.courierName ?? '',
        order.courierPhone,
      );
  }
  return contacts;
}
