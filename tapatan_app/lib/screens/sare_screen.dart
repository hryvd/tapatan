import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/lucide_icons.dart';
import '../providers/user_provider.dart';

// ── Product Model ─────────────────────────────────────────────────────────

class SarEProduct {
  final String name;
  final double price;
  final String category;

  const SarEProduct(this.name, this.price, this.category);
}

const _products = [
  SarEProduct('Kopiko Coffee 3-in-1 (10 sachets)', 55.0, 'kopiko'),
  SarEProduct('Lucky Me Pancit Canton', 15.0, 'noodles'),
  SarEProduct('San Miguel Pale Pilsen (6-pack)', 155.0, 'beer'),
  SarEProduct('Great Taste White Coffee', 18.0, 'coffee'),
  SarEProduct('Bear Brand Sterilized Milk', 95.0, 'milk'),
  SarEProduct('Boy Bawang (Big, 3 flavors)', 45.0, 'snack'),
  SarEProduct('Piattos Cheese 85g', 38.0, 'chips'),
  SarEProduct('Skyflakes Crackers (10pcs)', 22.0, 'crackers'),
];

// ── Sar-E Screen ──────────────────────────────────────────────────────────

class SarEScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateHome;
  final VoidCallback? onCheckoutWithCard;

  const SarEScreen({
    super.key,
    required this.onNavigateHome,
    this.onCheckoutWithCard,
  });

  @override
  ConsumerState<SarEScreen> createState() => _SarEScreenState();
}

class _SarEScreenState extends ConsumerState<SarEScreen> {
  // qty per product index
  final Map<int, int> _cart = {};

  static const _teal = Color(0xFF06B6D4);
  static const _amber = Color(0xFFF59E0B);

  int get _cartItemCount => _cart.values.fold(0, (a, b) => a + b);
  double get _cartTotal {
    double total = 0;
    _cart.forEach((i, qty) => total += _products[i].price * qty);
    return total;
  }

  void _increment(int i) => setState(() => _cart[i] = (_cart[i] ?? 0) + 1);
  void _decrement(int i) {
    if ((_cart[i] ?? 0) <= 0) return;
    setState(() {
      _cart[i] = _cart[i]! - 1;
      if (_cart[i] == 0) _cart.remove(i);
    });
  }

  void _checkout() {
    if (_cartItemCount == 0) return;

    final items = _cart.entries.map((e) {
      final p = _products[e.key];
      return SarECartItem(name: p.name, price: p.price, qty: e.value);
    }).toList();

    final order = SarEPendingOrder(
      orderId: 'SARE-${DateTime.now().millisecondsSinceEpoch}',
      merchant: 'Sarisari ni Aling Nena',
      items: items,
      totalAmount: _cartTotal,
    );

    ref.read(userProvider.notifier).setSarEOrder(order);

    // Clear cart
    setState(() => _cart.clear());

    // Immediately trigger automatic NFC card checkout & payment approval
    if (widget.onCheckoutWithCard != null) {
      widget.onCheckoutWithCard!();
    } else {
      widget.onNavigateHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Product list
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0369A1), Color(0xFF0891B2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(LucideIcons.store, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sar-E Store', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                  Text('Sarisari ni Aling Nena', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _teal.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _teal.withOpacity(0.35)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Available Money',
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9),
                                  ),
                                  Text(
                                    '₱${user.balance.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _amber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _amber.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.creditCard, size: 14, color: _amber),
                              const SizedBox(width: 8),
                              const Text(
                                'Pay securely with your Tapat Card',
                                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Product list ────────────────────────────────────────
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _ProductTile(
                        product: _products[i],
                        qty: _cart[i] ?? 0,
                        onIncrement: () => _increment(i),
                        onDecrement: () => _decrement(i),
                      ),
                      childCount: _products.length,
                    ),
                  ),
                ),
              ],
            ),

            // ── Floating cart bar ────────────────────────────────────
            if (_cartItemCount > 0)
              Positioned(
                bottom: bottomPad + 96,
                left: 16,
                right: 16,
                child: _CartBar(
                  itemCount: _cartItemCount,
                  total: _cartTotal,
                  onCheckout: _checkout,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Product Tile ──────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final SarEProduct product;
  final int qty;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ProductTile({
    required this.product,
    required this.qty,
    required this.onIncrement,
    required this.onDecrement,
  });

  static const _teal = Color(0xFF06B6D4);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0369A1).withOpacity(qty > 0 ? 0.25 : 0.10),
            const Color(0xFF0891B2).withOpacity(qty > 0 ? 0.15 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qty > 0
              ? _teal.withOpacity(0.4)
              : const Color(0xFF0891B2).withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          // Emoji icon area (simple colored circle)
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0369A1).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.shoppingBag, color: Color(0xFF38BDF8), size: 22),
          ),
          const SizedBox(width: 12),

          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Qty stepper
          Row(
            children: [
              _StepperButton(
                icon: LucideIcons.x,
                onTap: onDecrement,
                enabled: qty > 0,
                isRemove: true,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: qty > 0 ? Colors.white : Colors.white38,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _StepperButton(icon: LucideIcons.plus, onTap: onIncrement, enabled: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool isRemove;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.isRemove = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? (isRemove
                  ? const Color(0xFFEF4444).withOpacity(0.12)
                  : const Color(0xFF0891B2).withOpacity(0.18))
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? (isRemove
                    ? const Color(0xFFEF4444).withOpacity(0.35)
                    : const Color(0xFF0891B2).withOpacity(0.4))
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled
              ? (isRemove ? const Color(0xFFF87171) : const Color(0xFF38BDF8))
              : Colors.white24,
        ),
      ),
    );
  }
}

// ── Cart Bar ──────────────────────────────────────────────────────────────

class _CartBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final VoidCallback onCheckout;

  const _CartBar({
    required this.itemCount,
    required this.total,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0369A1), Color(0xFF0891B2), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0369A1).withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(LucideIcons.shoppingCart, color: Colors.white, size: 18),
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$itemCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                ),
                Text(
                  '₱${total.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCheckout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.creditCard, color: Color(0xFF0369A1), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Checkout',
                    style: TextStyle(color: Color(0xFF0369A1), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
