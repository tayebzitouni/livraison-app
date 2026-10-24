import 'dart:async';
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
      child = LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final logicalWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final cacheWidth = (logicalWidth * pixelRatio).round().clamp(1, 1600);
          return Image.network(
            media,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Image.asset(
              _fallbackMedia(product),
              fit: fit,
              width: double.infinity,
              height: double.infinity,
            ),
            loadingBuilder: (context, image, progress) => progress == null
                ? image
                : const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          );
        },
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
                    if (!product.available) ...[
                      const SizedBox(height: 12),
                      FormMessage(
                        store.tr(
                          'Produit épuisé · commande indisponible',
                          'المنتج نفد · الطلب غير متاح',
                        ),
                        error: false,
                      ),
                    ],
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
                    enabled: product.available,
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
                        onPressed: !product.available
                            ? null
                            : () {
                                store.addToCart(product, note: note.text);
                                Navigator.pop(context);
                              },
                        icon: Icon(
                          product.available
                              ? Icons.shopping_bag_outlined
                              : Icons.block_rounded,
                        ),
                        label: Text(
                          product.available
                              ? store.tr('Ajouter au panier', 'أضف إلى السلة')
                              : store.tr('Épuisé', 'نفد المخزون'),
                        ),
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

/// Inline feedback box, used inside sheets and dialogs where a SnackBar would
/// be hidden behind the modal layer.
class FormMessage extends StatelessWidget {
  const FormMessage(this.text, {super.key, this.error = true});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFB42318) : _green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFDECEA) : const Color(0xFFE4F0E9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
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

/// Outcome of choosing a photo or video: either a usable file or the reason
/// it cannot be used.
class MediaPick {
  const MediaPick.ok(PickedMedia this.media) : error = null;
  const MediaPick.fail(String this.error) : media = null;
  final PickedMedia? media;
  final String? error;
}

const _maxImageBytes = 8 * 1024 * 1024;
const _maxVideoBytes = 25 * 1024 * 1024;

/// Lets the user choose a photo (or video) from the gallery. Photos are
/// resized and compressed so a modern phone picture always fits the upload
/// limit. Returns `null` when the picker is dismissed.
Future<MediaPick?> pickProductMedia(
  MarketplaceStore store, {
  bool imagesOnly = false,
}) async {
  final picker = ImagePicker();
  final XFile? file;
  try {
    file = imagesOnly
        ? await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 82,
          )
        : await picker.pickMedia(
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 82,
          );
  } catch (_) {
    return MediaPick.fail(
      store.tr(
        'Impossible d’ouvrir la galerie. Autorisez l’accès aux photos.',
        'تعذر فتح المعرض. اسمح بالوصول إلى الصور.',
      ),
    );
  }
  if (file == null) return null;
  final data = await file.readAsBytes();
  if (data.isEmpty) {
    return MediaPick.fail(store.tr('Ce fichier est vide.', 'هذا الملف فارغ.'));
  }
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
  if (contentType.isEmpty) {
    return MediaPick.fail(
      store.tr(
        'Format non pris en charge. Choisissez une image JPG, PNG ou WebP, ou une vidéo MP4.',
        'صيغة غير مدعومة. اختر صورة JPG أو PNG أو WebP أو فيديو MP4.',
      ),
    );
  }
  final video = contentType.startsWith('video/');
  if (data.length > (video ? _maxVideoBytes : _maxImageBytes)) {
    return MediaPick.fail(
      store.tr(
        video
            ? 'Cette vidéo dépasse 25 Mo. Choisissez une vidéo plus courte.'
            : 'Cette image dépasse 8 Mo. Choisissez-en une plus légère.',
        video
            ? 'هذا الفيديو يتجاوز 25 م.ب. اختر فيديو أقصر.'
            : 'هذه الصورة تتجاوز 8 م.ب. اختر صورة أخف.',
      ),
    );
  }
  return MediaPick.ok(
    PickedMedia(
      bytes: data,
      name: file.name,
      contentType: contentType,
      type: video ? ProductMediaType.video : ProductMediaType.image,
    ),
  );
}

void showProductEditor(BuildContext context, MarketplaceStore store) {
  final messenger = ScaffoldMessenger.of(context);
  showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _surface,
    builder: (_) => FractionallySizedBox(
      heightFactor: .95,
      child: _ProductEditor(store: store),
    ),
  ).then((published) {
    if (published != true) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          store.tr(
            'Envoyé pour validation. Il sera visible après l’accord de l’administrateur.',
            'تم الإرسال للموافقة. سيظهر بعد موافقة المدير.',
          ),
        ),
      ),
    );
  });
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
  bool publishing = false, submitted = false;
  String? formError;

  MarketplaceStore get store => widget.store;

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

  String? _required(TextEditingController c, {int min = 1}) =>
      submitted && c.text.trim().length < min
      ? store.tr('Champ obligatoire', 'حقل إلزامي')
      : null;

  String? get _priceError {
    if (!submitted) return null;
    final price = int.tryParse(wholesale.text.trim());
    return price == null || price <= 0
        ? store.tr('Indiquez un prix supérieur à 0', 'أدخل سعراً أكبر من 0')
        : null;
  }

  Future<void> _pickMedia() async {
    final pick = await pickProductMedia(store);
    if (pick == null || !mounted) return;
    setState(() {
      if (pick.error != null) {
        formError = pick.error;
      } else {
        media = pick.media;
        formError = null;
      }
    });
  }

  /// Required: name, description, category and merchant price. Photo,
  /// ingredients and allergens are optional.
  Future<void> submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      submitted = true;
      formError = null;
    });
    final wholesalePrice = int.tryParse(wholesale.text.trim());
    if (name.text.trim().isEmpty ||
        description.text.trim().length < 2 ||
        category == null ||
        wholesalePrice == null ||
        wholesalePrice <= 0) {
      setState(
        () => formError = store.tr(
          'Complétez les champs obligatoires : nom, description, catégorie et votre prix de vente.',
          'أكمل الحقول الإلزامية: الاسم والوصف والتصنيف وسعر البيع الخاص بك.',
        ),
      );
      return;
    }
    setState(() => publishing = true);
    String? mediaUrl;
    if (media != null) {
      mediaUrl = await store.uploadMedia(
        bytes: media!.bytes,
        fileName: media!.name,
        contentType: media!.contentType,
      );
      if (mediaUrl == null) {
        if (mounted) {
          setState(() {
            publishing = false;
            formError =
                store.lastError ??
                store.tr(
                  'Le média n’a pas pu être envoyé. Retirez-le ou réessayez.',
                  'تعذر رفع الملف. أزله أو أعد المحاولة.',
                );
          });
        }
        return;
      }
    }
    final ok = await store.addProduct(
      name: name.text.trim(),
      description: description.text.trim(),
      category: category!,
      wholesale: wholesalePrice,
      emoji: '🍽️',
      mediaUrl: mediaUrl,
      mediaType: media?.type ?? ProductMediaType.image,
      ingredients: split(ingredients),
      allergens: split(allergens),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        publishing = false;
        formError =
            store.lastError ??
            store.tr('Publication impossible.', 'تعذر النشر.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = store.currentUser!.role == UserRole.supermarket
        ? ProductKind.grocery
        : ProductKind.meal;
    final categories = store.categoriesFor(kind);
    if (category != null && !categories.any((c) => c.name == category)) {
      category = null;
    }
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
              onTap: publishing ? null : _pickMedia,
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
            if (media != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: publishing
                      ? null
                      : () => setState(() => media = null),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(store.tr('Retirer le média', 'إزالة الملف')),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  store.tr(
                    'Photo ou vidéo facultative.',
                    'الصورة أو الفيديو اختياري.',
                  ),
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('product-name'),
              controller: name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: store.tr('Nom *', 'الاسم *'),
                errorText: _required(name),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('product-description'),
              controller: description,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: store.tr('Description complète *', 'الوصف الكامل *'),
                hintText: store.tr(
                  'Saveurs, texture, accompagnement, portion…',
                  'النكهة والمكونات والحصة…',
                ),
                alignLabelWithHint: true,
                errorText: _required(description, min: 2),
              ),
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              FormMessage(
                store.tr(
                  'Aucune catégorie n’est disponible pour le moment. Demandez à l’administrateur d’en ajouter.',
                  'لا توجد تصنيفات حالياً. اطلب من المدير إضافة تصنيف.',
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: const Key('product-category'),
                initialValue: category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: store.tr('Catégorie *', 'التصنيف *'),
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
                labelText: store.tr(
                  'Ingrédients (facultatif)',
                  'المكونات (اختياري)',
                ),
                hintText: store.tr(
                  'Poulet, quinoa, tomates…',
                  'دجاج، كينوا، طماطم…',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: allergens,
              decoration: InputDecoration(
                labelText: store.tr(
                  'Allergènes (facultatif)',
                  'مسببات الحساسية (اختياري)',
                ),
                hintText: store.tr(
                  'Gluten, lait, fruits à coque…',
                  'جلوتين، حليب، مكسرات…',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('product-wholesale'),
              controller: wholesale,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: store.tr(
                  'Votre prix de vente *',
                  'سعر البيع الخاص بك *',
                ),
                suffixText: store.tr('DA', 'دج'),
                errorText: _priceError,
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (_) {
                final merchantPrice = int.tryParse(wholesale.text.trim());
                final supermarket =
                    store.currentUser?.role == UserRole.supermarket;
                if (merchantPrice == null || merchantPrice <= 0) {
                  return Text(
                    store.tr(
                      supermarket
                          ? 'Indiquez votre prix. L’administrateur fixera ensuite directement le prix client, sans pourcentage.'
                          : 'La commission Wasla sera ajoutée automatiquement au prix client.',
                      supermarket
                          ? 'أدخل سعرك. سيحدد المدير بعد ذلك سعر الزبون مباشرة، بدون نسبة.'
                          : 'تُضاف عمولة وصلة تلقائياً إلى سعر الزبون.',
                    ),
                  );
                }
                if (supermarket) {
                  return FormMessage(
                    store.tr(
                      'Vous recevez ${_price(merchantPrice)}. L’administrateur choisit librement le prix de vente au client, sans calcul en pourcentage.',
                      'تحصل على ${_price(merchantPrice)}. يختار المدير سعر البيع للزبون مباشرة، بدون حساب النسبة.',
                    ),
                    error: false,
                  );
                }
                final commission = commissionForMerchantPrice(
                  merchantPrice,
                  store.commissionPercent,
                );
                final customerPrice = customerPriceFor(
                  merchantPrice,
                  store.commissionPercent,
                );
                return FormMessage(
                  store.tr(
                    'Vous recevez ${_price(merchantPrice)} + commission Wasla ${_price(commission)} (${store.commissionPercent} %) = prix client ${_price(customerPrice)}.',
                    'تحصل على ${_price(merchantPrice)} + عمولة وصلة ${_price(commission)} (${store.commissionPercent}٪) = سعر الزبون ${_price(customerPrice)}.',
                  ),
                  error: false,
                );
              },
            ),
            if (formError != null) ...[
              const SizedBox(height: 14),
              FormMessage(formError!),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('product-submit'),
                onPressed: publishing || categories.isEmpty ? null : submit,
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
                      final pick = await pickProductMedia(
                        widget.store,
                        imagesOnly: true,
                      );
                      if (pick == null || !context.mounted) return;
                      if (pick.error != null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(pick.error!)));
                      } else {
                        setState(() => avatar = pick.media);
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

/// Supplies notification widgets with the app-level order navigation action.
///
/// Keeping this in the widget tree means notification buttons in every role
/// (including the profile screen) open the same order-details page.
class NotificationNavigationScope extends InheritedWidget {
  const NotificationNavigationScope({
    super.key,
    required this.openOrder,
    required super.child,
  });

  final ValueChanged<AppNotification> openOrder;

  static ValueChanged<AppNotification>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NotificationNavigationScope>()
      ?.openOrder;

  @override
  bool updateShouldNotify(NotificationNavigationScope oldWidget) =>
      openOrder != oldWidget.openOrder;
}

void showNotifications(
  BuildContext context,
  MarketplaceStore store, {
  ValueChanged<AppNotification>? onOpenOrder,
}) {
  final openOrder = onOpenOrder ?? NotificationNavigationScope.maybeOf(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _surface,
    builder: (_) => FractionallySizedBox(
      heightFactor: .86,
      child: _NotificationsView(store: store, onOpenOrder: openOrder),
    ),
  );
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView({required this.store, this.onOpenOrder});
  final MarketplaceStore store;
  final ValueChanged<AppNotification>? onOpenOrder;

  void _open(BuildContext context, AppNotification item) {
    // Mark locally and navigate immediately; the server acknowledgement must
    // never make a notification tap feel unresponsive.
    unawaited(store.markNotificationRead(item));
    if (item.orderId == null || onOpenOrder == null) return;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => onOpenOrder!(item));
  }

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
                    onTap: () => _open(context, item),
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      backgroundColor: item.read
                          ? const Color(0xFFE7ECE8)
                          : _accent.withValues(alpha: .14),
                      foregroundColor: item.read ? _green : _accent,
                      child: Icon(icon),
                    ),
                    title: Text(
                      store.language == 'ar'
                          ? translateNotice(item.title)
                          : item.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        store.language == 'ar'
                            ? translateNotice(item.message)
                            : item.message,
                      ),
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
      tooltip: store.tr('Notifications', 'الإشعارات'),
      onPressed: () => showNotifications(context, store),
      icon: const Icon(Icons.notifications_none_rounded),
    ),
  );
}

class CategoryManagementPanel extends StatelessWidget {
  const CategoryManagementPanel({super.key, required this.store});
  final MarketplaceStore store;

  @override
  Widget build(BuildContext context) {
    Widget group(ProductKind kind, String title) {
      final items = store.categories.where((c) => c.kind == kind).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              '$title · ${items.length}',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                store.tr('Aucune catégorie.', 'لا توجد تصنيفات.'),
                style: const TextStyle(color: _muted),
              ),
            ),
          ...items.map(
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

    return Column(
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
              key: const Key('category-add'),
              onPressed: () => _showAddCategory(context, store),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        group(ProductKind.meal, store.tr('Repas', 'وجبات')),
        group(ProductKind.grocery, store.tr('Supérette', 'بقالة')),
      ],
    );
  }
}

void _showAddCategory(BuildContext context, MarketplaceStore store) {
  final messenger = ScaffoldMessenger.of(context);
  showDialog<String>(
    context: context,
    builder: (_) => _CategoryDialog(store: store),
  ).then((created) {
    if (created == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          store.tr(
            'Catégorie « $created » créée. Elle est déjà disponible pour les partenaires.',
            'تم إنشاء التصنيف «$created». أصبح متاحاً للشركاء.',
          ),
        ),
      ),
    );
  });
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.store});
  final MarketplaceStore store;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final controller = TextEditingController();
  var kind = ProductKind.meal;
  bool saving = false;
  String? error;

  MarketplaceStore get store => widget.store;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = controller.text.trim();
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await store.addCategory(name, kind);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, name);
    } else {
      setState(() {
        saving = false;
        error =
            store.lastError ??
            store.tr('Création impossible.', 'تعذر الإنشاء.');
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle catégorie'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('category-name'),
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => error = null),
            decoration: InputDecoration(labelText: store.tr('Nom', 'الاسم')),
          ),
          const SizedBox(height: 12),
          Text(
            store.tr('Type de catégorie', 'نوع التصنيف'),
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ProductKind>(
              segments: [
                ButtonSegment(
                  value: ProductKind.meal,
                  icon: const Icon(Icons.restaurant_rounded, size: 18),
                  label: Text(store.tr('Repas', 'وجبات')),
                ),
                ButtonSegment(
                  value: ProductKind.grocery,
                  icon: const Icon(Icons.shopping_basket_rounded, size: 18),
                  label: Text(store.tr('Supérette', 'بقالة')),
                ),
              ],
              selected: {kind},
              onSelectionChanged: saving
                  ? null
                  : (value) => setState(() => kind = value.first),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            FormMessage(error!),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const Key('category-create'),
        onPressed: saving ? null : _create,
        child: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Créer'),
      ),
    ],
  );
}
