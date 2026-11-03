import '../../core/utils/money.dart';
import 'intent_parser.dart';
import 'product_matcher.dart';

/// Validates structured intents produced by an on-device LLM before they
/// reach business logic. Anything outside the whitelist is rejected, and the
/// LLM can only *name* a product, never invent one.
///
/// Expected JSON: {"intent": "...", "product_id": 3, "qty": 5, "unit": "kg",
///                 "amount": 65, "price_type": "retail"}
class IntentValidator {
  static const Map<String, IntentType> _allowed = {
    'price_query': IntentType.priceQuery,
    'stock_query': IntentType.stockQuery,
    'low_stock': IntentType.lowStock,
    'add_to_bill': IntentType.addToBill,
    'complete_bill': IntentType.completeBill,
    'price_set': IntentType.priceSet,
    'price_adjust': IntentType.priceAdjust,
    'stock_in': IntentType.stockIn,
    'sales_query': IntentType.salesQuery,
    'show_bills': IntentType.showBills,
    'price_history': IntentType.priceHistory,
  };

  static ParsedIntent? fromMap(Map<String, Object?> m, List<ProductRef> prods) {
    final type = _allowed[m['intent']];
    if (type == null) return null;

    ProductRef? product;
    final pid = m['product_id'];
    if (pid != null) {
      if (pid is! int) return null;
      for (final p in prods) {
        if (p.id == pid) product = p;
      }
      if (product == null) return null; // LLM named a product that does not exist
    }

    int? qty;
    final q = m['qty'];
    if (q != null) {
      if (q is! num || q <= 0 || q > 100000) return null;
      qty = Qty.parse(q.toString());
      if (qty == null) return null;
    }

    String? unit;
    final u = m['unit'];
    if (u != null) {
      if (u is! String || !Units.isValid(u)) return null;
      unit = Units.normalize(u);
    }

    int? amount;
    final a = m['amount'];
    if (a != null) {
      if (a is! num || a < 0 || a > 10000000) return null;
      amount = Money.parse(a.toString());
      if (amount == null) return null;
    }

    String? priceType;
    final pt = m['price_type'];
    if (pt != null) {
      if (pt != 'retail' && pt != 'wholesale') return null;
      priceType = pt as String;
    }

    var sign = 0;
    if (type == IntentType.priceAdjust) {
      final s = m['sign'];
      if (s != 1 && s != -1) return null;
      sign = s as int;
    }

    return ParsedIntent(
      type: type,
      product: product,
      qtyMilli: qty,
      unit: unit,
      amountPaise: amount,
      priceType: priceType,
      sign: sign,
    );
  }
}
