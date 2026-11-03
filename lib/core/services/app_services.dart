import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../ai/local_llm/llm_service.dart';
import '../../ai/voice/voice_service.dart';
import '../../features/billing/billing_service.dart';
import '../../features/inventory/inventory_service.dart';
import '../../features/pricing/pricing_service.dart';
import '../../features/products/product_service.dart';
import '../../features/purchases/purchase_service.dart';
import '../../features/reports/report_service.dart';
import '../../features/settings/backup_service.dart';
import '../../shared/repositories/shop_repository.dart';
import '../../shared/repositories/user_repository.dart';
import '../database/app_database.dart';
import '../security/security_service.dart';
import 'audit_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';

/// Holds every service. Everything runs locally; no network clients exist.
class AppServices {
  final Database db;
  final SecurityService security;
  final SettingsService settings;
  final AuditService audit;
  final ShopRepository shop;
  final UserRepository users;
  final ProductService products;
  final PricingService pricing;
  final InventoryService inventory;
  final BillingService billing;
  final PurchaseService purchases;
  final ReportService reports;
  final BackupService backup;
  final NotificationService notifications;
  final AlertsService alerts;
  final VoiceService voice;
  final LocalLlmService llm;

  AppServices._(this.db, this.security, this.settings, this.audit, this.shop,
      this.users, this.products, this.pricing, this.inventory, this.billing,
      this.purchases, this.reports, this.backup, this.notifications,
      this.alerts, this.voice, this.llm);

  factory AppServices.fromDb(Database db, SecurityService security) {
    final settings = SettingsService(db);
    final inventory = InventoryService(db);
    final notifications = NotificationService();
    return AppServices._(
      db,
      security,
      settings,
      AuditService(db),
      ShopRepository(db, security),
      UserRepository(db, security),
      ProductService(db),
      PricingService(db),
      inventory,
      BillingService(db),
      PurchaseService(db),
      ReportService(db),
      BackupService(db),
      notifications,
      AlertsService(settings, inventory, notifications),
      VoiceService(),
      LocalLlmService(settings),
    );
  }

  /// Opens the SQLCipher database with a key held in Android Keystore storage.
  static Future<AppServices> create() async {
    final security = SecurityService();
    final key = await security.getOrCreateDbKey();
    final dir = await getDatabasesPath();
    final db = await AppDatabase.open(p.join(dir, 'localbiz_ai.db'), key);
    return AppServices.fromDb(db, security);
  }
}
