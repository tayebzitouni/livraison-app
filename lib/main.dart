import 'package:flutter/material.dart';
import 'data/app_database.dart';

void main() => runApp(const App());

class C {
  static const bg = Color(0xfff7fafb);
  static const dark = Color(0xff352b28);
  static const text = Color(0xff302723);
  static const orange = Color(0xffef7000);
  static const pale = Color(0xffffead9);
  static const muted = Color(0xff8b8581);
  static const green = Color(0xff1ecb69);
}

class Item {
  final String title, emoji;
  final int price;
  final Color color;
  const Item(this.title, this.emoji, this.price, this.color);
}

const menu = [
  Item('طاجين زيتون بالدجاج', '🍲', 800, Color(0xffffd7b0)),
  Item('بوراك باللحم (3 حبات)', '🥟', 300, Color(0xffffe6bd)),
  Item('مطلوع الدار', '🫓', 50, Color(0xffffc58f)),
  Item('شربة فريك', '🍜', 250, Color(0xffffcfc1)),
];

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'وصلة',
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      scaffoldBackgroundColor: C.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: C.orange),
    ),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final db = AppDatabase.instance;
  var index = 0;
  var cart = 0;
  var total = 0;
  var driver = false;

  void add(Item item) {
    setState(() {
      cart++;
      total += item.price;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.title} تضاف للسلة'),
        backgroundColor: C.dark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    if (driver) {
      page = DriverLive(db: db, onBack: () => setState(() => driver = false));
    } else if (index == 0) {
      page = Home(
        cart: cart,
        onAdd: add,
        onCart: () => openCart(),
        onDriver: () => setState(() => driver = true),
      );
    } else if (index == 1) {
      page = Favorites(onAdd: add);
    } else if (index == 2) {
      page = OrdersLive(db: db, onReorder: () => add(menu[0]));
    } else {
      page = Profile(onDriver: () => setState(() => driver = true));
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: page),
        bottomNavigationBar: driver
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() => index = i),
                backgroundColor: Colors.white,
                indicatorColor: C.pale,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'الرئيسية',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite_border),
                    selectedIcon: Icon(Icons.favorite),
                    label: 'المفضلة',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'طلباتي',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'حسابي',
                  ),
                ],
              ),
      ),
    );
  }

  void openCart() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Cart(
        count: cart,
        total: total,
        onDone: () {
          db.createOrder(
            foodTotal: total == 0 ? 800 : total,
            itemCount: cart == 0 ? 1 : cart,
          );
          Navigator.pop(context);
          setState(() {
            index = 2;
            cart = 0;
            total = 0;
          });
        },
      ),
    ),
  );
}

class Home extends StatelessWidget {
  final int cart;
  final ValueChanged<Item> onAdd;
  final VoidCallback onCart, onDriver;
  const Home({
    super.key,
    required this.cart,
    required this.onAdd,
    required this.onCart,
    required this.onDriver,
  });
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Header(cart: cart, onCart: onCart, onDriver: onDriver),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 145,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff46332d), Color(0xff70432c)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'سخونتها توصلك لباب الدار 🔥',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'وجبات بيتية محضّرة اليوم',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: C.orange,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'اكتشف الآن',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'توصيل سريع ←',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: Section(title: 'الفئات')),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 102,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final names = ['وجبات منزلية', 'حلويات', 'فطور', 'مشروبات'];
              final icons = [
                Icons.soup_kitchen_outlined,
                Icons.cake_outlined,
                Icons.free_breakfast_outlined,
                Icons.local_cafe_outlined,
              ];
              return Column(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: i == 0 ? C.orange : C.pale,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icons[i],
                      color: i == 0 ? Colors.white : C.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    names[i],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(child: Section(title: 'الأكثر شعبية')),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 255,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: menu.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) =>
                CardItem(item: menu[i], onAdd: () => onAdd(menu[i])),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: Section(title: 'مطابخ قريبة منك')),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: const [
              Kitchen(
                name: 'مطبخ أم خديجة',
                desc: 'أكل منزلي نظيف • أطباق تقليدية',
                rating: '4.9',
                time: '30 - 45 د',
              ),
              Kitchen(
                name: 'مطبخ جدتي',
                desc: 'وصفات أصيلة بطابع عصري',
                rating: '4.8',
                time: '25 - 40 د',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class Header extends StatelessWidget {
  final int cart;
  final VoidCallback onCart, onDriver;
  const Header({
    super.key,
    required this.cart,
    required this.onCart,
    required this.onDriver,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: C.dark,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحبا، فتحي 👋',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: C.text,
                ),
              ),
              SizedBox(height: 3),
              Text(
                '📍 الجزائر العاصمة',
                style: TextStyle(color: C.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onDriver,
          icon: const Icon(Icons.local_shipping_outlined),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onCart,
              icon: const Icon(Icons.shopping_bag_outlined),
            ),
            if (cart > 0)
              Positioned(
                right: 0,
                top: 0,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: C.orange,
                  child: Text(
                    '$cart',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class Section extends StatelessWidget {
  final String title;
  const Section({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 25, 20, 14),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: C.text,
          ),
        ),
        const Spacer(),
        const Text(
          'مشاهدة الكل',
          style: TextStyle(
            color: C.orange,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class CardItem extends StatelessWidget {
  final Item item;
  final VoidCallback onAdd;
  const CardItem({super.key, required this.item, required this.onAdd});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffece7e2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 122,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Center(
                  child: Text(item.emoji, style: const TextStyle(fontSize: 60)),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: C.dark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '🔥 الأكثر طلباً',
                    style: TextStyle(color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'مطبخ أم خديجة',
                  style: TextStyle(color: C.muted, fontSize: 10),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Text(
                      '${item.price} دج',
                      style: const TextStyle(
                        color: C.orange,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onAdd,
                      child: const CircleAvatar(
                        radius: 15,
                        backgroundColor: C.orange,
                        child: Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class Kitchen extends StatelessWidget {
  final String name, desc, rating, time;
  const Kitchen({
    super.key,
    required this.name,
    required this.desc,
    required this.rating,
    required this.time,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffece7e2)),
    ),
    child: Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: C.pale,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Center(
            child: Text('👩‍🍳', style: TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(desc, style: const TextStyle(color: C.muted, fontSize: 11)),
              const SizedBox(height: 6),
              Text(
                '⭐ $rating   ⏱ $time',
                style: const TextStyle(fontSize: 11, color: C.muted),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_left, color: C.muted),
      ],
    ),
  );
}

class Cart extends StatelessWidget {
  final int count, total;
  final VoidCallback onDone;
  const Cart({
    super.key,
    required this.count,
    required this.total,
    required this.onDone,
  });
  @override
  Widget build(BuildContext context) {
    final sum = total == 0 ? 800 : total;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سلة الطلبات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: C.dark,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CartRow(item: menu[0], qty: count == 0 ? 1 : count),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const TextField(
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                hintText: '0550 12 34 56',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Line('ثمن الأكل', '$sum دج'),
                Line('خدمة التوصيل', '200 دج'),
                const Divider(),
                Line('المجموع (الدفع نقداً)', '${sum + 200} دج', strong: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('تأكيد الطلب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartRow extends StatelessWidget {
  final Item item;
  final int qty;
  const CartRow({super.key, required this.item, required this.qty});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(item.emoji, style: const TextStyle(fontSize: 38)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${item.price} دج',
                style: const TextStyle(
                  color: C.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text('الكمية: $qty', style: const TextStyle(color: C.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class Line extends StatelessWidget {
  final String a, b;
  final bool strong;
  const Line(this.a, this.b, {this.strong = false, super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(
          a,
          style: TextStyle(
            color: strong ? C.text : C.muted,
            fontWeight: strong ? FontWeight.bold : null,
          ),
        ),
        const Spacer(),
        Text(
          b,
          style: TextStyle(
            color: strong ? C.orange : C.text,
            fontWeight: FontWeight.bold,
            fontSize: strong ? 17 : 14,
          ),
        ),
      ],
    ),
  );
}

class Favorites extends StatelessWidget {
  final ValueChanged<Item> onAdd;
  const Favorites({super.key, required this.onAdd});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const TitleBlock('المفضلة', 'وجباتك المحفوظة في مكان واحد'),
      const SizedBox(height: 18),
      ...menu
          .take(2)
          .map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CartRow(item: i, qty: 1),
            ),
          ),
    ],
  );
}

class Orders extends StatelessWidget {
  final VoidCallback onReorder;
  const Orders({super.key, required this.onReorder});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const TitleBlock('طلباتي', 'تابع طلباتك وأعد الطلب بنقرة'),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Text(
                  '●  الطلب #TJ-104',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  'قيد التحضير',
                  style: TextStyle(color: C.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            const Line('طاجين زيتون بالدجاج', '800 دج'),
            const Line('بوراك باللحم', '300 دج'),
            const Divider(),
            const Line('المجموع', '1,300 دج', strong: true),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onReorder,
              child: const Text('إعادة الطلب'),
            ),
          ],
        ),
      ),
    ],
  );
}

class TitleBlock extends StatelessWidget {
  final String a, b;
  const TitleBlock(this.a, this.b, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        a,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: C.text,
        ),
      ),
      const SizedBox(height: 5),
      Text(b, style: const TextStyle(color: C.muted)),
    ],
  );
}

class Profile extends StatelessWidget {
  final VoidCallback onDriver;
  const Profile({super.key, required this.onDriver});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const TitleBlock('حسابي', 'إدارة الحساب والمحفظة'),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: C.dark,
          borderRadius: BorderRadius.circular(21),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: C.orange,
              child: Icon(Icons.person, color: Colors.white),
            ),
            SizedBox(width: 14),
            Text(
              'فتحي بوعلام\nزبون • عضو منذ 2026',
              style: TextStyle(
                color: Colors.white,
                height: 1.6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      ActionTile(Icons.account_balance_wallet_outlined, 'محفظتي', '0 دج'),
      ActionTile(
        Icons.local_shipping_outlined,
        'وضع السائق',
        'تجربة لوحة السائق',
        onTap: onDriver,
      ),
      ActionTile(
        Icons.receipt_long_outlined,
        'التقرير المالي',
        'عرض اليوم',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Finance()),
        ),
      ),
      const ActionTile(Icons.settings_outlined, 'الإعدادات', ''),
    ],
  );
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, tail;
  final VoidCallback? onTap;
  const ActionTile(this.icon, this.title, this.tail, {this.onTap, super.key});
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: C.orange),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Text(tail, style: const TextStyle(color: C.muted)),
    ),
  );
}

class Driver extends StatelessWidget {
  final VoidCallback onBack;
  const Driver({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) => Container(
    color: C.dark,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
            ),
            const Expanded(
              child: Text(
                'لوحة السائق',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Text(
              '1,300 دج',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const Text(
          'موجة نشطة • الطلب #TJ-104',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 22),
        StepCard('1', 'استلام المشتريات', 'مقهى أبو أنس', true),
        StepCard('2', 'مطبخ أم خديجة', 'استلام طاجين زيتون + بوراك', false),
        StepCard('3', 'الزبون: فتحي', 'التحصيل: 1,300 دج', false),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xff493a34),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              const Line(
                'المبلغ الواجب تسليمه للإدارة',
                '1,100 دج',
                strong: true,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffd7382d),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('إغلاق الوردية وتسليم العهدة'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class StepCard extends StatelessWidget {
  final String no, title, sub;
  final bool active;
  const StepCard(this.no, this.title, this.sub, this.active, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: active ? const Color(0xff493a34) : const Color(0xff292321),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: active ? C.orange : Colors.transparent,
          child: Text(no, style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(sub, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ],
    ),
  );
}

class Finance extends StatelessWidget {
  const Finance({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('التقرير المالي'),
      backgroundColor: C.dark,
      foregroundColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إجمالي الكاش المحصل اليوم',
                style: TextStyle(color: C.muted),
              ),
              SizedBox(height: 7),
              Text(
                '1,300 دج',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              Divider(height: 26),
              Line('أرباح التوصيل', '+ 200 دج'),
              Line('الطلبات المنجزة', '1 مهمة'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'تفاصيل عهدة اليوم',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            children: [
              Line('الطلب #TJ-104', '1,300 دج'),
              Line('مشتريات (كوكوكاولا)', '200 دج'),
              Line('طاجين زيتون + بوراك', '900 دج'),
              Line('خدمة التوصيل', '200 دج'),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Live customer order list backed by the shared database adapter.
class OrdersLive extends StatelessWidget {
  final AppDatabase db;
  final VoidCallback onReorder;
  const OrdersLive({super.key, required this.db, required this.onReorder});

  String label(String status) => switch (status) {
    'draft' => 'مسودة • بانتظار السائق',
    'confirmed' => 'تم التأكيد',
    'picked_up' => 'في الطريق',
    'delivered' => 'تم التسليم',
    _ => status,
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: db,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const TitleBlock('طلباتي', 'حالة طلبك تتحدث مباشرة'),
        const SizedBox(height: 18),
        ...db.orders.map(
          (order) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'الطلب #${order['id']}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      label(order['status'] as String),
                      style: TextStyle(
                        color: order['status'] == 'delivered'
                            ? C.green
                            : C.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Text(
                      'المبلغ الإجمالي',
                      style: TextStyle(color: C.muted),
                    ),
                    const Spacer(),
                    Text(
                      '${order['total']} دج',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: C.orange,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onReorder,
                  child: const Text('إعادة الطلب'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Driver queue: draft orders become confirmed, picked up, then delivered.
class DriverLive extends StatelessWidget {
  final AppDatabase db;
  final VoidCallback onBack;
  const DriverLive({super.key, required this.db, required this.onBack});

  @override
  Widget build(BuildContext context) => Container(
    color: C.dark,
    child: AnimatedBuilder(
      animation: db,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'طلبات السائق',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'الطلبات الجديدة تظهر هنا كمسودة',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          ...db.orders.map((order) => _DriverOrder(db: db, order: order)),
        ],
      ),
    ),
  );
}

class _DriverOrder extends StatelessWidget {
  final AppDatabase db;
  final Map<String, dynamic> order;
  const _DriverOrder({required this.db, required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String;
    final isDone = status == 'delivered';
    final action = status == 'draft'
        ? 'تأكيد الطلب'
        : status == 'confirmed'
        ? 'تأكيد استلام الطلب'
        : status == 'picked_up'
        ? 'تأكيد التسليم'
        : 'تم تحويل المستحقات';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff493a34),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${order['id']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Text(
                '${order['total']} دج',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status == 'draft' ? 'طلب جديد من فتحي' : 'حالة الطلب: $status',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isDone
                  ? null
                  : () => status == 'draft'
                        ? db.confirmOrder(order['id'] as String)
                        : db.advanceOrder(order['id'] as String),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'draft' ? C.orange : C.green,
                foregroundColor: Colors.white,
              ),
              child: Text(action),
            ),
          ),
          if (status == 'confirmed' || status == 'picked_up') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => db.advanceOrder(order['id'] as String),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: Text(
                  status == 'confirmed' ? 'استلام من المطبخ' : 'تسليم للزبون',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
