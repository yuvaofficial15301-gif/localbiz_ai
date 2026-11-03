import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/services/audit_service.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';

class PriceChange {
  final int productId;
  final String productName;
  final String type;
  final int? oldPrice;
  final int newPrice;
  final bool changed;
  const PriceChange(this.productId, this.productName, this.type, this.oldPrice,
      this.newPrice, this.changed);
}

/// One products table, two independent price columns. All permission checks
/// live here so the UI/assistant cannot bypass them.
class PricingService {
  static const int maxPrice = 1000000000; // ₹1 crore ceiling as a sanity guard
  final Database db;
  PricingService(this.db);

  static String _col(String type) {
    if (type == 'retail') return 'retail_price';
    if (type == 'wholesale') return 'wholesale_price';
    throw AppError('invalid', 'Price type must be retail or wholesale');
  }

  static String _perm(String type) =>
      type == 'retail' ? Perm.editRetail : Perm.editWholesale;

  /// Records a price change inside the caller's transaction.
  static Future<PriceChange> applyInTxn(
    DatabaseExecutor ex,
    Session s,
    int productId,
    String type,
    int Function(int? old) compute,
  ) async {
    s.need(_perm(type));
    final col = _col(type);
    final r = await ex.query('products',
        columns: ['name', col],
        where: 'id = ? AND deleted = 0',
        whereArgs: [productId]);
    if (r.isEmpty) throw AppError('not_found', 'Product not found');
    final old = r.first[col] as int?;
    final next = compute(old);
    if (next < 0 || next > maxPrice) {
      throw AppError('invalid', 'Price is out of range');
    }
    final name = r.first['name'] as String;
    if (old == next) return PriceChange(productId, name, type, old, next, false);
    await ex.update('products', {col: next, 'updated_at': nowIso()},
        where: 'id = ?', whereArgs: [productId]);
    await ex.insert('price_history', {
      'product_id': productId,
      'price_type': type,
      'old_price': old,
      'new_price': next,
      'changed_at': nowIso(),
      'changed_by': s.name,
    });
    await AuditService.log(ex, s.name, 'price_changed',
        '$name $type ${old == null ? '-' : Money.plain(old)} -> ${Money.plain(next)}');
    return PriceChange(productId, name, type, old, next, true);
  }

  Future<PriceChange> setPrice(Session s, int productId, String type, int newPaise) {
    return db.transaction<PriceChange>(
        (txn) => applyInTxn(txn, s, productId, type, (_) => newPaise));
  }

  /// Increase (positive) or decrease (negative) by a delta in paise.
  Future<PriceChange> adjust(Session s, int productId, String type, int deltaPaise) {
    return db.transaction<PriceChange>((txn) async {
      return applyInTxn(txn, s, productId, type, (old) {
        if (old == null) {
          throw AppError('no_price', 'No $type price is saved for this product');
        }
        return old + deltaPaise;
      });
    });
  }

  Future<int?> getRetail(int productId) async {
    final r = await db.query('products',
        columns: ['retail_price'],
        where: 'id = ? AND deleted = 0',
        whereArgs: [productId]);
    if (r.isEmpty) throw AppError('not_found', 'Product not found');
    return r.first['retail_price'] as int?;
  }

  /// Wholesale lookup: authorised owner only; every view is audit-logged.
  Future<int?> getWholesale(Session s, int productId) async {
    s.need(Perm.viewWholesale);
    final r = await db.query('products',
        columns: ['name', 'wholesale_price'],
        where: 'id = ? AND deleted = 0',
        whereArgs: [productId]);
    if (r.isEmpty) throw AppError('not_found', 'Product not found');
    await AuditService.log(db, s.name, 'wholesale_viewed', r.first['name'] as String);
    return r.first['wholesale_price'] as int?;
  }

  Future<List<PriceHistoryRec>> history(Session s,
      {int? productId, String? type, int limit = 300}) async {
    s.needAny([Perm.viewProducts, Perm.viewReports]);
    final where = <String>[];
    final args = <Object?>[];
    if (productId != null) {
      where.add('ph.product_id = ?');
      args.add(productId);
    }
    if (type != null) {
      where.add('ph.price_type = ?');
      args.add(type);
    }
    if (!s.can(Perm.viewWholesale)) where.add("ph.price_type = 'retail'");
    final r = await db.rawQuery(
        'SELECT ph.*, p.name AS product_name FROM price_history ph '
        'JOIN products p ON p.id = ph.product_id '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY ph.id DESC LIMIT $limit',
        args);
    return r.map(PriceHistoryRec.fromMap).toList();
  }
}
