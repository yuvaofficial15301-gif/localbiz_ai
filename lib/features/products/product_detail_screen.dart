import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'product_form_screen.dart';

final _detailProvider =
    FutureProvider.autoDispose.family<Product?, int>((ref, id) async {
  ref.watch(refreshProvider);
  return ref.read(svcProvider).products.getById(ref.read(authProvider).session!, id);
});

final _priceHistProvider =
    FutureProvider.autoDispose.family<List<PriceHistoryRec>, int>((ref, id) async {
  ref.watch(refreshProvider);
  return ref.read(svcProvider).pricing.history(ref.read(authProvider).session!, productId: id);
});

final _stockHistProvider =
    FutureProvider.autoDispose.family<List<StockMovementRec>, int>((ref, id) async {
  ref.watch(refreshProvider);
  return ref.read(svcProvider).inventory.movements(ref.read(authProvider).session!, productId: id);
});

class ProductDetailScreen extends ConsumerWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  Future<void> _setPrice(BuildContext context, WidgetRef ref, Product p, String type) async {
    final s = sess(ref);
    if (type == 'wholesale') {
      final pin = await askPin(context, title: 'Owner PIN to change wholesale price');
      if (pin == null) return;
      if (!await ref.read(svcProvider).users.verifyPin(s.userId, pin)) {
        if (context.mounted) toast(context, 'Wrong PIN', error: true);
        return;
      }
    }
    if (!context.mounted) return;
    final txt = await askText(context, 'New $type price',
        label: 'Price (${Money.symbol})',
        initial: Money.plain(type == 'retail' ? p.retail : p.wholesale));
    if (txt == null) return;
    final v = Money.parse(txt);
    if (v == null) {
      if (context.mounted) toast(context, 'Enter a valid amount', error: true);
      return;
    }
    try {
      await ref.read(svcProvider).pricing.setPrice(s, p.id, type, v);
      ref.read(refreshProvider.notifier).state++;
    } on AppError catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _stock(BuildContext context, WidgetRef ref, Product p, String mode) async {
    final txt = await askText(context,
        mode == 'in' ? 'Add stock' : (mode == 'out' ? 'Remove stock' : 'Set counted stock'),
        label: 'Quantity (${p.unit})');
    if (txt == null) return;
    final q = Qty.parse(txt);
    if (q == null) {
      if (context.mounted) toast(context, 'Enter a valid number', error: true);
      return;
    }
    try {
      final s = sess(ref);
      final inv = ref.read(svcProvider).inventory;
      if (mode == 'in') {
        await inv.stockIn(s, p.id, q, p.unit);
      } else if (mode == 'out') {
        await inv.stockOut(s, p.id, q, p.unit, reason: 'stock_out');
      } else {
        await inv.setStock(s, p.id, q);
      }
      ref.read(refreshProvider.notifier).state++;
    } on AppError catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authProvider).session!;
    final async = ref.watch(_detailProvider(productId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(appBar: AppBar(), body: ErrorState(e)),
      data: (p) {
        if (p == null) {
          return Scaffold(appBar: AppBar(), body: const EmptyState('Product not found'));
        }
        final ph = ref.watch(_priceHistProvider(productId));
        final sh = ref.watch(_stockHistProvider(productId));
        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              if (s.can(Perm.editProducts))
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProductFormScreen(product: p))),
                ),
              if (s.can(Perm.deleteProducts))
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () async {
                    final ok = await askConfirm(context, 'Delete ${p.name}?',
                        'The product will be hidden. Old bills and history stay unchanged.',
                        ok: 'Delete', danger: true);
                    if (!ok) return;
                    await ref.read(svcProvider).products.delete(s, p.id);
                    ref.read(refreshProvider.notifier).state++;
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Retail price', p.retail == null ? 'Not set' : '${Money.format(p.retail!)} / ${p.unit}'),
                      if (s.can(Perm.viewWholesale))
                        _row('Wholesale price', p.wholesale == null ? 'Not set' : '${Money.format(p.wholesale!)} / ${p.unit}'),
                      _row('Stock', '${Qty.format(p.stockMilli)} ${p.unit}'),
                      _row('Minimum stock', '${Qty.format(p.minStockMilli)} ${p.unit}'),
                      if (p.category.isNotEmpty) _row('Category', p.category),
                      if (p.altNames.isNotEmpty) _row('Other names', p.altNames),
                      if (p.barcode != null) _row('Barcode', p.barcode!),
                      if (p.expiry != null) _row('Expiry', p.expiry!),
                      if (p.description.isNotEmpty) _row('Description', p.description),
                      _row('Status', p.active ? 'Active' : 'Inactive'),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Prices'),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (s.can(Perm.editRetail))
                  BigButton('Change retail', icon: Icons.sell, outlined: true,
                      onPressed: () => _setPrice(context, ref, p, 'retail')),
                if (s.can(Perm.editWholesale))
                  BigButton('Change wholesale', icon: Icons.lock, outlined: true,
                      onPressed: () => _setPrice(context, ref, p, 'wholesale')),
              ]),
              if (s.can(Perm.manageStock)) ...[
                const SectionTitle('Stock'),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  BigButton('Stock in', icon: Icons.add_circle_outline, outlined: true,
                      onPressed: () => _stock(context, ref, p, 'in')),
                  BigButton('Stock out', icon: Icons.remove_circle_outline, outlined: true,
                      onPressed: () => _stock(context, ref, p, 'out')),
                  BigButton('Set count', icon: Icons.fact_check_outlined, outlined: true,
                      onPressed: () => _stock(context, ref, p, 'set')),
                ]),
              ],
              const SectionTitle('Price history'),
              ph.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => ErrorState(e),
                data: (l) => l.isEmpty
                    ? const Text('No price changes yet.')
                    : Card(
                        child: Column(children: [
                          for (final r in l.take(15))
                            ListTile(
                              dense: true,
                              title: Text(
                                  '${r.type == 'retail' ? 'Retail' : 'Wholesale'}: '
                                  '${r.oldPrice == null ? '—' : Money.format(r.oldPrice!)} → ${Money.format(r.newPrice)}'),
                              subtitle: Text('${shortDate(r.changedAt)}  •  ${r.changedBy}'),
                            ),
                        ]),
                      ),
              ),
              const SectionTitle('Stock history'),
              sh.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => ErrorState(e),
                data: (l) => l.isEmpty
                    ? const Text('No stock movements yet.')
                    : Card(
                        child: Column(children: [
                          for (final m in l.take(15))
                            ListTile(
                              dense: true,
                              title: Text(
                                  '${m.changeMilli >= 0 ? '+' : ''}${Qty.format(m.changeMilli)} ${p.unit}  (${m.reason})'),
                              subtitle: Text('${shortDate(m.createdAt)}  •  balance ${Qty.format(m.balanceMilli)}'),
                            ),
                        ]),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 15))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
