import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'receipt_service.dart';

class _ReceiptData {
  final ShopProfile shop;
  final BillRec bill;
  final List<BillItemRec> items;
  final Uint8List png;
  _ReceiptData(this.shop, this.bill, this.items, this.png);
}

final _receiptProvider =
    FutureProvider.autoDispose.family<_ReceiptData, int>((ref, id) async {
  final svc = ref.read(svcProvider);
  final s = ref.read(authProvider).session!;
  final shop = await svc.shop.profile();
  final bill = await svc.billing.getBill(s, id);
  if (shop == null || bill == null) throw StateError('Bill not found');
  final items = await svc.billing.items(s, id);
  final png = await ReceiptService.renderPng(shop, bill, items);
  return _ReceiptData(shop, bill, items, png);
});

class ReceiptScreen extends ConsumerWidget {
  final int billId;
  const ReceiptScreen({super.key, required this.billId});

  Future<void> _sharePdf(BuildContext context, _ReceiptData d) async {
    try {
      final bytes = await ReceiptService.pdfFor(d.shop, d.bill, d.items);
      final dir = await getTemporaryDirectory();
      final f = File(p.join(dir.path, 'receipt_${d.bill.billNo}.pdf'));
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)], text: 'Receipt ${d.bill.billNo}');
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _print(BuildContext context, _ReceiptData d) async {
    try {
      final bytes = await ReceiptService.pdfFor(d.shop, d.bill, d.items);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: d.bill.billNo);
    } catch (e) {
      if (context.mounted) toast(context, 'Printing is not available: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_receiptProvider(billId));
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(e),
        data: (d) => Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Image.memory(d.png),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: BigButton('Share PDF',
                        icon: Icons.share, onPressed: () => _sharePdf(context, d)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BigButton('Print',
                        icon: Icons.print, outlined: true, onPressed: () => _print(context, d)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
