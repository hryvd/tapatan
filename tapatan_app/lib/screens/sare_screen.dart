import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

// ── Models & Catalog (1:1 with SarEScreen.tsx) ──────────────────────────────

class SarEProduct {
  final String id;
  final String name;
  final String emoji;
  final double price;
  final int stock;
  final String category;

  const SarEProduct({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    required this.stock,
    required this.category,
  });
}

const kSarEProducts = [
  SarEProduct(
    id: 'p1',
    name: 'Nescafé 3-in-1',
    emoji: '☕',
    price: 9.0,
    stock: 40,
    category: 'Snacks & Drinks',
  ),
  SarEProduct(
    id: 'p2',
    name: 'Piattos Cheese',
    emoji: '🥔',
    price: 25.0,
    stock: 18,
    category: 'Snacks & Drinks',
  ),
  SarEProduct(
    id: 'p3',
    name: 'Coke Mismo',
    emoji: '🥤',
    price: 22.0,
    stock: 6,
    category: 'Snacks & Drinks',
  ),
  SarEProduct(
    id: 'p4',
    name: 'Skyflakes',
    emoji: '🍘',
    price: 8.0,
    stock: 30,
    category: 'Snacks & Drinks',
  ),
  SarEProduct(
    id: 'p5',
    name: 'Jasmine Rice 1kg',
    emoji: '🍚',
    price: 58.0,
    stock: 12,
    category: 'Pantry',
  ),
  SarEProduct(
    id: 'p6',
    name: 'Itlog (6 pcs)',
    emoji: '🥚',
    price: 54.0,
    stock: 4,
    category: 'Pantry',
  ),
  SarEProduct(
    id: 'p7',
    name: 'Lucky Me Pancit',
    emoji: '🍜',
    price: 16.0,
    stock: 50,
    category: 'Pantry',
  ),
  SarEProduct(
    id: 'p8',
    name: 'Datu Puti Suka',
    emoji: '🍶',
    price: 19.0,
    stock: 14,
    category: 'Pantry',
  ),
  SarEProduct(
    id: 'p9',
    name: 'Globe Load ₱50',
    emoji: '📱',
    price: 50.0,
    stock: 99,
    category: 'Load & Bills',
  ),
  SarEProduct(
    id: 'p10',
    name: 'Meralco Bill Pay',
    emoji: '💡',
    price: 100.0,
    stock: 99,
    category: 'Load & Bills',
  ),
];

const kSarEStores = [
  "Aling Nena's Sari-Sari",
  'Campus Coop',
  'Tapat Express',
];

const kSarECategories = [
  'All',
  'Snacks & Drinks',
  'Pantry',
  'Load & Bills',
];

// ── Screen ──────────────────────────────────────────────────────────────────

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
  final Map<String, int> _cart = {};
  int _selectedStore = 0;
  String _selectedCategory = 'All';
  bool _menuOpen = false;

  int get _cartItemCount => _cart.values.fold(0, (a, b) => a + b);

  double get _cartTotal {
    double total = 0;
    _cart.forEach((id, qty) {
      final p = kSarEProducts.firstWhere((item) => item.id == id);
      total += p.price * qty;
    });
    return total;
  }

  void _modifyQty(String id, int delta) {
    final current = _cart[id] ?? 0;
    final next = current + delta;
    setState(() {
      if (next <= 0) {
        _cart.remove(id);
      } else {
        _cart[id] = next;
      }
    });
  }

  void _checkout() {
    if (_cartItemCount == 0) return;

    final items = _cart.entries.map((e) {
      final p = kSarEProducts.firstWhere((item) => item.id == e.key);
      return SarECartItem(name: p.name, price: p.price, qty: e.value);
    }).toList();

    final order = SarEPendingOrder(
      orderId: 'SARE-${DateTime.now().millisecondsSinceEpoch}',
      merchant: kSarEStores[_selectedStore],
      items: items,
      totalAmount: _cartTotal,
    );

    ref.read(userProvider.notifier).setSarEOrder(order);

    setState(() {
      _cart.clear();
      _menuOpen = false;
    });

    if (widget.onCheckoutWithCard != null) {
      widget.onCheckoutWithCard!();
    } else {
      widget.onNavigateHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final filtered = kSarEProducts
        .where(
          (p) => _selectedCategory == 'All' || p.category == _selectedCategory,
        )
        .toList();

    return SafeArea(
      bottom: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_menuOpen) setState(() => _menuOpen = false);
        },
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header & Balance ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(T.screenPad, 8, T.screenPad, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Store selector dropdown button
                                  PressScale(
                                    onTap: () => setState(() => _menuOpen = !_menuOpen),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            kSarEStores[_selectedStore],
                                            style: T.text(20, w: T.w800, color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          _menuOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                                          size: 16,
                                          color: T.white(0.6),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Neighborhood store · NFC checkout',
                                    style: T.text(12, color: T.white(0.45)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Balance pill
                            Glass(
                              kind: GlassKind.pill,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Available', style: T.caption.copyWith(fontSize: 9)),
                                  Text(
                                    '₱${user.balance.toStringAsFixed(2)}',
                                    style: T.mono(12, w: T.w700, color: T.cyan300),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Shopping basket badge button
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Glass(
                                  kind: GlassKind.pill,
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Icon(
                                      LucideIcons.shoppingBasket,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (_cartItemCount > 0)
                                  Positioned(
                                    top: -3,
                                    right: -3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: T.cyan400,
                                        borderRadius: BorderRadius.circular(999),
                                        boxShadow: T.glow(T.cyan400, 8),
                                      ),
                                      child: Text(
                                        '$_cartItemCount',
                                        style: T.mono(11, w: T.w800, color: T.bg),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // Store dropdown popup
                        if (_menuOpen) ...[
                          const SizedBox(height: 8),
                          Glass(
                            kind: GlassKind.strong,
                            radius: T.rStrong,
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < kSarEStores.length; i++)
                                  PressScale(
                                    onTap: () {
                                      setState(() {
                                        _selectedStore = i;
                                        _menuOpen = false;
                                      });
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _selectedStore == i ? T.white(0.10) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              kSarEStores[i],
                                              style: T.text(
                                                13,
                                                w: _selectedStore == i ? T.w700 : T.w500,
                                                color: _selectedStore == i ? T.cyan300 : Colors.white,
                                              ),
                                            ),
                                          ),
                                          if (_selectedStore == i)
                                            Icon(LucideIcons.check, size: 16, color: T.cyan300),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Category filter pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: kSarECategories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: PressScale(
                                  onTap: () => setState(() => _selectedCategory = cat),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? T.op(T.cyan400, 0.20) : T.white(0.05),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isSelected ? T.op(T.cyan300, 0.60) : T.white(0.10),
                                      ),
                                    ),
                                    child: Text(
                                      cat,
                                      style: T.text(
                                        12,
                                        w: T.w600,
                                        color: isSelected ? T.cyan200 : T.white(0.60),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 2-Column Product Grid ─────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    T.screenPad,
                    4,
                    T.screenPad,
                    T.navBottomPad + 20,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 184,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = filtered[index];
                        final qty = _cart[product.id] ?? 0;
                        final lowStock = product.stock < 8;

                        return Glass(
                          kind: GlassKind.glass,
                          radius: 22,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Emoji container with stock badge
                              Container(
                                height: 80,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: T.white(0.07),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        product.emoji,
                                        style: const TextStyle(fontSize: 34),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: lowStock ? T.op(T.amber500, 0.20) : T.op(T.emerald, 0.15),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          lowStock ? '${product.stock} left' : 'In stock',
                                          style: T.text(
                                            9,
                                            w: T.w700,
                                            color: lowStock ? T.amber300 : T.emerald300,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Name
                              Text(
                                product.name,
                                style: T.text(13, w: T.w600, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const Spacer(),

                              // Price & Add/Stepper row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₱${product.price.toStringAsFixed(0)}',
                                    style: T.mono(14, w: T.w800, color: T.cyan200),
                                  ),
                                  if (qty == 0)
                                    PressScale(
                                      onTap: () => _modifyQty(product.id, 1),
                                      child: Container(
                                        height: 30,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(999),
                                          gradient: T.btnLiquidGradient,
                                          boxShadow: T.btnShadow,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(LucideIcons.plus, size: 12, color: Colors.white),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Add',
                                              style: T.text(12, w: T.w700, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Glass(
                                      kind: GlassKind.pill,
                                      height: 30,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PressScale(
                                            onTap: () => _modifyQty(product.id, -1),
                                            child: const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: Center(
                                                child: Icon(LucideIcons.minus, size: 13, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 18,
                                            child: Text(
                                              '$qty',
                                              textAlign: TextAlign.center,
                                              style: T.mono(12, w: T.w700, color: Colors.white),
                                            ),
                                          ),
                                          PressScale(
                                            onTap: () {
                                              if (qty < product.stock) {
                                                _modifyQty(product.id, 1);
                                              }
                                            },
                                            child: const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: Center(
                                                child: Icon(LucideIcons.plus, size: 13, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
              ],
            ),

            // ── Floating Cart Bar (1:1 with React SarEScreen) ───────────────
            if (_cartItemCount > 0)
              Positioned(
                bottom: 84, // elevated above bottom nav
                left: T.screenPad,
                right: T.screenPad,
                child: Glass(
                  kind: GlassKind.strong,
                  radius: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_cartItemCount item${_cartItemCount > 1 ? "s" : ""}',
                              style: T.caption.copyWith(color: T.white(0.55)),
                            ),
                            Text(
                              '₱${_cartTotal.toStringAsFixed(2)}',
                              style: T.mono(17, w: T.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Btn(
                        onTap: _checkout,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Checkout with NFC', style: T.btn.copyWith(fontSize: 13)),
                            const SizedBox(width: 4),
                            const Icon(LucideIcons.arrowRight, size: 15),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
