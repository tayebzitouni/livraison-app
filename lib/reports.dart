import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'domain.dart';
import 'marketplace_store.dart';

enum ReportPeriod { day, week, month }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.store});
  final MarketplaceStore store;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod period = ReportPeriod.day;
  DateTime anchor = DateTime.now();
  bool exporting = false;

  DateTime get start {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    return switch (period) {
      ReportPeriod.day => d,
      ReportPeriod.week => d.subtract(Duration(days: d.weekday - 1)),
      ReportPeriod.month => DateTime(d.year, d.month),
    };
  }

  DateTime get end => switch (period) {
    ReportPeriod.day => start.add(const Duration(days: 1)),
    ReportPeriod.week => start.add(const Duration(days: 7)),
    ReportPeriod.month => DateTime(start.year, start.month + 1),
  };

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
  List<MarketOrder> get orders => widget.store
      .ordersFor(widget.store.currentUser!)
      .where((o) => contains(o.createdAt))
      .toList();
  List<WalletEntry> get wallet =>
      (widget.store.currentUser?.role == UserRole.admin
              ? widget.store.walletEntries
              : widget.store.currentWalletEntries)
          .where((e) => contains(e.createdAt))
          .toList();
  String label(ReportPeriod p) => switch (p) {
    ReportPeriod.day => widget.store.tr('Jour', 'يومي'),
    ReportPeriod.week => widget.store.tr('Semaine', 'أسبوعي'),
    ReportPeriod.month => widget.store.tr('Mois', 'شهري'),
  };
  String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String money(int n) => '$n DA';
  String roleLabel(UserRole role) => widget.store.language == 'ar'
      ? switch (role) {
          UserRole.client => 'زبون',
          UserRole.courier => 'موصل',
          UserRole.restaurant => 'مطعم',
          UserRole.supermarket => 'بقالة',
          UserRole.admin => 'مدير',
        }
      : role.label;
  String status(OrderStatus s) => widget.store.language == 'ar'
      ? switch (s) {
          OrderStatus.placed => 'بانتظار الموصل',
          OrderStatus.courierValidated => 'تم تأكيد الموصل',
          OrderStatus.merchantAccepted => 'مقبول',
          OrderStatus.preparing => 'قيد التحضير',
          OrderStatus.ready => 'جاهز للاستلام',
          OrderStatus.pickedUp => 'في الطريق',
          OrderStatus.delivered => 'تم التسليم',
          OrderStatus.clientConfirmed => 'تم تأكيد الاستلام',
          OrderStatus.cancelled => 'ملغى',
        }
      : s.label;
  String entryType(String type) => widget.store.language == 'ar'
      ? switch (type) {
          'sale' => 'مبيعات',
          'delivery_fee' => 'رسوم التوصيل',
          'commission' => 'العمولة',
          'withdrawal' => 'سحب',
          _ => type,
        }
      : switch (type) {
          'sale' => 'Vente',
          'delivery_fee' => 'Frais de livraison',
          'commission' => 'Commission',
          'withdrawal' => 'Retrait',
          _ => type,
        };
  String approval(String value) => widget.store.language == 'ar'
      ? switch (value) {
          'approved' => 'موافق عليه',
          'pending' => 'بانتظار الموافقة',
          'rejected' => 'مرفوض',
          _ => value,
        }
      : switch (value) {
          'approved' => 'Approuvé',
          'pending' => 'En attente',
          'rejected' => 'Refusé',
          _ => value,
        };

  Future<Uint8List> buildPdf() async {
    final store = widget.store, user = store.currentUser!;
    final reportOrders = orders, reportWallet = wallet;
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic.ttf'),
    );
    final latin = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans.ttf'),
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: store.language == 'ar' ? font : latin,
        bold: store.language == 'ar' ? font : latin,
        fontFallback: [font, latin],
      ),
    );
    final heading = pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold);
    final title =
        '${user.businessName ?? user.name} - ${store.tr('Rapport', 'تقرير')} ${label(period)}';
    final income = reportWallet
        .where((e) => e.amount > 0)
        .fold<int>(0, (s, e) => s + e.amount);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: store.language == 'ar'
            ? pw.TextDirection.rtl
            : pw.TextDirection.ltr,
        build: (_) => [
          pw.Text(title, style: heading),
          pw.Text(
            '${store.tr('Période', 'الفترة')} : ${date(start)} - ${date(end.subtract(const Duration(days: 1)))}',
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            store.tr('Résumé', 'الملخص'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${store.tr('Commandes', 'الطلبات')} : ${reportOrders.length}',
          ),
          pw.Text(
            '${store.tr('Livrées', 'تم التسليم')} : ${reportOrders.where((o) => o.status == OrderStatus.clientConfirmed).length}',
          ),
          pw.Text(
            '${store.tr('Annulées', 'ملغاة')} : ${reportOrders.where((o) => o.status == OrderStatus.cancelled).length}',
          ),
          pw.Text(
            '${store.tr('Total des commandes', 'مجموع الطلبات')} : ${money(reportOrders.fold<int>(0, (s, o) => s + o.total))}',
          ),
          pw.Text(
            '${store.tr('Revenus du portefeuille', 'إيرادات المحفظة')} : ${money(income)}',
          ),
          if (user.role == UserRole.admin) ...[
            pw.Text(
              '${store.tr('Commission', 'العمولة')} : ${money(reportWallet.where((e) => e.type == 'commission').fold<int>(0, (s, e) => s + e.amount))}',
            ),
            pw.Text(
              '${store.tr('Utilisateurs', 'المستخدمون')} : ${store.users.length}',
            ),
            pw.Text(
              '${store.tr('Produits', 'المنتجات')} : ${store.products.length}',
            ),
            pw.Text(
              '${store.tr('Commission actuelle', 'العمولة الحالية')} : ${store.commissionPercent}% ; ${store.tr('Livraison', 'التوصيل')} : ${money(store.deliveryFee)}',
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            store.tr('Détail des commandes', 'تفاصيل الطلبات'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ...reportOrders.map(
            (o) => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${o.id} · ${date(o.createdAt)} · ${status(o.status)} · ${money(o.total)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${store.tr('Client', 'الزبون')} : ${o.clientName ?? o.clientId} · ${store.tr('Partenaire', 'الشريك')} : ${o.merchantName ?? o.merchantId} · ${store.tr('Livreur', 'الموصل')} : ${o.courierName ?? o.courierId ?? '-'}',
                  ),
                  pw.Text(
                    '${store.tr('Adresse', 'العنوان')} : ${o.address} · ${store.tr('Livraison', 'التوصيل')} : ${money(o.deliveryFee)} · ${store.tr('Commission', 'العمولة')} : ${money(o.commissionAmount)}',
                  ),
                  ...o.items.map(
                    (i) => pw.Text(
                      '  ${i.quantity} × ${i.product.name} : ${money(i.total)}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            store.tr('Mouvements du portefeuille', 'حركات المحفظة'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ...reportWallet.map(
            (e) => pw.Text(
              '${date(e.createdAt)} · ${e.ownerId} · ${entryType(e.type)} · ${e.orderId ?? '-'} · ${money(e.amount)}',
            ),
          ),
          if (user.role == UserRole.admin) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              store.tr('Utilisateurs', 'المستخدمون'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...store.users.map(
              (u) => pw.Text(
                '${u.name} · ${u.email} · ${roleLabel(u.role)} · ${u.active ? store.tr('Actif', 'نشط') : store.tr('Inactif', 'غير نشط')}',
              ),
            ),
          ],
          if (user.role == UserRole.admin ||
              user.role == UserRole.restaurant ||
              user.role == UserRole.supermarket) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              store.tr('Catalogue', 'الكتالوج'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...store.products
                .where(
                  (p) => user.role == UserRole.admin || p.ownerId == user.id,
                )
                .map(
                  (p) => pw.Text(
                    '${p.name} · ${store.tr('Gros', 'الجملة')} ${money(p.wholesalePrice)} · ${store.tr('Client', 'الزبون')} ${money(p.retailPrice)} · ${approval(p.approvalStatus)}',
                  ),
                ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  Future<void> export() async {
    setState(() => exporting = true);
    try {
      await Printing.sharePdf(
        bytes: await buildPdf(),
        filename: 'wasla_rapport_${date(start).replaceAll('/', '-')}.pdf',
      );
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final reportOrders = orders, reportWallet = wallet;
    final income = reportWallet
        .where((e) => e.amount > 0)
        .fold<int>(0, (s, e) => s + e.amount);
    return Scaffold(
      appBar: AppBar(title: Text(store.tr('Rapports', 'التقارير'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<ReportPeriod>(
            segments: ReportPeriod.values
                .map((p) => ButtonSegment(value: p, label: Text(label(p))))
                .toList(),
            selected: {period},
            onSelectionChanged: (values) =>
                setState(() => period = values.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => anchor = period == ReportPeriod.day
                      ? anchor.subtract(const Duration(days: 1))
                      : period == ReportPeriod.week
                      ? anchor.subtract(const Duration(days: 7))
                      : DateTime(anchor.year, anchor.month - 1, anchor.day),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${date(start)} – ${date(end.subtract(const Duration(days: 1)))}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => anchor = period == ReportPeriod.day
                      ? anchor.add(const Duration(days: 1))
                      : period == ReportPeriod.week
                      ? anchor.add(const Duration(days: 7))
                      : DateTime(anchor.year, anchor.month + 1, anchor.day),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${store.tr('Commandes', 'الطلبات')} : ${reportOrders.length}',
                  ),
                  Text(
                    '${store.tr('Livrées', 'تم التسليم')} : ${reportOrders.where((o) => o.status == OrderStatus.clientConfirmed).length}',
                  ),
                  Text(
                    '${store.tr('Total', 'المجموع')} : ${money(reportOrders.fold<int>(0, (s, o) => s + o.total))}',
                  ),
                  Text(
                    '${store.tr('Revenus', 'الإيرادات')} : ${money(income)}',
                  ),
                  if (store.currentUser?.role == UserRole.admin)
                    Text(
                      '${store.tr('Commission', 'العمولة')} : ${money(reportWallet.where((e) => e.type == 'commission').fold<int>(0, (s, e) => s + e.amount))}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...reportOrders.map(
            (o) => Card(
              child: ListTile(
                title: Text('${o.id} · ${money(o.total)}'),
                subtitle: Text(
                  '${date(o.createdAt)} · ${o.items.map((i) => '${i.quantity}× ${i.product.name}').join(', ')}',
                ),
              ),
            ),
          ),
          if (reportOrders.isEmpty)
            Text(
              store.tr(
                'Aucune commande pour cette période.',
                'لا توجد طلبات في هذه الفترة.',
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: exporting ? null : export,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              store.tr('Exporter le PDF complet', 'تصدير تقرير PDF كامل'),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountLedger {
  AccountLedger(this.store, this.user);
  final MarketplaceStore store;
  final AppUser user;

  List<MarketOrder> get orders {
    final all = store.orders;
    return switch (user.role) {
      UserRole.client => all.where((o) => o.clientId == user.id).toList(),
      UserRole.courier => all.where((o) => o.courierId == user.id).toList(),
      UserRole.restaurant || UserRole.supermarket =>
        all.where((o) => o.merchantId == user.id).toList(),
      UserRole.admin => all,
    };
  }

  List<WalletEntry> get wallet =>
      store.walletEntries.where((e) => e.ownerId == user.id).toList();

  List<Product> get catalog =>
      store.products.where((p) => p.ownerId == user.id).toList();

  int get orderCount => orders.length;
  int get deliveredCount =>
      orders.where((o) => o.status == OrderStatus.clientConfirmed).length;
  int get cancelledCount =>
      orders.where((o) => o.status == OrderStatus.cancelled).length;
  int get inProgressCount => orders
      .where(
        (o) =>
            o.status != OrderStatus.clientConfirmed &&
            o.status != OrderStatus.cancelled,
      )
      .length;
  int get orderTotal => orders.fold<int>(0, (s, o) => s + o.total);
  int get walletIncome =>
      wallet.where((e) => e.amount > 0).fold<int>(0, (s, e) => s + e.amount);
  int get walletBalance => wallet.fold<int>(0, (s, e) => s + e.amount);
}

String reportDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String reportMoney(int n) => '$n DA';

String reportRoleLabel(MarketplaceStore store, UserRole role) =>
    store.language == 'ar'
    ? switch (role) {
        UserRole.client => 'زبون',
        UserRole.courier => 'موصل',
        UserRole.restaurant => 'مطعم',
        UserRole.supermarket => 'بقالة',
        UserRole.admin => 'مدير',
      }
    : role.label;

String reportStatus(MarketplaceStore store, OrderStatus s) =>
    store.language == 'ar'
    ? switch (s) {
        OrderStatus.placed => 'بانتظار الموصل',
        OrderStatus.courierValidated => 'تم تأكيد الموصل',
        OrderStatus.merchantAccepted => 'مقبول',
        OrderStatus.preparing => 'قيد التحضير',
        OrderStatus.ready => 'جاهز للاستلام',
        OrderStatus.pickedUp => 'في الطريق',
        OrderStatus.delivered => 'تم التسليم',
        OrderStatus.clientConfirmed => 'تم تأكيد الاستلام',
        OrderStatus.cancelled => 'ملغى',
      }
    : s.label;

String reportEntryType(MarketplaceStore store, String type) =>
    store.language == 'ar'
    ? switch (type) {
        'sale' => 'مبيعات',
        'delivery_fee' => 'رسوم التوصيل',
        'commission' => 'العمولة',
        'withdrawal' => 'سحب',
        _ => type,
      }
    : switch (type) {
        'sale' => 'Vente',
        'delivery_fee' => 'Frais de livraison',
        'commission' => 'Commission',
        'withdrawal' => 'Retrait',
        _ => type,
      };

String reportApproval(MarketplaceStore store, String value) =>
    store.language == 'ar'
    ? switch (value) {
        'approved' => 'موافق عليه',
        'pending' => 'بانتظار الموافقة',
        'rejected' => 'مرفوض',
        _ => value,
      }
    : switch (value) {
        'approved' => 'Approuvé',
        'pending' => 'En attente',
        'rejected' => 'Refusé',
        _ => value,
      };

Future<Uint8List> buildAccountReportPdf(
  MarketplaceStore store,
  AppUser user,
) async {
  final ledger = AccountLedger(store, user);
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic.ttf'),
  );
  final latin = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans.ttf'));
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: store.language == 'ar' ? font : latin,
      bold: store.language == 'ar' ? font : latin,
      fontFallback: [font, latin],
    ),
  );
  final heading = pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold);
  final title =
      '${user.businessName ?? user.name} - ${store.tr('Rapport complet', 'تقرير كامل')}';
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: store.language == 'ar'
          ? pw.TextDirection.rtl
          : pw.TextDirection.ltr,
      build: (_) => [
        pw.Text(title, style: heading),
        pw.Text(
          '${store.tr('Généré le', 'تاريخ الإنشاء')} : ${reportDate(DateTime.now())}',
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          store.tr('Identité du compte', 'هوية الحساب'),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('${store.tr('Nom', 'الاسم')} : ${user.name}'),
        if (user.businessName != null && user.businessName!.isNotEmpty)
          pw.Text(
            '${store.tr('Établissement', 'المؤسسة')} : ${user.businessName}',
          ),
        pw.Text('${store.tr('E-mail', 'البريد')} : ${user.email}'),
        pw.Text(
          '${store.tr('Téléphone', 'الهاتف')} : ${user.phone.isEmpty ? '-' : user.phone}',
        ),
        pw.Text(
          '${store.tr('Adresse', 'العنوان')} : ${user.address.isEmpty ? '-' : user.address}',
        ),
        pw.Text(
          '${store.tr('Rôle', 'الدور')} : ${reportRoleLabel(store, user.role)}',
        ),
        pw.Text(
          '${store.tr('Statut', 'الحالة')} : ${user.active ? store.tr('Actif', 'نشط') : store.tr('Inactif', 'غير نشط')}',
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          store.tr('Statistiques', 'الإحصائيات'),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('${store.tr('Commandes', 'الطلبات')} : ${ledger.orderCount}'),
        pw.Text(
          '${store.tr('En cours', 'قيد التنفيذ')} : ${ledger.inProgressCount}',
        ),
        pw.Text(
          '${store.tr('Livrées', 'تم التسليم')} : ${ledger.deliveredCount}',
        ),
        pw.Text('${store.tr('Annulées', 'ملغاة')} : ${ledger.cancelledCount}'),
        pw.Text(
          '${store.tr('Total des commandes', 'مجموع الطلبات')} : ${reportMoney(ledger.orderTotal)}',
        ),
        pw.Text(
          '${store.tr('Revenus du portefeuille', 'إيرادات المحفظة')} : ${reportMoney(ledger.walletIncome)}',
        ),
        pw.Text(
          '${store.tr('Solde', 'الرصيد')} : ${reportMoney(ledger.walletBalance)}',
        ),
        if (user.role == UserRole.restaurant ||
            user.role == UserRole.supermarket)
          pw.Text(
            '${store.tr('Produits', 'المنتجات')} : ${ledger.catalog.length}',
          ),
        pw.SizedBox(height: 16),
        pw.Text(
          store.tr('Détail des commandes', 'تفاصيل الطلبات'),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        if (ledger.orders.isEmpty)
          pw.Text(
            store.tr(
              'Aucune commande pour ce compte.',
              'لا توجد طلبات لهذا الحساب.',
            ),
          ),
        ...ledger.orders.map(
          (o) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${o.id} · ${reportDate(o.createdAt)} · ${reportStatus(store, o.status)} · ${reportMoney(o.total)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '${store.tr('Client', 'الزبون')} : ${o.clientName ?? o.clientId} · ${store.tr('Partenaire', 'الشريك')} : ${o.merchantName ?? o.merchantId} · ${store.tr('Livreur', 'الموصل')} : ${o.courierName ?? o.courierId ?? '-'}',
                ),
                pw.Text(
                  '${store.tr('Adresse', 'العنوان')} : ${o.address} · ${store.tr('Livraison', 'التوصيل')} : ${reportMoney(o.deliveryFee)} · ${store.tr('Commission', 'العمولة')} : ${reportMoney(o.commissionAmount)}',
                ),
                if (o.note.isNotEmpty)
                  pw.Text('${store.tr('Note', 'ملاحظة')} : ${o.note}'),
                ...o.items.map(
                  (i) => pw.Text(
                    '  ${i.quantity} × ${i.product.name} : ${reportMoney(i.total)}',
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          store.tr('Mouvements du portefeuille', 'حركات المحفظة'),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        if (ledger.wallet.isEmpty)
          pw.Text(
            store.tr(
              'Aucun mouvement de portefeuille.',
              'لا توجد حركات في المحفظة.',
            ),
          ),
        ...ledger.wallet.map(
          (e) => pw.Text(
            '${reportDate(e.createdAt)} · ${reportEntryType(store, e.type)} · ${e.orderId ?? '-'} · ${reportMoney(e.amount)}',
          ),
        ),
        if (user.role == UserRole.restaurant ||
            user.role == UserRole.supermarket) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            store.tr('Catalogue', 'الكتالوج'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (ledger.catalog.isEmpty)
            pw.Text(
              store.tr('Aucun produit publié.', 'لا توجد منتجات منشورة.'),
            ),
          ...ledger.catalog.map(
            (p) => pw.Text(
              '${p.name} · ${store.tr('Gros', 'الجملة')} ${reportMoney(p.wholesalePrice)} · ${store.tr('Client', 'الزبون')} ${reportMoney(p.retailPrice)} · ${reportApproval(store, p.approvalStatus)} · ${p.available ? store.tr('Disponible', 'متوفر') : store.tr('Indisponible', 'غير متوفر')}',
            ),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

Future<void> printAccountReport(MarketplaceStore store, AppUser user) {
  final slug = (user.businessName ?? user.name)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return Printing.layoutPdf(
    onLayout: (_) => buildAccountReportPdf(store, user),
    name: 'wasla_rapport_${slug.isEmpty ? user.id : slug}',
  );
}
