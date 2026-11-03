import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/security/security_service.dart';
import '../../core/services/audit_service.dart';
import '../../core/utils/money.dart';
import '../models/models.dart';

class UserRepository {
  final Database db;
  final SecurityService security;
  UserRepository(this.db, this.security);

  Future<List<UserRec>> listActive() async {
    final r = await db.query('users',
        where: 'active = 1', orderBy: "CASE role WHEN 'owner' THEN 0 WHEN 'manager' THEN 1 ELSE 2 END, name");
    return r.map(UserRec.fromMap).toList();
  }

  Future<List<UserRec>> listAll(Session s) async {
    s.need(Perm.manageUsers);
    final r = await db.query('users', orderBy: 'id');
    return r.map(UserRec.fromMap).toList();
  }

  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) c FROM users');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<Set<String>> permissionsFor(String role) async {
    final r = await db.query('permissions',
        columns: ['permission'],
        where: 'role = ? AND allowed = 1',
        whereArgs: [role]);
    final set = r.map((e) => e['permission'] as String).toSet();
    if (role != 'owner') set.removeAll(Perm.ownerOnly);
    return set;
  }

  Future<Session?> sessionFor(int userId) async {
    final r = await db.query('users',
        where: 'id = ? AND active = 1', whereArgs: [userId], limit: 1);
    if (r.isEmpty) return null;
    final role = r.first['role'] as String;
    return Session(userId, r.first['name'] as String, role,
        await permissionsFor(role));
  }

  Future<Session?> ownerSession() async {
    final r = await db.query('users',
        where: "role = 'owner' AND active = 1", limit: 1);
    if (r.isEmpty) return null;
    return sessionFor(r.first['id'] as int);
  }

  /// Verifies a PIN for a specific user without logging anything in.
  Future<bool> verifyPin(int userId, String pin) async {
    final r = await db.query('users',
        where: 'id = ? AND active = 1', whereArgs: [userId], limit: 1);
    if (r.isEmpty) return false;
    return security.verifyPin(
        pin, r.first['pin_salt'] as String, r.first['pin_hash'] as String);
  }

  Future<void> create(Session s, String name, String role, String pin) async {
    s.need(Perm.manageUsers);
    if (role != 'manager' && role != 'employee') {
      throw AppError('invalid', 'Role must be manager or employee');
    }
    if (name.trim().isEmpty) throw AppError('invalid', 'Name is required');
    if (!SecurityService.validPin(pin)) {
      throw AppError('invalid', 'PIN must be 4 to 6 digits');
    }
    final salt = security.newSalt();
    final hash = security.hashPin(pin, salt);
    await db.transaction((txn) async {
      await txn.insert('users', {
        'name': name.trim(),
        'role': role,
        'pin_hash': hash,
        'pin_salt': salt,
        'active': 1,
        'created_at': nowIso(),
      });
      await AuditService.log(txn, s.name, 'user_created', '${name.trim()} ($role)');
    });
  }

  Future<void> changePin(Session s, int userId, String oldPin, String newPin) async {
    if (userId != s.userId && !s.can(Perm.manageUsers)) {
      throw PermissionDenied(Perm.manageUsers);
    }
    if (!SecurityService.validPin(newPin)) {
      throw AppError('invalid', 'PIN must be 4 to 6 digits');
    }
    if (userId == s.userId && !await verifyPin(userId, oldPin)) {
      throw AppError('bad_pin', 'Current PIN is incorrect');
    }
    final salt = security.newSalt();
    final hash = security.hashPin(newPin, salt);
    await db.transaction((txn) async {
      await txn.update('users', {'pin_hash': hash, 'pin_salt': salt},
          where: 'id = ?', whereArgs: [userId]);
      await AuditService.log(txn, s.name, 'pin_changed', 'user $userId');
    });
  }

  Future<void> setActive(Session s, int userId, bool active) async {
    s.need(Perm.manageUsers);
    final r = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (r.isEmpty) throw AppError('not_found', 'User not found');
    if (r.first['role'] == 'owner') {
      throw AppError('invalid', 'The owner account cannot be disabled');
    }
    await db.transaction((txn) async {
      await txn.update('users', {'active': active ? 1 : 0},
          where: 'id = ?', whereArgs: [userId]);
      await AuditService.log(
          txn, s.name, active ? 'user_enabled' : 'user_disabled', 'user $userId');
    });
  }

  Future<Map<String, bool>> rolePermissions(Session s, String role) async {
    s.need(Perm.manageUsers);
    final r = await db.query('permissions', where: 'role = ?', whereArgs: [role]);
    return {for (final e in r) e['permission'] as String: (e['allowed'] as int) == 1};
  }

  Future<void> setRolePermission(
      Session s, String role, String permission, bool allowed) async {
    s.need(Perm.manageUsers);
    if (role == 'owner') {
      throw AppError('invalid', 'Owner permissions cannot be changed');
    }
    if (Perm.ownerOnly.contains(permission)) {
      throw AppError('invalid', 'This permission is reserved for the owner');
    }
    await db.transaction((txn) async {
      await txn.update('permissions', {'allowed': allowed ? 1 : 0},
          where: 'role = ? AND permission = ?', whereArgs: [role, permission]);
      await AuditService.log(
          txn, s.name, 'permission_changed', '$role.$permission=$allowed');
    });
  }
}
