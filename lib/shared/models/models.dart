import '../../core/database/app_database.dart';

/// Domain errors surfaced to the UI/assistant.
class AppError implements Exception {
  final String code;
  final String message;
  AppError(this.code, this.message);
  @override
  String toString() => message;
}

class PermissionDenied extends AppError {
  final String permission;
  PermissionDenied(this.permission)
      : super('permission', 'Permission denied: $permission');
}

class InsufficientStock extends AppError {
  final String product;
  final int availableMilli;
  final String unit;
  InsufficientStock(this.product, this.availableMilli, this.unit)
      : super('insufficient_stock', 'Not enough stock for $product');
}

/// Authenticated user session with resolved permissions.
class Session {
  final int userId;
  final String name;
  final String role;
  final Set<String> perms;
  const Session(this.userId, this.name, this.role, this.perms);

  bool get isOwner => role == 'owner';

  bool can(String p) {
    if (Perm.ownerOnly.contains(p)) return isOwner && perms.contains(p);
    return perms.contains(p);
  }

  void need(String p) {
    if (!can(p)) throw PermissionDenied(p);
  }

  void needAny(List<String> ps) {
    if (!ps.any(can)) throw PermissionDenied(ps.first);
  }
}

class UserRec {
  final int id;
  final String name;
  final String role;
  final bool active;
  const UserRec(this.id, this.name, this.role, this.active);
  factory UserRec.fromMap(Map<String, Object?> m) => UserRec(
      m['id'] as int, m['name'] as String, m['role'] as String,
      (m['active'] as int) == 1);
}

class ShopProfile {
  final String ownerName;
  final String shopName;
  final String category;
  final String phone;
  final String address;
  final String language;
  final String currency;
  final String? openingDate;
  const ShopProfile({
    required this.ownerName,
    required this.shopName,
    required this.category,
    required this.phone,
    required this.address,
    required this.language,
    required this.currency,
    this.openingDate,
  });
  factory ShopProfile.fromMap(Map<String, Object?> m) => ShopProfile(
        ownerName: m['owner_name'] as String,
        shopName: m['shop_name'] as String,
        category: (m['category'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        language: (m['language'] as String?) ?? 'en',
        currency: (m['currency'] as String?) ?? '₹',
        openingDate: m['opening_date'] as String?,
      );
}

class Product {
  final int id;
  final String name;
  final String altNames;
  final String category;
  final String unit;
  final int? wholesale; // null if not set OR caller not authorised
  final int? retail;
  final int stockMilli;
  final int minStockMilli;
  final String? barcode;
  final String description;
  final String? expiry;
  final bool active;
  final String createdAt;
  final String updatedAt;
  const Product({
    required this.id,
    required this.name,
    required this.altNames,
    required this.category,
    required this.unit,
    required this.wholesale,
    required this.retail,
    required this.stockMilli,
    required this.minStockMilli,
    required this.barcode,
    required this.description,
    required this.expiry,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLow => minStockMilli > 0 && stockMilli <= minStockMilli;

  List<String> get altList => altNames
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  factory Product.fromMap(Map<String, Object?> m, {required bool includeWholesale}) {
    return Product(
      id: m['id'] as int,
      name: m['name'] as String,
      altNames: (m['alt_names'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      unit: (m['unit'] as String?) ?? 'kg',
      wholesale: includeWholesale ? m['wholesale_price'] as int? : null,
      retail: m['retail_price'] as int?,
      stockMilli: (m['stock_milli'] as int?) ?? 0,
      minStockMilli: (m['min_stock_milli'] as int?) ?? 0,
      barcode: m['barcode'] as String?,
      description: (m['description'] as String?) ?? '',
      expiry: m['expiry_date'] as String?,
      active: (m['active'] as int?) == 1,
      createdAt: (m['created_at'] as String?) ?? '',
      updatedAt: (m['updated_at'] as String?) ?? '',
    );
  }
}

class ProductInput {
  String name;
  String altNames;
  String category;
  String unit;
  int? wholesale;
  int? retail;
  int stockMilli;
  int minStockMilli;
  String? barcode;
  String description;
  String? expiry;
  bool active;
  ProductInput({
    required this.name,
    this.altNames = '',
    this.category = '',
    this.unit = 'kg',
    this.wholesale,
    this.retail,
    this.stockMilli = 0,
    this.minStockMilli = 0,
    this.barcode,
    this.description = '',
    this.expiry,
    this.active = true,
  });
}

class BillLine {
  final int productId;
  final String name;
  final int qtyMilli; // in the product's own unit
  final String unit;
  const BillLine(this.productId, this.name, this.qtyMilli, this.unit);
  BillLine withQty(int q) => BillLine(productId, name, q, unit);
}

class BillDraft {
  final List<BillLine> lines;
  final String paymentMethod;
  final String discountMode; // 'amount' (paise) | 'percent' (basis points)
  final int discountValue;
  final String customer;
  final String idemKey;
  const BillDraft({
    required this.lines,
    this.paymentMethod = 'cash',
    this.discountMode = 'amount',
    this.discountValue = 0,
    this.customer = '',
    required this.idemKey,
  });

  static BillDraft empty() =>
      BillDraft(lines: const [], idemKey: newKey());

  static String newKey() =>
      '${DateTime.now().microsecondsSinceEpoch}-${(DateTime.now().millisecondsSinceEpoch * 7919) % 100000}';

  BillDraft copyWith({
    List<BillLine>? lines,
    String? paymentMethod,
    String? discountMode,
    int? discountValue,
    String? customer,
  }) =>
      BillDraft(
        lines: lines ?? this.lines,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        discountMode: discountMode ?? this.discountMode,
        discountValue: discountValue ?? this.discountValue,
        customer: customer ?? this.customer,
        idemKey: idemKey,
      );

  /// Adds quantity, merging with an existing line of the same product.
  BillDraft addLine(BillLine l) {
    final out = <BillLine>[];
    var merged = false;
    for (final e in lines) {
      if (e.productId == l.productId && !merged) {
        out.add(e.withQty(e.qtyMilli + l.qtyMilli));
        merged = true;
      } else {
        out.add(e);
      }
    }
    if (!merged) out.add(l);
    return copyWith(lines: out);
  }

  BillDraft removeAt(int i) {
    final out = List<BillLine>.from(lines)..removeAt(i);
    return copyWith(lines: out);
  }
}

class BillRec {
  final int id;
  final String billNo;
  final String createdAt;
  final int subtotal;
  final int discount;
  final int tax;
  final int total;
  final String paymentMethod;
  final String customer;
  final String createdBy;
  const BillRec(this.id, this.billNo, this.createdAt, this.subtotal,
      this.discount, this.tax, this.total, this.paymentMethod, this.customer,
      this.createdBy);
  factory BillRec.fromMap(Map<String, Object?> m) => BillRec(
        m['id'] as int,
        m['bill_no'] as String,
        m['created_at'] as String,
        m['subtotal'] as int,
        m['discount'] as int,
        m['tax'] as int,
        m['total'] as int,
        (m['payment_method'] as String?) ?? 'cash',
        (m['customer_name'] as String?) ?? '',
        (m['created_by'] as String?) ?? '',
      );
}

class BillItemRec {
  final int id;
  final int? productId;
  final String name;
  final int qtyMilli;
  final String unit;
  final int unitPrice;
  final int lineTotal;
  final int discount;
  final int tax;
  final int finalAmount;
  const BillItemRec(this.id, this.productId, this.name, this.qtyMilli,
      this.unit, this.unitPrice, this.lineTotal, this.discount, this.tax,
      this.finalAmount);
  factory BillItemRec.fromMap(Map<String, Object?> m) => BillItemRec(
        m['id'] as int,
        m['product_id'] as int?,
        m['product_name'] as String,
        m['qty_milli'] as int,
        m['unit'] as String,
        m['unit_price'] as int,
        m['line_total'] as int,
        m['discount'] as int,
        m['tax'] as int,
        m['final_amount'] as int,
      );
}

class PriceHistoryRec {
  final int id;
  final int productId;
  final String productName;
  final String type;
  final int? oldPrice;
  final int newPrice;
  final String changedAt;
  final String changedBy;
  const PriceHistoryRec(this.id, this.productId, this.productName, this.type,
      this.oldPrice, this.newPrice, this.changedAt, this.changedBy);
  factory PriceHistoryRec.fromMap(Map<String, Object?> m) => PriceHistoryRec(
        m['id'] as int,
        m['product_id'] as int,
        (m['product_name'] as String?) ?? '',
        m['price_type'] as String,
        m['old_price'] as int?,
        m['new_price'] as int,
        m['changed_at'] as String,
        (m['changed_by'] as String?) ?? '',
      );
}

class StockMovementRec {
  final int id;
  final int productId;
  final String productName;
  final int changeMilli;
  final int balanceMilli;
  final String reason;
  final String ref;
  final String createdAt;
  final String createdBy;
  const StockMovementRec(this.id, this.productId, this.productName,
      this.changeMilli, this.balanceMilli, this.reason, this.ref,
      this.createdAt, this.createdBy);
  factory StockMovementRec.fromMap(Map<String, Object?> m) => StockMovementRec(
        m['id'] as int,
        m['product_id'] as int,
        m['product_name'] as String,
        m['change_milli'] as int,
        m['balance_milli'] as int,
        m['reason'] as String,
        (m['ref'] as String?) ?? '',
        m['created_at'] as String,
        (m['created_by'] as String?) ?? '',
      );
}

class PurchaseRec {
  final int id;
  final String supplier;
  final String date;
  final int total;
  final String status;
  final String invoiceRef;
  const PurchaseRec(this.id, this.supplier, this.date, this.total,
      this.status, this.invoiceRef);
  factory PurchaseRec.fromMap(Map<String, Object?> m) => PurchaseRec(
        m['id'] as int,
        m['supplier_name'] as String,
        m['purchase_date'] as String,
        m['total'] as int,
        m['payment_status'] as String,
        (m['invoice_ref'] as String?) ?? '',
      );
}

class PurchaseLineInput {
  final int productId;
  final String name;
  final int qtyMilli;
  final String unit;
  final int unitCost; // paise per product unit, recorded independently
  const PurchaseLineInput(
      this.productId, this.name, this.qtyMilli, this.unit, this.unitCost);
}

class AuditRec {
  final int id;
  final String at;
  final String user;
  final String action;
  final String detail;
  const AuditRec(this.id, this.at, this.user, this.action, this.detail);
  factory AuditRec.fromMap(Map<String, Object?> m) => AuditRec(
        m['id'] as int,
        m['at'] as String,
        m['user_name'] as String,
        m['action'] as String,
        (m['detail'] as String?) ?? '',
      );
}

class SalesSummary {
  final int total;
  final int count;
  const SalesSummary(this.total, this.count);
}

class DailySales {
  final DateTime day;
  final int total;
  const DailySales(this.day, this.total);
}

class BestSeller {
  final String name;
  final int qtyMilli;
  final String unit;
  final int amount;
  const BestSeller(this.name, this.qtyMilli, this.unit, this.amount);
}
