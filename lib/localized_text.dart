import 'package:flutter/material.dart' as material;

// Translates the app's static display copy while keeping merchant supplied
// names and descriptions unchanged.
class Text extends material.Text {
  const Text(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  @override
  material.Widget build(material.BuildContext context) {
    if (material.Localizations.localeOf(context).languageCode != 'ar' ||
        data == null) {
      return super.build(context);
    }
    final translated = _translate(data!);
    if (translated == data) return super.build(context);
    return material.Text(
      translated,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

String _translate(String value) {
  final exact = _arabic[value];
  if (exact != null) return exact;
  if (value.startsWith('Bonjour ')) {
    return value.replaceFirst('Bonjour ', 'مرحباً ');
  }
  if (value.startsWith('Livraison ')) {
    return value.replaceFirst('Livraison ', 'التوصيل ');
  }
  if (value.startsWith('Commission ')) {
    return value.replaceFirst('Commission ', 'العمولة ');
  }
  if (value.startsWith('Frais de livraison ')) {
    return value.replaceFirst('Frais de livraison ', 'رسوم التوصيل ');
  }
  if (value.startsWith('Client ')) {
    return value.replaceFirst('Client ', 'الزبون ');
  }
  if (value.startsWith('Allergènes :')) {
    return value.replaceFirst('Allergènes :', 'مسببات الحساسية:');
  }
  if (value.startsWith('Prix de gros :')) {
    return value.replaceFirst('Prix de gros :', 'سعر الجملة:');
  }
  if (value.startsWith('Commande ') && value.endsWith(' envoyée')) {
    return value
        .replaceFirst('Commande ', 'الطلب ')
        .replaceFirst(' envoyée', ' أُرسل');
  }
  if (value.contains(' articles · ')) {
    return value.replaceFirst(' articles · ', ' منتجات · ');
  }
  if (value.endsWith(' offres')) {
    return value.replaceFirst(' offres', ' عروض');
  }
  for (final status in const [
    'En attente du livreur',
    'Livreur confirmé',
    'Acceptée',
    'En préparation',
    'Prête à récupérer',
    'En route',
    'Livré · confirmation requise',
    'Réception confirmée',
    'Annulée',
  ]) {
    if (value.endsWith(status)) {
      return value.replaceFirst(status, _arabic[status]!);
    }
  }
  if (value.endsWith(' gros')) {
    return value.replaceFirst(' gros', ' جملة');
  }
  if (value.endsWith(' client')) {
    return value.replaceFirst(' client', ' للزبون');
  }
  return value;
}

const _arabic = <String, String>{
  'Accueil': 'الرئيسية',
  'Explorer': 'استكشاف',
  'Commandes': 'الطلبات',
  'Produits': 'المنتجات',
  'Profil': 'الملف الشخصي',
  'Aperçu': 'نظرة عامة',
  'Livraisons': 'التوصيلات',
  'Revenus': 'الإيرادات',
  'Utilisateurs': 'المستخدمون',
  'Comptes': 'الحسابات',
  'Gestion': 'الإدارة',
  'Client': 'زبون',
  'Clients': 'الزبائن',
  'Livreur': 'موصل',
  'Livreurs': 'الموصلون',
  'Restaurant': 'مطعم',
  'Restaurants': 'المطاعم',
  'Supérette': 'بقالة',
  'Supérettes': 'البقالات',
  'Administrateur': 'مدير',
  'Administrateurs': 'المديرون',
  'Ajouter': 'إضافة',
  'Ajouter au panier': 'أضف إلى السلة',
  'Annuler': 'إلغاء',
  'Approuver': 'موافقة',
  'Refuser': 'رفض',
  'Valider / refuser': 'موافقة / رفض',
  'Créer': 'إنشاء',
  'Créer un compte': 'إنشاء حساب',
  'Créer votre compte': 'أنشئ حسابك',
  'Se connecter': 'تسجيل الدخول',
  'Connexion': 'دخول',
  'Bon retour parmi nous': 'مرحباً بعودتك',
  'Bon retour !': 'مرحباً بعودتك!',
  'ESPACE PARTENAIRE': 'فضاء الشركاء',
  'Votre activité avance avec Wasla.': 'طوّر نشاطك مع وصلة.',
  'Rejoignez votre espace professionnel.': 'انضم إلى فضائك المهني.',
  'Retrouvez vos commandes et votre activité.': 'تابع طلباتك ونشاطك.',
  'Accès administrateur': 'دخول المدير',
  'Accès administrateur sécurisé': 'دخول آمن للمدير',
  'Administration': 'الإدارة',
  'Changer': 'تغيير',
  'Voir les produits': 'عرض المنتجات',
  'Espace partenaire : se connecter ou créer un compte':
      'فضاء الشركاء: تسجيل الدخول أو إنشاء حساب',
  'Espace partenaire': 'فضاء الشركاء',
  'Choisissez votre activité sur Wasla.': 'اختر نشاطك في وصلة.',
  'Connectez-vous à votre espace.': 'سجّل الدخول إلى حسابك.',
  'Déjà inscrit ?': 'لديك حساب؟',
  'Nouveau sur Wasla ?': 'جديد في وصلة؟',
  'Je suis': 'أنا',
  'Continuer comme client': 'المتابعة كزبون',
  'Restaurant, livreur, supérette ou admin : connexion':
      'دخول المطعم أو الموصل أو البقالة أو المدير',
  'Nom': 'الاسم',
  'Commerce': 'المتجر',
  'E-mail': 'البريد الإلكتروني',
  'Mot de passe': 'كلمة المرور',
  'Téléphone': 'الهاتف',
  'Type de compte': 'نوع الحساب',
  'Tout votre quartier,\nlivré avec soin.': 'كل ما في حيّك،\nيصلك بعناية.',
  'Un vrai repas,\nlivré chaud.': 'وجبة شهية،\nتصلك ساخنة.',
  'Tout ce que vous aimez,\nlivré simplement.': 'كل ما تحبه،\nيصلك بسهولة.',
  'Repas, courses et livraison locale dans une seule expérience.':
      'الوجبات والمشتريات والتوصيل المحلي في مكان واحد.',
  'LIVRER À': 'التوصيل إلى',
  'Choisir une adresse': 'اختر عنواناً',
  'Qu’est-ce qui vous\nferait plaisir ?': 'ماذا تشتهي\nاليوم؟',
  'OFFRE DU JOUR': 'عرض اليوم',
  'OUVERT': 'مفتوح',
  'Catégories': 'التصنيفات',
  'Les plus commandés': 'الأكثر طلباً',
  'Restaurants près de vous': 'مطاعم قريبة منك',
  'Votre activité': 'نشاطك',
  'Restaurants & menus': 'المطاعم والقوائم',
  'Tout ce qui vous fait envie, livré maintenant.': 'كل ما تشتهيه يصلك الآن.',
  'Commerces populaires': 'متاجر رائجة',
  'Tous les menus': 'كل القوائم',
  'Commandes récentes': 'الطلبات الأخيرة',
  'Livrées': 'تم التسليم',
  'Dépenses': 'المصروفات',
  'Produits actifs': 'منتجات نشطة',
  'À préparer': 'بانتظار التحضير',
  'Rien pour le moment': 'لا شيء حالياً',
  'Les commandes validées par un livreur apparaîtront ici.':
      'تظهر هنا الطلبات التي قبلها موصل.',
  'Toutes les commandes de la plateforme.': 'كل طلبات المنصة.',
  'Suivi en direct et historique complet.': 'متابعة مباشرة وسجل كامل.',
  'Aucune commande': 'لا توجد طلبات',
  'Aucun résultat': 'لا توجد نتائج',
  'Essayez une autre recherche.': 'جرّب بحثاً آخر.',
  'Les nouvelles commandes apparaîtront ici.': 'ستظهر الطلبات الجديدة هنا.',
  'Disponibles à proximité': 'متاح بالقرب منك',
  'Vous êtes à jour': 'لا توجد مهام جديدة',
  'Les nouvelles offres apparaîtront automatiquement.':
      'ستظهر العروض الجديدة تلقائياً.',
  'Carte du restaurant': 'قائمة المطعم',
  'Produits de supérette': 'منتجات البقالة',
  'Votre compte publie uniquement des produits de courses.':
      'يمكن لمتجرك نشر منتجات البقالة فقط.',
  'Votre compte publie uniquement des plats préparés.':
      'يمكن لمطعمك نشر الأطباق فقط.',
  'Catalogue vide': 'الكتالوج فارغ',
  'Ajoutez votre premier article.': 'أضف منتجك الأول.',
  'Prêt à livrer ?': 'مستعد للتوصيل؟',
  'Restez en ligne et faites avancer les commandes.':
      'ابق متصلاً وتابع الطلبات.',
  'Livraison active': 'التوصيل النشط',
  'Vos performances de livraison cette semaine.': 'أداء التوصيل هذا الأسبوع.',
  'Contrôlez les accès de tous les comptes.': 'إدارة صلاحيات جميع الحسابات.',
  'Catégories dynamiques, médias, prix et disponibilité.':
      'التصنيفات والصور والأسعار والتوفر.',
  'Disponibilité, prix client et prix de gros.':
      'التوفر وسعر الزبون وسعر الجملة.',
  'En attente de commandes': 'بانتظار الطلبات',
  'Aucune commande pour le moment.': 'لا توجد طلبات حالياً.',
  'Compte, préférences et assistance.': 'الحساب والتفضيلات والمساعدة.',
  'Voir tout': 'عرض الكل',
  'Tout': 'الكل',
  'Toutes catégories': 'كل التصنيفات',
  'Repas': 'وجبات',
  'Courses': 'مشتريات',
  'Restaurant, plat ou produit…': 'مطعم أو طبق أو منتج…',
  'Commander': 'اطلب',
  'Commander maintenant': 'اطلب الآن',
  'Votre commande': 'طلبك',
  'Frais de livraison': 'رسوم التوصيل',
  'Total': 'المجموع',
  'En ligne': 'متصل',
  'SOLDE DISPONIBLE': 'الرصيد المتاح',
  'Demander un retrait': 'طلب سحب',
  'Cette semaine': 'هذا الأسبوع',
  'Pourboires': 'الإكراميات',
  'Terminées': 'مكتملة',
  'Note': 'التقييم',
  'Volume brut': 'إجمالي المبيعات',
  'Articles': 'المنتجات',
  'Acteurs de la plateforme': 'أطراف المنصة',
  'Activité récente': 'النشاط الأخير',
  'Vue administrateur': 'لوحة المدير',
  'Santé en direct de toute la plateforme.': 'نظرة مباشرة على نشاط المنصة.',
  'Gestion du catalogue': 'إدارة الكتالوج',
  'Tous les produits': 'كل المنتجات',
  'À valider': 'بانتظار الموافقة',
  'En attente de validation': 'بانتظار الموافقة',
  'Refusé': 'مرفوض',
  'Tarifs de la plateforme': 'تسعير المنصة',
  'Enregistrer': 'حفظ',
  'Fermer': 'إغلاق',
  'Nom complet': 'الاسم الكامل',
  'Nom du commerce': 'اسم المتجر',
  'Adresse e-mail': 'البريد الإلكتروني',
  'Adresse': 'العنوان',
  'Adresse de livraison': 'عنوان التوصيل',
  'Indiquez où vous souhaitez recevoir vos commandes.':
      'حدد المكان الذي تريد استلام طلباتك فيه.',
  'Adresses utilisées récemment': 'عناوين استخدمت مؤخراً',
  'Enregistrer cette adresse': 'حفظ هذا العنوان',
  'Mode de paiement': 'طريقة الدفع',
  'Carte': 'بطاقة',
  'Paiement à la livraison': 'الدفع عند التسليم',
  'Créer un plat': 'إنشاء طبق',
  'Créer un produit': 'إنشاء منتج',
  'Ajouter une photo ou une vidéo': 'أضف صورة أو فيديو',
  'Image 8 Mo max · Vidéo 25 Mo max': 'الصورة حتى 8 م.ب · الفيديو حتى 25 م.ب',
  'Le prix client sera fixé par l’administrateur après validation.':
      'يحدد المدير سعر الزبون بعد الموافقة.',
  'Cette version a expiré': 'انتهت صلاحية هذه النسخة',
  'Cette copie n’est valable que 24 heures. Demandez une nouvelle version à Wasla.':
      'هذه النسخة صالحة لـ 24 ساعة فقط. اطلب نسخة جديدة من وصلة.',
  'Notes pour le restaurant ou le livreur': 'ملاحظات للمطعم أو الموصّل',
  'Numéro de téléphone': 'رقم الهاتف',
  'Confirmer via WhatsApp': 'تأكيد الطلب عبر واتساب',
  'Confirmer par appel': 'تأكيد الطلب عبر مكالمة هاتفية',
  'Le livreur vous contactera bientôt pour confirmer la commande.':
      'سيتصل بك الموصّل قريباً لتأكيد الطلب.',
  'Ajoutez une adresse de livraison.': 'أضف عنوان التوصيل.',
  'Ajoutez un numéro de téléphone.': 'أضف رقم الهاتف.',
  'Envoyer pour validation': 'إرسال للموافقة',
  'Envoi…': 'جارٍ الإرسال…',
  'Nouvelle catégorie': 'تصنيف جديد',
  'Modifier mon profil': 'تعديل الملف الشخصي',
  'Enregistrer les modifications': 'حفظ التعديلات',
  'Notifications': 'الإشعارات',
  'Aucune notification pour le moment.': 'لا توجد إشعارات حالياً.',
  'Aucune nouvelle notification.': 'لا توجد إشعارات جديدة.',
  'Aucune adresse enregistrée pour le moment.': 'لا توجد عناوين محفوظة حالياً.',
  'Ce que contient ce produit': 'مكونات هذا المنتج',
  'VIDÉO DU PRODUIT': 'فيديو المنتج',
  'Prix': 'السعر',
  'Tout lire': 'قراءة الكل',
  'Gardez votre catalogue à jour': 'حافظ على تحديث منتجاتك',
  'Commande envoyée': 'تم إرسال الطلب',
  'Nouvelle commande': 'طلب جديد',
  'En attente du livreur': 'بانتظار الموصل',
  'Livreur confirmé': 'تم تأكيد الموصل',
  'Acceptée': 'مقبول',
  'En préparation': 'قيد التحضير',
  'Prête à récupérer': 'جاهز للاستلام',
  'En route': 'في الطريق',
  'Livré · confirmation requise': 'تم التسليم · يرجى التأكيد',
  'Réception confirmée': 'تم تأكيد الاستلام',
  'Annulée': 'ملغى',
  'Aide et support': 'المساعدة والدعم',
  'Réponse sous 24 heures': 'رد خلال 24 ساعة',
  'Une question sur une commande ou un paiement ?': 'لديك سؤال عن طلب أو دفع؟',
  'Tous les jours, 08:00–22:00': 'يومياً، 08:00–22:00',
};
