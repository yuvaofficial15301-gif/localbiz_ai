import '../../core/utils/money.dart';
import 'keywords.dart';
import 'product_matcher.dart';
import 'text_normalizer.dart';

enum IntentType {
  greeting, priceQuery, stockQuery, lowStock, addToBill, completeBill,
  priceSet, priceAdjust, stockIn, salesQuery, showBills, profileOwner,
  profileShop, profileAddress, profilePhone, addProduct, priceHistory,
  confirm, cancel, unknown,
}

/// Structured result of understanding one utterance. This is the only thing
/// that crosses from language understanding into business logic.
class ParsedIntent {
  final IntentType type;
  final ProductRef? product;
  final String productQuery;
  final int? qtyMilli;
  final String? unit;
  final int? amountPaise;
  final int? looseAmountPaise;
  final int? looseQtyMilli;
  final String? priceType; // retail | wholesale
  final int sign; // +1 increase, -1 decrease, 0 set
  final String period; // today | week | month
  final String? newName;
  final int? retailPaise;
  final int? wholesalePaise;
  final String norm;

  const ParsedIntent({
    this.type = IntentType.unknown,
    this.product,
    this.productQuery = '',
    this.qtyMilli,
    this.unit,
    this.amountPaise,
    this.looseAmountPaise,
    this.looseQtyMilli,
    this.priceType,
    this.sign = 0,
    this.period = 'today',
    this.newName,
    this.retailPaise,
    this.wholesalePaise,
    this.norm = '',
  });

  ParsedIntent copyWith({
    IntentType? type,
    ProductRef? product,
    String? productQuery,
    int? qtyMilli,
    String? unit,
    int? amountPaise,
    String? priceType,
  }) =>
      ParsedIntent(
        type: type ?? this.type,
        product: product ?? this.product,
        productQuery: productQuery ?? this.productQuery,
        qtyMilli: qtyMilli ?? this.qtyMilli,
        unit: unit ?? this.unit,
        amountPaise: amountPaise ?? this.amountPaise,
        looseAmountPaise: looseAmountPaise,
        looseQtyMilli: looseQtyMilli,
        priceType: priceType ?? this.priceType,
        sign: sign,
        period: period,
        newName: newName,
        retailPaise: retailPaise,
        wholesalePaise: wholesalePaise,
        norm: norm,
      );

  /// Fills gaps of this (clarification-pending) intent from a follow-up.
  ParsedIntent merge(ParsedIntent o) => ParsedIntent(
        type: type,
        product: product ?? o.product,
        productQuery: product != null ? productQuery : o.productQuery,
        qtyMilli: qtyMilli ?? o.qtyMilli ?? o.looseQtyMilli,
        unit: unit ?? o.unit,
        amountPaise: amountPaise ?? o.amountPaise ?? o.looseAmountPaise,
        looseAmountPaise: looseAmountPaise,
        looseQtyMilli: looseQtyMilli,
        priceType: priceType ?? o.priceType,
        sign: sign,
        period: period,
        newName: newName,
        retailPaise: retailPaise,
        wholesalePaise: wholesalePaise,
        norm: o.norm,
      );
}

class IntentParser {
  static ParsedIntent parse(String raw, List<ProductRef> prods) {
    final norm = Norm.normalize(raw);
    final tokens = norm.isEmpty ? <String>[] : norm.split(' ');
    bool has(List<String> w) => tokens.any((t) => Kw.hit(t, w));

    final hasPrice = has(Kw.price);
    final wholesaleW = tokens.any(Kw.isWholesale);
    final retailW = has(Kw.retail);
    final hasStock = has(Kw.stock);
    final hasAdd = has(Kw.add);
    final hasSet = has(Kw.change);
    final hasInc = has(Kw.increase);
    final hasDec = has(Kw.decrease);
    final hasBill = has(Kw.bill);
    final hasShow = has(Kw.show);
    final hasMy = has(Kw.my);
    final hasShop = has(Kw.shop);
    final priceType = wholesaleW ? 'wholesale' : (retailW ? 'retail' : null);
    final period = has(Kw.week) ? 'week' : (has(Kw.month) ? 'month' : 'today');

    // ---- numbers, quantities, amounts
    int? qtyMilli;
    String? qUnit;
    int? amountPaise;
    final loose = <String>[];
    final used = <int>{};
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (!Kw.isNum(t)) continue;
      final next = i + 1 < tokens.length ? tokens[i + 1] : '';
      final prev = i > 0 ? tokens[i - 1] : '';
      final u = next.isEmpty ? null : Kw.unitOf(next);
      if (u != null && qtyMilli == null) {
        qtyMilli = Qty.parse(t);
        qUnit = u;
        used.addAll([i, i + 1]);
      } else if (Kw.isRupee(next) || Kw.isRupee(prev)) {
        amountPaise ??= Money.parse(t);
        used.add(i);
        if (Kw.isRupee(next)) used.add(i + 1);
      } else {
        loose.add(t);
        used.add(i);
      }
    }
    final looseQty = loose.isEmpty ? null : Qty.parse(loose.first);
    final looseAmt = loose.isEmpty ? null : Money.parse(loose.last);

    final product = ProductMatcher.find(norm, tokens, prods);

    // words that are not commands, numbers, units: used for "not found" text
    final left = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (used.contains(i) || Kw.isNum(t) || Kw.stop.contains(t)) continue;
      if (Kw.hit(t, Kw.price) || Kw.hit(t, Kw.stock) || Kw.hit(t, Kw.bill)) continue;
      left.add(t);
    }
    final leftover = left.take(3).join(' ');

    ParsedIntent make(IntentType type, {String? newName, int? retail, int? whole, String? unit}) =>
        ParsedIntent(
          type: type,
          product: product,
          productQuery: leftover,
          qtyMilli: qtyMilli,
          unit: unit ?? qUnit,
          amountPaise: amountPaise,
          looseAmountPaise: looseAmt,
          looseQtyMilli: looseQty,
          priceType: priceType,
          sign: hasInc ? 1 : (hasDec ? -1 : 0),
          period: period,
          newName: newName,
          retailPaise: retail,
          wholesalePaise: whole,
          norm: norm,
        );

    if (tokens.isEmpty) return make(IntentType.unknown);

    // ---- confirmation words (short utterances only)
    if (tokens.length <= 4) {
      if (tokens.any((t) => Kw.hit(t, Kw.yes)) && !hasAdd) return make(IntentType.confirm);
      if (tokens.any((t) => Kw.hit(t, Kw.no))) return make(IntentType.cancel);
    }
    if (tokens.length <= 3 && has(Kw.greeting)) return make(IntentType.greeting);

    // ---- profile questions
    final nameW = has(Kw.name);
    if (product == null && !hasPrice && !hasBill) {
      if (hasShop && nameW) return make(IntentType.profileShop);
      if (nameW && hasMy) return make(IntentType.profileOwner);
      if (has(Kw.address) && (hasShop || hasMy)) return make(IntentType.profileAddress);
      if (has(Kw.phone) && (hasMy || hasShop)) return make(IntentType.profilePhone);
    }

    // ---- bill commands
    if (hasBill && has(Kw.complete)) return make(IntentType.completeBill);
    if (hasBill && hasShow) return make(IntentType.showBills);

    // ---- low stock
    if (hasStock && has(Kw.low) && product == null) return make(IntentType.lowStock);

    // ---- sales
    if (has(Kw.sales)) return make(IntentType.salesQuery);

    // ---- voice product registration
    if (hasAdd && (retailW || wholesaleW) && tokens.any(Kw.isNum)) {
      final r = _addProduct(tokens);
      if (r != null) {
        return make(IntentType.addProduct,
            newName: r.name, retail: r.retail, whole: r.wholesale, unit: r.unit);
      }
    }

    // ---- price update / adjustment
    if (hasPrice && (hasInc || hasDec)) return make(IntentType.priceAdjust);
    if (hasPrice && hasSet) return make(IntentType.priceSet);

    // ---- stock in
    if (hasStock && (hasAdd || hasSet) && (qtyMilli != null || looseQty != null)) {
      return make(IntentType.stockIn);
    }

    // ---- price history
    if (hasPrice && has(Kw.history)) return make(IntentType.priceHistory);

    // ---- price / stock queries
    if (hasPrice) return make(IntentType.priceQuery);
    if (hasStock) return make(IntentType.stockQuery);

    // ---- add to bill
    if (product != null && (qtyMilli != null || hasAdd || looseQty != null)) {
      return make(IntentType.addToBill);
    }
    if (product == null && qtyMilli != null && leftover.isNotEmpty) {
      return make(IntentType.addToBill); // unknown product with a quantity
    }
    return make(IntentType.unknown);
  }

  static _NewProduct? _addProduct(List<String> tokens) {
    final addIdx = tokens.indexWhere((t) => Kw.hit(t, Kw.add));
    if (addIdx < 0) return null;
    bool isQualifier(String t) =>
        Kw.hit(t, Kw.retail) ||
        Kw.isWholesale(t) ||
        Kw.hit(t, Kw.price) ||
        t == 'unit' ||
        t == 'units' ||
        Kw.isNum(t);
    final nameTokens = <String>[];
    for (var i = addIdx + 1; i < tokens.length; i++) {
      final t = tokens[i];
      if (isQualifier(t)) break;
      if (Kw.stop.contains(t) && t != 'oil') continue;
      nameTokens.add(t);
    }
    // name given before the add word ("rice add ...")
    if (nameTokens.isEmpty) {
      for (var i = 0; i < addIdx; i++) {
        final t = tokens[i];
        if (isQualifier(t) || Kw.stop.contains(t)) continue;
        nameTokens.add(t);
      }
    }
    if (nameTokens.isEmpty) return null;

    int? numAfter(int idx, int stopAt) {
      for (var i = idx + 1; i < stopAt && i < tokens.length; i++) {
        if (Kw.isNum(tokens[i])) return Money.parse(tokens[i]);
      }
      return null;
    }

    final iR = tokens.indexWhere((t) => Kw.hit(t, Kw.retail));
    final iW = tokens.indexWhere(Kw.isWholesale);
    final iU = tokens.indexWhere((t) => t == 'unit' || t == 'units');
    int stopFor(int idx) {
      var s = tokens.length;
      for (final o in [iR, iW, iU]) {
        if (o > idx && o < s) s = o;
      }
      return s;
    }

    final retail = iR >= 0 ? numAfter(iR, stopFor(iR)) : null;
    final whole = iW >= 0 ? numAfter(iW, stopFor(iW)) : null;
    String? unit;
    if (iU >= 0) {
      for (var i = iU + 1; i < tokens.length; i++) {
        final u = Kw.unitOf(tokens[i]);
        if (u != null) {
          unit = u;
          break;
        }
        if (!Kw.stop.contains(tokens[i])) {
          unit = Units.normalize(tokens[i]);
          break;
        }
      }
    }
    if (retail == null && whole == null) return null;
    return _NewProduct(nameTokens.join(' '), retail, whole, unit);
  }
}

class _NewProduct {
  final String name;
  final int? retail;
  final int? wholesale;
  final String? unit;
  const _NewProduct(this.name, this.retail, this.wholesale, this.unit);
}
