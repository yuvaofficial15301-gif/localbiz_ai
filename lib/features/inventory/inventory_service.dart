import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/services/audit_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';

class InventoryService {
  final Database db;
  InventoryService(this.db);

  /// Core stock mutation used by billing, purchases and manual adjustments.
  /// Must run inside the caller's transaction.
  static Future<int> applyDelta(
    DatabaseExecutor ex, {
    required int productId,
    required int deltaMilli,
    required String reason,
    String ref = '',
    required String user,
  }) async {
    final r = await ex.query('products',
        columns: ['name', 'stock_milli', 'unit'],
        where: 'id = ?',
        whereArgs: [productId]);
    if (r.isEmpty) throw AppError('not_found', 'Product not found');
    final cur = r.first['stock_milli'] as int;
    final name = r.first['name'] as String;
    final unit = r.first['unit'] as String;
    final next = cur + deltaMilli;
    final allowNeg = await SettingsService.readBool(ex, 'allow_negative_stock');
    if (next < 0 && !allowNeg) throw InsufficientStock(name, cur, unit);
    await ex.update('products', {'stock_milli': next, 'updated_at': nowIso()},
        where: 'id = ?', whereArgs: [productId]);
    await ex.insert('stock_movements', {
      'product_id': productId,
      'product_name': name,
      'change_milli': deltaMilli,
      'balance_milli': next,
      'reason': reason,
      'ref': ref,
      'created_at': nowIso(),
      'created_by': user,
    });
    return next;
  }

  /// Adds stock. [qtyMilli]/[unit] may use any unit compatible with the product.
  Future<int> stockIn(Session s, int productId, int qtyMilli, String unit,
      {String reason = 'stock_in', String note = ''}) async {
    s.need(Perm.manageStock);
    if (qtyMilli <= 0) throw AppError('invalid', 'Quantity must be positive');
    return db.transaction<int>((txn) async {
      final p = await txn.query('products',
          columns: ['unit', 'name'],
          where: 'id = ? AND deleted = 0',
          whereArgs: [productId]);
      if (p.isEmpty) throw AppError('not_found', 'Product not found');
      final pu = p.first['unit'] as String;
      if (!Units.compatible(unit, pu)) {
        throw AppError('unit_mismatch', '$unit cannot be used for ${p.first['name']}');
      }
      final q = Units.convertMilli(qtyMilli, unit, pu);
      final bal = await applyDelta(txn,
          productId: productId, deltaMilli: q, reason: reason, ref: note, user: s.name);
      await AuditService.log(txn, s.name, 'stock_in',
          '${p.first['name']} +${Qty.format(q)} $pu');
      return bal;
    });
  }

  Future<int> stockOut(Session s, int productId, int qtyMilli, String unit,
      {String reason = 'stock_out', String note = ''}) async {
    s.need(Perm.manageStock);
    if (qtyMilli <= 0) throw AppError('invalid', 'Quantity must be positive');
    return db.transaction<int>((txn) async {
      final p = await txn.query('products',
          columns: ['unit', 'name'],
          where: 'id = ? AND deleted = 0',
          whereArgs: [productId]);
      if (p.isEmpty) throw AppError('not_found', 'Product not found');
      final pu = p.first['unit'] as String;
      if (!Units.compatible(unit, pu)) {
        throw AppError('unit_mismatch', '$unit cannot be used for ${p.first['name']}');
      }
      final q = Units.convertMilli(qtyMilli, unit, pu);
      final bal = await applyDelta(txn,
          productId: productId, deltaMilli: -q, reason: reason, ref: note, user: s.name);
      await AuditService.log(txn, s.name, 'stock_out',
          '${p.first['name']} -${Qty.format(q)} $pu');
      return bal;
    });
  }

  /// Sets stock to an exact counted value (manual adjustment).
  Future<int> setStock(Session s, int productId, int newMilli, {String note = ''}) async {
    s.need(Perm.manageStock);
    if (newMilli < 0) throw AppError('invalid', 'Stock cannot be negative');
    return db.transaction<int>((txn) async {
      final p = await txn.query('products',
          columns: ['stock_milli', 'name'],
          where: 'id = ? AND deleted = 0',
          whereArgs: [productId]);
      if (p.isEmpty) throw AppError('not_found', 'Product not found');
      final delta = newMilli - (p.first['stock_milli'] as int);
      if (delta == 0) return newMilli;
      final bal = await applyDelta(txn,
          productId: productId, deltaMilli: delta, reason: 'adjustment', ref: note, user: s.name);
      await AuditService.log(txn, s.name, 'stock_adjusted',
          '${p.first['name']} -> ${Qty.format(newMilli)}');
      return bal;
    });
  }

  Future<List<StockMovementRec>> movements(Session s,
      {int? productId, int limit = 200}) async {
    s.needAny([Perm.manageStock, Perm.viewReports, Perm.viewProducts]);
    final r = await db.query('stock_movements',
        where: productId == null ? null : 'product_id = ?',
        whereArgs: productId == null ? null : [productId],
        orderBy: 'id DESC',
        limit: limit);
    return r.map(StockMovementRec.fromMap).toList();
  }

  Future<List<Product>> lowStock(Session s) async {
    s.needAny([Perm.viewProducts, Perm.createBill]);
    final r = await db.query('products',
        where: 'deleted = 0 AND active = 1 AND min_stock_milli > 0 AND stock_milli <= min_stock_milli',
        orderBy: 'name COLLATE NOCASE');
    final w = s.can(Perm.viewWholesale);
    return r.map((e) => Product.fromMap(e, includeWholesale: w)).toList();
  }

  Future<List<Product>> expiringSoon(Session s, int days) async {
    s.needAny([Perm.viewProducts, Perm.createBill]);
    final limit = AppClock.now().add(Duration(days: days));
    final lim = '${limit.year.toString().padLeft(4, '0')}-${limit.month.toString().padLeft(2, '0')}-${limit.day.toString().padLeft(2, '0')}';
    final r = await db.query('products',
        where: "deleted = 0 AND active = 1 AND expiry_date IS NOT NULL AND expiry_date <> '' AND expiry_date <= ?",
        whereArgs: [lim],
        orderBy: 'expiry_date');
    final w = s.can(Perm.viewWholesale);
    return r.map((e) => Product.fromMap(e, includeWholesale: w)).toList();
  }
}
