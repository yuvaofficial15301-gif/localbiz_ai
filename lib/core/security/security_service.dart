import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key storage (Android Keystore backed) and PIN hashing.
class SecurityService {
  static const int pinIterations = 10000;
  static const _dbKeyName = 'localbiz_db_key_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Returns the SQLCipher passphrase, generating it on first run.
  /// It lives only in Android Keystore-backed secure storage, never in source.
  Future<String> getOrCreateDbKey() async {
    var key = await _storage.read(key: _dbKeyName);
    if (key == null || key.length < 32) {
      key = randomHex(32);
      await _storage.write(key: _dbKeyName, value: key);
    }
    return key;
  }

  static String randomHex(int bytes) {
    final r = Random.secure();
    final b = List<int>.generate(bytes, (_) => r.nextInt(256));
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  }

  String newSalt() => randomHex(16);

  /// Format "iterations:hexhash".
  String hashPin(String pin, String saltHex, {int iterations = pinIterations}) {
    final dk = pbkdf2(utf8.encode(pin), hexToBytes(saltHex), iterations, 32);
    return '$iterations:${bytesToHex(dk)}';
  }

  bool verifyPin(String pin, String saltHex, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final iters = int.tryParse(parts[0]);
    if (iters == null || iters < 1) return false;
    final computed = hashPin(pin, saltHex, iterations: iters);
    return constantTimeEquals(computed, stored);
  }

  static bool validPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Uint8List hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String bytesToHex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

/// PBKDF2-HMAC-SHA256.
Uint8List pbkdf2(List<int> password, List<int> salt, int iterations, int dkLen) {
  final hmac = Hmac(sha256, password);
  final blocks = (dkLen + 31) ~/ 32;
  final out = BytesBuilder();
  for (var i = 1; i <= blocks; i++) {
    final first = <int>[
      ...salt,
      (i >> 24) & 255,
      (i >> 16) & 255,
      (i >> 8) & 255,
      i & 255,
    ];
    var u = hmac.convert(first).bytes;
    final t = List<int>.from(u);
    for (var j = 1; j < iterations; j++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    out.add(t);
  }
  return Uint8List.fromList(out.toBytes().sublist(0, dkLen));
}
