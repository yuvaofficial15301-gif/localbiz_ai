import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/services/audit_service.dart';
import '../../core/utils/csv.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../inventory/inventory_service.dart';
import '../pricing/pricing_service.dart';

class ImportResult {
  final int added;
  final int skipped;
  final List<String> errors;
  const ImportResult(this.added, this.skipped, this.errors);
}

class ProductService {
  final Database db;
  ProductService(this.db);

  static void _validate(ProductInput p) {
    final n = p.name.trim();
    if (n.isEmpty) throw AppError('invalid', 'Product name is required');
    if (n.length > 80) throw AppError('invalid', 'Product name is too long');
    if (!Units.isValid(p.unit)) throw AppError('invalid_unit', 'Invalid unit');
    for (final v in [p.retail, p.wholesale]) {
      if (v != null && (v < 0 || v > 1000000000)) {
        throw AppError('invalid', 'Price is out of range');
      }
    }
    if (p.stockMilli < 0 || p.minStockMilli < 0) {
      throw AppError('invalid', 'Stock cannot be negative');
    }
  }

  Future<List<Product>> list(
    Session s, {
    String query = '',
    String category = '',
    String filter = 'all', // all | active | inactive | low
    String sort = 'name', // name | stock | price | updated
  }) async {
    s.needAny([Perm.viewProducts, Perm.createBill]);
    final where = <String>['deleted = 0'];
    final args = <Object?>[];
    if (filter == 'low') {
      where.add('min_stock_milli > 0 AND stock_milli <= min_stock_milli');
    } else if (filter == 'inactive') {
      where.add('active = 0');
    } else if (filter == 'active') {
      where.add('active = 1');
    }
    if (category.isNotEmpty) {
      where.add('category = ?');
      args.add(category);
    }
    if (query.trim().isNotEmpty) {
      where.add('(name LIKE ? OR alt_names LIKE ? OR barcode LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }
    final order = switch (sort) {
      'stock' => 'stock_milli ASC',
      'price' => 'retail_price DESC',
      'updated' => 'updated_at DESC',
      _ => 'name COLLATE NOCASE ASC',
    };
    final r = await db.query('products',
        where: where.join(' AND '), whereArgs: args, orderBy: order);
    final w = s.can(Perm.viewWholesale);
    return r.map((e) => Product.fromMap(e, includeWholesale: w)).toList();
  }

  Future<Product?> getById(Session s, int id) async {
    s.needAny([Perm.viewProducts, Perm.createBill]);
    final r = await db.query('products',
        where: 'id = ? AND deleted = 0', whereArgs: [id], limit: 1);
    if (r.isEmpty) return null;
    return Product.fromMap(r.first, includeWholesale: s.can(Perm.viewWholesale));
  }

  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) c FROM products WHERE deleted = 0');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<String>> categories() async {
    final r = await db.rawQuery(
        "SELECT DISTINCT category FROM products WHERE deleted = 0 AND category <> '' ORDER BY category");
    return r.map((e) => e['category'] as String).toList();
  }

  Future<int> create(Session s, ProductInput input) async {
    s.need(Perm.editProducts);
    _validate(input);
    if (input.wholesale != null) s.need(Perm.editWholesale);
    if (input.retail != null) s.need(Perm.editRetail);
    final name = input.name.trim();
    return db.transaction<int>((txn) async {
      final dup = await txn.query('products',
          where: 'deleted = 0 AND lower(name) = ?', whereArgs: [name.toLowerCase()]);
      if (dup.isNotEmpty) {
        throw AppError('duplicate', 'A product named "$name" already exists');
      }
      final now = nowIso();
      final id = await txn.insert('products', {
        'name': name,
        'alt_names': input.altNames.trim(),
        'category': input.category.trim(),
        'unit': Units.normalize(input.unit),
        'wholesale_price': input.wholesale,
        'retail_price': input.retail,
        'stock_milli': 0,
        'min_stock_milli': input.minStockMilli,
        'barcode': (input.barcode ?? '').trim().isEmpty ? null : input.barcode!.trim(),
        'description': input.description.trim(),
        'expiry_date': (input.expiry ?? '').isEmpty ? null : input.expiry,
        'active': input.active ? 1 : 0,
        'deleted': 0,
        'created_at': now,
        'updated_at': now,
      });
      if (input.retail != null) {
        await txn.insert('price_history', {
          'product_id': id, 'price_type': 'retail', 'old_price': null,
          'new_price': input.retail, 'changed_at': now, 'changed_by': s.name,
        });
      }
      if (input.wholesale != null) {
        await txn.insert('price_history', {
          'product_id': id, 'price_type': 'wholesale', 'old_price': null,
          'new_price': input.wholesale, 'changed_at': now, 'changed_by': s.name,
        });
      }
      if (input.stockMilli > 0) {
        await InventoryService.applyDelta(txn,
            productId: id, deltaMilli: input.stockMilli, reason: 'initial', user: s.name);
      }
      await AuditService.log(txn, s.name, 'product_created', name);
      return id;
    });
  }

  /// Edits details. Price edits are recorded in price_history; stock is
  /// never changed here (use InventoryService).
  Future<void> update(Session s, int id, ProductInput input) async {
    s.need(Perm.editProducts);
    _validate(input);
    await db.transaction((txn) async {
      final r = await txn.query('products',
          where: 'id = ? AND deleted = 0', whereArgs: [id]);
      if (r.isEmpty) throw AppError('not_found', 'Product not found');
      final name = input.name.trim();
      final dup = await txn.query('products',
          where: 'deleted = 0 AND lower(name) = ? AND id <> ?',
          whereArgs: [name.toLowerCase(), id]);
      if (dup.isNotEmpty) {
        throw AppError('duplicate', 'A product named "$name" already exists');
      }
      final oldRetail = r.first['retail_price'] as int?;
      final oldWholesale = r.first['wholesale_price'] as int?;
      await txn.update(
          'products',
          {
            'name': name,
            'alt_names': input.altNames.trim(),
            'category': input.category.trim(),
            'unit': Units.normalize(input.unit),
            'min_stock_milli': input.minStockMilli,
            'barcode': (input.barcode ?? '').trim().isEmpty ? null : input.barcode!.trim(),
            'description': input.description.trim(),
            'expiry_date': (input.expiry ?? '').isEmpty ? null : input.expiry,
            'active': input.active ? 1 : 0,
            'updated_at': nowIso(),
          },
          where: 'id = ?',
          whereArgs: [id]);
      if (input.retail != null && input.retail != oldRetail) {
        await PricingService.applyInTxn(txn, s, id, 'retail', (_) => input.retail!);
      }
      // Callers who cannot see wholesale prices can never change them.
      if (s.can(Perm.viewWholesale) &&
          input.wholesale != null &&
          input.wholesale != oldWholesale) {
        await PricingService.applyInTxn(txn, s, id, 'wholesale', (_) => input.wholesale!);
      }
      await AuditService.log(txn, s.name, 'product_updated', name);
    });
  }

  /// Soft delete: bills, price and stock history remain intact.
  Future<void> delete(Session s, int id) async {
    s.need(Perm.deleteProducts);
    await db.transaction((txn) async {
      final r = await txn.query('products', where: 'id = ? AND deleted = 0', whereArgs: [id]);
      if (r.isEmpty) throw AppError('not_found', 'Product not found');
      await txn.update('products', {'deleted': 1, 'active': 0, 'updated_at': nowIso()},
          where: 'id = ?', whereArgs: [id]);
      await AuditService.log(txn, s.name, 'product_deleted', r.first['name'] as String);
    });
  }

  Future<void> setActive(Session s, int id, bool active) async {
    s.need(Perm.editProducts);
    await db.update('products', {'active': active ? 1 : 0, 'updated_at': nowIso()},
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
  }

  /// Lightweight rows used by the assistant to resolve spoken product names.
  /// Contains no price information.
  Future<List<Map<String, Object?>>> matchables(Session s) async {
    s.needAny([Perm.viewProducts, Perm.createBill]);
    return db.query('products',
        columns: ['id', 'name', 'alt_names', 'unit'],
        where: 'deleted = 0 AND active = 1');
  }

  static const _csvHeader = [
    'name', 'alt_names', 'category', 'unit', 'wholesale_price', 'retail_price',
    'stock', 'min_stock', 'barcode', 'description', 'expiry_date', 'active'
  ];

  Future<String> exportCsv(Session s) async {
    s.need(Perm.viewProducts);
    final withW = s.can(Perm.viewWholesale);
    final list = await this.list(s);
    final rows = <List<String>>[_csvHeader];
    for (final p in list) {
      rows.add([
        p.name,
        p.altNames,
        p.category,
        p.unit,
        withW ? Money.plain(p.wholesale) : '',
        Money.plain(p.retail),
        Qty.format(p.stockMilli),
        Qty.format(p.minStockMilli),
        p.barcode ?? '',
        p.description,
        p.expiry ?? '',
        p.active ? '1' : '0',
      ]);
    }
    await db.transaction((txn) => AuditService.log(txn, s.name, 'products_exported', '${list.length}'));
    return Csv.encode(rows);
  }

  Future<ImportResult> importCsv(Session s, String text) async {
    s.need(Perm.editProducts);
    final rows = Csv.parse(text);
    if (rows.isEmpty) return const ImportResult(0, 0, ['Empty file']);
    final header = rows.first.map((e) => e.trim().toLowerCase()).toList();
    int col(String n) => header.indexOf(n);
    if (col('name') < 0) {
      return const ImportResult(0, 0, ['Missing "name" column']);
    }
    String cell(List<String> r, String n) {
      final i = col(n);
      return (i < 0 || i >= r.length) ? '' : r[i].trim();
    }

    var added = 0;
    var skipped = 0;
    final errors = <String>[];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      try {
        final retailTxt = cell(r, 'retail_price');
        final wholeTxt = cell(r, 'wholesale_price');
        final retail = retailTxt.isEmpty ? null : Money.parse(retailTxt);
        final whole = wholeTxt.isEmpty ? null : Money.parse(wholeTxt);
        if (retailTxt.isNotEmpty && retail == null) {
          throw AppError('invalid', 'Bad retail price');
        }
        if (wholeTxt.isNotEmpty && whole == null) {
          throw AppError('invalid', 'Bad wholesale price');
        }
        final stockTxt = cell(r, 'stock');
        final minTxt = cell(r, 'min_stock');
        final stock = stockTxt.isEmpty ? 0 : Qty.parse(stockTxt);
        final minStock = minTxt.isEmpty ? 0 : Qty.parse(minTxt);
        if (stock == null || minStock == null) {
          throw AppError('invalid', 'Bad stock number');
        }
        await create(
            s,
            ProductInput(
              name: cell(r, 'name'),
              altNames: cell(r, 'alt_names'),
              category: cell(r, 'category'),
              unit: cell(r, 'unit').isEmpty ? 'kg' : Units.normalize(cell(r, 'unit')),
              wholesale: s.can(Perm.editWholesale) ? whole : null,
              retail: retail,
              stockMilli: stock,
              minStockMilli: minStock,
              barcode: cell(r, 'barcode'),
              description: cell(r, 'description'),
              expiry: cell(r, 'expiry_date'),
              active: cell(r, 'active') != '0',
            ));
        added++;
      } on AppError catch (e) {
        if (e.code == 'duplicate') {
          skipped++;
        } else {
          errors.add('Row ${i + 1}: ${e.message}');
        }
      }
    }
    return ImportResult(added, skipped, errors);
  }
}
