import 'package:url_launcher/url_launcher.dart';

import 'domain.dart';

const waslaWhatsAppLocal = '0554917545';
const waslaWhatsAppE164 = '213554917545';

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
  return '''
Commande Wasla ${order.id}
Client: $clientName
Téléphone: $phone
Adresse: ${order.address}
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

List<Uri> waslaWhatsAppUris(String message) {
  final encoded = Uri.encodeComponent(message);
  return [
    Uri.parse('whatsapp://send?phone=$waslaWhatsAppE164&text=$encoded'),
    Uri.parse(
      'https://api.whatsapp.com/send?phone=$waslaWhatsAppE164&text=$encoded',
    ),
    Uri.parse('https://wa.me/$waslaWhatsAppE164?text=$encoded'),
  ];
}

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

Future<bool> openWaslaWhatsApp(String message) async {
  for (final uri in waslaWhatsAppUris(message)) {
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
