# وصلة — تطبيق توصيل الوجبات

Prototype Flutter مبني على الـrapport والصور المرفقة. الواجهة RTL بالعربية، بألوان البني/البرتقالي/الكريمي وبطاقات مستديرة مثل المرجع.

## الموجود في النسخة

- الصفحة الرئيسية: الفئات، الأكثر طلباً، المطابخ القريبة، ووسم `🔥 الأكثر طلباً`.
- سلة الطلب: الكمية، رقم الهاتف، خدمة التوصيل، الإجمالي، وزر تأكيد داخلي.
- الطلبات: حالة الطلب `#TJ-104` وإعادة الطلب بنقرة.
- المفضلة والحساب.
- وضع السائق: موجة الطلبات، نقاط الاستلام والتسليم، والمبلغ الواجب تسليمه عند إغلاق الوردية.
- التقرير المالي: الكاش المحصل، أرباح التوصيل، وعدد المهام وتفاصيل العهدة.
- قاعدة بيانات مركزية أولية في `lib/data/app_database.dart` تشمل المنتجات والطلبات وقيود المحفظة.
- schema production في `supabase/schema.sql` للجداول: profiles, products, orders, order_items, wallet_entries, settlements مع دالة تمنع السحب المزدوج.
- دورة الطلب: `draft` عند الإرسال → `confirmed` عند قبول السائق → `picked_up` عند الاستلام → `delivered` عند التسليم. عند `delivered` تسجل المحفظة تلقائياً 80% لصاحب الطبق، 20% عمولة الإدارة، وأجرة التوصيل.
- ربط Supabase اختياري ومجهز في `lib/data/supabase_backend.dart`: بدون مفاتيح يشتغل demo adapter، ومع المفاتيح يقرأ/يكتب المنتجات والطلبات والمحفظة من قاعدة production.

## التشغيل

```bash
flutter pub get
flutter run
```

لتشغيله على Supabase الحقيقي (استعمل publishable/anon key فقط داخل تطبيق Flutter):

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

طبّق `supabase/schema.sql` من Supabase SQL Editor، ثم أنشئ مستخدمين في Authentication وأضف صفوفهم في `profiles` بنفس `id` وحدد `role` المناسب.

لنسخة الويب:

```bash
flutter build web --release
```

الـadapter الحالي مركزي داخل التطبيق لتسهيل التطوير. قبل الاستضافة، يتم استبداله باتصال production إلى Supabase/Firebase أو API خاص، مع إضافة مفاتيح المشروع وسياسات الصلاحيات.
