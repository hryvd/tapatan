import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/local/daos/product_dao.dart';
import '../domain/entities/category.dart';
import '../domain/entities/product.dart';
import 'auth_provider.dart';
import 'sync_provider.dart';

const Uuid _uuid = Uuid();

// ─── Inventory State ──────────────────────────────────────────────────────────

class InventoryState {
  const InventoryState({
    this.products = const <Product>[],
    this.categories = const <Category>[],
    this.isLoading = false,
    this.searchQuery = '',
    this.selectedCategory,
  });

  final List<Product> products;
  final List<Category> categories;
  final bool isLoading;
  final String searchQuery;
  final String? selectedCategory;

  List<Product> get filtered {
    Iterable<Product> list = products;
    if (selectedCategory != null) {
      list = list.where((Product p) => p.categoryId == selectedCategory);
    }
    if (searchQuery.isNotEmpty) {
      final String q = searchQuery.toLowerCase();
      list = list.where((Product p) => p.name.toLowerCase().contains(q));
    }
    return list.toList();
  }

  int get lowStockCount => products.where((Product p) => p.isLowStock).length;
  double get totalValue => products.fold<double>(
      0, (double s, Product p) => s + p.unitPrice * p.stockQty);

  InventoryState copyWith({
    List<Product>? products,
    List<Category>? categories,
    bool? isLoading,
    String? searchQuery,
    String? selectedCategory,
    bool clearCategory = false,
  }) =>
      InventoryState(
        products: products ?? this.products,
        categories: categories ?? this.categories,
        isLoading: isLoading ?? this.isLoading,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedCategory:
            clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      );
}

// ─── AI Demand Insights ───────────────────────────────────────────────────────

class DemandInsight {
  const DemandInsight({
    required this.productName,
    required this.demandLevel,
    required this.priceTrend,
    required this.suggestion,
    required this.confidence,
  });

  final String productName;
  final String demandLevel; // 'High', 'Medium', 'Low'
  final String priceTrend;  // 'Rising', 'Stable', 'Falling'
  final String suggestion;
  final double confidence;  // 0.0 – 1.0
}

List<DemandInsight> computeDemandInsights(List<Product> products) {
  if (products.isEmpty) return const [];
  final List<DemandInsight> insights = [];
  for (final Product p in products) {
    final double turnover = p.threshold > 0
        ? (p.threshold - p.stockQty) / p.threshold
        : 0;
    final String demand = turnover >= 0.7
        ? 'High'
        : turnover >= 0.3
            ? 'Medium'
            : 'Low';
    final double markup =
        p.costPrice > 0 ? (p.unitPrice - p.costPrice) / p.costPrice : 0;
    final String trend = markup < 0.10
        ? 'Rising'
        : markup < 0.25
            ? 'Stable'
            : 'Falling';
    final String suggestion = demand == 'High' && trend == 'Rising'
        ? 'Restock soon — high turnover & rising cost'
        : demand == 'High'
            ? 'Consider increasing price slightly'
            : trend == 'Rising'
                ? 'Cost pressure — monitor margins'
                : 'Stock level is healthy';
    insights.add(DemandInsight(
      productName: p.name,
      demandLevel: demand,
      priceTrend: trend,
      suggestion: suggestion,
      confidence: (0.55 + turnover * 0.35).clamp(0.0, 1.0),
    ));
  }
  insights.sort((a, b) {
    const Map<String, int> rank = {'High': 0, 'Medium': 1, 'Low': 2};
    return (rank[a.demandLevel] ?? 2).compareTo(rank[b.demandLevel] ?? 2);
  });
  return insights.take(10).toList();
}

// ─── Philippine Grocery Seed Data ─────────────────────────────────────────────

class _SeedItem {
  const _SeedItem({
    required this.name,
    required this.category,
    required this.barcode,
    required this.cost,
    required this.price,
    required this.stock,
    required this.threshold,
  });
  final String name;
  final String category;
  final String barcode;
  final double cost;
  final double price;
  final int stock;
  final int threshold;
}

const List<_SeedItem> _phGroceries = <_SeedItem>[
  // Instant Noodles
  _SeedItem(name: 'Lucky Me! Pancit Canton Original', category: 'Instant Noodles', barcode: '4800016060027', cost: 8, price: 12, stock: 50, threshold: 10),
  _SeedItem(name: 'Lucky Me! Pancit Canton Chilimansi', category: 'Instant Noodles', barcode: '4800016060034', cost: 8, price: 12, stock: 50, threshold: 10),
  _SeedItem(name: 'Lucky Me! Chicken Mami', category: 'Instant Noodles', barcode: '4800016010030', cost: 9, price: 14, stock: 30, threshold: 8),
  _SeedItem(name: 'Quickchow Pancit Bihon', category: 'Instant Noodles', barcode: '4800393000116', cost: 7, price: 11, stock: 40, threshold: 10),
  _SeedItem(name: 'Nissin Cup Noodles Chicken', category: 'Instant Noodles', barcode: '4800394837035', cost: 20, price: 30, stock: 20, threshold: 5),
  // Beverages
  _SeedItem(name: 'Nescafé 3-in-1 Original (Sachet)', category: 'Beverages', barcode: '4800361012014', cost: 5, price: 8, stock: 100, threshold: 20),
  _SeedItem(name: 'Milo Chocolate Powder (Sachet)', category: 'Beverages', barcode: '4800361087905', cost: 8, price: 13, stock: 80, threshold: 15),
  _SeedItem(name: 'Bear Brand Powdered Milk (Sachet)', category: 'Beverages', barcode: '4800361010171', cost: 10, price: 16, stock: 60, threshold: 15),
  _SeedItem(name: 'C2 Green Tea 230mL', category: 'Beverages', barcode: '4806501404506', cost: 18, price: 25, stock: 24, threshold: 6),
  _SeedItem(name: 'Cobra Energy Drink 240mL', category: 'Beverages', barcode: '4806508014022', cost: 20, price: 30, stock: 24, threshold: 6),
  _SeedItem(name: 'Gatorade Lemon 500mL', category: 'Beverages', barcode: '4800016030001', cost: 35, price: 50, stock: 12, threshold: 3),
  _SeedItem(name: 'Pepsi 1.5L', category: 'Beverages', barcode: '4800052073019', cost: 50, price: 70, stock: 10, threshold: 3),
  _SeedItem(name: 'Sprite 1.5L', category: 'Beverages', barcode: '4806380010025', cost: 50, price: 70, stock: 10, threshold: 3),
  // Condiments
  _SeedItem(name: 'Datu Puti Soy Sauce (Sachet)', category: 'Condiments', barcode: '4800016030025', cost: 2, price: 4, stock: 150, threshold: 30),
  _SeedItem(name: 'Datu Puti Vinegar (Sachet)', category: 'Condiments', barcode: '4800016030032', cost: 2, price: 4, stock: 150, threshold: 30),
  _SeedItem(name: 'UFC Banana Ketchup (Sachet)', category: 'Condiments', barcode: '4800016030056', cost: 3, price: 5, stock: 120, threshold: 25),
  _SeedItem(name: 'Knorr Sinigang Mix 22g', category: 'Condiments', barcode: '4800235101043', cost: 10, price: 16, stock: 60, threshold: 12),
  _SeedItem(name: 'Maggi Magic Sarap 8g', category: 'Condiments', barcode: '4800361021023', cost: 5, price: 8, stock: 80, threshold: 15),
  _SeedItem(name: 'Del Monte Tomato Sauce (Sachet)', category: 'Condiments', barcode: '4800014310017', cost: 5, price: 8, stock: 100, threshold: 20),
  _SeedItem(name: 'Lady\'s Choice Mayonnaise (Sachet)', category: 'Condiments', barcode: '4800016052022', cost: 6, price: 10, stock: 80, threshold: 15),
  // Canned Goods
  _SeedItem(name: '555 Sardines Tomato Sauce 155g', category: 'Canned Goods', barcode: '4806011012014', cost: 22, price: 35, stock: 30, threshold: 8),
  _SeedItem(name: 'Ligo Sardines in Chili 155g', category: 'Canned Goods', barcode: '4806011014018', cost: 22, price: 35, stock: 30, threshold: 8),
  _SeedItem(name: 'Argentina Corned Beef 175g', category: 'Canned Goods', barcode: '4806011070015', cost: 45, price: 65, stock: 20, threshold: 5),
  _SeedItem(name: 'Century Tuna Flakes in Oil 180g', category: 'Canned Goods', barcode: '4806501101125', cost: 38, price: 55, stock: 20, threshold: 5),
  // Snacks
  _SeedItem(name: 'Sky Flakes Crackers 33g', category: 'Snacks', barcode: '4800016047011', cost: 8, price: 13, stock: 50, threshold: 10),
  _SeedItem(name: 'Piattos Cheese 85g', category: 'Snacks', barcode: '4800016095014', cost: 25, price: 38, stock: 30, threshold: 8),
  _SeedItem(name: 'Nova Country Cheddar 78g', category: 'Snacks', barcode: '4800016098015', cost: 22, price: 35, stock: 30, threshold: 8),
  _SeedItem(name: 'Regent Cheese Rings 60g', category: 'Snacks', barcode: '4800393000215', cost: 14, price: 22, stock: 40, threshold: 10),
  _SeedItem(name: 'Rebisco Peanut Butter Crackers', category: 'Snacks', barcode: '4800393000131', cost: 10, price: 16, stock: 50, threshold: 10),
  // Dairy
  _SeedItem(name: 'Alaska Evaporated Milk 370mL', category: 'Dairy', barcode: '4800016078017', cost: 38, price: 55, stock: 24, threshold: 6),
  _SeedItem(name: 'Eden Cheese 165g', category: 'Dairy', barcode: '4800016083011', cost: 62, price: 90, stock: 15, threshold: 4),
  // Personal Care
  _SeedItem(name: 'Safeguard Soap Classic White 60g', category: 'Personal Care', barcode: '4800016040111', cost: 22, price: 35, stock: 30, threshold: 6),
  _SeedItem(name: 'Palmolive Naturals Shampoo (Sachet)', category: 'Personal Care', barcode: '4800016031016', cost: 5, price: 9, stock: 100, threshold: 20),
  _SeedItem(name: 'Head & Shoulders Cool Menthol (Sachet)', category: 'Personal Care', barcode: '4800016035014', cost: 6, price: 10, stock: 80, threshold: 15),
  _SeedItem(name: 'Colgate Strong Teeth Toothpaste (Sachet)', category: 'Personal Care', barcode: '4800016050011', cost: 5, price: 9, stock: 100, threshold: 20),
  _SeedItem(name: 'Champion Detergent Bar 130g', category: 'Personal Care', barcode: '4800016060073', cost: 15, price: 22, stock: 40, threshold: 8),
  _SeedItem(name: 'Ariel Powder Detergent (Sachet)', category: 'Personal Care', barcode: '4800016060080', cost: 10, price: 16, stock: 80, threshold: 15),
];

// ─── Notifier ─────────────────────────────────────────────────────────────────

class InventoryNotifier extends AsyncNotifier<InventoryState> {
  final ProductDao _dao = ProductDao();

  bool get _isOffline => ref.read(authProvider).value?.isOfflineMode ?? false;

  @override
  Future<InventoryState> build() async => _load();

  Future<InventoryState> _load() async {
    final List<Product> products = await _dao.getAllProducts();
    final List<Category> cats = await _dao.getAllCategories();
    return InventoryState(products: products, categories: cats);
  }

  Future<void> refresh() async {
    state = AsyncData<InventoryState>(state.value!.copyWith(isLoading: true));
    final InventoryState s = await _load();
    state = AsyncData<InventoryState>(s);
  }

  void setSearch(String q) {
    state = AsyncData<InventoryState>(state.value!.copyWith(searchQuery: q));
  }

  void setCategory(String? categoryId) {
    state = AsyncData<InventoryState>(state.value!.copyWith(
      selectedCategory: categoryId,
      clearCategory: categoryId == null,
    ));
  }

  Future<void> addProduct({
    required String name,
    String? barcode,
    required double unitPrice,
    required double costPrice,
    required int stockQty,
    required int threshold,
    String? categoryId,
  }) async {
    final Product product = Product(
      productId: _uuid.v4(),
      categoryId: categoryId,
      barcode: barcode,
      name: name,
      unitPrice: unitPrice,
      costPrice: costPrice,
      stockQty: stockQty,
      threshold: threshold,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _dao.insert(product);
    try { await _generateSuggestionFor(product); } catch (_) {}
    try {
      if (!_isOffline) {
        await SyncNotifier.enqueue(entityType: 'products', entityId: product.productId, operation: 'create', payload: product.toMap());
        ref.read(syncProvider.notifier).sync();
      }
    } catch (_) {}
    await refresh();
  }

  Future<void> updateProduct(Product product) async {
    await _dao.update(product);
    try { await _generateSuggestionFor(product); } catch (_) {}
    try {
      if (!_isOffline) {
        await SyncNotifier.enqueue(entityType: 'products', entityId: product.productId, operation: 'update', payload: product.toMap());
        ref.read(syncProvider.notifier).sync();
      }
    } catch (_) {}
    await refresh();
  }

  Future<void> deleteProduct(String productId) async {
    await _dao.deactivate(productId);
    if (!_isOffline) {
      await SyncNotifier.enqueue(entityType: 'products', entityId: productId, operation: 'delete', payload: <String, dynamic>{'product_id': productId});
      ref.read(syncProvider.notifier).sync();
    }
    await refresh();
  }

  Future<void> _generateSuggestionFor(Product product) async {
    if (product.costPrice <= 0) return;
    final double suggested =
        double.parse((product.costPrice * 1.25).toStringAsFixed(2));
    final double diff = (suggested - product.unitPrice).abs();
    if (product.unitPrice > 0 && diff / product.unitPrice < 0.05) return;
    await _dao.insertPriceSuggestion(<String, dynamic>{
      'suggestion_id': _uuid.v4(),
      'product_id': product.productId,
      'suggested_price': suggested,
      'benchmark_source': 'cost_markup',
      'fetched_at': DateTime.now().toIso8601String(),
      'accepted': 0,
    });
  }

  Future<void> recalculateAllSuggestions() async {
    final List<Product> products = await _dao.getAllProducts();
    for (final Product p in products) { await _generateSuggestionFor(p); }
    await refresh();
  }

  Future<void> updateStock(String productId, int newQty) async {
    await _dao.updateStock(productId, newQty);
    if (!_isOffline) {
      try {
        final List<Product> products = await _dao.getAllProducts();
        final Product? p = products.where((Product x) => x.productId == productId).firstOrNull;
        if (p != null) {
          await SyncNotifier.enqueue(entityType: 'products', entityId: productId, operation: 'update', payload: p.copyWith(stockQty: newQty).toMap());
          ref.read(syncProvider.notifier).sync();
        }
      } catch (_) {}
    }
    await refresh();
  }

  Future<void> acceptSuggestedPrice(String productId, double price) async {
    await _dao.acceptPriceSuggestion(productId, price);
    await refresh();
  }

  /// Seeds 35+ Philippine sari-sari groceries. Skips duplicates by name.
  Future<int> seedPhilippineGroceries() async {
    final InventoryState current = state.value!;
    final Set<String> existing =
        current.products.map((p) => p.name.toLowerCase()).toSet();
    int added = 0;
    final Map<String, String> catMap = {};
    for (final Category cat in current.categories) {
      catMap[cat.name] = cat.categoryId;
    }
    final Set<String> neededCats = _phGroceries.map((i) => i.category).toSet();
    for (final String catName in neededCats) {
      if (!catMap.containsKey(catName)) {
        final String id = await addCategory(catName);
        catMap[catName] = id;
      }
    }
    for (final _SeedItem item in _phGroceries) {
      if (existing.contains(item.name.toLowerCase())) continue;
      final Product product = Product(
        productId: _uuid.v4(),
        categoryId: catMap[item.category],
        barcode: item.barcode,
        name: item.name,
        unitPrice: item.price,
        costPrice: item.cost,
        stockQty: item.stock,
        threshold: item.threshold,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _dao.insert(product);
      try { await _generateSuggestionFor(product); } catch (_) {}
      added++;
    }
    await refresh();
    return added;
  }

  Future<String> addCategory(String name, {String? description}) async {
    final Category cat = Category(
      categoryId: _uuid.v4(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );
    await _dao.insertCategory(cat);
    if (!_isOffline) {
      await SyncNotifier.enqueue(entityType: 'categories', entityId: cat.categoryId, operation: 'create', payload: cat.toMap());
      ref.read(syncProvider.notifier).sync();
    }
    await refresh();
    return cat.categoryId;
  }

  Future<void> deleteCategory(String categoryId) async {
    await _dao.deleteCategory(categoryId);
    if (!_isOffline) {
      await SyncNotifier.enqueue(entityType: 'categories', entityId: categoryId, operation: 'delete', payload: <String, dynamic>{'category_id': categoryId});
      ref.read(syncProvider.notifier).sync();
    }
    await refresh();
  }
}

final AsyncNotifierProvider<InventoryNotifier, InventoryState>
    inventoryProvider =
    AsyncNotifierProvider<InventoryNotifier, InventoryState>(
        InventoryNotifier.new);

Future<bool> isOfflineModeActive() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isOfflineMode') ?? false;
}
