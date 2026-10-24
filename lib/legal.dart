import 'package:flutter/material.dart' hide Text;

import 'localized_text.dart';
import 'marketplace_store.dart';

const waslaLegalBaseUrl = 'https://livraison-api.story-trends-dz.workers.dev';

enum LegalPageKind { privacy, terms, refund }

extension LegalPageKindUi on LegalPageKind {
  String title(MarketplaceStore store) => switch (this) {
    LegalPageKind.privacy => store.tr(
      'Politique de confidentialité',
      'سياسة الخصوصية',
    ),
    LegalPageKind.terms => store.tr('Conditions d’utilisation', 'شروط الخدمة'),
    LegalPageKind.refund => store.tr(
      'Politique de remboursement',
      'سياسة الاسترجاع',
    ),
  };

  String get path => switch (this) {
    LegalPageKind.privacy => '/privacy',
    LegalPageKind.terms => '/terms',
    LegalPageKind.refund => '/refund',
  };

  String get publicUrl => '$waslaLegalBaseUrl$path';
}

class LegalSection {
  const LegalSection(this.titleFr, this.titleAr, this.bodyFr, this.bodyAr);
  final String titleFr, titleAr, bodyFr, bodyAr;
  String title(bool ar) => ar ? titleAr : titleFr;
  String body(bool ar) => ar ? bodyAr : bodyFr;
}

const privacySections = [
  LegalSection(
    'Qui nous sommes',
    'من نحن',
    'Wasla est une application de commande et de livraison locale en Algérie (wasla.dz). Contact : support@wasla.dz.',
    'وصلة تطبيق لطلب الوجبات والمنتجات وتوصيلها محلياً في الجزائر (wasla.dz). للتواصل: support@wasla.dz.',
  ),
  LegalSection(
    'Données collectées',
    'البيانات التي نجمعها',
    'Selon votre usage : nom, e-mail, téléphone, adresse de livraison, notes de commande, historique des commandes, rôle (client, livreur, restaurant, supérette, administrateur), et éventuellement une photo de profil. Les commandes confirmées via WhatsApp incluent le numéro que vous saisissez.',
    'حسب استخدامك: الاسم، البريد، الهاتف، عنوان التوصيل، ملاحظات الطلب، سجل الطلبات، الدور (زبون، موصل، مطعم، بقالة، مدير)، وقد نجمع صورة الملف. الطلبات المؤكدة عبر واتساب تتضمن الرقم الذي تدخله.',
  ),
  LegalSection(
    'Pourquoi nous les utilisons',
    'لماذا نستخدمها',
    'Pour créer et gérer votre compte, préparer et livrer les commandes, contacter le client, le partenaire et le livreur, calculer les frais et commissions, produire des rapports, et assurer la sécurité de la plateforme.',
    'لإنشاء حسابك وإدارته، تحضير الطلبات وتوصيلها، التواصل مع الزبون والشريك والموصل، احتساب الرسوم والعمولات، إعداد التقارير، وحماية المنصة.',
  ),
  LegalSection(
    'Partage',
    'المشاركة',
    'Nous partageons uniquement ce qui est nécessaire : le restaurant ou la supérette voit la commande et les notes ; le livreur voit l’adresse et le téléphone pour la livraison ; l’administrateur gère les comptes. Une confirmation peut être envoyée sur WhatsApp au numéro Wasla. Nous ne vendons pas vos données.',
    'نشارك فقط ما يلزم: يرى المطعم أو البقالة الطلب والملاحظات؛ يرى الموصل العنوان والهاتف للتوصيل؛ يدير المسؤول الحسابات. قد يُرسل تأكيد عبر واتساب إلى رقم وصلة. لا نبيع بياناتك.',
  ),
  LegalSection(
    'Conservation et sécurité',
    'الحفظ والأمان',
    'Les données sont hébergées chez nos prestataires cloud (Cloudflare). Elles sont conservées le temps nécessaire au service, à la comptabilité et aux obligations légales, puis supprimées ou anonymisées.',
    'تُستضاف البيانات لدى مزودينا السحابيين (Cloudflare). نحتفظ بها طالما يلزم للخدمة والمحاسبة والالتزامات القانونية، ثم تُحذف أو تُجهَّل.',
  ),
  LegalSection(
    'Vos droits',
    'حقوقك',
    'Vous pouvez demander l’accès, la correction ou la suppression de vos données en écrivant à support@wasla.dz. Les partenaires sont créés et désactivés par l’administrateur Wasla.',
    'يمكنك طلب الاطلاع على بياناتك أو تصحيحها أو حذفها عبر support@wasla.dz. حسابات الشركاء يفتحها ويوقفها مسؤول وصلة.',
  ),
];

const termsSections = [
  LegalSection(
    'Objet',
    'الغرض',
    'Wasla met en relation des clients, des restaurants, des supérettes et des livreurs pour commander et livrer des repas et des courses en Algérie. En utilisant l’application, vous acceptez ces conditions.',
    'تربط وصلة الزبائن بالمطاعم والبقالات والموصلين لطلب الوجبات والمنتجات وتوصيلها في الجزائر. باستخدام التطبيق فإنك توافق على هذه الشروط.',
  ),
  LegalSection(
    'Comptes',
    'الحسابات',
    'Le client peut commander sans créer de compte partenaire. Les comptes livreur, restaurant et supérette sont ouverts uniquement par l’administrateur Wasla. Vous devez fournir des informations exactes et garder vos identifiants confidentiels.',
    'يمكن للزبون الطلب دون فتح حساب شريك. حسابات الموصل والمطعم والبقالة يفتحها مسؤول وصلة فقط. يجب تقديم معلومات صحيحة والحفاظ على سرية بيانات الدخول.',
  ),
  LegalSection(
    'Commandes et paiement',
    'الطلبات والدفع',
    'Les prix affichés sont en dinars algériens. Le paiement se fait à la livraison, sauf indication contraire. Une commande peut être confirmée par WhatsApp ou par appel. Le téléphone du client est obligatoire pour confirmer. L’adresse et les notes sont facultatives mais aident la livraison.',
    'الأسعار بالدينار الجزائري. الدفع عند الاستلام ما لم يُذكر خلاف ذلك. يمكن تأكيد الطلب عبر واتساب أو مكالمة. رقم هاتف الزبون إلزامي للتأكيد. العنوان والملاحظات اختياريان لكنهما يساعدان التوصيل.',
  ),
  LegalSection(
    'Rôles',
    'الأدوار',
    'Le client commande et confirme la réception. Le livreur prend, récupère et livre. Le partenaire prépare les produits validés par l’administrateur. Wasla peut suspendre un compte en cas d’abus, de fraude ou de non-respect de ces conditions.',
    'الزبون يطلب ويؤكد الاستلام. الموصل يأخذ الطلب ويستلمه ويوصله. الشريك يجهّز المنتجات التي وافق عليها المسؤول. يمكن لوصلة إيقاف حساب عند الإساءة أو الاحتيال أو مخالفة هذه الشروط.',
  ),
  LegalSection(
    'Responsabilité',
    'المسؤولية',
    'Wasla facilite la mise en relation. La qualité des plats et produits relève du partenaire. Les délais dépendent du trafic et de la disponibilité. L’application est fournie « en l’état » ; nous nous efforçons d’éviter les interruptions mais ne les garantissons pas.',
    'وصلة تسهّل الربط بين الأطراف. جودة الأطباق والمنتجات مسؤولية الشريك. المهل تعتمد على حركة السير والتوفر. يُقدَّم التطبيق كما هو؛ نسعى لتفادي الانقطاع دون ضمانه.',
  ),
];

const refundSections = [
  LegalSection(
    'Principe',
    'المبدأ',
    'Le paiement se fait à la livraison. Un remboursement n’est dû que si la commande a été payée ou si un incident justifié survient après confirmation.',
    'الدفع عند الاستلام. يُستحق الاسترجاع فقط إذا دُفع الطلب أو وقع حادث مبرر بعد التأكيد.',
  ),
  LegalSection(
    'Annulation',
    'الإلغاء',
    'Vous pouvez demander l’annulation tant que le partenaire n’a pas commencé la préparation. Une fois la commande acceptée ou en préparation, l’annulation n’est plus garantie. Contactez le support ou le livreur au plus vite.',
    'يمكنك طلب الإلغاء ما دام الشريك لم يبدأ التحضير. بعد قبول الطلب أو بدء التحضير لا يُضمن الإلغاء. تواصل مع الدعم أو الموصل فوراً.',
  ),
  LegalSection(
    'Produit manquant ou incorrect',
    'منتج ناقص أو خاطئ',
    'Signalez le problème dans les 24 heures après la livraison (photo si possible) à support@wasla.dz. Wasla peut proposer un avoir, un réassort ou un remboursement partiel selon le cas.',
    'بلّغ خلال 24 ساعة من التسليم (مع صورة إن أمكن) عبر support@wasla.dz. قد تعرض وصلة رصيداً أو استبدالاً أو استرجاعاً جزئياً حسب الحالة.',
  ),
  LegalSection(
    'Frais de livraison',
    'رسوم التوصيل',
    'Les frais de livraison restent dus si le livreur s’est déjà déplacé jusqu’au point de retrait ou chez le client, sauf faute de Wasla ou du partenaire.',
    'تبقى رسوم التوصيل مستحقة إذا كان الموصل قد تنقّل إلى نقطة الاستلام أو إلى الزبون، إلا في حال خطأ من وصلة أو من الشريك.',
  ),
  LegalSection(
    'Délai',
    'المهلة',
    'Un remboursement validé est traité sous 7 jours ouvrés, par le même moyen que le paiement ou par accord avec le support.',
    'يُعالَج الاسترجاع الموافق عليه خلال 7 أيام عمل، بنفس وسيلة الدفع أو باتفاق مع الدعم.',
  ),
];

List<LegalSection> sectionsFor(LegalPageKind kind) => switch (kind) {
  LegalPageKind.privacy => privacySections,
  LegalPageKind.terms => termsSections,
  LegalPageKind.refund => refundSections,
};

void openLegalPage(
  BuildContext context,
  MarketplaceStore store,
  LegalPageKind kind,
) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => LegalScreen(store: store, kind: kind),
    ),
  );
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.store, required this.kind});
  final MarketplaceStore store;
  final LegalPageKind kind;

  @override
  Widget build(BuildContext context) {
    final ar = store.language == 'ar';
    final sections = sectionsFor(kind);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(title: Text(kind.title(store))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
        children: [
          Text(
            store.tr(
              'Dernière mise à jour : 22 septembre 2026',
              'آخر تحديث: 22 سبتمبر 2026',
            ),
            style: const TextStyle(color: Color(0xFF6A746E)),
          ),
          const SizedBox(height: 8),
          Text(
            store.tr(
              'Lien public : ${kind.publicUrl}',
              'الرابط العام: ${kind.publicUrl}',
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF6A746E)),
          ),
          const SizedBox(height: 18),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title(ar),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(section.body(ar), style: const TextStyle(height: 1.45)),
                ],
              ),
            ),
          ),
          Text(
            store.tr(
              'Pour toute question : support@wasla.dz',
              'لأي سؤال: support@wasla.dz',
            ),
          ),
        ],
      ),
    );
  }
}
