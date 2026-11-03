import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductQuery {
  final String text;
  final String filter;
  final String sort;
  final String category;
  const ProductQuery({this.text = '', this.filter = 'all', this.sort = 'name', this.category = ''});
  ProductQuery copy({String? text, String? filter, String? sort, String? category}) =>
      ProductQuery(
          text: text ?? this.text,
          filter: filter ?? this.filter,
          sort: sort ?? this.sort,
          category: category ?? this.category);
}

final productQueryProvider = StateProvider<ProductQuery>((ref) => const ProductQuery());

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  ref.watch(refreshProvider);
  final q = ref.watch(productQueryProvider);
  final s = ref.read(authProvider).session!;
  return ref.read(svcProvider).products.list(s,
      query: q.text, filter: q.filter, sort: q.sort, category: q.category);
});

final categoriesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(svcProvider).products.categories();
});

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final s = sess(ref);
      final csv = await ref.read(svcProvider).products.exportCsv(s);
      final dir = await getTemporaryDirectory();
      final f = File(p.join(dir.path, 'localbiz_products.csv'));
      await f.writeAsString(csv);
      await Share.shareXFiles([XFile(f.path)], text: 'LocalBiz AI products');
    } catch (e) {
      toast(context, '$e', error: true);
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      if (r == null || r.files.single.path == null) return;
      final text = await File(r.files.single.path!).readAsString();
      final res = await ref.read(svcProvider).products.importCsv(sess(ref), text);
      ref.read(refreshProvider.notifier).state++;
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Import finished'),
          content: Text(
              'Added: ${res.added}\nSkipped (already exist): ${res.skipped}'
              '${res.errors.isEmpty ? '' : '\n\nProblems:\n${res.errors.take(8).join('\n')}'}'),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authProvider).session!;
    final q = ref.watch(productQueryProvider);
    final list = ref.watch(productsProvider);
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final canEdit = s.can(Perm.editProducts);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'nav_products')),
        actions: [
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'import' ? _import(context, ref) : _export(context, ref),
              itemBuilder: (c) => const [
                PopupMenuItem(value: 'import', child: Text('Import products (CSV)')),
                PopupMenuItem(value: 'export', child: Text('Export products (CSV)')),
              ],
            ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: 'add_product',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProductFormScreen())),
              icon: const Icon(Icons.add),
              label: Text(tr(ref, 'add')),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr(ref, 'search'),
              ),
              onChanged: (v) => ref.read(productQueryProvider.notifier).state = q.copy(text: v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final f in const [
                  ['all', 'All'], ['active', 'Active'], ['inactive', 'Inactive'], ['low', 'Low stock']
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(f[1]),
                      selected: q.filter == f[0],
                      onSelected: (_) =>
                          ref.read(productQueryProvider.notifier).state = q.copy(filter: f[0]),
                    ),
                  ),
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(c),
                      selected: q.category == c,
                      onSelected: (v) => ref.read(productQueryProvider.notifier).state =
                          q.copy(category: v ? c : ''),
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort),
                  onSelected: (v) =>
                      ref.read(productQueryProvider.notifier).state = q.copy(sort: v),
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 'name', child: Text('Sort by name')),
                    PopupMenuItem(value: 'stock', child: Text('Lowest stock first')),
                    PopupMenuItem(value: 'price', child: Text('Highest price first')),
                    PopupMenuItem(value: 'updated', child: Text('Recently updated')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => ErrorState(e),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(canEdit
                      ? 'No products yet.\nTap Add to create your first product, or say it to the assistant.'
                      : 'No products found.', icon: Icons.inventory_2_outlined);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  itemCount: items.length,
                  itemBuilder: (c, i) => _tile(context, ref, items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, Product p) {
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
        title: Text(p.name,
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                decoration: p.active ? null : TextDecoration.lineThrough)),
        subtitle: Text(
            '${p.retail == null ? 'No retail price' : '${Money.format(p.retail!)} / ${p.unit}'}'
            '${p.category.isEmpty ? '' : '  •  ${p.category}'}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${Qty.format(p.stockMilli)} ${p.unit}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: p.isLow ? AppColors.warning : AppColors.text)),
            if (p.isLow)
              const Text('Low', style: TextStyle(color: AppColors.warning, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
