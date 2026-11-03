import 'package:sqflite_sqlcipher/sqflite.dart';

/// Key/value app settings stored in the encrypted database.
class SettingsService {
  final Database db;
  SettingsService(this.db);

  static Future<String?> read(DatabaseExecutor ex, String key) async {
    final r = await ex.query('app_settings',
        where: 'key = ?', whereArgs: [key], limit: 1);
    if (r.isEmpty) return null;
    return r.first['value'] as String?;
  }

  static Future<bool> readBool(DatabaseExecutor ex, String key,
      {bool def = false}) async {
    final v = await read(ex, key);
    if (v == null) return def;
    return v == '1' || v == 'true';
  }

  static Future<int> readInt(DatabaseExecutor ex, String key,
      {int def = 0}) async {
    final v = await read(ex, key);
    return int.tryParse(v ?? '') ?? def;
  }

  Future<String?> get(String key) => read(db, key);
  Future<bool> getBool(String key, {bool def = false}) =>
      readBool(db, key, def: def);
  Future<int> getInt(String key, {int def = 0}) => readInt(db, key, def: def);

  Future<void> set(String key, String value) async {
    await db.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setBool(String key, bool v) => set(key, v ? '1' : '0');
  Future<void> setInt(String key, int v) => set(key, '$v');
}
