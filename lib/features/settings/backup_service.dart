import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/security/security_service.dart';
import '../../core/services/audit_service.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';

class BackupInfo {
  final String path;
  final int bytes;
  final String createdAt;
  final Map<String, int> counts;
  const BackupInfo(this.path, this.bytes, this.createdAt, this.counts);
}

/// Encrypted, passphrase-protected backups (AES-256-GCM, PBKDF2 key).
///
/// File layout: "LBK1" | salt(16) | iv(12) | ciphertext+tag.
class BackupService {
  static const _magic = [0x4C, 0x42, 0x4B, 0x31]; // "LBK1"
  static const int kdfIterations = 20000;
  final Database db;
  BackupService(this.db);

  Future<Directory> backupDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'backups'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Serialises every table into a JSON document.
  Future<Map<String, Object?>> snapshot() async {
    final tables = <String, Object?>{};
    final counts = <String, int>{};
    for (final t in AppDatabase.tables) {
      final rows = await db.query(t);
      tables[t] = rows;
      counts[t] = rows.length;
    }
    final body = jsonEncode(tables);
    return {
      'app': 'localbiz_ai',
      'schema': AppDatabase.schemaVersion,
      'created': nowIso(),
      'counts': counts,
      'sha256': sha256.convert(utf8.encode(body)).toString(),
      'tables': tables,
    };
  }

  static Uint8List encryptBytes(Uint8List plain, String passphrase) {
    final salt = SecurityService.hexToBytes(SecurityService.randomHex(16));
    final iv = SecurityService.hexToBytes(SecurityService.randomHex(12));
    final key = pbkdf2(utf8.encode(passphrase), salt, kdfIterations, 32);
    final encrypter =
        enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
    final cipher = encrypter.encryptBytes(plain, iv: enc.IV(iv));
    final out = BytesBuilder()
      ..add(_magic)
      ..add(salt)
      ..add(iv)
      ..add(cipher.bytes);
    return out.toBytes();
  }

  static Uint8List decryptBytes(Uint8List data, String passphrase) {
    if (data.length < 4 + 16 + 12 + 16) {
      throw AppError('backup_invalid', 'This is not a LocalBiz backup file');
    }
    for (var i = 0; i < 4; i++) {
      if (data[i] != _magic[i]) {
        throw AppError('backup_invalid', 'This is not a LocalBiz backup file');
      }
    }
    final salt = data.sublist(4, 20);
    final iv = data.sublist(20, 32);
    final cipher = data.sublist(32);
    final key = pbkdf2(utf8.encode(passphrase), salt, kdfIterations, 32);
    final encrypter =
        enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
    try {
      final plain = encrypter.decryptBytes(enc.Encrypted(cipher), iv: enc.IV(iv));
      return Uint8List.fromList(plain);
    } catch (_) {
      throw AppError('backup_wrong_pass',
          'Wrong passphrase, or the backup file is damaged');
    }
  }

  /// Validates a decrypted snapshot (structure + checksum).
  static Map<String, Object?> parseSnapshot(Uint8List plain) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(plain));
    } catch (_) {
      throw AppError('backup_invalid', 'Backup content is unreadable');
    }
    if (decoded is! Map<String, Object?> || decoded['app'] != 'localbiz_ai') {
      throw AppError('backup_invalid', 'Backup content is not from LocalBiz AI');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, Object?>) {
      throw AppError('backup_invalid', 'Backup has no data');
    }
    final check = sha256.convert(utf8.encode(jsonEncode(tables))).toString();
    if (check != decoded['sha256']) {
      throw AppError('backup_corrupt', 'Backup checksum mismatch (file is damaged)');
    }
    if ((decoded['schema'] as int? ?? 0) > AppDatabase.schemaVersion) {
      throw AppError('backup_newer', 'Backup is from a newer app version');
    }
    return decoded;
  }

  Future<BackupInfo> createBackup(Session s, String passphrase) async {
    s.need(Perm.backup);
    if (passphrase.length < 6) {
      throw AppError('invalid', 'Backup passphrase must be at least 6 characters');
    }
    final snap = await snapshot();
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(snap)));
    final encrypted = encryptBytes(plain, passphrase);
    final dir = await backupDir();
    final now = AppClock.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'localbiz_backup_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.lbk';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(encrypted, flush: true);
    // Verify what we just wrote can be read back and decrypted.
    final back = parseSnapshot(decryptBytes(await file.readAsBytes(), passphrase));
    final counts = (back['counts'] as Map).map((k, v) => MapEntry('$k', v as int));
    await db.insert('app_settings', {'key': 'last_backup', 'value': nowIso()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await AuditService.log(db, s.name, 'backup_created', name);
    return BackupInfo(file.path, await file.length(), snap['created'] as String, counts);
  }

  Future<BackupInfo> verify(String path, String passphrase) async {
    final f = File(path);
    final snap = parseSnapshot(decryptBytes(await f.readAsBytes(), passphrase));
    final counts = (snap['counts'] as Map).map((k, v) => MapEntry('$k', v as int));
    return BackupInfo(path, await f.length(), snap['created'] as String, counts);
  }

  Future<List<FileSystemEntity>> listBackups() async {
    final d = await backupDir();
    final l = d.listSync().where((e) => e.path.endsWith('.lbk')).toList();
    l.sort((a, b) => b.path.compareTo(a.path));
    return l;
  }

  /// Restores a backup, replacing ALL current data. A safety backup of the
  /// current data is written first (same passphrase).
  Future<void> restore(Session s, String path, String passphrase) async {
    s.need(Perm.backup);
    final snap = parseSnapshot(decryptBytes(await File(path).readAsBytes(), passphrase));
    await createBackup(s, passphrase); // safety copy before destructive step
    await restoreSnapshot(snap, s.name);
  }

  Future<void> restoreSnapshot(Map<String, Object?> snap, String actor) async {
    final tables = snap['tables'] as Map<String, Object?>;
    await db.transaction((txn) async {
      for (final g in AppDatabase.guardDrop) {
        await txn.execute(g);
      }
      for (final t in AppDatabase.tables.reversed) {
        await txn.delete(t);
      }
      for (final t in AppDatabase.tables) {
        final rows = tables[t];
        if (rows is List) {
          for (final row in rows) {
            await txn.insert(t, Map<String, Object?>.from(row as Map));
          }
        }
      }
      for (final g in AppDatabase.guardSql) {
        await txn.execute(g);
      }
      await AuditService.log(txn, actor, 'backup_restored', '');
    });
  }
}
