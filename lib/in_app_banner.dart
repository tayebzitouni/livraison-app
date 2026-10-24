import 'dart:async';

import 'package:flutter/material.dart';

/// Lets the banner reach the root overlay, so it stays visible above sheets
/// and dialogs that are open at the time.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

OverlayEntry? _current;
Timer? _timer;

void dismissInAppBanner() {
  _timer?.cancel();
  _current?.remove();
  _current = null;
}

/// Shows a short banner at the top of the screen for a new notification.
void showInAppBanner({
  required String title,
  required String message,
  IconData icon = Icons.notifications_active_rounded,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 6),
}) {
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  dismissInAppBanner();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Banner(
      title: title,
      message: message,
      icon: icon,
      onTap: () {
        dismissInAppBanner();
        onTap?.call();
      },
      onClose: dismissInAppBanner,
    ),
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(duration, () {
    if (_current == entry) dismissInAppBanner();
  });
}

class _Banner extends StatefulWidget {
  const _Banner({
    required this.title,
    required this.message,
    required this.icon,
    required this.onTap,
    required this.onClose,
  });
  final String title, message;
  final IconData icon;
  final VoidCallback onTap, onClose;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + 8,
    left: 14,
    right: 14,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, -1.4), end: Offset.zero).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            key: const Key('in-app-banner'),
            color: const Color(0xFF181C19),
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      child: Icon(widget.icon, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD9DED9),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
