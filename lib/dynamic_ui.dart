import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'localized_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'domain.dart';
import 'marketplace_store.dart';

const _ink = Color(0xFF181C19);
const _accent = Color(0xFFFF6B35);
const _green = Color(0xFF145A42);
const _surface = Color(0xFFFFFFFF);
const _muted = Color(0xFF6A746E);

String _price(num value) => '${value.toStringAsFixed(0)} DA';

String _fallbackMedia(Product product) {
  final value = '${product.name} ${product.category}'.toLowerCase();
  if (value.contains('pâte') || value.contains('pasta')) {
    return 'assets/products/mushroom-pasta.png';
  }
  if (value.contains('burger')) return 'assets/products/smash-burger.png';
  if (value.contains('avocat')) {
    return 'assets/products/organic-avocados.png';
  }
  if (value.contains('pain') || value.contains('boulanger')) {
    return 'assets/products/artisan-bread.png';
  }
  return 'assets/marketplace_hero.png';
}

class ProductMedia extends StatelessWidget {
  const ProductMedia(
    this.product, {
    super.key,
    this.borderRadius = 24,
    this.fit = BoxFit.cover,
    this.playVideo = false,
  });

  final Product product;
  final double borderRadius;
  final BoxFit fit;
  final bool playVideo;

  @override
  Widget build(BuildContext context) {
    final media = product.mediaUrl;
    Widget child;
    if (media == null || media.isEmpty || media.startsWith('assets/')) {
      child = Image.asset(
        media?.isNotEmpty == true ? media! : _fallbackMedia(product),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (product.mediaType == ProductMediaType.video) {
      child = playVideo
          ? _VideoPlayer(url: media)
          : Container(
              color: _ink,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white,
                    foregroundColor: _ink,
                    child: Icon(Icons.play_arrow_rounded, size: 34),
                  ),
                  SizedBox(height: 9),
                  Text(
                    'VIDÉO DU PRODUIT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            );
    } else {
      child = Image.network(
        media,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Image.asset(
          _fallbackMedia(product),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
        ),
        loadingBuilder: (context, image, progress) => progress == null
            ? image
            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(color: const Color(0xFFE8ECE7), child: child),
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({required this.url});
  final String url;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(
        color: _ink,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        controller.value.isPlaying ? controller.pause() : controller.play();
      }),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            const Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                foregroundColor: _ink,
                child: Icon(Icons.play_arrow_rounded, size: 38),
              ),
            ),
        ],
      ),
    );
  }
}

void showProductDetails(
  BuildContext context,
  Product product,
  MarketplaceStore store,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _surface,
    builder: (context) {
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height - keyboard;
            return SizedBox(
              height: height,
              child: _ProductDetails(product: product, store: store),
            );
          },
        ),
      );
    },
  );
}

class _ProductDetails extends StatefulWidget {
  const _ProductDetails({required this.product, required this.store});
  final Product product;
  final MarketplaceStore store;

  @override
  State<_ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<_ProductDetails> {
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final store = widget.store;
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                expandedHeight: 240,
                backgroundColor: _surface,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(7),
                  child: IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _ink,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: ProductMedia(
                    product,
                    borderRadius: 0,
                    playVideo: true,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        _Pill(product.category, _green),
                        const Spacer(),
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB400),
                        ),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Text(
                      product.name,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 30,
                        height: 1.05,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      store.merchantName(product),
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      product.description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 19),
                    Row(
                      children: [
                        _Metric(
                          product.kind == ProductKind.meal
                              ? Icons.restaurant_outlined
                              : Icons.shopping_basket_outlined,
                          product.kind == ProductKind.meal ? 'Plat' : 'Produit',
                          'Type',
                        ),
                        _Metric(
                          Icons.timer_outlined,
                          '${product.preparationMinutes} min',
                          'Préparation',
                        ),
                      ],
                    ),
                    if (product.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 25),
                      const Text(
                        'Ce que contient ce produit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: product.ingredients
                            .map((ingredient) => _Pill(ingredient, _ink))
                            .toList(),
                      ),
                    ],
                    if (product.allergens.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: _accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Allergènes : ${product.allergens.join(', ')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
        if (store.currentUser?.role == UserRole.client)
          SafeArea(
            top: false,
            bottom: MediaQuery.viewInsetsOf(context).bottom == 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E9E5))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('product-note-field'),
                    controller: note,
                    maxLines: 2,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 160),
                    decoration: InputDecoration(
                      labelText: store.tr(
                        'Notes pour le restaurant ou le livreur',
                        'ملاحظات للمطعم أو الموصّل',
                      ),
                      hintText: store.tr(
                        'Ex. sans oignons, sonner à l’arrivée…',
                        'مثال: بدون بصل، اتصل عند الوصول…',
                      ),
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prix', style: TextStyle(color: _muted)),
                            Text(
                              _price(product.retailPrice),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          store.addToCart(product, note: note.text);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Ajouter au panier'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.value, this.label);
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: _green),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class PickedMedia {
  const PickedMedia({
    required this.bytes,
    required this.name,
    required this.contentType,
    required this.type,
  });
  final Uint8List bytes;
  final String name, contentType;
  final ProductMediaType type;
}

Future<PickedMedia?> pickProductMedia({bool imagesOnly = false}) async {
  final picker = ImagePicker();
  final file = imagesOnly
      ? await picker.pickImage(source: ImageSource.gallery)
      : await picker.pickMedia();
  if (file == null) return null;
  final data = await file.readAsBytes();
  if (data.isEmpty) return null;
  final dot = file.name.lastIndexOf('.');
  final extension = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
  final contentType = switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'mp4' => 'video/mp4',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    _ => '',
  };
  if (contentType.isEmpty) return null;
  return PickedMedia(
    bytes: data,
    name: file.name,
    contentType: contentType,
    type: contentType.startsWith('video/')
        ? ProductMediaType.video
        : ProductMediaType.image,
  );
}

void showProductEditor(BuildContext context, MarketplaceStore store) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _surface,
    builder: (_) => FractionallySizedBox(
      heightFactor: .95,
      child: _ProductEditor(store: store),
    ),
  );
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({required this.store});
  final MarketplaceStore store;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final name = TextEditingController();
  final description = TextEditingController();
  final ingredients = TextEditingController();
  final allergens = TextEditingController();
  final wholesale = TextEditingController();
  PickedMedia? media;
  String? category;
  bool publishing = false;

  @override
  void dispose() {
    for (final controller in [
      name,
      description,
      ingredients,
      allergens,
      wholesale,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> split(TextEditingController controller) => controller.text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  Future<void> submit() async {
    final wholesalePrice = int.tryParse(wholesale.text);
    if (name.text.trim().isEmpty ||
        description.text.trim().length < 10 ||
        category == null ||
        media == null ||
        wholesalePrice == null ||
        wholesalePrice <= 0) {
      _message('Ajoutez le média et complétez tous les détails obligatoires.');
      return;
    }
    setState(() => publishing = true);
    final mediaUrl = await widget.store.uploadMedia(
      bytes: media!.bytes,
      fileName: media!.name,
      contentType: media!.contentType,
    );
    if (mediaUrl == null) {
      if (mounted) setState(() => publishing = false);
      return;
    }
    final ok = await widget.store.addProduct(
      name: name.text.trim(),
      description: description.text.trim(),
      category: category!,
      wholesale: wholesalePrice,
      emoji: '🍽️',
      mediaUrl: mediaUrl,
      mediaType: media!.type,
      ingredients: split(ingredients),
      allergens: split(allergens),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => publishing = false);
      _message(widget.store.lastError ?? 'Publication impossible.');
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final kind = widget.store.currentUser!.role == UserRole.supermarket
        ? ProductKind.grocery
        : ProductKind.meal;
    final categories = widget.store.categoriesFor(kind);
    category ??= categories.isEmpty ? null : categories.first.name;
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(
          kind == ProductKind.meal ? 'Créer un plat' : 'Créer un produit',
        ),
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: publishing
                  ? null
                  : () async {
                      final picked = await pickProductMedia();
                      if (picked != null && mounted) {
                        setState(() => media = picked);
                      }
                    },
              child: Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECE7),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFD9DED9)),
                  image: media?.type == ProductMediaType.image
                      ? DecorationImage(
                          image: MemoryImage(media!.bytes),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: media?.type == ProductMediaType.image
                    ? null
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            media == null
                                ? Icons.add_photo_alternate_outlined
                                : Icons.movie_outlined,
                            size: 44,
                            color: _green,
                          ),
                          const SizedBox(height: 9),
                          Text(
                            media?.name ?? 'Ajouter une photo ou une vidéo',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          const Text('Image 8 Mo max · Vidéo 25 Mo max'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: widget.store.tr('Nom *', 'الاسم *'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: widget.store.tr(
                  'Description complète *',
                  'الوصف الكامل *',
                ),
                hintText: widget.store.tr(
                  'Saveurs, texture, accompagnement, portion…',
                  'النكهة والمكونات والحصة…',
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: widget.store.tr(
                  'Catégorie dynamique *',
                  'التصنيف *',
                ),
              ),
              items: categories
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.name,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => category = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ingredients,
              decoration: InputDecoration(
                labelText: widget.store.tr('Ingrédients', 'المكونات'),
                hintText: widget.store.tr(
                  'Poulet, quinoa, tomates…',
                  'دجاج، كينوا، طماطم…',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: allergens,
              decoration: InputDecoration(
                labelText: widget.store.tr('Allergènes', 'مسببات الحساسية'),
                hintText: widget.store.tr(
                  'Gluten, lait, fruits à coque…',
                  'جلوتين، حليب، مكسرات…',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: wholesale,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.store.tr('Prix de gros *', 'سعر الجملة *'),
                suffixText: 'DA',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le prix client sera fixé par l’administrateur après validation.',
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: publishing ? null : submit,
                icon: publishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.publish_rounded),
                label: Text(publishing ? 'Envoi…' : 'Envoyer pour validation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showProfileEditor(BuildContext context, MarketplaceStore store) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _surface,
    builder: (_) => FractionallySizedBox(
      heightFactor: .92,
      child: _ProfileEditor(store: store),
    ),
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.store});
  final MarketplaceStore store;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController name;
  late final TextEditingController email;
  late final TextEditingController phone;
  late final TextEditingController address;
  late final TextEditingController business;
  PickedMedia? avatar;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.store.currentUser!;
    name = TextEditingController(text: user.name);
    email = TextEditingController(text: user.email);
    phone = TextEditingController(text: user.phone);
    address = TextEditingController(text: user.address);
    business = TextEditingController(text: user.businessName ?? '');
  }

  @override
  void dispose() {
    for (final controller in [name, email, phone, address, business]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().length < 2 || !email.text.contains('@')) return;
    setState(() => saving = true);
    var avatarUrl = widget.store.currentUser!.avatarUrl;
    if (avatar != null) {
      avatarUrl = await widget.store.uploadMedia(
        bytes: avatar!.bytes,
        fileName: avatar!.name,
        contentType: avatar!.contentType,
      );
      if (avatarUrl == null) {
        if (mounted) setState(() => saving = false);
        return;
      }
    }
    final ok = await widget.store.updateProfile(
      name: name.text.trim(),
      email: email.text.trim(),
      phone: phone.text.trim(),
      address: address.text.trim(),
      businessName: business.text.trim().isEmpty ? null : business.text.trim(),
      avatarUrl: avatarUrl,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.store.lastError ?? 'Enregistrement impossible.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.store.currentUser!;
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
        child: Column(
          children: [
            GestureDetector(
              onTap: saving
                  ? null
                  : () async {
                      final picked = await pickProductMedia(imagesOnly: true);
                      if (picked != null && mounted) {
                        setState(() => avatar = picked);
                      }
                    },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFE6ECE7),
                    backgroundImage: avatar != null
                        ? MemoryImage(avatar!.bytes)
                        : user.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(user.avatarUrl!) as ImageProvider
                        : null,
                    child: avatar == null && user.avatarUrl?.isNotEmpty != true
                        ? Text(
                            user.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.camera_alt_rounded, size: 17),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: widget.store.tr('Nom complet', 'الاسم الكامل'),
              ),
            ),
            const SizedBox(height: 12),
            if (user.role == UserRole.restaurant ||
                user.role == UserRole.supermarket) ...[
              TextField(
                controller: business,
                decoration: InputDecoration(
                  labelText: widget.store.tr('Nom du commerce', 'اسم المتجر'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: widget.store.tr(
                  'Adresse e-mail',
                  'البريد الإلكتروني',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: widget.store.tr('Téléphone', 'الهاتف'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: user.role == UserRole.client
                    ? widget.store.tr(
                        'Adresse de livraison par défaut',
                        'عنوان التوصيل الافتراضي',
                      )
                    : widget.store.tr('Adresse professionnelle', 'عنوان العمل'),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enregistrer les modifications'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showNotifications(BuildContext context, MarketplaceStore store) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _surface,
    builder: (_) => FractionallySizedBox(
      heightFactor: .86,
      child: _NotificationsView(store: store),
    ),
  );
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView({required this.store});
  final MarketplaceStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (store.unreadNotifications > 0)
            TextButton(
              onPressed: store.markAllNotificationsRead,
              child: const Text('Tout lire'),
            ),
        ],
      ),
      body: store.notifications.isEmpty
          ? const Center(child: Text('Aucune notification pour le moment.'))
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: store.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = store.notifications[index];
                final icon = switch (item.type) {
                  'payment' => Icons.account_balance_wallet_outlined,
                  'catalog' => Icons.inventory_2_outlined,
                  'account' => Icons.person_add_alt_rounded,
                  _ => Icons.receipt_long_outlined,
                };
                return Material(
                  color: item.read ? Colors.white : const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(20),
                  child: ListTile(
                    onTap: () => store.markNotificationRead(item),
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      backgroundColor: item.read
                          ? const Color(0xFFE7ECE8)
                          : _accent.withValues(alpha: .14),
                      foregroundColor: item.read ? _green : _accent,
                      child: Icon(icon),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(item.message),
                    ),
                    trailing: item.read
                        ? null
                        : const CircleAvatar(
                            radius: 5,
                            backgroundColor: _accent,
                          ),
                  ),
                );
              },
            ),
    ),
  );
}

class NotificationButton extends StatelessWidget {
  const NotificationButton({super.key, required this.store});
  final MarketplaceStore store;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: store.unreadNotifications > 0,
    label: Text('${store.unreadNotifications}'),
    child: IconButton.filledTonal(
      tooltip: 'Notifications',
      onPressed: () => showNotifications(context, store),
      icon: const Icon(Icons.notifications_none_rounded),
    ),
  );
}

class CategoryManagementPanel extends StatelessWidget {
  const CategoryManagementPanel({super.key, required this.store});
  final MarketplaceStore store;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Catégories',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _showAddCategory(context, store),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ...store.categories.map(
        (category) => Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: category.kind == ProductKind.meal
                  ? const Color(0xFFFFE9DF)
                  : const Color(0xFFE2EFE7),
              child: Icon(
                category.kind == ProductKind.meal
                    ? Icons.restaurant_rounded
                    : Icons.shopping_basket_rounded,
                color: category.kind == ProductKind.meal ? _accent : _green,
              ),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              category.kind == ProductKind.meal ? 'Repas' : 'Supérette',
            ),
            trailing: Switch(
              value: category.active,
              onChanged: (_) => store.toggleCategory(category),
            ),
          ),
        ),
      ),
    ],
  );
}

void _showAddCategory(BuildContext context, MarketplaceStore store) {
  final controller = TextEditingController();
  var kind = ProductKind.meal;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: store.tr('Nom', 'الاسم')),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ProductKind>(
              segments: const [
                ButtonSegment(value: ProductKind.meal, label: Text('Repas')),
                ButtonSegment(
                  value: ProductKind.grocery,
                  label: Text('Supérette'),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (value) => setState(() => kind = value.first),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await store.addCategory(controller.text, kind);
              if (dialogContext.mounted && ok) Navigator.pop(dialogContext);
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}
