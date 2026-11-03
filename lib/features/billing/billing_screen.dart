import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../billing/billing_service.dart';
import '../billing/receipt_screen.dart';

final _totalsProvider = FutureProvider.autoDispose<BillTotals>((ref) async {
  ref.watch(refreshProvider);
  final d = ref.watch(billDraftProvider);
  final s = ref.read(authProvider).session!;
  return ref.read(svcProvider).billing.preview(s, d);
});

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  Future<void> _addProduct(BuildContext context, WidgetRef ref) async {
    final s = sess(ref);
    final prods = await ref.read(svcProvider).products.list(s, filter: 'active');
    if (!context.mounted) return;
    final chosen = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _ProductPicker(products: prods),
    );
    if (chosen == null || !context.mounted) return;
    if (chosen.retail == null) {
      toast(context, '${chosen.name} has no retail price. Set it first.', error: true);
      return;
    }
    final txt = await askText(context, '${chosen.name} — quantity',
        label: 'Quantity (${chosen.unit})', initial: '1');
    if (txt == null) return;
    final q = Qty.parse(txt);
    if (q == null || q <= 0) {
      if (context.mounted) toast(context, 'Enter a valid quantity', error: true);
      return;
    }
    final d = ref.read(billDraftProvider);
    ref.read(billDraftProvider.notifier).set(
        d.addLine(BillLine(chosen.id, chosen.name, q, chosen.unit)));
  }

  Future<void> _discount(BuildContext context, WidgetRef ref) async {
    final txt = await askText(context, 'Discount',
        label: 'Amount (${Money.symbol}), or percent like 10%');
    if (txt == null) return;
    final d = ref.read(billDraftProvider);
    final t = txt.trim();
    if (t.endsWith('%')) {
      final v = Money.parse(t.substring(0, t.length - 1));
      if (v == null || v > 10000) {
        if (context.mounted) toast(context, 'Invalid percent', error: true);
        return;
      }
      // 10.5% -> 1050 basis points (v is in "paise" of percent)
      ref.read(billDraftProvider.notifier).set(
          d.copyWith(discountMode: 'percent', discountValue: v));
    } else {
      final v = Money.parse(t);
      if (v == null) {
        if (context.mounted) toast(context, 'Invalid amount', error: true);
        return;
      }
      ref.read(billDraftProvider.notifier).set(
          d.copyWith(discountMode: 'amount', discountValue: v));
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, BillTotals t) async {
    final ok = await askConfirm(context, 'Complete bill?',
        'Total ${Money.format(t.total)}. Stock will be reduced.');
    if (!ok) return;
    try {
      final bill = await ref
          .read(svcProvider)
          .billing
          .finalize(sess(ref), ref.read(billDraftProvider));
      ref.read(billDraftProvider.notifier).clear();
      ref.read(refreshProvider.notifier).state++;
      if (!context.mounted) return;
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReceiptScreen(billId: bill.id)));
    } on InsufficientStock catch (e) {
      if (context.mounted) {
        toast(context,
            'Not enough stock for ${e.product}. Available ${Qty.format(e.availableMilli)} ${e.unit}.',
            error: true);
      }
    } on AppError catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authProvider).session!;
    final draft = ref.watch(billDraftProvider);
    final totals = ref.watch(_totalsProvider);
    final canBill = s.can(Perm.createBill);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'nav_billing')),
        actions: [
          if (draft.lines.isNotEmpty)
            TextButton(
              onPressed: () async {
                if (await askConfirm(context, 'Clear bill?', 'Remove all items from this bill.',
                    danger: true, ok: 'Clear')) {
                  ref.read(billDraftProvider.notifier).clear();
                }
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: !canBill
          ? const EmptyState('You do not have permission to create bills.')
          : Column(
              children: [
                Expanded(
                  child: draft.lines.isEmpty
                      ? const EmptyState(
                          'Bill is empty.\nTap “Add item”, or tell the assistant:\n"Rice 5 kilo add pannu"',
                          icon: Icons.receipt_long_outlined)
                      : totals.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, st) => ErrorState(e),
                          data: (t) => ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              for (var i = 0; i < t.lines.length; i++)
                                Card(
                                  child: ListTile(
                                    title: Text(t.lines[i].name,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                        '${Qty.format(t.lines[i].qtyMilli)} ${t.lines[i].unit} × ${Money.format(t.lines[i].unitPrice)}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(Money.format(t.lines[i].lineTotal),
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: AppColors.error),
                                          onPressed: () => ref
                                              .read(billDraftProvider.notifier)
                                              .set(draft.removeAt(i)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              _sum('Subtotal', Money.format(t.subtotal)),
                              if (t.discount > 0) _sum('Discount', '-${Money.format(t.discount)}'),
                              if (t.tax > 0) _sum('Tax', Money.format(t.tax)),
                              const Divider(),
                              _sum(tr(ref, 'total'), Money.format(t.total), big: true),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: draft.paymentMethod,
                                      decoration: const InputDecoration(labelText: 'Payment'),
                                      items: [
                                        for (final m in BillingService.paymentMethods)
                                          DropdownMenuItem(value: m, child: Text(m.toUpperCase())),
                                      ],
                                      onChanged: (v) => ref
                                          .read(billDraftProvider.notifier)
                                          .set(draft.copyWith(paymentMethod: v)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: () => _discount(context, ref),
                                    icon: const Icon(Icons.percent),
                                    label: const Text('Discount'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 90),
                            ],
                          ),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: BigButton('Add item',
                              icon: Icons.add, outlined: true,
                              onPressed: () => _addProduct(context, ref)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BigButton('Complete',
                              icon: Icons.check_circle,
                              onPressed: draft.lines.isEmpty || !totals.hasValue
                                  ? null
                                  : () => _complete(context, ref, totals.value!)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sum(String k, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: TextStyle(fontSize: big ? 22 : 17, fontWeight: big ? FontWeight.w800 : FontWeight.w500)),
            Text(v, style: TextStyle(fontSize: big ? 26 : 17, fontWeight: big ? FontWeight.w800 : FontWeight.w600,
                color: big ? AppColors.primary : AppColors.text)),
          ],
        ),
      );
}

class _ProductPicker extends StatefulWidget {
  final List<Product> products;
  const _ProductPicker({required this.products});
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = widget.products
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.altNames.toLowerCase().contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search product'),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState('No matching product')
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (c, i) => ListTile(
                        title: Text(list[i].name, style: const TextStyle(fontSize: 18)),
                        subtitle: Text(list[i].retail == null
                            ? 'No retail price'
                            : '${Money.format(list[i].retail!)} / ${list[i].unit}'),
                        trailing: Text('${Qty.format(list[i].stockMilli)} ${list[i].unit}'),
                        onTap: () => Navigator.pop(context, list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
