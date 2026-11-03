import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../shared/models/models.dart';
import '../utils/money.dart';

class AuditService {
  final Database db;
  AuditService(this.db);

  static Future<void> log(DatabaseExecutor ex, String user, String action,
      [String detail = '']) async {
    await ex.insert('audit_logs', {
      'at': nowIso(),
      'user_name': user,
      'action': action,
      'detail': detail,
    });
  }

  Future<List<AuditRec>> recent(Session s, {int limit = 30}) async {
    s.need('security_settings');
    final r = await db.query('audit_logs', orderBy: 'id DESC', limit: limit);
    return r.map(AuditRec.fromMap).toList();
  }

  /// Non-sensitive activity feed for the home screen.
  Future<List<AuditRec>> activityFeed({int limit = 8}) async {
    final r = await db.query('audit_logs',
        where: "action IN ('bill_created','price_changed','product_created','stock_in','purchase_created','stock_adjusted')",
        orderBy: 'id DESC',
        limit: limit);
    return r.map(AuditRec.fromMap).toList();
  }
}
