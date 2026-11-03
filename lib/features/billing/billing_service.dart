import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/services/audit_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../inventory/inventory_service.dart';

class CalcLine {
  final int productId;
  final String name;
  final int qtyMilli;
  final String unit;
  final int unitPrice;
  int lineTotal = 0;
  int discount = 0;
  int tax = 0;
  int get finalAmount => lineTotal - discount + tax;
  CalcLine(this.productId, this.name, this.qtyMilli, this.unit, this.unitPrice);
}

class BillTotals {
  final List<CalcLine> lines;
  final int subtotal;
  final int discount;
  final int tax;
  final int total;
  const BillTotals(this.lines, this.subtotal, this.discount, this.tax, this.total);
}

/// Deterministic bill arithmetic. The LLM never touches these numbers.
class BillCalc {
  /// [discountMode] 'amount' (paise) or 'percent' (basis points: 10% = 1000).
  /// [taxBp] is the tax rate in basis points (5% = 500).
  static BillTotals compute(List<CalcLine> lines,
      {String discountMode = 'amount', int discountValue = 0, int taxBp = 0}) {
    var subtotal = 0;
    for (final l in lines) {
      l.lineTotal = Qty.lineTotal(l.unitPrice, l.qtyMilli);
      subtotal += l.lineTotal;
    }
    var discount = discountMode == 'percent'
        ? (subtotal * discountValue + 5000) ~/ 10000
        : discountValue;
    discount = clampInt(discount, 0, subtotal);
    final taxable = subtotal - discount;
    final tax = (taxable * taxBp + 5000) ~/ 10000;
    final discAlloc = allocate(discount, lines.map((e) => e.lineTotal).toList());
    final taxBase = <int>[];
    for (var i = 0; i < lines.length; i++) {
      lines[i].discount = discAlloc[i];
      taxBase.add(lines[i].lineTotal - discAlloc[i]);
    }
    final taxAlloc = allocate(tax, taxBase);
    for (var i = 0; i < lines.length; i++) {
      lines[i].tax = taxAlloc[i];
    }
    return BillTotals(lines, subtotal, discount, tax, taxable + tax);
  }
}

class BillingService {
  final Database db;
  BillingService(this.db);

  static const paymentMethods = ['cash', 'upi', 'card', 'credit', 'other'];

  /// Builds totals from the latest confirmed retail prices (read-only preview).
  Future<BillTotals> preview(Session s, BillDraft d) async {
    s.need(Perm.createBill);
    final taxBp = await SettingsService.readInt(db, 'tax_percent_bp');
    final lines = await _calcLines(db, d);
    return BillCalc.compute(lines,
        discountMode: d.discountMode, discountValue: d.discountValue, taxBp: taxBp);
  }

  static Future<List<CalcLine>> _calcLines(DatabaseExecutor ex, BillDraft d,
      {bool strict = false}) async {
    final out = <CalcLine>[];
    for (final l in d.lines) {
      final r = await ex.query('products',
          columns: ['name', 'unit', 'retail_price', 'active', 'deleted'],
          where: 'id = ?',
          whereArgs: [l.productId]);
      if (r.isEmpty || (r.first['deleted'] as int) == 1) {
        if (strict) throw AppError('not_found', '${l.name} is no longer available');
        continue;
      }
      if (strict && (r.first['active'] as int) == 0) {
        throw AppError('inactive', '${r.first['name']} is inactive');
      }
      final price = r.first['retail_price'] as int?;
      if (price == null) {
        if (strict) {
          throw AppError('no_price', 'No retail price saved for ${r.first['name']}');
        }
        out.add(CalcLine(l.productId, r.first['name'] as String, l.qtyMilli,
            r.first['unit'] as String, 0));
        continue;
      }
      out.add(CalcLine(l.productId, r.first['name'] as String, l.qtyMilli,
          r.first['unit'] as String, price));
    }
    return out;
  }

  /// Saves a bill atomically: price snapshot, stock deduction, audit entry.
  /// Calling twice with the same draft (same idempotency key) returns the
  /// original bill instead of creating a duplicate.
  Future<BillRec> finalize(Session s, BillDraft d) async {
    s.need(Perm.createBill);
    if (d.lines.isEmpty) throw AppError('empty', 'The bill is empty');
    if (!paymentMethods.contains(d.paymentMethod)) {
      throw AppError('invalid', 'Unknown payment method');
    }
    return db.transaction<BillRec>((txn) async {
      final existing = await txn.query('bills',
          where: 'idem_key = ?', whereArgs: [d.idemKey], limit: 1);
      if (existing.isNotEmpty) return BillRec.fromMap(existing.first);

      final taxBp = await SettingsService.readInt(txn, 'tax_percent_bp');
      final lines = await _calcLines(txn, d, strict: true);
      for (final l in lines) {
        if (l.qtyMilli <= 0) throw AppError('invalid', 'Invalid quantity for ${l.name}');
      }
      final t = BillCalc.compute(lines,
          discountMode: d.discountMode, discountValue: d.discountValue, taxBp: taxBp);

      final now = AppClock.now();
      final day = '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final cnt = await txn.rawQuery(
          'SELECT COUNT(*) c FROM bills WHERE bill_no LIKE ?', ['B-$day-%']);
      final seq = ((cnt.first['c'] as int?) ?? 0) + 1;
      final billNo = 'B-$day-${seq.toString().padLeft(4, '0')}';

      final billId = await txn.insert('bills', {
        'bill_no': billNo,
        'created_at': nowIso(),
        'subtotal': t.subtotal,
        'discount': t.discount,
        'tax': t.tax,
        'total': t.total,
        'payment_method': d.paymentMethod,
        'customer_name': d.customer.trim(),
        'created_by': s.name,
        'idem_key': d.idemKey,
      });
      for (final l in t.lines) {
        await txn.insert('bill_items', {
          'bill_id': billId,
          'product_id': l.productId,
          'product_name': l.name,
          'qty_milli': l.qtyMilli,
          'unit': l.unit,
          'unit_price': l.unitPrice,
          'line_total': l.lineTotal,
          'discount': l.discount,
          'tax': l.tax,
          'final_amount': l.finalAmount,
        });
        await InventoryService.applyDelta(txn,
            productId: l.productId,
            deltaMilli: -l.qtyMilli,
            reason: 'sale',
            ref: billNo,
            user: s.name);
      }
      await AuditService.log(txn, s.name, 'bill_created', '$billNo ${Money.plain(t.total)}');
      final saved = await txn.query('bills', where: 'id = ?', whereArgs: [billId]);
      return BillRec.fromMap(saved.first);
    });
  }

  Future<BillRec?> getBill(Session s, int id) async {
    s.needAny([Perm.createBill, Perm.viewReports]);
    final r = await db.query('bills', where: 'id = ?', whereArgs: [id], limit: 1);
    if (r.isEmpty) return null;
    return BillRec.fromMap(r.first);
  }

  Future<List<BillItemRec>> items(Session s, int billId) async {
    s.needAny([Perm.createBill, Perm.viewReports]);
    final r = await db.query('bill_items',
        where: 'bill_id = ?', whereArgs: [billId], orderBy: 'id');
    return r.map(BillItemRec.fromMap).toList();
  }

  /// Search by bill number, date (YYYY-MM-DD prefix), product or payment method.
  Future<List<BillRec>> list(Session s,
      {DateTime? from,
      DateTime? toExclusive,
      String query = '',
      String payment = '',
      int limit = 300}) async {
    s.needAny([Perm.createBill, Perm.viewReports]);
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('b.created_at >= ?');
      args.add(_d(from));
    }
    if (toExclusive != null) {
      where.add('b.created_at < ?');
      args.add(_d(toExclusive));
    }
    if (payment.isNotEmpty) {
      where.add('b.payment_method = ?');
      args.add(payment);
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      where.add('(b.bill_no LIKE ? OR b.created_at LIKE ? OR b.customer_name LIKE ? OR b.payment_method LIKE ? '
          'OR EXISTS (SELECT 1 FROM bill_items bi WHERE bi.bill_id = b.id AND bi.product_name LIKE ?))');
      final like = '%$q%';
      args.addAll([like, '$q%', like, like, like]);
    }
    final r = await db.rawQuery(
        'SELECT b.* FROM bills b ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY b.id DESC LIMIT $limit',
        args);
    return r.map(BillRec.fromMap).toList();
  }

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T'
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}
