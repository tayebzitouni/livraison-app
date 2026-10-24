import 'package:flutter/material.dart';

import 'domain.dart';
import 'marketplace_store.dart';

const _ink = Color(0xFF181C19);
const _accent = Color(0xFFFF6B35);
const _green = Color(0xFF145A42);
const _muted = Color(0xFF6A746E);
const _line = Color(0xFFE3E1DB);

/// Where each of the three actors on the route stands for a given status.
enum _Stage { pending, assigned, active, done }

_Stage _originStage(OrderStatus s) {
  if (s == OrderStatus.cancelled || s == OrderStatus.placed) {
    return _Stage.pending;
  }
  return s.index >= OrderStatus.pickedUp.index ? _Stage.done : _Stage.active;
}

_Stage _courierStage(OrderStatus s) {
  if (s == OrderStatus.cancelled || s == OrderStatus.placed) {
    return _Stage.pending;
  }
  if (s.index < OrderStatus.pickedUp.index) return _Stage.assigned;
  return s == OrderStatus.pickedUp ? _Stage.active : _Stage.done;
}

_Stage _clientStage(OrderStatus s) {
  if (s == OrderStatus.clientConfirmed) return _Stage.done;
  return s == OrderStatus.delivered ? _Stage.active : _Stage.pending;
}

/// Share of the first leg (kitchen to courier) that is covered.
double _firstLeg(OrderStatus s) {
  if (s == OrderStatus.cancelled || s == OrderStatus.placed) return 0;
  return (s.index / OrderStatus.pickedUp.index).clamp(0.0, 1.0);
}

/// Share of the second leg (courier to customer) that is covered.
double _secondLeg(OrderStatus s) => switch (s) {
  OrderStatus.pickedUp => .5,
  OrderStatus.delivered || OrderStatus.clientConfirmed => 1,
  _ => 0,
};

/// Visual route: starting point (kitchen or supermarket), the courier and the
/// customer, joined by lines that fill as the order moves along.
class OrderRouteTracker extends StatelessWidget {
  const OrderRouteTracker({
    super.key,
    required this.order,
    required this.store,
    this.onDark = false,
  });

  final MarketOrder order;
  final MarketplaceStore store;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final merchants = store.products.where(
      (p) => p.ownerId == order.merchantId,
    );
    final supermarket =
        (order.items.isNotEmpty
            ? order.items.first.product.kind
            : merchants.isEmpty
            ? ProductKind.meal
            : merchants.first.kind) ==
        ProductKind.grocery;
    final courierName = order.courierName ?? store.tr('Livreur', 'الموصل');
    final clientName = store.currentUser?.id == order.clientId
        ? store.tr('Vous', 'أنت')
        : (order.clientName ?? store.tr('Client', 'الزبون'));
    final track = onDark ? Colors.white24 : _line;
    final fill = onDark ? const Color(0xFFFFC857) : _green;
    final caption = onDark ? Colors.white : _ink;
    final subtle = onDark ? const Color(0xFFC9D8D1) : _muted;

    Widget leg(double progress) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 17),
        child: Stack(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: progress,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: store.tr(
        'Suivi de la commande ${order.id} : ${status.label}',
        'تتبع الطلب ${order.id}: ${_stepTitle(store, status, order)}',
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Node(
                icon: supermarket
                    ? Icons.local_grocery_store_rounded
                    : Icons.restaurant_rounded,
                stage: _originStage(status),
                onDark: onDark,
              ),
              leg(_firstLeg(status)),
              _Node(
                icon: Icons.delivery_dining_rounded,
                stage: _courierStage(status),
                onDark: onDark,
              ),
              leg(_secondLeg(status)),
              _Node(
                icon: Icons.home_rounded,
                stage: _clientStage(status),
                onDark: onDark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Caption(
                store.orderMerchant(order),
                supermarket
                    ? store.tr('Supérette', 'البقالة')
                    : store.tr('Cuisine', 'المطبخ'),
                caption,
                subtle,
              ),
              _Caption(
                order.courierId == null
                    ? store.tr('En attente', 'بانتظار الموصل')
                    : courierName,
                store.tr('Livreur', 'الموصل'),
                caption,
                subtle,
              ),
              _Caption(
                clientName,
                store.tr('Destination', 'الوجهة'),
                caption,
                subtle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.title, this.role, this.color, this.subtle);
  final String title, role;
  final Color color, subtle;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          role,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: subtle),
        ),
      ],
    ),
  );
}

class _Node extends StatelessWidget {
  const _Node({required this.icon, required this.stage, required this.onDark});
  final IconData icon;
  final _Stage stage;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final done = stage == _Stage.done;
    final active = stage == _Stage.active;
    final assigned = stage == _Stage.assigned;
    final base = onDark ? Colors.white : _green;
    final background = done
        ? base
        : active
        ? _accent
        : onDark
        ? Colors.white12
        : Colors.white;
    final foreground = done
        ? (onDark ? _green : Colors.white)
        : active
        ? Colors.white
        : assigned
        ? base
        : (onDark ? Colors.white54 : _muted);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: done || active
              ? background
              : assigned
              ? base
              : (onDark ? Colors.white30 : _line),
          width: 2,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _accent.withValues(alpha: .35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        size: 20,
        color: foreground,
      ),
    );
  }
}

String _stepTitle(
  MarketplaceStore store,
  OrderStatus step,
  MarketOrder order,
) => switch (step) {
  OrderStatus.placed => store.tr('Commande envoyée', 'تم ارسال الطلب'),
  OrderStatus.courierValidated => store.tr(
    'Livreur confirmé',
    'تم تأكيد الطلب',
  ),
  OrderStatus.merchantAccepted => store.tr(
    'Acceptée par ${store.orderMerchant(order)}',
    'قبلها ${store.orderMerchant(order)}',
  ),
  OrderStatus.preparing => store.tr('En préparation', 'قيد التحضير'),
  OrderStatus.ready => store.tr(
    'Prête à récupérer',
    'الموصل استلم الطلب من ${store.orderMerchant(order)}',
  ),
  OrderStatus.pickedUp => store.tr(
    'En route avec le livreur',
    'في الطريق مع الموصل',
  ),
  OrderStatus.delivered => store.tr(
    'Livrée · confirmez la réception',
    'تم التسليم · أكّد الاستلام',
  ),
  OrderStatus.clientConfirmed => store.tr(
    'Réception confirmée',
    'تم تأكيد الاستلام',
  ),
  OrderStatus.cancelled => store.tr('Annulée', 'ملغى'),
};

/// Step by step history: what is done, what is happening and what comes next.
class OrderStepList extends StatelessWidget {
  const OrderStepList({super.key, required this.order, required this.store});
  final MarketOrder order;
  final MarketplaceStore store;

  static const steps = [
    OrderStatus.placed,
    OrderStatus.courierValidated,
    OrderStatus.merchantAccepted,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.pickedUp,
    OrderStatus.delivered,
    OrderStatus.clientConfirmed,
  ];

  static const arabicSteps = [
    OrderStatus.placed,
    OrderStatus.courierValidated,
    OrderStatus.ready,
    OrderStatus.pickedUp,
    OrderStatus.clientConfirmed,
  ];

  int _arabicPosition(OrderStatus status) => switch (status) {
    OrderStatus.placed => 0,
    OrderStatus.courierValidated ||
    OrderStatus.merchantAccepted ||
    OrderStatus.preparing => 1,
    OrderStatus.ready => 2,
    OrderStatus.pickedUp || OrderStatus.delivered => 3,
    OrderStatus.clientConfirmed => 4,
    OrderStatus.cancelled => 0,
  };

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) {
      return Row(
        children: [
          const Icon(Icons.cancel_outlined, color: Color(0xFFB42318)),
          const SizedBox(width: 8),
          Text(
            store.tr('Commande annulée', 'تم إلغاء الطلب'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      );
    }
    final visibleSteps = store.language == 'ar' ? arabicSteps : steps;
    final current = store.language == 'ar'
        ? _arabicPosition(order.status)
        : order.status.index;
    return Column(
      children: [
        for (var i = 0; i < visibleSteps.length; i++)
          _StepRow(
            title: _stepTitle(store, visibleSteps[i], order),
            done: i < current || order.status == OrderStatus.clientConfirmed,
            current:
                i == current && order.status != OrderStatus.clientConfirmed,
            last: i == visibleSteps.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.done,
    required this.current,
    required this.last,
  });
  final String title;
  final bool done, current, last;

  @override
  Widget build(BuildContext context) {
    final color = done ? _green : (current ? _accent : _line);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: done || current ? color : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : current
                      ? const Icon(Icons.circle, size: 7, color: Colors.white)
                      : null,
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: done ? _green : _line),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: current ? FontWeight.w900 : FontWeight.w600,
                  color: done || current ? _ink : _muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Route plus an expandable step list, used on every order card.
class OrderTracking extends StatefulWidget {
  const OrderTracking({
    super.key,
    required this.order,
    required this.store,
    this.initiallyExpanded = false,
  });
  final MarketOrder order;
  final MarketplaceStore store;
  final bool initiallyExpanded;

  @override
  State<OrderTracking> createState() => _OrderTrackingState();
}

class _OrderTrackingState extends State<OrderTracking> {
  late bool expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderRouteTracker(order: widget.order, store: store),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: Key('tracking-toggle-${widget.order.id}'),
            onPressed: () => setState(() => expanded = !expanded),
            icon: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
            ),
            label: Text(
              expanded
                  ? store.tr('Masquer le suivi', 'إخفاء التتبع')
                  : store.tr('Voir le suivi détaillé', 'عرض التتبع المفصل'),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 6),
          OrderStepList(order: widget.order, store: store),
        ],
      ],
    );
  }
}
