import 'package:sqflite_sqlcipher/sqflite.dart';

import '../utils/money.dart';

/// Permission names used across the app.
class Perm {
  static const viewProducts = 'view_products';
  static const editProducts = 'edit_products';
  static const deleteProducts = 'delete_products';
  static const editRetail = 'edit_retail_price';
  static const viewWholesale = 'view_wholesale';
  static const editWholesale = 'edit_wholesale';
  static const createBill = 'create_bill';
  static const viewReports = 'view_reports';
  static const manageStock = 'manage_stock';
  static const managePurchases = 'manage_purchases';
  static const backup = 'backup_restore';
  static const manageUsers = 'manage_users';
  static const security = 'security_settings';
  static const ownerDetails = 'view_owner_details';
  static const editShop = 'edit_shop_profile';

  static const all = <String>[
    viewProducts, editProducts, deleteProducts, editRetail, viewWholesale,
    editWholesale, createBill, viewReports, manageStock, managePurchases,
    backup, manageUsers, security, ownerDetails, editShop,
  ];

  /// Permissions that can never be delegated: enforced in code.
  static const ownerOnly = <String>{
    viewWholesale, editWholesale, manageUsers, security, ownerDetails, editShop,
  };

  static const managerDefaults = <String>{
    viewProducts, editProducts, editRetail, createBill, viewReports,
    manageStock, managePurchases,
  };
  static const employeeDefaults = <String>{viewProducts, createBill};
}

class AppDatabase {
  static const int schemaVersion = 1;

  /// Ordered list of tables (parents first) used by backup/restore.
  static const List<String> tables = [
    'app_settings', 'shop_profile', 'roles', 'permissions', 'users',
    'categories', 'products', 'suppliers', 'purchases', 'purchase_items',
    'bills', 'bill_items', 'price_history', 'stock_movements', 'audit_logs',
  ];

  static Future<Database> open(String path, String? password) {
    return openDatabase(
      path,
      password: password,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, v) => createSchema(db),
      onUpgrade: (db, from, to) => migrate(db, from, to),
    );
  }

  static const List<String> _schemaV1 = [
    '''CREATE TABLE shop_profile(
      id INTEGER PRIMARY KEY CHECK (id = 1),
      owner_name TEXT NOT NULL,
      shop_name TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      language TEXT NOT NULL DEFAULT 'en',
      currency TEXT NOT NULL DEFAULT '₹',
      opening_date TEXT,
      created_at TEXT NOT NULL)''',
    '''CREATE TABLE roles(name TEXT PRIMARY KEY)''',
    '''CREATE TABLE permissions(
      role TEXT NOT NULL REFERENCES roles(name),
      permission TEXT NOT NULL,
      allowed INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(role, permission))''',
    '''CREATE TABLE users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      role TEXT NOT NULL REFERENCES roles(name),
      pin_hash TEXT NOT NULL,
      pin_salt TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL)''',
    '''CREATE TABLE categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE)''',
    '''CREATE TABLE products(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      alt_names TEXT NOT NULL DEFAULT '',
      category TEXT NOT NULL DEFAULT '',
      unit TEXT NOT NULL DEFAULT 'kg',
      wholesale_price INTEGER CHECK (wholesale_price IS NULL OR wholesale_price >= 0),
      retail_price INTEGER CHECK (retail_price IS NULL OR retail_price >= 0),
      stock_milli INTEGER NOT NULL DEFAULT 0,
      min_stock_milli INTEGER NOT NULL DEFAULT 0,
      barcode TEXT,
      description TEXT NOT NULL DEFAULT '',
      expiry_date TEXT,
      active INTEGER NOT NULL DEFAULT 1,
      deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL)''',
    'CREATE INDEX idx_products_name ON products(name)',
    'CREATE INDEX idx_products_barcode ON products(barcode)',
    'CREATE INDEX idx_products_state ON products(deleted, active)',
    '''CREATE TABLE suppliers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL DEFAULT '')''',
    '''CREATE TABLE purchases(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      supplier_id INTEGER REFERENCES suppliers(id),
      supplier_name TEXT NOT NULL,
      purchase_date TEXT NOT NULL,
      total INTEGER NOT NULL,
      payment_status TEXT NOT NULL DEFAULT 'paid',
      invoice_ref TEXT NOT NULL DEFAULT '',
      created_by TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL)''',
    '''CREATE TABLE purchase_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
      product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
      product_name TEXT NOT NULL,
      qty_milli INTEGER NOT NULL,
      unit TEXT NOT NULL,
      unit_cost INTEGER NOT NULL,
      line_total INTEGER NOT NULL)''',
    'CREATE INDEX idx_purchase_items_p ON purchase_items(purchase_id)',
    '''CREATE TABLE bills(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_no TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL,
      subtotal INTEGER NOT NULL,
      discount INTEGER NOT NULL DEFAULT 0,
      tax INTEGER NOT NULL DEFAULT 0,
      total INTEGER NOT NULL,
      payment_method TEXT NOT NULL DEFAULT 'cash',
      customer_name TEXT NOT NULL DEFAULT '',
      created_by TEXT NOT NULL DEFAULT '',
      idem_key TEXT UNIQUE)''',
    'CREATE INDEX idx_bills_created ON bills(created_at)',
    '''CREATE TABLE bill_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_id INTEGER NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
      product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
      product_name TEXT NOT NULL,
      qty_milli INTEGER NOT NULL,
      unit TEXT NOT NULL,
      unit_price INTEGER NOT NULL,
      line_total INTEGER NOT NULL,
      discount INTEGER NOT NULL DEFAULT 0,
      tax INTEGER NOT NULL DEFAULT 0,
      final_amount INTEGER NOT NULL)''',
    'CREATE INDEX idx_bill_items_bill ON bill_items(bill_id)',
    'CREATE INDEX idx_bill_items_product ON bill_items(product_id)',
    '''CREATE TABLE price_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES products(id),
      price_type TEXT NOT NULL CHECK (price_type IN ('retail','wholesale')),
      old_price INTEGER,
      new_price INTEGER NOT NULL,
      changed_at TEXT NOT NULL,
      changed_by TEXT NOT NULL DEFAULT '')''',
    'CREATE INDEX idx_price_history_p ON price_history(product_id)',
    '''CREATE TABLE stock_movements(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES products(id),
      product_name TEXT NOT NULL,
      change_milli INTEGER NOT NULL,
      balance_milli INTEGER NOT NULL,
      reason TEXT NOT NULL,
      ref TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      created_by TEXT NOT NULL DEFAULT '')''',
    'CREATE INDEX idx_stock_mov_p ON stock_movements(product_id)',
    '''CREATE TABLE audit_logs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      at TEXT NOT NULL,
      user_name TEXT NOT NULL,
      action TEXT NOT NULL,
      detail TEXT NOT NULL DEFAULT '')''',
    '''CREATE TABLE app_settings(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL)''',
  ];

  /// Append-only guards (price history can never be deleted or rewritten).
  static const List<String> guardSql = [
    '''CREATE TRIGGER IF NOT EXISTS price_history_no_delete
       BEFORE DELETE ON price_history
       BEGIN SELECT RAISE(ABORT, 'price_history is append-only'); END''',
    '''CREATE TRIGGER IF NOT EXISTS price_history_no_update
       BEFORE UPDATE ON price_history
       BEGIN SELECT RAISE(ABORT, 'price_history is append-only'); END''',
  ];
  static const List<String> guardDrop = [
    'DROP TRIGGER IF EXISTS price_history_no_delete',
    'DROP TRIGGER IF EXISTS price_history_no_update',
  ];

  /// Future migrations: version -> statements executed when upgrading TO it.
  static const Map<int, List<String>> migrations = {};

  static Future<void> createSchema(Database db) async {
    for (final s in _schemaV1) {
      await db.execute(s);
    }
    for (final s in guardSql) {
      await db.execute(s);
    }
    await _seed(db);
  }

  static Future<void> migrate(Database db, int from, int to,
      {Map<int, List<String>>? steps}) async {
    final m = steps ?? migrations;
    for (var v = from + 1; v <= to; v++) {
      final list = m[v];
      if (list == null) continue;
      for (final s in list) {
        await db.execute(s);
      }
    }
  }

  static Future<void> _seed(Database db) async {
    for (final r in const ['owner', 'manager', 'employee']) {
      await db.insert('roles', {'name': r});
    }
    for (final p in Perm.all) {
      await db.insert('permissions',
          {'role': 'owner', 'permission': p, 'allowed': 1});
      await db.insert('permissions', {
        'role': 'manager',
        'permission': p,
        'allowed': Perm.managerDefaults.contains(p) ? 1 : 0
      });
      await db.insert('permissions', {
        'role': 'employee',
        'permission': p,
        'allowed': Perm.employeeDefaults.contains(p) ? 1 : 0
      });
    }
    const defaults = <String, String>{
      'allow_negative_stock': '0',
      'tax_percent_bp': '0',
      'tax_name': 'Tax',
      'auto_lock_minutes': '5',
      'voice_offline_only': '1',
      'tts_enabled': '1',
      'notif_low_stock': '1',
      'notif_expiry': '1',
      'notif_backup': '1',
      'backup_reminder_days': '7',
      'biometric_enabled': '0',
      'expiry_warn_days': '14',
    };
    for (final e in defaults.entries) {
      await db.insert('app_settings', {'key': e.key, 'value': e.value});
    }
  }

  /// Convenience used by tests and backup to check the schema is intact.
  static Future<List<String>> tableNames(Database db) async {
    final r = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'");
    return r.map((e) => e['name'] as String).toList();
  }

  static String stamp() => nowIso();
}
