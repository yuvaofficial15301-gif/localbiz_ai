import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/services/audit_service.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../inventory/inventory_service.dart';

/// Purchases record what you paid suppliers. The purchase cost is stored
/// independently from the product's wholesale/retail prices, and no profit is
/// calculated here (reserved for a future module).
class PurchaseService {
  final Database db;
  PurchaseService(this.db);

  Future<int> create(
    Session s, {
    required String supplier,
    required String date, // YYYY-MM-DD
    required String paymentStatus, // paid | pending
    String invoiceRef = '',
    String supplierPhone = '',
    required List<PurchaseLineInput> lines,
  }) async {
    s.need(Perm.managePurchases);
    if (supplier.trim().isEmpty) throw AppError('invalid', 'Supplier is required');
    if (lines.isEmpty) throw AppError('invalid', 'Add at least one product');
    if (paymentStatus != 'paid' && paymentStatus != 'pending') {
      throw AppError('invalid', 'Payment status must be paid or pending');
    }
    for (final l in lines) {
      if (l.qtyMilli <= 0 || l.unitCost < 0) {
        throw AppError('invalid', 'Invalid quantity or cost for ${l.name}');
      }
    }
    return db.transaction<int>((txn) async {
      var sid = 0;
      final sup = await txn.query('suppliers',
          where: 'lower(name) = ?', whereArgs: [supplier.trim().toLowerCase()], limit: 1);
      if (sup.isEmpty) {
        sid = await txn.insert('suppliers',
            {'name': supplier.trim(), 'phone': supplierPhone.trim()});
      } else {
        sid = sup.first['id'] as int;
      }
      var total = 0;
      final computed = <List<Object>>[];
      for (final l in lines) {
        final p = await txn.query('products',
            columns: ['unit', 'name'],
            where: 'id = ? AND deleted = 0',
            whereArgs: [l.productId]);
        if (p.isEmpty) throw AppError('not_found', '${l.name} not found');
        final pu = p.first['unit'] as String;
        if (!Units.compatible(l.unit, pu)) {
          throw AppError('unit_mismatch', '${l.unit} cannot be used for ${l.name}');
        }
        final qtyInProductUnit = Units.convertMilli(l.qtyMilli, l.unit, pu);
        final lineTotal = Qty.lineTotal(l.unitCost, qtyInProductUnit);
        total += lineTotal;
        computed.add([l, qtyInProductUnit, pu, lineTotal]);
      }
      final pid = await txn.insert('purchases', {
        'supplier_id': sid,
        'supplier_name': supplier.trim(),
        'purchase_date': date,
        'total': total,
        'payment_status': paymentStatus,
        'invoice_ref': invoiceRef.trim(),
        'created_by': s.name,
        'created_at': nowIso(),
      });
      for (final c in computed) {
        final l = c[0] as PurchaseLineInput;
        final q = c[1] as int;
        final pu = c[2] as String;
        final lt = c[3] as int;
        await txn.insert('purchase_items', {
          'purchase_id': pid,
          'product_id': l.productId,
          'product_name': l.name,
          'qty_milli': q,
          'unit': pu,
          'unit_cost': l.unitCost,
          'line_total': lt,
        });
        await InventoryService.applyDelta(txn,
            productId: l.productId,
            deltaMilli: q,
            reason: 'purchase',
            ref: 'P-$pid',
            user: s.name);
      }
      await AuditService.log(txn, s.name, 'purchase_created',
          '${supplier.trim()} ${Money.plain(total)}');
      return pid;
    });
  }

  Future<List<PurchaseRec>> list(Session s, {int limit = 200}) async {
    s.needAny([Perm.managePurchases, Perm.viewReports]);
    final r = await db.query('purchases', orderBy: 'id DESC', limit: limit);
    return r.map(PurchaseRec.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> items(Session s, int purchaseId) async {
    s.needAny([Perm.managePurchases, Perm.viewReports]);
    return db.query('purchase_items',
        where: 'purchase_id = ?', whereArgs: [purchaseId], orderBy: 'id');
  }

  Future<void> markPaid(Session s, int purchaseId) async {
    s.need(Perm.managePurchases);
    await db.transaction((txn) async {
      await txn.update('purchases', {'payment_status': 'paid'},
          where: 'id = ?', whereArgs: [purchaseId]);
      await AuditService.log(txn, s.name, 'purchase_paid', 'P-$purchaseId');
    });
  }
}
