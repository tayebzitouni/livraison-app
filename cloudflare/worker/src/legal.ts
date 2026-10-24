type LegalKind = 'privacy' | 'terms' | 'refund';

const pages: Record<
  LegalKind,
  { frTitle: string; arTitle: string; sections: [string, string, string, string][] }
> = {
  privacy: {
    frTitle: 'Politique de confidentialité',
    arTitle: 'سياسة الخصوصية',
    sections: [
      [
        'Qui nous sommes',
        'من نحن',
        'Wasla est une application de commande et de livraison locale en Algérie (wasla.dz). Contact : support@wasla.dz.',
        'وصلة تطبيق لطلب الوجبات والمنتجات وتوصيلها محلياً في الجزائر (wasla.dz). للتواصل: support@wasla.dz.',
      ],
      [
        'Données collectées',
        'البيانات التي نجمعها',
        'Selon votre usage : nom, e-mail, téléphone, adresse de livraison, notes de commande, historique des commandes, rôle, et éventuellement une photo de profil.',
        'حسب استخدامك: الاسم، البريد، الهاتف، عنوان التوصيل، ملاحظات الطلب، سجل الطلبات، الدور، وقد نجمع صورة الملف.',
      ],
      [
        'Pourquoi nous les utilisons',
        'لماذا نستخدمها',
        'Pour gérer les comptes, livrer les commandes, contacter les parties, calculer les frais et commissions, et sécuriser la plateforme.',
        'لإدارة الحسابات وتوصيل الطلبات والتواصل واحتساب الرسوم والعمولات وحماية المنصة.',
      ],
      [
        'Partage',
        'المشاركة',
        'Nous partageons uniquement ce qui est nécessaire avec le partenaire, le livreur et l’administrateur. Une confirmation peut partir sur WhatsApp. Nous ne vendons pas vos données.',
        'نشارك فقط ما يلزم مع الشريك والموصل والمسؤول. قد يُرسل تأكيد عبر واتساب. لا نبيع بياناتك.',
      ],
      [
        'Vos droits',
        'حقوقك',
        'Accès, correction ou suppression : support@wasla.dz.',
        'للاطلاع أو التصحيح أو الحذف: support@wasla.dz.',
      ],
    ],
  },
  terms: {
    frTitle: 'Conditions d’utilisation',
    arTitle: 'شروط الخدمة',
    sections: [
      [
        'Objet',
        'الغرض',
        'Wasla relie clients, restaurants, supérettes et livreurs en Algérie. L’usage de l’application vaut acceptation de ces conditions.',
        'تربط وصلة الزبائن بالمطاعم والبقالات والموصلين في الجزائر. استخدام التطبيق يعني الموافقة على هذه الشروط.',
      ],
      [
        'Comptes',
        'الحسابات',
        'Le client peut commander sans compte partenaire. Les comptes partenaires sont créés par l’administrateur Wasla.',
        'يمكن للزبون الطلب دون حساب شريك. حسابات الشركاء يفتحها مسؤول وصلة.',
      ],
      [
        'Commandes',
        'الطلبات',
        'Prix en dinars algériens. Paiement à la livraison. Le téléphone est obligatoire pour confirmer une commande.',
        'الأسعار بالدينار الجزائري. الدفع عند الاستلام. رقم الهاتف إلزامي لتأكيد الطلب.',
      ],
    ],
  },
  refund: {
    frTitle: 'Politique de remboursement',
    arTitle: 'سياسة الاسترجاع',
    sections: [
      [
        'Annulation',
        'الإلغاء',
        'Annulation possible tant que le partenaire n’a pas commencé la préparation.',
        'يمكن الإلغاء ما دام الشريك لم يبدأ التحضير.',
      ],
      [
        'Incident après livraison',
        'حادث بعد التسليم',
        'Signalez le problème sous 24 heures à support@wasla.dz.',
        'بلّغ خلال 24 ساعة عبر support@wasla.dz.',
      ],
      [
        'Délai',
        'المهلة',
        'Remboursement validé traité sous 7 jours ouvrés.',
        'يُعالَج الاسترجاع الموافق عليه خلال 7 أيام عمل.',
      ],
    ],
  },
};

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

export function legalResponse(kind: LegalKind, lang: string | null): Response {
  const ar = lang === 'ar';
  const page = pages[kind];
  const title = ar ? page.arTitle : page.frTitle;
  const dir = ar ? 'rtl' : 'ltr';
  const other = ar ? 'Français' : 'العربية';
  const otherLang = ar ? 'fr' : 'ar';
  const body = page.sections
    .map(
      ([frT, arT, frB, arB]) =>
        `<h2>${escapeHtml(ar ? arT : frT)}</h2><p>${escapeHtml(ar ? arB : frB)}</p>`,
    )
    .join('');
  const html = `<!doctype html>
<html lang="${ar ? 'ar' : 'fr'}" dir="${dir}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Wasla · ${escapeHtml(title)}</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 720px; margin: 32px auto; padding: 0 20px 48px; color: #181C19; line-height: 1.55; background: #F7F7F4; }
    a { color: #145A42; }
    h1 { font-size: 1.8rem; }
    nav { display: flex; gap: 14px; flex-wrap: wrap; margin: 12px 0 24px; }
  </style>
</head>
<body>
  <p>Wasla</p>
  <h1>${escapeHtml(title)}</h1>
  <nav>
    <a href="/privacy">Privacy</a>
    <a href="/terms">Terms</a>
    <a href="/refund">Refund</a>
    <a href="?lang=${otherLang}">${other}</a>
  </nav>
  ${body}
  <p>support@wasla.dz</p>
</body>
</html>`;
  return new Response(html, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
      'Access-Control-Allow-Origin': '*',
    },
  });
}

export function matchLegalPath(pathname: string): LegalKind | null {
  if (pathname === '/privacy' || pathname === '/privacy/') return 'privacy';
  if (pathname === '/terms' || pathname === '/terms/') return 'terms';
  if (pathname === '/refund' || pathname === '/refund/') return 'refund';
  return null;
}
