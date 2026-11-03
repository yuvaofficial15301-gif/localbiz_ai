import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../assistant/assistant_screen.dart';

class DashData {
  final SalesSummary today;
  final bool showSales;
  final int productCount;
  final List<Product> low;
  final List<AuditRec> recent;
  const DashData(this.today, this.showSales, this.productCount, this.low, this.recent);
}

final dashProvider = FutureProvider.autoDispose<DashData>((ref) async {
  ref.watch(refreshProvider);
  final svc = ref.watch(svcProvider);
  final s = ref.read(authProvider).session!;
  final showSales = s.can(Perm.viewReports);
  final today = showSales ? await svc.reports.today(s) : const SalesSummary(0, 0);
  final count = await svc.products.count();
  final low = await svc.inventory.lowStock(s);
  final recent = await svc.audit.activityFeed();
  return DashData(today, showSales, count, low, recent);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final dash = ref.watch(dashProvider);
    final online = ref.watch(onlineProvider).valueOrNull ?? false;
    final date = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.read(refreshProvider.notifier).state++,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.shopName ?? '',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(profile?.ownerName ?? '',
                          style: const TextStyle(fontSize: 17, color: AppColors.muted)),
                      Text(date, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(online ? Icons.wifi : Icons.wifi_off,
                      size: 18, color: online ? AppColors.warning : AppColors.success),
                  label: Text(tr(ref, online ? 'online' : 'offline')),
                  backgroundColor: online ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => openAssistant(context, autoListen: true),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 24,
                              spreadRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.mic, size: 72, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(tr(ref, 'talk_title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (ref.watch(langProvider) != 'ta')
                    const Text('உங்கள் கடையுடன் பேசுங்கள்',
                        style: TextStyle(color: AppColors.muted, fontSize: 15)),
                  TextButton.icon(
                    onPressed: () => openAssistant(context),
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Type instead'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            dash.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, st) => ErrorState(e),
              data: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.45,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 4,
                    children: [
                      if (d.showSales)
                        StatCard(tr(ref, 'today_sales'), Money.format(d.today.total), Icons.payments),
                      if (d.showSales)
                        StatCard(tr(ref, 'bills'), '${d.today.count}', Icons.receipt_long),
                      StatCard(tr(ref, 'nav_products'), '${d.productCount}', Icons.inventory_2),
                      StatCard(tr(ref, 'low_stock'), '${d.low.length}', Icons.warning_amber_rounded,
                          color: d.low.isEmpty ? AppColors.success : AppColors.warning),
                    ],
                  ),
                  if (d.low.isNotEmpty) ...[
                    SectionTitle(tr(ref, 'low_stock')),
                    Card(
                      child: Column(
                        children: [
                          for (final p in d.low.take(5))
                            ListTile(
                              leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                              title: Text(p.name),
                              trailing: Text('${Qty.format(p.stockMilli)} ${p.unit}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  SectionTitle(tr(ref, 'recent')),
                  if (d.recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Nothing yet. Add products and make your first bill.',
                          style: TextStyle(color: AppColors.muted, fontSize: 16)),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final a in d.recent)
                            ListTile(
                              dense: true,
                              leading: Icon(_icon(a.action), color: AppColors.primary),
                              title: Text(_label(a)),
                              subtitle: Text(shortDate(a.at)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  static IconData _icon(String a) {
    switch (a) {
      case 'bill_created':
        return Icons.receipt_long;
      case 'price_changed':
        return Icons.sell;
      case 'product_created':
        return Icons.add_box;
      case 'purchase_created':
        return Icons.local_shipping;
      default:
        return Icons.inventory;
    }
  }

  static String _label(AuditRec a) {
    switch (a.action) {
      case 'bill_created':
        return 'Bill ${a.detail}';
      case 'price_changed':
        // wholesale details are not shown on the home feed
        return a.detail.contains('wholesale') ? 'Price updated' : 'Price: ${a.detail}';
      case 'product_created':
        return 'Product added: ${a.detail}';
      case 'purchase_created':
        return 'Purchase: ${a.detail}';
      case 'stock_in':
        return 'Stock in: ${a.detail}';
      default:
        return 'Stock updated: ${a.detail}';
    }
  }
}
