import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:localbiz_ai/core/security/security_service.dart';
import 'package:localbiz_ai/core/utils/csv.dart';
import 'package:localbiz_ai/core/utils/money.dart';
import 'package:localbiz_ai/features/billing/billing_service.dart';

void main() {
  group('Money', () {
    test('formats with Indian grouping', () {
      Money.symbol = '₹';
      expect(Money.format(6000), '₹60');
      expect(Money.format(6550), '₹65.50');
      expect(Money.format(123456700), '₹12,34,567');
      expect(Money.format(-500), '-₹5');
    });
    test('parses safely', () {
      expect(Money.parse('65'), 6500);
      expect(Money.parse('65.5'), 6550);
      expect(Money.parse('₹1,200.25'), 120025);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('-5'), isNull);
      expect(Money.parse('1.234'), isNull);
    });
  });

  group('Qty and units', () {
    test('quantity formatting and parsing', () {
      expect(Qty.format(500), '0.5');
      expect(Qty.format(2500), '2.5');
      expect(Qty.format(5000), '5');
      expect(Qty.parse('1.25'), 1250);
      expect(Qty.parse('x'), isNull);
    });
    test('line total is exact integer arithmetic', () {
      expect(Qty.lineTotal(6000, 5000), 30000);
      expect(Qty.lineTotal(6000, 500), 3000);
      expect(Qty.lineTotal(333, 3000), 999);
    });
    test('unit conversion', () {
      expect(Units.convertMilli(500000, 'g', 'kg'), 500);
      expect(Units.convertMilli(2000, 'dozen', 'piece'), 24000);
      expect(Units.compatible('kg', 'l'), isFalse);
      expect(() => Units.convertMilli(1000, 'kg', 'l'), throwsArgumentError);
      expect(Units.normalize('Kilogram'), 'kg');
    });
  });

  group('Bill calculation', () {
    test('plain total: 5kg rice + 2kg sugar = 400', () {
      final lines = [
        CalcLine(1, 'Rice', 5000, 'kg', 6000),
        CalcLine(2, 'Sugar', 2000, 'kg', 5000),
      ];
      final t = BillCalc.compute(lines);
      expect(t.subtotal, 40000);
      expect(t.total, 40000);
    });
    test('discount and tax are allocated exactly', () {
      final lines = [
        CalcLine(1, 'Rice', 5000, 'kg', 6000),
        CalcLine(2, 'Sugar', 2000, 'kg', 5000),
      ];
      final t = BillCalc.compute(lines,
          discountMode: 'percent', discountValue: 1000, taxBp: 500);
      expect(t.discount, 4000);
      expect(t.tax, 1800);
      expect(t.total, 37800);
      expect(lines.fold<int>(0, (a, l) => a + l.discount), t.discount);
      expect(lines.fold<int>(0, (a, l) => a + l.tax), t.tax);
      expect(lines.fold<int>(0, (a, l) => a + l.finalAmount), t.total);
    });
    test('discount can never exceed subtotal', () {
      final t = BillCalc.compute([CalcLine(1, 'A', 1000, 'kg', 1000)],
          discountValue: 999999);
      expect(t.discount, 1000);
      expect(t.total, 0);
    });
    test('allocate adds up', () {
      final a = allocate(100, [1, 1, 1]);
      expect(a.fold<int>(0, (x, y) => x + y), 100);
    });
  });

  group('Security primitives', () {
    String hex(List<int> b) => SecurityService.bytesToHex(b);
    test('PBKDF2-HMAC-SHA256 known vectors', () {
      expect(hex(pbkdf2(utf8.encode('password'), utf8.encode('salt'), 1, 32)),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      expect(hex(pbkdf2(utf8.encode('password'), utf8.encode('salt'), 2, 32)),
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
    });
    test('PIN hashing verifies and never stores plain text', () {
      final s = SecurityService();
      final salt = s.newSalt();
      final h = s.hashPin('1234', salt, iterations: 50);
      expect(h.contains('1234'), isFalse);
      expect(s.verifyPin('1234', salt, h), isTrue);
      expect(s.verifyPin('1235', salt, h), isFalse);
      expect(s.hashPin('1234', s.newSalt(), iterations: 50) == h, isFalse);
    });
    test('PIN validation', () {
      expect(SecurityService.validPin('1234'), isTrue);
      expect(SecurityService.validPin('123'), isFalse);
      expect(SecurityService.validPin('1234567'), isFalse);
      expect(SecurityService.validPin('12a4'), isFalse);
    });
  });

  group('CSV', () {
    test('round trip with commas, quotes and newlines', () {
      final rows = [
        ['name', 'note'],
        ['Rice, basmati', 'He said "good"'],
        ['Line', 'a\nb'],
      ];
      final parsed = Csv.parse(Csv.encode(rows));
      expect(parsed, rows);
    });
  });
}
