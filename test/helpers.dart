import 'package:localbiz_ai/ai/conversation/assistant_engine.dart';
import 'package:localbiz_ai/core/database/app_database.dart';
import 'package:localbiz_ai/core/security/security_service.dart';
import 'package:localbiz_ai/core/utils/money.dart';
import 'package:localbiz_ai/features/billing/billing_service.dart';
import 'package:localbiz_ai/features/inventory/inventory_service.dart';
import 'package:localbiz_ai/features/pricing/pricing_service.dart';
import 'package:localbiz_ai/features/products/product_service.dart';
import 'package:localbiz_ai/features/purchases/purchase_service.dart';
import 'package:localbiz_ai/features/reports/report_service.dart';
import 'package:localbiz_ai/features/settings/backup_service.dart';
import 'package:localbiz_ai/shared/models/models.dart';
import 'package:localbiz_ai/shared/repositories/shop_repository.dart';
import 'package:localbiz_ai/shared/repositories/user_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openTestDb() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      version: AppDatabase.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, v) => AppDatabase.createSchema(db),
    ),
  );
}

/// A fully wired in-memory shop for tests.
class Fixture {
  late Database db;
  final security = SecurityService();
  late ShopRepository shop;
  late UserRepository users;
  late ProductService products;
  late PricingService pricing;
  late InventoryService inventory;
  late BillingService billing;
  late PurchaseService purchases;
  late ReportService reports;
  late BackupService backup;
  late Session owner;
  BillDraft draft = BillDraft.empty();

  static Future<Fixture> create({bool register = true}) async {
    Money.symbol = '₹';
    final f = Fixture();
    f.db = await openTestDb();
    f.shop = ShopRepository(f.db, f.security);
    f.users = UserRepository(f.db, f.security);
    f.products = ProductService(f.db);
    f.pricing = PricingService(f.db);
    f.inventory = InventoryService(f.db);
    f.billing = BillingService(f.db);
    f.purchases = PurchaseService(f.db);
    f.reports = ReportService(f.db);
    f.backup = BackupService(f.db);
    if (register) {
      await f.shop.register(
        ownerName: 'Ravi',
        shopName: 'Ravi Stores',
        category: 'Grocery shop',
        address: '12 Main Road',
        language: 'en',
        pin: '1234',
      );
      f.owner = (await f.users.ownerSession())!;
    }
    return f;
  }

  Future<int> addProduct(String name,
      {int? retail, int? wholesale, String unit = 'kg', int stock = 0, int min = 0, String alt = ''}) {
    return products.create(
        owner,
        ProductInput(
            name: name,
            altNames: alt,
            retail: retail,
            wholesale: wholesale,
            unit: unit,
            stockMilli: stock,
            minStockMilli: min));
  }

  Future<Session> employee({String role = 'employee', String pin = '2222'}) async {
    await users.create(owner, 'Staff $role', role, pin);
    final all = await users.listAll(owner);
    final u = all.firstWhere((e) => e.role == role);
    return (await users.sessionFor(u.id))!;
  }

  /// Seeds Rice (₹60/₹45, 20 kg) and Sugar (₹50/₹38, 10 kg).
  Future<void> seedBasics() async {
    await addProduct('Rice', retail: 6000, wholesale: 4500, stock: 20000, min: 5000);
    await addProduct('Sugar', retail: 5000, wholesale: 3800, stock: 10000, min: 2000);
  }

  AssistantEngine engine({Session? session, String lang = 'en'}) {
    final s = session ?? owner;
    return AssistantEngine(
      products: products,
      pricing: pricing,
      inventory: inventory,
      billing: billing,
      reports: reports,
      shop: shop,
      users: users,
      getSession: () => s,
      getLang: () => lang,
      getDraft: () => draft,
      setDraft: (d) => draft = d,
    );
  }

  Future<void> close() => db.close();
}
