import '../../core/database/app_database.dart';
import '../../core/l10n/languages.dart';
import '../../core/l10n/strings.dart';
import '../../core/utils/money.dart';
import '../../features/billing/billing_service.dart';
import '../../features/inventory/inventory_service.dart';
import '../../features/pricing/pricing_service.dart';
import '../../features/products/product_service.dart';
import '../../features/reports/report_service.dart';
import '../../shared/models/models.dart';
import '../../shared/repositories/shop_repository.dart';
import '../../shared/repositories/user_repository.dart';
import '../intent/intent_parser.dart';
import '../intent/intent_validator.dart';
import '../intent/product_matcher.dart';

enum PendingKind { priceChange, stockIn, finalizeBill, addProduct }

class Pending {
  final PendingKind kind;
  final Map<String, Object?> data;
  final bool needsPin;
  const Pending(this.kind, this.data, {this.needsPin = false});
}

class AssistantReply {
  final String text;
  final Pending? pending;
  final String? nav; // 'history_bills' | 'billing'
  final bool needsPin;
  final int? savedBillId;
  final bool dataChanged;
  const AssistantReply(this.text,
      {this.pending,
      this.nav,
      this.needsPin = false,
      this.savedBillId,
      this.dataChanged = false});
}

typedef LlmIntentProvider = Future<Map<String, Object?>?> Function(
    String text, List<ProductRef> products);

/// Hybrid assistant. Layer 1 (this deterministic parser) handles common
/// commands; an optional local LLM may suggest a structured intent for
/// anything unclear, which is validated and then executed by exactly the same
/// permission-checked code. All numbers come from the database/services.
class AssistantEngine {
  final ProductService products;
  final PricingService pricing;
  final InventoryService inventory;
  final BillingService billing;
  final ReportService reports;
  final ShopRepository shop;
  final UserRepository users;
  final Session? Function() getSession;
  final String Function() getLang;
  final BillDraft Function() getDraft;
  final void Function(BillDraft) setDraft;
  final LlmIntentProvider? llm;

  AssistantEngine({
    required this.products,
    required this.pricing,
    required this.inventory,
    required this.billing,
    required this.reports,
    required this.shop,
    required this.users,
    required this.getSession,
    required this.getLang,
    required this.getDraft,
    required this.setDraft,
    this.llm,
  });

  Pending? pending;
  ParsedIntent? _clarify;
  String _lang = 'en';

  String _t(String key, [Map<String, String>? p]) => S.t(_lang, key, p);

  String _typeLabel(String type) {
    final w = _t(type == 'wholesale' ? 'w_wholesale' : 'w_retail');
    return (_lang == 'en' || _lang == 'ta_en') ? w.toLowerCase() : w;
  }

  Future<List<ProductRef>> _refs(Session s) async =>
      ProductMatcher.build(await products.matchables(s));

  void reset() {
    pending = null;
    _clarify = null;
  }

  Future<AssistantReply> handle(String raw) async {
    final s = getSession();
    if (s == null) return const AssistantReply('Please sign in first.');
    _lang = Languages.detect(raw, getLang());
    try {
      final refs = await _refs(s);
      final p = IntentParser.parse(raw, refs);

      if (pending != null) {
        if (p.type == IntentType.confirm) return await confirm();
        if (p.type == IntentType.cancel) return cancel();
        if (p.type == IntentType.unknown) {
          return AssistantReply(_t('a_pending_ask'), pending: pending);
        }
        pending = null; // a new command replaces the unanswered one
      } else if (p.type == IntentType.cancel) {
        _clarify = null;
        return AssistantReply(_t('a_cancelled'));
      } else if (p.type == IntentType.confirm) {
        return AssistantReply(_t('a_unclear'));
      }

      var it = p;
      if (_clarify != null && p.type == IntentType.unknown) {
        it = _clarify!.merge(p);
      } else if (p.type == IntentType.unknown && llm != null) {
        final m = await llm!(raw, refs);
        if (m != null) {
          final v = IntentValidator.fromMap(m, refs);
          if (v != null) it = v;
        }
      }
      _clarify = null;
      return await _execute(it, s);
    } catch (e) {
      return _error(e);
    }
  }

  AssistantReply _error(Object e) {
    if (e is PermissionDenied) {
      final owner = e.permission == Perm.viewWholesale ||
          e.permission == Perm.editWholesale ||
          e.permission == Perm.ownerDetails;
      return AssistantReply(_t(owner ? 'a_need_owner' : 'a_not_allowed'));
    }
    if (e is InsufficientStock) {
      return AssistantReply(_t('a_insufficient', {
        'p': e.product,
        'qty': Qty.format(e.availableMilli),
        'unit': e.unit,
      }));
    }
    if (e is AppError) {
      return AssistantReply(_t('a_error', {'e': e.message}));
    }
    return AssistantReply(_t('a_error', {'e': '$e'}));
  }

  AssistantReply _askProduct(ParsedIntent it) {
    _clarify = it;
    if (it.productQuery.isNotEmpty) {
      return AssistantReply(_t('a_not_found', {'q': it.productQuery}));
    }
    return AssistantReply(_t('a_which_product'));
  }

  Future<AssistantReply> _execute(ParsedIntent it, Session s) async {
    switch (it.type) {
      case IntentType.greeting:
        return AssistantReply(_t('a_greet'));

      case IntentType.priceQuery:
        return _priceQuery(it, s);

      case IntentType.priceHistory:
        return _priceHistory(it, s);

      case IntentType.priceSet:
      case IntentType.priceAdjust:
        return _priceChange(it, s);

      case IntentType.stockQuery:
        if (it.product == null) return _askProduct(it);
        final sp = await products.getById(s, it.product!.id);
        if (sp == null) return _askProduct(it);
        return AssistantReply(_t('a_stock', {
          'p': sp.name,
          'qty': Qty.format(sp.stockMilli),
          'unit': sp.unit,
        }));

      case IntentType.lowStock:
        final low = await inventory.lowStock(s);
        if (low.isEmpty) return AssistantReply(_t('a_low_none'));
        return AssistantReply(_t('a_low_list', {
          'list': low
              .map((e) => '${e.name} (${Qty.format(e.stockMilli)} ${e.unit})')
              .join(', ')
        }));

      case IntentType.stockIn:
        return _stockIn(it, s);

      case IntentType.addToBill:
        return _addToBill(it, s);

      case IntentType.completeBill:
        s.need(Perm.createBill);
        final d = getDraft();
        if (d.lines.isEmpty) return AssistantReply(_t('a_bill_empty'));
        final t = await billing.preview(s, d);
        pending = const Pending(PendingKind.finalizeBill, {});
        return AssistantReply(
            _t('a_bill_confirm', {'total': Money.format(t.total)}),
            pending: pending);

      case IntentType.showBills:
        return AssistantReply(_t('a_open_bills'), nav: 'history_bills');

      case IntentType.salesQuery:
        final sum = it.period == 'week'
            ? await reports.thisWeek(s)
            : it.period == 'month'
                ? await reports.thisMonth(s)
                : await reports.today(s);
        final key = it.period == 'week'
            ? 'w_week'
            : it.period == 'month'
                ? 'w_month'
                : 'w_today';
        return AssistantReply(_t('a_sales', {
          'period': _t(key),
          'amt': Money.format(sum.total),
          'n': '${sum.count}',
        }));

      case IntentType.profileShop:
        final prShop = await shop.profile();
        return _profileReply('a_shop_name', prShop?.shopName);
      case IntentType.profileOwner:
        s.need(Perm.ownerDetails);
        final prOwner = await shop.profile();
        return _profileReply('a_owner_name', prOwner?.ownerName);
      case IntentType.profileAddress:
        s.need(Perm.ownerDetails);
        final prAddr = await shop.profile();
        return _profileReply('a_shop_addr', prAddr?.address);
      case IntentType.profilePhone:
        s.need(Perm.ownerDetails);
        final prPhone = await shop.profile();
        return _profileReply('a_phone', prPhone?.phone);

      case IntentType.addProduct:
        return _addProduct(it, s);

      case IntentType.confirm:
      case IntentType.cancel:
      case IntentType.unknown:
        return AssistantReply(_t('a_unclear'));
    }
  }

  AssistantReply _profileReply(String key, String? value) {
    if (value == null || value.trim().isEmpty) {
      return AssistantReply(_t('a_not_saved'));
    }
    return AssistantReply(_t(key, {'v': value}));
  }

  Future<AssistantReply> _priceQuery(ParsedIntent it, Session s) async {
    if (it.product == null) return _askProduct(it);
    final p = await products.getById(s, it.product!.id);
    if (p == null) return _askProduct(it);
    if (it.priceType == 'wholesale') {
      // Authorisation is enforced inside PricingService as well.
      if (!s.can(Perm.viewWholesale)) {
        return AssistantReply(_t('a_need_owner'));
      }
      final w = await pricing.getWholesale(s, p.id);
      if (w == null) {
        return AssistantReply(
            _t('a_no_price', {'p': p.name, 'type': _typeLabel('wholesale')}));
      }
      return AssistantReply(_t('a_wholesale',
          {'p': p.name, 'price': Money.format(w), 'unit': p.unit}));
    }
    // Normal price questions return ONLY the retail price.
    if (p.retail == null) {
      return AssistantReply(
          _t('a_no_price', {'p': p.name, 'type': _typeLabel('retail')}));
    }
    return AssistantReply(_t('a_price',
        {'p': p.name, 'price': Money.format(p.retail!), 'unit': p.unit}));
  }

  Future<AssistantReply> _priceHistory(ParsedIntent it, Session s) async {
    if (it.product == null) return _askProduct(it);
    final type = it.priceType ?? 'retail';
    if (type == 'wholesale' && !s.can(Perm.viewWholesale)) {
      return AssistantReply(_t('a_need_owner'));
    }
    final rows = await pricing.history(s, productId: it.product!.id, type: type, limit: 1);
    if (rows.isEmpty) {
      return AssistantReply(_t('a_no_history', {'p': it.product!.name}));
    }
    final r = rows.first;
    return AssistantReply(_t('a_prev_price', {
      'p': it.product!.name,
      'type': _typeLabel(type),
      'old': r.oldPrice == null ? _t('w_none') : Money.format(r.oldPrice!),
      'new': Money.format(r.newPrice),
    }));
  }

  Future<AssistantReply> _priceChange(ParsedIntent it, Session s) async {
    if (it.product == null) return _askProduct(it);
    if (it.type == IntentType.priceAdjust && it.priceType == null) {
      _clarify = it;
      return AssistantReply(_t('a_ask_type'));
    }
    final type = it.priceType ?? 'retail';
    if (type == 'wholesale' && !s.can(Perm.editWholesale)) {
      return AssistantReply(_t('a_need_owner'));
    }
    if (type == 'retail' && !s.can(Perm.editRetail)) {
      return AssistantReply(_t('a_not_allowed'));
    }
    final amount = it.amountPaise ?? it.looseAmountPaise;
    if (amount == null) {
      _clarify = it.copyWith(priceType: type);
      return AssistantReply(_t('a_ask_amount'));
    }
    final p = await products.getById(s, it.product!.id);
    if (p == null) return _askProduct(it);
    final old = type == 'retail' ? p.retail : p.wholesale;
    int next;
    if (it.type == IntentType.priceSet) {
      next = amount;
    } else {
      if (old == null) {
        return AssistantReply(
            _t('a_no_price', {'p': p.name, 'type': _typeLabel(type)}));
      }
      next = old + (it.sign >= 0 ? amount : -amount);
      if (next < 0) return AssistantReply(_t('a_error', {'e': 'Price cannot be negative'}));
    }
    pending = Pending(
        PendingKind.priceChange,
        {'id': p.id, 'name': p.name, 'type': type, 'new': next},
        needsPin: type == 'wholesale');
    return AssistantReply(
        _t('a_price_change', {
          'p': p.name,
          'type': _typeLabel(type),
          'old': old == null ? _t('w_none') : Money.format(old),
          'new': Money.format(next),
        }),
        pending: pending);
  }

  Future<AssistantReply> _stockIn(ParsedIntent it, Session s) async {
    s.need(Perm.manageStock);
    if (it.product == null) return _askProduct(it);
    final p = await products.getById(s, it.product!.id);
    if (p == null) return _askProduct(it);
    final qty = it.qtyMilli ?? it.looseQtyMilli;
    if (qty == null || qty <= 0) {
      _clarify = it;
      return AssistantReply(_t('a_ask_qty', {'p': p.name}));
    }
    final unit = it.unit ?? p.unit;
    if (!Units.compatible(unit, p.unit)) {
      return AssistantReply(_t('a_unit_bad', {'unit': unit, 'p': p.name}));
    }
    pending = Pending(PendingKind.stockIn,
        {'id': p.id, 'name': p.name, 'qty': qty, 'unit': unit});
    return AssistantReply(
        _t('a_stockin_confirm', {
          'qty': Qty.format(qty),
          'unit': unit,
          'p': p.name,
          'cur': '${Qty.format(p.stockMilli)} ${p.unit}',
        }),
        pending: pending);
  }

  Future<AssistantReply> _addToBill(ParsedIntent it, Session s) async {
    s.need(Perm.createBill);
    if (it.product == null) return _askProduct(it);
    final p = await products.getById(s, it.product!.id);
    if (p == null) return _askProduct(it);
    final qty = it.qtyMilli ?? it.looseQtyMilli;
    if (qty == null || qty <= 0) {
      _clarify = it;
      return AssistantReply(_t('a_ask_qty', {'p': p.name}));
    }
    final unit = it.unit ?? p.unit;
    if (!Units.compatible(unit, p.unit)) {
      return AssistantReply(_t('a_unit_bad', {'unit': unit, 'p': p.name}));
    }
    if (p.retail == null) {
      return AssistantReply(
          _t('a_no_price', {'p': p.name, 'type': _typeLabel('retail')}));
    }
    final q = Units.convertMilli(qty, unit, p.unit);
    final draft = getDraft().addLine(BillLine(p.id, p.name, q, p.unit));
    setDraft(draft);
    final totals = await billing.preview(s, draft);
    return AssistantReply(
        _t('a_added_bill', {
          'qty': Qty.format(q),
          'unit': p.unit,
          'p': p.name,
          'amt': Money.format(Qty.lineTotal(p.retail!, q)),
          'total': Money.format(totals.total),
        }),
        dataChanged: true);
  }

  Future<AssistantReply> _addProduct(ParsedIntent it, Session s) async {
    s.need(Perm.editProducts);
    final name = (it.newName ?? '').trim();
    if (name.isEmpty) return AssistantReply(_t('a_unclear'));
    if (it.wholesalePaise != null && !s.can(Perm.editWholesale)) {
      return AssistantReply(_t('a_need_owner'));
    }
    if (it.retailPaise != null && !s.can(Perm.editRetail)) {
      return AssistantReply(_t('a_not_allowed'));
    }
    final unit = it.unit ?? 'kg';
    pending = Pending(PendingKind.addProduct, {
      'name': _titleCase(name),
      'retail': it.retailPaise,
      'wholesale': it.wholesalePaise,
      'unit': unit,
    });
    return AssistantReply(
        _t('a_prod_preview', {
          'p': _titleCase(name),
          'r': it.retailPaise == null ? _t('w_none') : Money.format(it.retailPaise!),
          'w': it.wholesalePaise == null ? _t('w_none') : Money.format(it.wholesalePaise!),
          'u': unit,
        }),
        pending: pending);
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  AssistantReply cancel() {
    pending = null;
    _clarify = null;
    return AssistantReply(_t('a_cancelled'));
  }

  /// Executes the pending action. Wholesale price changes need the owner's PIN.
  Future<AssistantReply> confirm({String? pin}) async {
    final s = getSession();
    final pd = pending;
    if (s == null || pd == null) return AssistantReply(_t('a_unclear'));
    try {
      if (pd.needsPin) {
        if (pin == null) {
          return AssistantReply(_t('a_pin_needed'), pending: pd, needsPin: true);
        }
        if (!s.isOwner || !await users.verifyPin(s.userId, pin)) {
          return AssistantReply(_t('a_pin_wrong'), pending: pd, needsPin: true);
        }
      }
      pending = null;
      switch (pd.kind) {
        case PendingKind.priceChange:
          final c = await pricing.setPrice(s, pd.data['id'] as int,
              pd.data['type'] as String, pd.data['new'] as int);
          return AssistantReply(
              _t('a_price_updated', {
                'p': c.productName,
                'type': _typeLabel(c.type),
                'new': Money.format(c.newPrice),
              }),
              dataChanged: true);
        case PendingKind.stockIn:
          final bal = await inventory.stockIn(s, pd.data['id'] as int,
              pd.data['qty'] as int, pd.data['unit'] as String);
          final pr = await products.getById(s, pd.data['id'] as int);
          return AssistantReply(
              _t('a_stock_updated', {
                'p': pd.data['name'] as String,
                'qty': Qty.format(bal),
                'unit': pr?.unit ?? '',
              }),
              dataChanged: true);
        case PendingKind.finalizeBill:
          final bill = await billing.finalize(s, getDraft());
          setDraft(BillDraft.empty());
          return AssistantReply(
              _t('a_bill_saved',
                  {'no': bill.billNo, 'total': Money.format(bill.total)}),
              savedBillId: bill.id,
              dataChanged: true);
        case PendingKind.addProduct:
          await products.create(
              s,
              ProductInput(
                name: pd.data['name'] as String,
                unit: pd.data['unit'] as String,
                retail: pd.data['retail'] as int?,
                wholesale: pd.data['wholesale'] as int?,
              ));
          return AssistantReply(
              _t('a_prod_saved', {'p': pd.data['name'] as String}),
              dataChanged: true);
      }
    } catch (e) {
      pending = null;
      return _error(e);
    }
  }
}
