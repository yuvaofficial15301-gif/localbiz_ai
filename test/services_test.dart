import 'package:flutter_test/flutter_test.dart';
import 'package:localbiz_ai/core/database/app_database.dart';
import 'package:localbiz_ai/features/purchases/purchase_service.dart';
import 'package:localbiz_ai/shared/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show ConflictAlgorithm;

import 'helpers.dart';

void main() {
  late Fixture f;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    f = await Fixture.create();
  });
  tearDown(() async => f.close());

  group('Shop registration', () {
    test('saves only what was entered', () async {
      final p = (await f.shop.profile())!;
      expect(p.ownerName, 'Ravi');
      expect(p.shopName, 'Ravi Stores');
      expect(p.phone, '');
      expect(p.currency, '₹');
    });
    test('requires names and a valid PIN; cannot register twice', () async {
      final g = await Fixture.create(register: false);
      expect(() => g.shop.register(ownerName: '', shopName: 'x', category: '', language: 'en', pin: '1234'), throwsA(isA<AppError>()));
      expect(() => g.shop.register(ownerName: 'a', shopName: 'x', category: '', language: 'en', pin: '12'), throwsA(isA<AppError>()));
      await g.shop.register(ownerName: 'a', shopName: 'x', category: '', language: 'en', pin: '1234');
      expect(() => g.shop.register(ownerName: 'b', shopName: 'y', category: '', language: 'en', pin: '1234'), throwsA(isA<AppError>()));
      await g.close();
    });
    test('owner can edit profile, employee cannot', () async {
      await f.shop.update(f.owner, shopName: 'New Name');
      expect((await f.shop.profile())!.shopName, 'New Name');
      final e = await f.employee();
      expect(() => f.shop.update(e, shopName: 'Hack'), throwsA(isA<PermissionDenied>()));
    });
  });

  group('Products', () {
    test('create, edit, soft delete', () async {
      final id = await f.addProduct('Rice', retail: 6000, wholesale: 4500, stock: 10000);
      var p = (await f.products.getById(f.owner, id))!;
      expect(p.name, 'Rice');
      expect(p.stockMilli, 10000);

      await f.products.update(
          f.owner,
          id,
          ProductInput(name: 'Basmati Rice', unit: 'kg', retail: 7000, wholesale: 4500));
      p = (await f.products.getById(f.owner, id))!;
      expect(p.name, 'Basmati Rice');
      expect(p.retail, 7000);

      await f.products.delete(f.owner, id);
      expect(await f.products.getById(f.owner, id), isNull);
      // history is kept
      final hist = await f.pricing.history(f.owner, productId: id);
      expect(hist.length, greaterThanOrEqualTo(3));
    });
    test('duplicate names and invalid input are rejected', () async {
      await f.addProduct('Rice', retail: 6000);
      expect(() => f.addProduct('rice', retail: 100), throwsA(isA<AppError>()));
      expect(() => f.addProduct('  '), throwsA(isA<AppError>()));
      expect(() => f.products.create(f.owner, ProductInput(name: 'X', unit: '')), throwsA(isA<AppError>()));
    });
    test('search, filter and sort', () async {
      await f.seedBasics();
      await f.addProduct('Oil', retail: 15000, stock: 1000, min: 2000);
      expect((await f.products.list(f.owner, query: 'sug')).single.name, 'Sugar');
      expect((await f.products.list(f.owner, filter: 'low')).single.name, 'Oil');
      final byPrice = await f.products.list(f.owner, sort: 'price');
      expect(byPrice.first.name, 'Oil');
    });
    test('CSV export and import', () async {
      await f.seedBasics();
      final csv = await f.products.exportCsv(f.owner);
      expect(csv.contains('Rice'), isTrue);
      final g = await Fixture.create();
      final res = await g.products.importCsv(g.owner, csv);
      expect(res.added, 2);
      expect(res.errors, isEmpty);
      final again = await g.products.importCsv(g.owner, csv);
      expect(again.skipped, 2);
      await g.close();
    });
  });

  group('Pricing', () {
    test('retail and wholesale are independent in ONE table', () async {
      final id = await f.addProduct('Rice', retail: 6000, wholesale: 4500);
      await f.pricing.setPrice(f.owner, id, 'retail', 6500);
      final p = (await f.products.getById(f.owner, id))!;
      expect(p.retail, 6500);
      expect(p.wholesale, 4500);
      await f.pricing.setPrice(f.owner, id, 'wholesale', 4800);
      final q = (await f.products.getById(f.owner, id))!;
      expect(q.retail, 6500);
      expect(q.wholesale, 4800);
      final tables = await AppDatabase.tableNames(f.db);
      expect(tables.where((t) => t.contains('product')).toList(), ['products']);
    });
    test('increase / decrease and bounds', () async {
      final id = await f.addProduct('Rice', retail: 6000);
      await f.pricing.adjust(f.owner, id, 'retail', 500);
      expect(await f.pricing.getRetail(id), 6500);
      await f.pricing.adjust(f.owner, id, 'retail', -1000);
      expect(await f.pricing.getRetail(id), 5500);
      expect(() => f.pricing.adjust(f.owner, id, 'retail', -999999), throwsA(isA<AppError>()));
      expect(() => f.pricing.adjust(f.owner, id, 'wholesale', 100), throwsA(isA<AppError>()));
    });
    test('price history is recorded and append-only', () async {
      final id = await f.addProduct('Rice', retail: 6000);
      await f.pricing.setPrice(f.owner, id, 'retail', 6500);
      await f.pricing.setPrice(f.owner, id, 'retail', 7000);
      final h = await f.pricing.history(f.owner, productId: id, type: 'retail');
      expect(h.length, 3); // initial + 2 changes
      expect(h.first.oldPrice, 6500);
      expect(h.first.newPrice, 7000);
      expect(() => f.db.delete('price_history'), throwsA(anything));
      expect(() => f.db.update('price_history', {'new_price': 1}), throwsA(anything));
    });
    test('unchanged price does not create history', () async {
      final id = await f.addProduct('Rice', retail: 6000);
      final c = await f.pricing.setPrice(f.owner, id, 'retail', 6000);
      expect(c.changed, isFalse);
      expect((await f.pricing.history(f.owner, productId: id)).length, 1);
    });
  });

  group('Wholesale authorisation (service layer)', () {
    test('employee and manager never see wholesale prices', () async {
      final id = await f.addProduct('Rice', retail: 6000, wholesale: 4500);
      final emp = await f.employee(role: 'employee', pin: '2222');
      final mgr = await f.employee(role: 'manager', pin: '3333');
      for (final s in [emp, mgr]) {
        expect((await f.products.getById(s, id))!.wholesale, isNull);
        expect((await f.products.list(s)).single.wholesale, isNull);
        expect(() => f.pricing.getWholesale(s, id), throwsA(isA<PermissionDenied>()));
        expect(() => f.pricing.setPrice(s, id, 'wholesale', 1), throwsA(isA<PermissionDenied>()));
        final csv = await f.products.exportCsv(s);
        expect(csv.contains('45'), isFalse);
        final hist = await f.pricing.history(s, productId: id);
        expect(hist.every((r) => r.type == 'retail'), isTrue);
      }
    });
    test('owner can read wholesale and it is audit-logged', () async {
      final id = await f.addProduct('Rice', retail: 6000, wholesale: 4500);
      expect(await f.pricing.getWholesale(f.owner, id), 4500);
      final log = await f.db.query('audit_logs', where: "action = 'wholesale_viewed'");
      expect(log, isNotEmpty);
    });
    test('editing a product as manager cannot alter wholesale', () async {
      final id = await f.addProduct('Rice', retail: 6000, wholesale: 4500);
      final mgr = await f.employee(role: 'manager', pin: '3333');
      await f.products.update(mgr, id, ProductInput(name: 'Rice', retail: 6200, wholesale: 1));
      expect(await f.pricing.getWholesale(f.owner, id), 4500);
      expect(await f.pricing.getRetail(id), 6200);
    });
  });

  group('Billing and old bills', () {
    test('bill saves snapshot, deducts stock, price change leaves old bill intact', () async {
      await f.seedBasics();
      final rice = (await f.products.list(f.owner, query: 'Rice')).single;
      var d = BillDraft.empty().addLine(BillLine(rice.id, 'Rice', 5000, 'kg'));
      final bill1 = await f.billing.finalize(f.owner, d);
      expect(bill1.total, 30000);
      expect((await f.products.getById(f.owner, rice.id))!.stockMilli, 15000);

      await f.pricing.setPrice(f.owner, rice.id, 'retail', 6500);

      final old = await f.billing.items(f.owner, bill1.id);
      expect(old.single.unitPrice, 6000); // unchanged
      expect((await f.billing.getBill(f.owner, bill1.id))!.total, 30000);

      d = BillDraft.empty().addLine(BillLine(rice.id, 'Rice', 1000, 'kg'));
      final bill2 = await f.billing.finalize(f.owner, d);
      expect(bill2.total, 6500); // latest confirmed retail price
      expect(bill2.billNo == bill1.billNo, isFalse);
    });
    test('same draft twice never creates duplicate bills or double deduction', () async {
      await f.seedBasics();
      final rice = (await f.products.list(f.owner, query: 'Rice')).single;
      final d = BillDraft.empty().addLine(BillLine(rice.id, 'Rice', 1000, 'kg'));
      final a = await f.billing.finalize(f.owner, d);
      final b = await f.billing.finalize(f.owner, d);
      expect(a.id, b.id);
      expect((await f.products.getById(f.owner, rice.id))!.stockMilli, 19000);
    });
    test('insufficient stock rolls everything back', () async {
      await f.seedBasics();
      final prods = await f.products.list(f.owner);
      final rice = prods.firstWhere((p) => p.name == 'Rice');
      final sugar = prods.firstWhere((p) => p.name == 'Sugar');
      final d = BillDraft.empty()
          .addLine(BillLine(rice.id, 'Rice', 1000, 'kg'))
          .addLine(BillLine(sugar.id, 'Sugar', 99000, 'kg'));
      expect(() => f.billing.finalize(f.owner, d), throwsA(isA<InsufficientStock>()));
      final bills = await f.db.query('bills');
      expect(bills, isEmpty);
      expect((await f.products.getById(f.owner, rice.id))!.stockMilli, 20000);
    });
    test('negative stock only when enabled', () async {
      await f.seedBasics();
      final sugar = (await f.products.list(f.owner, query: 'Sugar')).single;
      await f.db.insert('app_settings', {'key': 'allow_negative_stock', 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      final d = BillDraft.empty().addLine(BillLine(sugar.id, 'Sugar', 12000, 'kg'));
      await f.billing.finalize(f.owner, d);
      expect((await f.products.getById(f.owner, sugar.id))!.stockMilli, -2000);
    });
    test('missing retail price blocks billing', () async {
      final id = await f.addProduct('Mystery', stock: 1000);
      final d = BillDraft.empty().addLine(BillLine(id, 'Mystery', 1000, 'kg'));
      expect(() => f.billing.finalize(f.owner, d), throwsA(isA<AppError>()));
    });
    test('search bills by number, product and payment', () async {
      await f.seedBasics();
      final rice = (await f.products.list(f.owner, query: 'Rice')).single;
      final d = BillDraft.empty().addLine(BillLine(rice.id, 'Rice', 1000, 'kg')).copyWith(paymentMethod: 'upi');
      final b = await f.billing.finalize(f.owner, d);
      expect((await f.billing.list(f.owner, query: b.billNo)).length, 1);
      expect((await f.billing.list(f.owner, query: 'Rice')).length, 1);
      expect((await f.billing.list(f.owner, payment: 'upi')).length, 1);
      expect((await f.billing.list(f.owner, payment: 'cash')).length, 0);
    });
  });

  group('Inventory and purchases', () {
    test('stock in/out/adjust keep a movement history', () async {
      final id = await f.addProduct('Rice', retail: 6000, stock: 5000);
      await f.inventory.stockIn(f.owner, id, 2000, 'kg');
      await f.inventory.stockIn(f.owner, id, 500000, 'g'); // 500 g = 0.5 kg
      await f.inventory.stockOut(f.owner, id, 1000, 'kg');
      await f.inventory.setStock(f.owner, id, 3000);
      final m = await f.inventory.movements(f.owner, productId: id);
      expect(m.length, 5);
      expect(m.first.balanceMilli, 3000);
      expect(() => f.inventory.stockIn(f.owner, id, 1000, 'l'), throwsA(isA<AppError>()));
      expect(() => f.inventory.stockOut(f.owner, id, 99000, 'kg'), throwsA(isA<InsufficientStock>()));
    });
    test('purchase raises stock but never changes selling prices', () async {
      final id = await f.addProduct('Rice', retail: 6000, wholesale: 4500, stock: 1000);
      final pid = await f.purchases.create(f.owner,
          supplier: 'Sri Traders',
          date: '2026-11-01',
          paymentStatus: 'pending',
          invoiceRef: 'INV-7',
          lines: [PurchaseLineInput(id, 'Rice', 10000, 'kg', 4000)]);
      final list = await f.purchases.list(f.owner);
      expect(list.single.total, 40000);
      expect(list.single.status, 'pending');
      final items = await f.purchases.items(f.owner, pid);
      expect(items.single['unit_cost'], 4000);
      final p = (await f.products.getById(f.owner, id))!;
      expect(p.stockMilli, 11000);
      expect(p.retail, 6000);
      expect(p.wholesale, 4500);
      await f.purchases.markPaid(f.owner, pid);
      expect((await f.purchases.list(f.owner)).single.status, 'paid');
    });
    test('invalid purchases are rejected', () async {
      expect(() => f.purchases.create(f.owner, supplier: '', date: '2026-11-01', paymentStatus: 'paid', lines: []), throwsA(isA<AppError>()));
    });
  });

  group('Reports', () {
    test('sales summaries use real bills', () async {
      await f.seedBasics();
      final rice = (await f.products.list(f.owner, query: 'Rice')).single;
      expect((await f.reports.today(f.owner)).count, 0);
      await f.billing.finalize(f.owner, BillDraft.empty().addLine(BillLine(rice.id, 'Rice', 2000, 'kg')));
      final t = await f.reports.today(f.owner);
      expect(t.count, 1);
      expect(t.total, 12000);
      final best = await f.reports.bestSellers(f.owner, DateTime.now().subtract(const Duration(days: 1)), DateTime.now().add(const Duration(days: 1)));
      expect(best.single.name, 'Rice');
      expect((await f.reports.lastDays(f.owner, 7)).length, 7);
      final csv = await f.reports.exportTransactionsCsv(f.owner);
      expect(csv.contains('Rice'), isTrue);
    });
    test('reports require permission', () async {
      final emp = await f.employee();
      expect(() => f.reports.today(emp), throwsA(isA<PermissionDenied>()));
    });
  });

  group('Authentication and roles', () {
    test('PIN verification', () async {
      expect(await f.users.verifyPin(f.owner.userId, '1234'), isTrue);
      expect(await f.users.verifyPin(f.owner.userId, '0000'), isFalse);
      final row = (await f.db.query('users')).first;
      expect((row['pin_hash'] as String).contains('1234'), isFalse);
    });
    test('change PIN needs the old PIN', () async {
      expect(() => f.users.changePin(f.owner, f.owner.userId, '9999', '5678'), throwsA(isA<AppError>()));
      await f.users.changePin(f.owner, f.owner.userId, '1234', '5678');
      expect(await f.users.verifyPin(f.owner.userId, '5678'), isTrue);
      expect(await f.users.verifyPin(f.owner.userId, '1234'), isFalse);
    });
    test('default role permissions', () async {
      final emp = await f.employee();
      final mgr = await f.employee(role: 'manager', pin: '3333');
      expect(emp.can(Perm.createBill), isTrue);
      expect(emp.can(Perm.editProducts), isFalse);
      expect(mgr.can(Perm.editProducts), isTrue);
      expect(mgr.can(Perm.viewWholesale), isFalse);
      expect(f.owner.can(Perm.viewWholesale), isTrue);
      expect(() => f.products.create(emp, ProductInput(name: 'X')), throwsA(isA<PermissionDenied>()));
      expect(() => f.products.delete(mgr, 1), throwsA(isA<PermissionDenied>()));
    });
    test('owner can delegate normal permissions but never owner-only ones', () async {
      final mgr0 = await f.employee(role: 'manager', pin: '3333');
      expect(mgr0.can(Perm.deleteProducts), isFalse);
      await f.users.setRolePermission(f.owner, 'manager', Perm.deleteProducts, true);
      final mgr = (await f.users.sessionFor(mgr0.userId))!;
      expect(mgr.can(Perm.deleteProducts), isTrue);
      expect(() => f.users.setRolePermission(f.owner, 'manager', Perm.viewWholesale, true), throwsA(isA<AppError>()));
      expect(() => f.users.setRolePermission(mgr, 'employee', Perm.createBill, false), throwsA(isA<PermissionDenied>()));
    });
    test('disabled users cannot sign in', () async {
      final e = await f.employee();
      await f.users.setActive(f.owner, e.userId, false);
      expect(await f.users.verifyPin(e.userId, '2222'), isFalse);
      expect(await f.users.sessionFor(e.userId), isNull);
    });
  });

  group('Database migrations', () {
    test('upgrade keeps data and adds new structure', () async {
      await f.addProduct('Rice', retail: 6000);
      await AppDatabase.migrate(f.db, 1, 2, steps: {
        2: ['ALTER TABLE products ADD COLUMN shelf TEXT'],
      });
      final cols = await f.db.rawQuery('PRAGMA table_info(products)');
      expect(cols.any((c) => c['name'] == 'shelf'), isTrue);
      expect((await f.products.list(f.owner)).single.name, 'Rice');
    });
    test('schema contains every required table', () async {
      final t = await AppDatabase.tableNames(f.db);
      for (final n in AppDatabase.tables) {
        expect(t.contains(n), isTrue, reason: n);
      }
    });
    test('foreign keys are enforced', () async {
      expect(
          () => f.db.insert('bill_items', {
                'bill_id': 9999, 'product_name': 'x', 'qty_milli': 1, 'unit': 'kg',
                'unit_price': 1, 'line_total': 1, 'final_amount': 1,
              }),
          throwsA(anything));
    });
  });
}
