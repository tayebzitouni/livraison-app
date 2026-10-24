import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import 'domain.dart';
import 'dynamic_ui.dart';
import 'localized_text.dart';
import 'marketplace_store.dart';
import 'order_contact.dart';

const _paper = Color(0xFFFFFFFF);
const _muted = Color(0xFF6A746E);
const _whatsapp = Color(0xFF25D366);

String _dzd(num n) => '${n.toStringAsFixed(0)} DA';

/// Order summary, delivery details and the two ways to confirm an order.
///
/// The order is saved first, so it always exists (and is stored in the
/// customer's history) even if WhatsApp cannot be opened afterwards.
void cartSheet(BuildContext context, MarketplaceStore store) {
  final host = context;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (sheetContext) => _CartSheet(store: store, host: host),
  );
}

class _CartSheet extends StatefulWidget {
  const _CartSheet({required this.store, required this.host});
  final MarketplaceStore store;
  final BuildContext host;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  late final TextEditingController address = TextEditingController(
    text: store.currentUser?.address ?? '',
  );
  late final TextEditingController phone = TextEditingController(
    text: store.currentUser?.phone ?? '',
  );
  late final TextEditingController note = TextEditingController(
    text: store.pendingOrderNote,
  );
  String? phoneError, formError;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    // Delivery fee and commission may have changed since the last refresh.
    store.refreshPricing();
  }

  MarketplaceStore get store => widget.store;

  @override
  void dispose() {
    address.dispose();
    phone.dispose();
    note.dispose();
    super.dispose();
  }

  bool get _phoneValid =>
      RegExp(r'^\+?[0-9\s\-]{8,20}$').hasMatch(phone.text.trim()) &&
      phone.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 9;

  /// Validates, saves the order and returns it, or `null` after showing why.
  Future<MarketOrder?> _place() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      formError = null;
      phoneError = null;
    });
    if (phone.text.trim().isEmpty) {
      setState(
        () => phoneError = store.tr(
          'Ajoutez un numéro de téléphone.',
          'أضف رقم الهاتف.',
        ),
      );
      return null;
    }
    if (!_phoneValid) {
      setState(
        () => phoneError = store.tr(
          'Numéro de téléphone invalide.',
          'رقم الهاتف غير صالح.',
        ),
      );
      return null;
    }
    setState(() => busy = true);
    final order = await store.checkout(
      address.text.trim(),
      'Paiement à la livraison',
      phone: phone.text.trim(),
      note: [
        'Tél. ${phone.text.trim()}',
        if (note.text.trim().isNotEmpty) note.text.trim(),
      ].join('\n'),
    );
    if (!mounted) return order;
    if (order == null) {
      setState(() {
        busy = false;
        formError =
            store.lastError ??
            store.tr(
              'La commande n’a pas pu être enregistrée. Réessayez.',
              'تعذر تسجيل الطلب. حاول مرة أخرى.',
            );
      });
    }
    return order;
  }

  Future<void> _confirmWithWhatsApp() async {
    final order = await _place();
    if (order == null || !mounted) return;
    final message = waslaWhatsAppMessage(
      order: order,
      clientName: store.currentUser?.name ?? '',
      phone: phone.text.trim(),
      merchant: store.orderMerchant(order),
    );
    final opened = await openWaslaWhatsApp(message);
    if (!mounted) return;
    final host = widget.host;
    Navigator.pop(context);
    if (!host.mounted) return;
    if (opened) {
      ScaffoldMessenger.of(host).showSnackBar(
        SnackBar(
          content: Text(
            store.tr(
              'Commande ${order.id} enregistrée. Envoyez le message WhatsApp pour la confirmer.',
              'تم تسجيل الطلب ${order.id}. أرسل رسالة واتساب لتأكيده.',
            ),
          ),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: host,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(store.tr('WhatsApp indisponible', 'واتساب غير متاح')),
        content: Text(
          store.tr(
            'Votre commande ${order.id} est bien enregistrée, mais WhatsApp n’a pas pu s’ouvrir. Copiez le message et envoyez-le par WhatsApp plus tard, ou attendez l’appel du livreur.',
            'تم تسجيل طلبك ${order.id} لكن تعذر فتح واتساب. انسخ الرسالة وأرسلها عبر واتساب لاحقاً أو انتظر اتصال الموصل.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(store.tr('Copier le message', 'نسخ الرسالة')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmByCall() async {
    final order = await _place();
    if (order == null || !mounted) return;
    final host = widget.host;
    Navigator.pop(context);
    if (!host.mounted) return;
    await showDialog<void>(
      context: host,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(store.tr('Commande envoyée', 'تم إرسال الطلب')),
        content: Text(
          store.tr(
            'Le livreur vous contactera bientôt pour confirmer la commande.',
            'سيتصل بك الموصّل قريباً لتأكيد الطلب.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        13,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
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
              const SizedBox(height: 20),
              Text(
                'Votre commande',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              ...store.cartProducts.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: ProductMedia(p, borderRadius: 15),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(_dzd(p.retailPrice)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: busy ? null : () => store.quantity(p, -1),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      Text(
                        '${store.cart[p.id]}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        onPressed: busy ? null : () => store.quantity(p, 1),
                        icon: const Icon(Icons.add_circle_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              TextField(
                key: const Key('order-phone-field'),
                controller: phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) {
                  if (phoneError != null) setState(() => phoneError = null);
                },
                decoration: InputDecoration(
                  labelText: store.tr('Numéro de téléphone *', 'رقم الهاتف *'),
                  errorText: phoneError,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 11),
              TextField(
                key: const Key('order-address-field'),
                controller: address,
                decoration: InputDecoration(
                  labelText: store.tr('Adresse de livraison', 'عنوان التوصيل'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 11),
              TextField(
                key: const Key('order-note-field'),
                controller: note,
                maxLines: 3,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: store.tr(
                    'Instructions pour le restaurant ou le livreur',
                    'ملاحظات للمطعم أو الموصّل',
                  ),
                  hintText: store.tr(
                    'Ex. sans oignons, appelez à l’arrivée…',
                    'مثال: بدون بصل، اتصل عند الوصول…',
                  ),
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store.tr(
                        store.cartProducts.any(
                              (p) => p.kind == ProductKind.grocery,
                            )
                            ? 'Articles (prix admin inclus)'
                            : 'Articles (commission incluse)',
                        store.cartProducts.any(
                              (p) => p.kind == ProductKind.grocery,
                            )
                            ? 'المنتجات (سعر المدير مشمول)'
                            : 'المنتجات (العمولة مشمولة)',
                      ),
                    ),
                  ),
                  Text(
                    _dzd(store.cartSubtotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store.tr(
                        store.cartProducts.any(
                              (p) => p.kind == ProductKind.grocery,
                            )
                            ? 'Marge fixée directement par l’administrateur'
                            : 'Dont commission Wasla ${store.commissionPercent} %',
                        store.cartProducts.any(
                              (p) => p.kind == ProductKind.grocery,
                            )
                            ? 'الهامش محدد مباشرة من المدير'
                            : 'منها عمولة وصلة ${store.commissionPercent}٪',
                      ),
                      style: const TextStyle(color: _muted, fontSize: 12.5),
                    ),
                  ),
                  Text(
                    _dzd(store.cartCommission),
                    style: const TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Expanded(child: Text('Frais de livraison')),
                  Text(
                    _dzd(store.deliveryFee),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    _dzd(store.cartSubtotal + store.deliveryFee),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (formError != null) ...[
                const SizedBox(height: 14),
                Container(
                  key: const Key('order-error'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFB42318),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          formError!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('confirm-whatsapp-order'),
                  onPressed: store.cart.isEmpty || busy
                      ? null
                      : _confirmWithWhatsApp,
                  icon: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.chat_rounded),
                  label: Text(
                    store.tr(
                      'Confirmer via WhatsApp',
                      'تأكيد الطلب عبر واتساب',
                    ),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: _whatsapp),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('confirm-phone-order'),
                  onPressed: store.cart.isEmpty || busy ? null : _confirmByCall,
                  icon: const Icon(Icons.phone_in_talk_rounded),
                  label: Text(
                    store.tr(
                      'Confirmer par appel',
                      'تأكيد الطلب عبر مكالمة هاتفية',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                store.tr(
                  'Paiement à la livraison. Votre commande est enregistrée dans « Commandes » dès la confirmation.',
                  'الدفع عند التسليم. يُسجَّل طلبك في «الطلبات» بمجرد التأكيد.',
                ),
                style: const TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
