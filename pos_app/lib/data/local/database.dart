import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Central sqflite database initialiser.
/// All 16 tables from the ER diagram are created here.
class AppDatabase {
  AppDatabase._();

  static const String _dbName = 'sare.db';
  static const int _version = 4;

  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final String dbPath = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
        dbPath,
        version: _version,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_credentials (
        user_id         TEXT PRIMARY KEY,
        pin_hash        TEXT NOT NULL,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        role            TEXT NOT NULL DEFAULT 'owner',
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until    TEXT,
        last_login_at   TEXT,
        store_name      TEXT NOT NULL DEFAULT 'My Store'
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        category_id TEXT PRIMARY KEY,
        name        TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        product_id  TEXT PRIMARY KEY,
        category_id TEXT REFERENCES categories(category_id),
        barcode     TEXT UNIQUE,
        name        TEXT NOT NULL,
        unit_price  REAL NOT NULL,
        cost_price  REAL NOT NULL DEFAULT 0,
        stock_qty   INTEGER NOT NULL DEFAULT 0,
        threshold   INTEGER NOT NULL DEFAULT 0,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_products_name ON products(name, category_id)');

    await db.execute('''
      CREATE TABLE customers (
        customer_id    TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        mobile_number  TEXT UNIQUE,
        credit_balance REAL NOT NULL DEFAULT 0,
        is_active      INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_customers_mobile ON customers(mobile_number)');

    await db.execute('''
      CREATE TABLE credit_entries (
        entry_id        TEXT PRIMARY KEY,
        customer_id     TEXT NOT NULL REFERENCES customers(customer_id),
        items           TEXT NOT NULL,
        amount          REAL NOT NULL,
        amount_paid     REAL NOT NULL DEFAULT 0,
        due_date        TEXT NOT NULL,
        status          TEXT NOT NULL DEFAULT 'active',
        reminder_count  INTEGER NOT NULL DEFAULT 0,
        last_reminder_at TEXT,
        created_at      TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_credit_customer_status ON credit_entries(customer_id, status)');

    await db.execute('''
      CREATE TABLE repayment_records (
        repayment_id TEXT PRIMARY KEY,
        entry_id     TEXT NOT NULL REFERENCES credit_entries(entry_id),
        amount_paid  REAL NOT NULL,
        timestamp    TEXT NOT NULL,
        notes        TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        transaction_id TEXT PRIMARY KEY,
        receipt_id     TEXT,
        timestamp      TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        total_amount   REAL NOT NULL,
        change_due     REAL NOT NULL DEFAULT 0,
        status         TEXT NOT NULL DEFAULT 'pending',
        created_at     TEXT NOT NULL,
        synced_at      TEXT
      )
    ''');
    await db
        .execute('CREATE INDEX idx_txn_timestamp ON transactions(timestamp)');
    await db.execute('CREATE INDEX idx_txn_status ON transactions(status)');

    await db.execute('''
      CREATE TABLE transaction_line_items (
        line_item_id   TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL REFERENCES transactions(transaction_id),
        product_id     TEXT NOT NULL REFERENCES products(product_id),
        qty            INTEGER NOT NULL,
        unit_price     REAL NOT NULL,
        subtotal       REAL NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_line_items_txn ON transaction_line_items(transaction_id)');

    await db.execute('''
      CREATE TABLE payment_records (
        payment_id     TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL UNIQUE REFERENCES transactions(transaction_id),
        method         TEXT NOT NULL,
        amount         REAL NOT NULL,
        gateway_ref    TEXT,
        confirmed_at   TEXT,
        status         TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE receipts (
        receipt_id      TEXT PRIMARY KEY,
        transaction_id  TEXT NOT NULL UNIQUE REFERENCES transactions(transaction_id),
        store_name      TEXT NOT NULL,
        timestamp       TEXT NOT NULL,
        qr_payload      TEXT NOT NULL,
        customer_mobile TEXT,
        delivery_status TEXT NOT NULL DEFAULT 'pending',
        sms_delivered_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_summaries (
        summary_id    TEXT PRIMARY KEY,
        period        TEXT NOT NULL,
        period_start  TEXT NOT NULL,
        period_end    TEXT NOT NULL,
        total_revenue REAL NOT NULL DEFAULT 0,
        cogs          REAL NOT NULL DEFAULT 0,
        gross_profit  REAL NOT NULL DEFAULT 0,
        txn_count     INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_sales_period ON sales_summaries(period, period_start)');

    await db.execute('''
      CREATE TABLE price_suggestions (
        suggestion_id    TEXT PRIMARY KEY,
        product_id       TEXT NOT NULL REFERENCES products(product_id),
        suggested_price  REAL NOT NULL,
        benchmark_source TEXT NOT NULL DEFAULT 'cost_markup',
        fetched_at       TEXT NOT NULL,
        accepted         INTEGER NOT NULL DEFAULT 0,
        accepted_at      TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        log_id      TEXT PRIMARY KEY,
        user_id     TEXT REFERENCES user_credentials(user_id),
        action      TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id   TEXT NOT NULL,
        timestamp   TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_audit_user ON audit_logs(user_id, timestamp)');

    await db.execute('''
      CREATE TABLE sync_queue (
        queue_id    TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id   TEXT NOT NULL,
        operation   TEXT NOT NULL,
        payload     TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status      TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_sync_status ON sync_queue(status, created_at)');

    await db.execute('''
      CREATE TABLE outbound_messages (
        message_id  TEXT PRIMARY KEY,
        type        TEXT NOT NULL DEFAULT 'sms',
        recipient   TEXT NOT NULL,
        content     TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        sent_at     TEXT,
        status      TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_outbound_status ON outbound_messages(status, created_at)');

    await _seedDefaultCategories(db);
    await _seedDefaultProducts(db);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT UNIQUE');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          queue_id    TEXT PRIMARY KEY,
          entity_type TEXT NOT NULL,
          entity_id   TEXT NOT NULL,
          operation   TEXT NOT NULL,
          payload     TEXT NOT NULL,
          created_at  TEXT NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0,
          status      TEXT NOT NULL DEFAULT 'pending'
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_status ON sync_queue(status, created_at)');
      try {
        await db.execute(
            "ALTER TABLE price_suggestions ADD COLUMN benchmark_source TEXT NOT NULL DEFAULT 'cost_markup'");
      } catch (_) {}
      await _seedDefaultCategories(db);
    }
    if (oldVersion < 4) {
      await _seedDefaultProducts(db);
    }
  }

  static Future<void> _seedDefaultCategories(Database db) async {
    final List<String> names = <String>[
      'Beverages',
      'Snacks',
      'Canned Goods',
      'Instant Noodles',
      'Condiments',
      'Dairy & Eggs',
      'Frozen Foods',
      'Personal Care',
      'Household',
      'Tobacco',
      'Alcohol',
      'Other',
    ];
    final String now = DateTime.now().toIso8601String();
    for (final String name in names) {
      try {
        await db.execute(
          "INSERT OR IGNORE INTO categories (category_id, name, created_at) VALUES (lower(hex(randomblob(16))), ?, ?)",
          <Object>[name, now],
        );
      } catch (_) {}
    }
  }

  /// Close the database (useful in tests).
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _seedDefaultProducts(Database db) async {
    final String now = DateTime.now().toIso8601String();

    // Helper: get category id by name
    Future<String?> getCatId(String catName) async {
      final List<Map<String, dynamic>> rows = await db.query(
        'categories',
        where: 'name = ?',
        whereArgs: <String>[catName],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first['category_id'] as String?;
    }

    // Product entries: [name, unitPrice, costPrice, stockQty, threshold, categoryName, barcode?]
    final List<List<dynamic>> products = <List<dynamic>>[
      // ── Coffee / Powdered Drinks ──
      ['Kopiko Blanca 3-in-1', 8.0, 6.0, 100, 10, 'Beverages', 'SARE-4042'],
      ['Great Taste White 3-in-1', 8.0, 6.0, 100, 10, 'Beverages', 'SARE-4043'],
      ['Swiss Miss Choco Mix', 25.0, 18.0, 50, 5, 'Beverages', 'SARE-4045'],
      ['Milo Choco Malt Drink', 8.0, 6.0, 80, 10, 'Beverages', 'SARE-4047'],
      ['Great Taste Choco 3-in-1', 8.0, 6.0, 80, 10, 'Beverages', 'SARE-4048'],
      ['Choco Milk Drink Sachet', 7.0, 5.0, 80, 10, 'Beverages', 'SARE-4049'],
      ['Chocolait Choco Drink', 10.0, 7.0, 60, 8, 'Beverages', 'SARE-4050'],
      // ── Dairy / Milk ──
      ['Birch Tree Chocolate Milk Powder', 15.0, 11.0, 60, 5, 'Dairy & Eggs', 'SARE-4046'],
      ['Choco Crunch Milk Powder', 12.0, 9.0, 60, 5, 'Dairy & Eggs', 'SARE-4044'],
      ['Alaska Creamer Sachet', 7.0, 5.0, 100, 15, 'Dairy & Eggs', 'SARE-4053'],
      ['Alaska Classic Evaporated Milk 370mL', 38.0, 28.0, 50, 5, 'Dairy & Eggs', 'SARE-4059'],
      ['Alaska Evaporada 250mL', 25.0, 19.0, 50, 5, 'Dairy & Eggs', 'SARE-4060'],
      ['Hany Milk Chocolate Bar', 10.0, 7.0, 80, 10, 'Snacks', 'SARE-4061'],
      // ── Bread / Pastry ──
      ['Hopia Hapon Style Ube Flavor', 12.0, 9.0, 50, 5, 'Snacks', 'SARE-4051'],
      ['Hopia Hapon Style Monggo Flavor', 12.0, 9.0, 50, 5, 'Snacks', 'SARE-4052'],
      ['Special Piyaya', 15.0, 11.0, 40, 5, 'Snacks', 'SARE-4053b'],
      // ── Condiments ──
      ["Lady's Choice Mayonnaise 220mL", 55.0, 42.0, 30, 3, 'Condiments', 'SARE-4054'],
      ['Kulina Real Mayonnaise 220mL', 48.0, 36.0, 30, 3, 'Condiments', 'SARE-4055'],
      ['Kulina Spread 220mL', 45.0, 34.0, 30, 3, 'Condiments', 'SARE-4056'],
      ["Lady's Choice Sandwich Spread 220mL", 55.0, 42.0, 30, 3, 'Condiments', 'SARE-4057'],
      // ── Baking / Mixes ──
      ['Hotcake Mix 200g', 35.0, 26.0, 40, 5, 'Other', 'SARE-4058'],
      // ── Canned Goods ──
      ['Sea Point Corned Tuna 155g', 30.0, 22.0, 60, 8, 'Canned Goods', 'SARE-4062'],
      ['Bingo Corned Beef 150g', 35.0, 26.0, 60, 8, 'Canned Goods', 'SARE-4063'],
      ['Sea Point Tuna 155g', 28.0, 21.0, 60, 8, 'Canned Goods', 'SARE-4064'],
      ['Century Tuna Flakes in Oil 180g', 32.0, 24.0, 60, 8, 'Canned Goods', 'SARE-4065'],
      ['Century Tuna Hot and Spicy 180g', 32.0, 24.0, 60, 8, 'Canned Goods', 'SARE-4066'],
      ['San Marino Chili Corned Tuna 155g', 34.0, 25.0, 50, 5, 'Canned Goods', 'SARE-4067'],
      ['Sea Point Tuna Flakes in Spicy 155g', 30.0, 22.0, 50, 5, 'Canned Goods', 'SARE-4068'],
      // ── Instant Noodles ──
      ['Lucky Me! Pancit Canton Chilimansi', 14.0, 10.0, 100, 15, 'Instant Noodles', 'SARE-4069'],
      ['Lucky Me! Pancit Canton Original', 14.0, 10.0, 100, 15, 'Instant Noodles', 'SARE-4070'],
      ['Lucky Me! Pancit Canton Extra Spicy', 14.0, 10.0, 100, 15, 'Instant Noodles', 'SARE-4071'],
      ['Xtra Big Spicy Instant Noodles', 18.0, 13.0, 80, 10, 'Instant Noodles', 'SARE-4072'],
      ['Xtra Big Calamansi Instant Noodles', 18.0, 13.0, 80, 10, 'Instant Noodles', 'SARE-4073'],
      // ── Beverages ──
      ['Pocari Sweat 350mL', 38.0, 28.0, 50, 5, 'Beverages', 'SARE-4074'],
      ['Gatorade 350mL', 35.0, 26.0, 50, 5, 'Beverages', 'SARE-4075'],
      ['Twist-O Juice Drink', 12.0, 9.0, 60, 8, 'Beverages', 'SARE-4076'],
      ['Rite+Lite Lychee Rose Juice', 15.0, 11.0, 60, 8, 'Beverages', 'SARE-4077'],
      ['Soda Water', 20.0, 15.0, 48, 5, 'Beverages', 'SARE-4078'],
      ['Sprite 1.5L', 68.0, 50.0, 30, 3, 'Beverages', 'SARE-4079'],
      ['Mountain Dew 1.5L', 68.0, 50.0, 30, 3, 'Beverages', 'SARE-4081'],
    ];

    for (final List<dynamic> p in products) {
      final String catName = p[5] as String;
      final String? catId = await getCatId(catName);
      final String? barcode = p.length > 6 ? p[6] as String? : null;
      try {
        await db.execute(
          '''INSERT OR IGNORE INTO products
             (product_id, category_id, barcode, name, unit_price, cost_price, stock_qty, threshold, is_active, created_at, updated_at)
             VALUES (lower(hex(randomblob(16))), ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)''',
          <dynamic>[catId, barcode, p[0], p[1], p[2], p[3], p[4], now, now],
        );
      } catch (_) {} // Skip if barcode conflict
    }
  }
}
