import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/csv.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';

class ReportService {
  final Database db;
  ReportService(this.db);

  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<SalesSummary> summary(Session s, DateTime from, DateTime toExclusive) async {
    s.need(Perm.viewReports);
    return _summary(from, toExclusive);
  }

  Future<SalesSummary> _summary(DateTime from, DateTime toExclusive) async {
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(total),0) t, COUNT(*) c FROM bills WHERE created_at >= ? AND created_at < ?',
        [iso(from), iso(toExclusive)]);
    return SalesSummary((r.first['t'] as int?) ?? 0, (r.first['c'] as int?) ?? 0);
  }

  Future<SalesSummary> today(Session s) {
    final d = dayStart(AppClock.now());
    return summary(s, d, d.add(const Duration(days: 1)));
  }

  Future<SalesSummary> thisWeek(Session s) {
    final t = dayStart(AppClock.now());
    final start = t.subtract(Duration(days: t.weekday - 1)); // Monday
    return summary(s, start, t.add(const Duration(days: 1)));
  }

  Future<SalesSummary> thisMonth(Session s) {
    final t = dayStart(AppClock.now());
    return summary(s, DateTime(t.year, t.month, 1), t.add(const Duration(days: 1)));
  }

  Future<List<DailySales>> lastDays(Session s, int days) async {
    s.need(Perm.viewReports);
    final t = dayStart(AppClock.now());
    final out = <DailySales>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(t.year, t.month, t.day - i);
      final sum = await _summary(d, DateTime(d.year, d.month, d.day + 1));
      out.add(DailySales(d, sum.total));
    }
    return out;
  }

  Future<List<BestSeller>> bestSellers(Session s, DateTime from, DateTime toExclusive,
      {int limit = 10}) async {
    s.need(Perm.viewReports);
    final r = await db.rawQuery(
        'SELECT bi.product_name n, bi.unit u, SUM(bi.qty_milli) q, SUM(bi.final_amount) a '
        'FROM bill_items bi JOIN bills b ON b.id = bi.bill_id '
        'WHERE b.created_at >= ? AND b.created_at < ? '
        'GROUP BY bi.product_name, bi.unit ORDER BY a DESC LIMIT $limit',
        [iso(from), iso(toExclusive)]);
    return r
        .map((e) => BestSeller(e['n'] as String, (e['q'] as int?) ?? 0,
            e['u'] as String, (e['a'] as int?) ?? 0))
        .toList();
  }

  /// One CSV row per bill line (price snapshot as saved on the bill).
  Future<String> exportTransactionsCsv(Session s) async {
    s.need(Perm.viewReports);
    final r = await db.rawQuery(
        'SELECT b.bill_no, b.created_at, b.payment_method, b.customer_name, '
        'bi.product_name, bi.qty_milli, bi.unit, bi.unit_price, bi.line_total, '
        'bi.discount, bi.tax, bi.final_amount, b.total '
        'FROM bills b JOIN bill_items bi ON bi.bill_id = b.id ORDER BY b.id, bi.id');
    final rows = <List<String>>[
      ['bill_no', 'date', 'payment', 'customer', 'product', 'qty', 'unit',
        'unit_price', 'line_total', 'discount', 'tax', 'final_amount', 'bill_total']
    ];
    for (final e in r) {
      rows.add([
        e['bill_no'] as String,
        e['created_at'] as String,
        e['payment_method'] as String,
        (e['customer_name'] as String?) ?? '',
        e['product_name'] as String,
        Qty.format(e['qty_milli'] as int),
        e['unit'] as String,
        Money.plain(e['unit_price'] as int),
        Money.plain(e['line_total'] as int),
        Money.plain(e['discount'] as int),
        Money.plain(e['tax'] as int),
        Money.plain(e['final_amount'] as int),
        Money.plain(e['total'] as int),
      ]);
    }
    return Csv.encode(rows);
  }
}
