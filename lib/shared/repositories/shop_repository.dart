import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/security/security_service.dart';
import '../../core/services/audit_service.dart';
import '../../core/utils/money.dart';
import '../models/models.dart';

class ShopRepository {
  final Database db;
  final SecurityService security;
  ShopRepository(this.db, this.security);

  Future<ShopProfile?> profile() async {
    final r = await db.query('shop_profile', where: 'id = 1', limit: 1);
    if (r.isEmpty) return null;
    return ShopProfile.fromMap(r.first);
  }

  /// First-time registration: creates the shop profile and the owner account.
  Future<void> register({
    required String ownerName,
    required String shopName,
    required String category,
    String phone = '',
    String address = '',
    required String language,
    String currency = '₹',
    String? openingDate,
    required String pin,
  }) async {
    if (ownerName.trim().isEmpty) {
      throw AppError('invalid', 'Shopkeeper name is required');
    }
    if (shopName.trim().isEmpty) {
      throw AppError('invalid', 'Shop name is required');
    }
    if (!SecurityService.validPin(pin)) {
      throw AppError('invalid', 'PIN must be 4 to 6 digits');
    }
    if (await profile() != null) {
      throw AppError('duplicate', 'Shop is already registered');
    }
    final salt = security.newSalt();
    final hash = security.hashPin(pin, salt);
    await db.transaction((txn) async {
      await txn.insert('shop_profile', {
        'id': 1,
        'owner_name': ownerName.trim(),
        'shop_name': shopName.trim(),
        'category': category.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'language': language,
        'currency': currency.trim().isEmpty ? '₹' : currency.trim(),
        'opening_date': openingDate,
        'created_at': nowIso(),
      });
      await txn.insert('users', {
        'name': ownerName.trim(),
        'role': 'owner',
        'pin_hash': hash,
        'pin_salt': salt,
        'active': 1,
        'created_at': nowIso(),
      });
      await AuditService.log(txn, ownerName.trim(), 'shop_registered', shopName.trim());
    });
  }

  Future<void> update(Session s,
      {String? ownerName,
      String? shopName,
      String? category,
      String? phone,
      String? address,
      String? language,
      String? currency,
      String? openingDate}) async {
    // Language is a personal preference; everything else is owner-only.
    final onlyLanguage = language != null &&
        ownerName == null && shopName == null && category == null &&
        phone == null && address == null && currency == null &&
        openingDate == null;
    if (!onlyLanguage) s.need(Perm.editShop);
    final values = <String, Object?>{};
    if (ownerName != null) {
      if (ownerName.trim().isEmpty) throw AppError('invalid', 'Name is required');
      values['owner_name'] = ownerName.trim();
    }
    if (shopName != null) {
      if (shopName.trim().isEmpty) throw AppError('invalid', 'Shop name is required');
      values['shop_name'] = shopName.trim();
    }
    if (category != null) values['category'] = category.trim();
    if (phone != null) values['phone'] = phone.trim();
    if (address != null) values['address'] = address.trim();
    if (language != null) values['language'] = language;
    if (currency != null && currency.trim().isNotEmpty) {
      values['currency'] = currency.trim();
    }
    if (openingDate != null) values['opening_date'] = openingDate;
    if (values.isEmpty) return;
    await db.transaction((txn) async {
      await txn.update('shop_profile', values, where: 'id = 1');
      await AuditService.log(txn, s.name, 'profile_updated', values.keys.join(','));
    });
  }
}
