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
import '../purchases/purchase_form_screen.dart';

class BillFilter {
  final String text;
  final String payment;
  final DateTime? from;
  final DateTime? to; // inclusive day
  const BillFilter({this.text = '', this.payment = '', this.from, this.to});
  BillFilter copy({String? text, String? payment, DateTime? from, DateTime? to, bool clearDates = false}) =>
      BillFilter(
        text: text ?? this.text,
        payment: payment ?? this.payment,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
      );
}

final billFilterProvider = StateProvider<BillFilter>((ref) => const BillFilter());

final _billsProvider = FutureProvider.autoDispose<List<BillRec>>((ref) async {
  ref.watch(refreshProvider);
  final f = ref.watch(billFilterProvider);
  final s = ref.read(authProvider).session!;
  return ref.read(svcProvider).billing.list(s,
      from: f.from,
      toExclusive: f.to == null ? null : DateTime(f.to!.year, f.to!.month, f.to!.day + 1),
      query: f.text,
      payment: f.payment);
});

class _ReportData {
  final SalesSummary today, week, month;
  final List<DailySales> days;
  final List<BestSeller> best;
  _ReportData(this.today, this.week, this.month, this.days, this.best);
}

final _reportProvider = FutureProvider.autoDispose<_ReportData>((ref) async {
  ref.watch(refreshProvider);
  final svc = ref.read(svcProvider);
  final s = ref.read(authProvider).session!;
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  return _ReportData(
    await svc.reports.today(s),
    await svc.reports.thisWeek(s),
    await svc.reports.thisMonth(s),
    await svc.reports.lastDays(s, 7),
    await svc.reports.bestSellers(s, monthStart, DateTime(now.year, now.month, now.day + 1)),
  );
});

final _stockMovProvider = FutureProvider.autoDispose<List<StockMovementRec>>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(svcProvider).inventory.movements(ref.read(authProvider).session!);
});

final _priceAllProvider = FutureProvider.autoDispose<List<PriceHistoryRec>>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(svcProvider).pricing.history(ref.read(authProvider).session!);
});

final _purchProvider = FutureProvider.autoDispose<List<PurchaseRec>>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(svcProvider).purchases.list(ref.read(authProvider).session!);
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authProvider).session!;
    final tabs = <_Tab>[
      _Tab('Bills', const _BillsTab(), true),
      _Tab('Reports', const _ReportsTab(), s.can(Perm.viewReports)),
      _Tab('Stock', const _StockTab(), true),
      _Tab('Prices', const _PricesTab(), true),
      _Tab('Purchases', const _PurchasesTab(), s.can(Perm.managePurchases) || s.can(Perm.viewReports)),
    ].where((t) => t.show).toList();
    final idx = ref.watch(historyTabProvider).clamp(0, tabs.length - 1).toInt();
    return DefaultTabController(
      key: ValueKey('${tabs.length}-$idx'),
      length: tabs.length,
      initialIndex: idx,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(ref, 'nav_history')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final t in tabs) Tab(text: t.title)],
          ),
        ),
        body: TabBarView(children: [for (final t in tabs) t.page]),
      ),
    );
  }
}

class _Tab {
  final String title;
  final Widget page;
  final bool show;
  _Tab(this.title, this.page, this.show);
}

class _BillsTab extends ConsumerWidget {
  const _BillsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(billFilterProvider);
    final async = ref.watch(_billsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Bill no, date (2026-11-02), product, payment'),
            onChanged: (v) => ref.read(billFilterProvider.notifier).state = f.copy(text: v),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(f.from == null
                      ? 'Date range'
                      : '${dateOnly(f.from!)} → ${dateOnly(f.to ?? f.from!)}'),
                  onPressed: () async {
                    final r = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (r != null) {
                      ref.read(billFilterProvider.notifier).state =
                          f.copy(from: r.start, to: r.end);
                    }
                  },
                ),
              ),
              if (f.from != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: const Text('Clear dates'),
                    onPressed: () => ref.read(billFilterProvider.notifier).state =
                        f.copy(clearDates: true),
                  ),
                ),
              for (final m in BillingService.paymentMethods)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(m.toUpperCase()),
                    selected: f.payment == m,
                    onSelected: (v) => ref.read(billFilterProvider.notifier).state =
                        f.copy(payment: v ? m : ''),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => ErrorState(e),
            data: (l) => l.isEmpty
                ? const EmptyState('No bills found.', icon: Icons.receipt_long_outlined)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: l.length,
                    itemBuilder: (c, i) {
                      final b = l[i];
                      return Card(
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ReceiptScreen(billId: b.id))),
                          title: Text(b.billNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${shortDate(b.createdAt)}  •  ${b.paymentMethod.toUpperCase()}'),
                          trailing: Text(Money.format(b.total),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_reportProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(e),
      data: (d) => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(children: [
            Expanded(child: StatCard('Today', Money.format(d.today.total), Icons.today)),
            const SizedBox(width: 10),
            Expanded(child: StatCard('${d.today.count} bills', '${d.today.count}', Icons.receipt)),
          ]),
          Row(children: [
            Expanded(child: StatCard('This week (${d.week.count} bills)', Money.format(d.week.total), Icons.date_range)),
            const SizedBox(width: 10),
            Expanded(child: StatCard('This month (${d.month.count} bills)', Money.format(d.month.total), Icons.calendar_month)),
          ]),
          const SectionTitle('Last 7 days'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: BarChart(
                labels: [for (final x in d.days) '${x.day.day}/${x.day.month}'],
                values: [for (final x in d.days) x.total],
                fmt: (v) => Money.format(v),
              ),
            ),
          ),
          const SectionTitle('Best sellers this month'),
          if (d.best.isEmpty)
            const Text('No sales yet this month.', style: TextStyle(fontSize: 16))
          else
            Card(
              child: Column(children: [
                for (var i = 0; i < d.best.length; i++)
                  ListTile(
                    leading: CircleAvatar(
                        backgroundColor: AppColors.secondary,
                        child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))),
                    title: Text(d.best[i].name),
                    subtitle: Text('${Qty.format(d.best[i].qtyMilli)} ${d.best[i].unit}'),
                    trailing: Text(Money.format(d.best[i].amount),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _StockTab extends ConsumerWidget {
  const _StockTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_stockMovProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(e),
      data: (l) => l.isEmpty
          ? const EmptyState('No stock movements yet.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
              itemCount: l.length,
              itemBuilder: (c, i) {
                final m = l[i];
                return Card(
                  child: ListTile(
                    leading: Icon(m.changeMilli >= 0 ? Icons.south_west : Icons.north_east,
                        color: m.changeMilli >= 0 ? AppColors.success : AppColors.warning),
                    title: Text(m.productName),
                    subtitle: Text('${m.reason}${m.ref.isEmpty ? '' : ' • ${m.ref}'}\n${shortDate(m.createdAt)}'),
                    isThreeLine: true,
                    trailing: Text('${m.changeMilli >= 0 ? '+' : ''}${Qty.format(m.changeMilli)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                );
              },
            ),
    );
  }
}

class _PricesTab extends ConsumerWidget {
  const _PricesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_priceAllProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(e),
      data: (l) => l.isEmpty
          ? const EmptyState('No price changes yet.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
              itemCount: l.length,
              itemBuilder: (c, i) {
                final r = l[i];
                return Card(
                  child: ListTile(
                    title: Text('${r.productName} — ${r.type == 'retail' ? 'Retail' : 'Wholesale'}'),
                    subtitle: Text('${shortDate(r.changedAt)}  •  ${r.changedBy}'),
                    trailing: Text(
                        '${r.oldPrice == null ? '—' : Money.format(r.oldPrice!)} → ${Money.format(r.newPrice)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                );
              },
            ),
    );
  }
}

class _PurchasesTab extends ConsumerWidget {
  const _PurchasesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authProvider).session!;
    final async = ref.watch(_purchProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: s.can(Perm.managePurchases)
          ? FloatingActionButton.extended(
              heroTag: 'add_purchase',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PurchaseFormScreen())),
              icon: const Icon(Icons.add),
              label: const Text('New purchase'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(e),
        data: (l) => l.isEmpty
            ? const EmptyState('No purchases recorded.', icon: Icons.local_shipping_outlined)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: l.length,
                itemBuilder: (c, i) {
                  final p = l[i];
                  return Card(
                    child: ListTile(
                      title: Text(p.supplier, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${p.date}${p.invoiceRef.isEmpty ? '' : ' • ${p.invoiceRef}'}  •  ${p.status.toUpperCase()}'),
                      trailing: Text(Money.format(p.total),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      onLongPress: p.status == 'pending' && s.can(Perm.managePurchases)
                          ? () async {
                              if (await askConfirm(context, 'Mark as paid?', '${p.supplier} ${Money.format(p.total)}')) {
                                await ref.read(svcProvider).purchases.markPaid(s, p.id);
                                ref.read(refreshProvider.notifier).state++;
                              }
                            }
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
