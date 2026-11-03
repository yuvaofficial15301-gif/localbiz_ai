import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:localbiz_ai/features/settings/backup_service.dart';
import 'package:localbiz_ai/shared/models/models.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Fixture f;
  setUp(() async {
    f = await Fixture.create();
    await f.seedBasics();
    final rice = (await f.products.list(f.owner, query: 'Rice')).single;
    await f.billing.finalize(f.owner, BillDraft.empty().addLine(BillLine(rice.id, 'Rice', 2000, 'kg')));
  });
  tearDown(() async => f.close());

  test('encrypt / decrypt round trip', () {
    final plain = Uint8List.fromList(utf8.encode('{"hello":"world"}'));
    final enc = BackupService.encryptBytes(plain, 'secret123');
    expect(enc.length, greaterThan(plain.length));
    expect(utf8.decode(enc.sublist(0, 4)), 'LBK1');
    expect(BackupService.decryptBytes(enc, 'secret123'), plain);
  });

  test('wrong passphrase and damaged files are rejected', () {
    final enc = BackupService.encryptBytes(Uint8List.fromList(utf8.encode('data data data')), 'secret123');
    expect(() => BackupService.decryptBytes(enc, 'nope-nope'), throwsA(isA<AppError>()));
    final damaged = Uint8List.fromList(enc)..[enc.length - 3] ^= 0xFF;
    expect(() => BackupService.decryptBytes(damaged, 'secret123'), throwsA(isA<AppError>()));
    expect(() => BackupService.decryptBytes(Uint8List(10), 'x'), throwsA(isA<AppError>()));
  });

  test('snapshot verifies and detects tampering', () async {
    final snap = await f.backup.snapshot();
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(snap)));
    final ok = BackupService.parseSnapshot(bytes);
    expect((ok['counts'] as Map)['products'], 2);
    final tampered = jsonDecode(jsonEncode(snap)) as Map<String, dynamic>;
    ((tampered['tables'] as Map)['products'] as List).removeLast();
    expect(() => BackupService.parseSnapshot(Uint8List.fromList(utf8.encode(jsonEncode(tampered)))),
        throwsA(isA<AppError>()));
  });

  test('restore brings back deleted data, including price history and users', () async {
    final snap = await f.backup.snapshot();
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(snap)));
    final encrypted = BackupService.encryptBytes(plain, 'secret123');

    // wreck the data
    await f.db.delete('bill_items');
    await f.db.delete('bills');
    await f.db.update('products', {'deleted': 1});
    expect(await f.products.list(f.owner), isEmpty);

    final restored = BackupService.parseSnapshot(BackupService.decryptBytes(encrypted, 'secret123'));
    await f.backup.restoreSnapshot(restored, 'Ravi');

    expect((await f.products.list(f.owner)).length, 2);
    expect((await f.db.query('bills')).length, 1);
    expect((await f.db.query('bill_items')).length, 1);
    expect((await f.pricing.history(f.owner)).isNotEmpty, isTrue);
    expect(await f.users.verifyPin(f.owner.userId, '1234'), isTrue);
    // price history guard is back in place after restore
    expect(() => f.db.delete('price_history'), throwsA(anything));
  });
}
