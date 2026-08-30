import 'package:flutter/material.dart';
import 'data/app_database.dart';
import 'data/auth_service.dart';
import 'data/supabase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseBackend.initialize();
  } catch (_) {
    // Keep the demo adapter usable when production keys are not configured yet.
  }
  await AppDatabase.instance.refreshFromRemote();
  runApp(const App());
}

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
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final auth = AuthService.instance;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: auth,
    builder: (_, _) => auth.currentUser == null
        ? LoginScreen(auth: auth)
        : Shell(user: auth.currentUser!, onLogout: auth.logout),
  );
}

class LoginScreen extends StatefulWidget {
  final AuthService auth;
  const LoginScreen({super.key, required this.auth});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    final user = await widget.auth.login(email.text, password.text);
    if (!mounted) return;
    setState(() => loading = false);
    if (user == null) {
      setState(
        () =>
            error = 'المعلومات غير صحيحة. استعمل أحد الحسابات التجريبية أدناه.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xfffff7ed), C.bg],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: C.dark,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22352723),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.restaurant_menu,
                      color: C.orange,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'وصلة',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: C.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'من المطبخ لباب دارك',
                    style: TextStyle(color: C.muted),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xffeee6df)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تسجيل الدخول',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: C.text,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'ادخل لحسابك باش تتابع طلباتك',
                          style: TextStyle(color: C.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email / رقم الحساب',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: true,
                          onSubmitted: (_) => submit(),
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: loading ? null : submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'دخول إلى التطبيق',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.dark,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حسابات التجربة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '1 / 1  ︱ زبون      2 / 2  ︱ سائق\n3 / 3  ︱ مطعم     4 / 4  ︱ مورد\n5 / 5  ︱ مدير عام',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.8,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  final SessionUser user;
  final VoidCallback onLogout;
  const Shell({super.key, required this.user, required this.onLogout});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final db = AppDatabase.instance;
  var index = 0;
  var cart = 0;
  var total = 0;
  var driver = false;

  @override
  void initState() {
    super.initState();
    db.refreshFromRemote();
  }

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
    if (widget.user.role == UserRole.driver) {
      page = DriverWorkspace(db: db, onLogout: widget.onLogout);
    } else if (driver) {
      page = DriverLive(db: db, onBack: () => setState(() => driver = false));
    } else if (widget.user.role != UserRole.client) {
      page = PartnerWorkspace(
        db: db,
        role: widget.user.role,
        onLogout: widget.onLogout,
      );
    } else if (index == 0) {
      page = Home(cart: cart, onAdd: add, onCart: () => openCart());
    } else if (index == 1) {
      page = Favorites(onAdd: add);
    } else if (index == 2) {
      page = OrdersLive(db: db, onReorder: () => add(menu[0]));
    } else {
      page = Profile(
        onDriver: () => setState(() => driver = true),
        user: widget.user,
        onLogout: widget.onLogout,
      );
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
  final VoidCallback onCart;
  const Home({
    super.key,
    required this.cart,
    required this.onAdd,
    required this.onCart,
  });
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Header(cart: cart, onCart: onCart),
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
  final VoidCallback onCart;
  const Header({super.key, required this.cart, required this.onCart});
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
  final SessionUser user;
  final VoidCallback onLogout;
  const Profile({
    super.key,
    required this.onDriver,
    required this.user,
    required this.onLogout,
  });
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      TitleBlock('حسابي', 'إدارة الحساب والمحفظة • ${user.roleLabel}'),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: C.dark,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: C.orange,
              child: Icon(Icons.person, color: Colors.white),
            ),
            SizedBox(width: 14),
            Text(
              'فتحي بوعلام\n${user.roleLabel} • حساب تجريبي',
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
      ActionTile(Icons.logout, 'تسجيل الخروج', 'خروج آمن', onTap: onLogout),
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

class PartnerPortal extends StatelessWidget {
  final UserRole role;
  final VoidCallback onLogout;
  const PartnerPortal({super.key, required this.role, required this.onLogout});

  String get title => switch (role) {
    UserRole.restaurant => 'لوحة المطعم',
    UserRole.supplier => 'لوحة المورد',
    UserRole.admin => 'لوحة المدير العام',
    _ => 'لوحة الشريك',
  };

  String get subtitle => switch (role) {
    UserRole.restaurant => 'تابع الأطباق والطلبات وأرباحك',
    UserRole.supplier => 'إدارة التوريد والفواتير والطلبات',
    UserRole.admin => 'مراقبة العمليات والخزينة والتسويات',
    _ => 'مركز العمليات',
  };

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Row(
        children: [
          Expanded(child: TitleBlock(title, subtitle)),
          IconButton(
            onPressed: onLogout,
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout, color: C.orange),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: C.dark,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: C.orange,
              child: Icon(Icons.storefront, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role == UserRole.admin ? 'حساب الإدارة' : 'حساب الشريك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role == UserRole.admin ? 'صلاحيات كاملة' : 'متصل الآن',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: MetricCard(
              label: role == UserRole.admin ? 'إجمالي العمليات' : 'طلبات اليوم',
              value: role == UserRole.admin ? '24' : '8',
              icon: Icons.receipt_long_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricCard(
              label: 'الرصيد المتاح',
              value: role == UserRole.admin ? '12,480 دج' : '4,260 دج',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const Text(
        'الطلبات الأخيرة',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w900,
          color: C.text,
        ),
      ),
      const SizedBox(height: 10),
      ...const [
        PartnerOrderCard(
          code: '#TJ-104',
          status: 'قيد التحضير',
          total: '1,300 دج',
        ),
        PartnerOrderCard(
          code: '#TJ-103',
          status: 'تم التسليم',
          total: '850 دج',
        ),
      ],
      const SizedBox(height: 18),
      ActionTile(
        Icons.account_balance_wallet_outlined,
        role == UserRole.admin ? 'الخزينة المركزية' : 'المحفظة والتسويات',
        role == UserRole.admin ? '12,480 دج' : 'طلب سحب',
      ),
      ActionTile(
        Icons.inventory_2_outlined,
        role == UserRole.supplier ? 'الفواتير والمشتريات' : 'إدارة الأطباق',
        'فتح',
      ),
    ],
  );
}

class MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffece7e2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: C.orange),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: C.muted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: C.text,
          ),
        ),
      ],
    ),
  );
}

class PartnerOrderCard extends StatelessWidget {
  final String code, status, total;
  const PartnerOrderCard({
    super.key,
    required this.code,
    required this.status,
    required this.total,
  });
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: const CircleAvatar(backgroundColor: C.pale, child: Text('🍲')),
      title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        status,
        style: TextStyle(
          color: status == 'تم التسليم' ? C.green : C.orange,
          fontSize: 12,
        ),
      ),
      trailing: Text(
        total,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class DriverWorkspace extends StatefulWidget {
  final AppDatabase db;
  final VoidCallback onLogout;
  const DriverWorkspace({super.key, required this.db, required this.onLogout});
  @override
  State<DriverWorkspace> createState() => _DriverWorkspaceState();
}

class _DriverWorkspaceState extends State<DriverWorkspace> {
  int tab = 0;
  String statusText(String status) => switch (status) {
    'draft' => 'مسودة جديدة',
    'confirmed' => 'مؤكد • جاهز للاستلام',
    'picked_up' => 'في الطريق',
    'delivered' => 'تم التسليم',
    _ => status,
  };

  void showOrder(Map<String, dynamic> order) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: C.bg,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل الطلب #${order['id']}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 21,
                color: C.text,
              ),
            ),
            const SizedBox(height: 14),
            DetailLine('الزبون', order['customer'] as String? ?? 'فتحي'),
            DetailLine('المنتجات', '${order['items'] ?? 2} أصناف'),
            DetailLine('المبلغ', '${order['total']} دج'),
            DetailLine('الحالة', statusText(order['status'] as String)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => tab = 0);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('إغلاق التفاصيل'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.dark,
      foregroundColor: Colors.white,
      title: Text(
        tab == 0
            ? 'طلبات التوصيل'
            : tab == 1
            ? 'إحصائيات السائق'
            : 'ملفي الشخصي',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          onPressed: widget.onLogout,
          tooltip: 'تسجيل الخروج',
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.db,
      builder: (_, _) => switch (tab) {
        0 => driverOrders(),
        1 => driverStats(),
        _ => driverProfile(),
      },
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      backgroundColor: Colors.white,
      indicatorColor: C.pale,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'الطلبات',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights),
          label: 'إحصائيات',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'الملف',
        ),
      ],
    ),
  );

  Widget driverOrders() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const TitleBlock(
        'طلبات التوصيل',
        'كل طلب جديد يظهر هنا ويمكنك تحديث حالته',
      ),
      const SizedBox(height: 16),
      if (widget.db.orders.isEmpty)
        const EmptyState(text: 'ما كاش طلبات جديدة'),
      ...widget.db.orders.map(
        (order) => DriverOrderCard(
          order: order,
          statusText: statusText(order['status'] as String),
          onDetails: () => showOrder(order),
          onAction: () {
            final id = order['id'] as String;
            if (order['status'] == 'draft') {
              widget.db.confirmOrder(id);
            } else {
              widget.db.advanceOrder(id);
            }
          },
        ),
      ),
    ],
  );

  Widget driverStats() {
    final deliveries = widget.db.orders
        .where((o) => o['status'] == 'delivered')
        .length;
    final deliveryFees = widget.db.walletEntries
        .where((e) => e['type'] == 'delivery_fee')
        .fold<int>(0, (s, e) => s + (e['amount'] as int));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const TitleBlock('إحصائيات السائق', 'ملخص الأداء والعهدة اليومية'),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'الطلبات المسلّمة',
                value: '$deliveries',
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'أرباح التوصيل',
                value: '$deliveryFees دج',
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تقدم اليوم',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: widget.db.orders.isEmpty
                      ? 0
                      : deliveries / widget.db.orders.length,
                  minHeight: 12,
                  color: C.green,
                  backgroundColor: C.pale,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '$deliveries من ${widget.db.orders.length} طلبات مكتملة',
                style: const TextStyle(color: C.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: C.dark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'العهدة الواجب تسليمها',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 6),
              Text(
                '1,100 دج',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'تتحدث بعد كل عملية تسليم',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget driverProfile() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const TitleBlock('ملفي الشخصي', 'إعدادات حساب السائق'),
      const SizedBox(height: 18),
      const ProfileHero(
        name: 'سائق وصلة',
        role: 'سائق توصيل • متصل الآن',
        icon: Icons.local_shipping,
      ),
      const SizedBox(height: 14),
      const ActionTile(Icons.badge_outlined, 'معلومات الحساب', 'تعديل'),
      const ActionTile(Icons.notifications_none, 'الإشعارات', 'مفعّلة'),
      ActionTile(
        Icons.logout,
        'تسجيل الخروج',
        'خروج آمن',
        onTap: widget.onLogout,
      ),
    ],
  );
}

class DriverOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String statusText;
  final VoidCallback onDetails, onAction;
  const DriverOrderCard({
    super.key,
    required this.order,
    required this.statusText,
    required this.onDetails,
    required this.onAction,
  });
  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String;
    final done = status == 'delivered';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffece7e2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: done ? C.green : C.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '#${order['id']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              Text(
                '${order['total']} دج',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: C.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              statusText,
              style: TextStyle(color: done ? C.green : C.muted, fontSize: 12),
            ),
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetails,
                  child: const Text('التفاصيل'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: done ? null : onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'draft' ? C.orange : C.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    done
                        ? 'مكتمل'
                        : status == 'draft'
                        ? 'تأكيد'
                        : 'تحديث الحالة',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DetailLine extends StatelessWidget {
  final String label, value;
  const DetailLine(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: C.muted)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, color: C.text),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 58, color: C.muted),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(color: C.muted, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class ProfileHero extends StatelessWidget {
  final String name, role;
  final IconData icon;
  const ProfileHero({
    super.key,
    required this.name,
    required this.role,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: C.dark,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: C.orange,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              role,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

class PartnerWorkspace extends StatefulWidget {
  final AppDatabase db;
  final UserRole role;
  final VoidCallback onLogout;
  const PartnerWorkspace({
    super.key,
    required this.db,
    required this.role,
    required this.onLogout,
  });
  @override
  State<PartnerWorkspace> createState() => _PartnerWorkspaceState();
}

class _PartnerWorkspaceState extends State<PartnerWorkspace> {
  int tab = 0;
  String get title => switch (widget.role) {
    UserRole.restaurant => 'المطعم',
    UserRole.supplier => 'المورد',
    _ => 'المدير العام',
  };
  String get roleText => switch (widget.role) {
    UserRole.restaurant => 'إدارة الأطباق والطلبات والأرباح',
    UserRole.supplier => 'التوريد والفواتير والحسابات',
    _ => 'الخزينة والعمولات والتسويات',
  };

  String status(String s) => switch (s) {
    'draft' => 'مسودة',
    'confirmed' => 'مؤكد',
    'picked_up' => 'في الطريق',
    'delivered' => 'تم التسليم',
    _ => s,
  };

  void orderDetails(Map<String, dynamic> order) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: C.bg,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تفاصيل الطلب #${order['id']}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 15),
            DetailLine('الزبون', order['customer'] as String? ?? 'فتحي'),
            DetailLine('الحالة', status(order['status'] as String)),
            DetailLine('الإجمالي', '${order['total']} دج'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('تم'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.dark,
      foregroundColor: Colors.white,
      title: Text(
        tab == 0
            ? 'لوحة $title'
            : tab == 1
            ? 'طلبات $title'
            : 'ملف $title',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          onPressed: widget.onLogout,
          tooltip: 'تسجيل الخروج',
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.db,
      builder: (_, _) => switch (tab) {
        0 => overview(),
        1 => orders(),
        _ => profile(),
      },
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      backgroundColor: Colors.white,
      indicatorColor: C.pale,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'الطلبات',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'الملف',
        ),
      ],
    ),
  );

  Widget overview() {
    final delivered = widget.db.orders
        .where((o) => o['status'] == 'delivered')
        .length;
    final pending = widget.db.orders
        .where((o) => o['status'] != 'delivered')
        .length;
    final wallet = widget.db.walletEntries.fold<int>(
      0,
      (s, e) => s + (e['amount'] as int),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TitleBlock('لوحة $title', roleText),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'طلبات اليوم',
                value: '${widget.db.orders.length}',
                icon: Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'طلبات معلقة',
                value: '$pending',
                icon: Icons.hourglass_top_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'تم التسليم',
                value: '$delivered',
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'رصيد المحفظة',
                value: '$wallet دج',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: C.dark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ملخص مالي', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 8),
              Text(
                '80% مستحق للشريك  •  20% عمولة الإدارة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'يتم إنشاء القيود تلقائياً عند إتمام التسليم.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'آخر الطلبات',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
        const SizedBox(height: 10),
        ...widget.db.orders
            .take(3)
            .map(
              (o) => PartnerOrderCard(
                code: '#${o['id']}',
                status: status(o['status'] as String),
                total: '${o['total']} دج',
              ),
            ),
      ],
    );
  }

  Widget orders() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      TitleBlock('طلبات $title', 'افتح التفاصيل وتابع كل حالة'),
      const SizedBox(height: 18),
      ...widget.db.orders.map(
        (o) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          child: ListTile(
            onTap: () => orderDetails(o),
            leading: const CircleAvatar(
              backgroundColor: C.pale,
              child: Text('🍲'),
            ),
            title: Text(
              '#${o['id']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(status(o['status'] as String)),
            trailing: Text(
              '${o['total']} دج',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    ],
  );

  Widget profile() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      TitleBlock('ملف $title', 'بيانات الحساب والصلاحيات'),
      const SizedBox(height: 18),
      ProfileHero(
        name: title,
        role: roleText,
        icon: widget.role == UserRole.admin
            ? Icons.admin_panel_settings
            : Icons.storefront,
      ),
      const SizedBox(height: 14),
      const ActionTile(Icons.verified_user_outlined, 'صلاحيات الحساب', 'نشطة'),
      const ActionTile(Icons.notifications_none, 'الإشعارات', 'مفعّلة'),
      ActionTile(
        Icons.logout,
        'تسجيل الخروج',
        'خروج آمن',
        onTap: widget.onLogout,
      ),
    ],
  );
}
