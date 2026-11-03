import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});
  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _supplier = TextEditingController();
  final _invoice = TextEditingController();
  DateTime _date = DateTime.now();
  String _status = 'paid';
  final List<PurchaseLineInput> _lines = [];
  bool _busy = false;

  @override
  void dispose() {
    _supplier.dispose();
    _invoice.dispose();
    super.dispose();
  }

  int get _total => _lines.fold<int>(
      0, (a, l) => a + Qty.lineTotal(l.unitCost, l.qtyMilli));

  Future<void> _addLine() async {
    final s = sess(ref);
    final prods = await ref.read(svcProvider).products.list(s);
    if (!mounted || prods.isEmpty) {
      if (mounted) toast(context, 'Add products first.', error: true);
      return;
    }
    final p = await showModalBottomSheet<Product>(
      context: context,
      builder: (c) => ListView(
        children: [
          for (final x in prods)
            ListTile(
              title: Text(x.name, style: const TextStyle(fontSize: 18)),
              subtitle: Text(x.unit),
              onTap: () => Navigator.pop(c, x),
            ),
        ],
      ),
    );
    if (p == null || !mounted) return;
    final qtyTxt = await askText(context, '${p.name} — quantity bought', label: 'Quantity (${p.unit})');
    if (qtyTxt == null) return;
    final costTxt = await askText(context, 'Purchase price per ${p.unit}',
        label: 'Cost (${Money.symbol})');
    if (costTxt == null) return;
    final q = Qty.parse(qtyTxt);
    final c = Money.parse(costTxt);
    if (q == null || q <= 0 || c == null) {
      if (mounted) toast(context, 'Invalid quantity or cost', error: true);
      return;
    }
    setState(() => _lines.add(PurchaseLineInput(p.id, p.name, q, p.unit, c)));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(svcProvider).purchases.create(
            sess(ref),
            supplier: _supplier.text,
            date: dateOnly(_date),
            paymentStatus: _status,
            invoiceRef: _invoice.text,
            lines: _lines,
          );
      ref.read(refreshProvider.notifier).state++;
      if (mounted) Navigator.pop(context);
    } on AppError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New purchase')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _supplier, decoration: const InputDecoration(labelText: 'Supplier *')),
          const SizedBox(height: 12),
          TextField(controller: _invoice, decoration: const InputDecoration(labelText: 'Invoice reference (optional)')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now());
              if (d != null) setState(() => _date = d);
            },
            icon: const Icon(Icons.event),
            label: Text('Date: ${dateOnly(_date)}'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Payment status'),
            items: const [
              DropdownMenuItem(value: 'paid', child: Text('Paid')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'paid'),
          ),
          const SectionTitle('Items'),
          for (var i = 0; i < _lines.length; i++)
            Card(
              child: ListTile(
                title: Text(_lines[i].name),
                subtitle: Text(
                    '${Qty.format(_lines[i].qtyMilli)} ${_lines[i].unit} × ${Money.format(_lines[i].unitCost)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _lines.removeAt(i)),
                ),
              ),
            ),
          BigButton('Add item', icon: Icons.add, outlined: true, onPressed: _addLine),
          const SizedBox(height: 12),
          Text('Total: ${Money.format(_total)}',
              style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'Purchase costs are recorded separately and never change your selling prices.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          BigButton(_busy ? '…' : 'Save purchase',
              icon: Icons.check, onPressed: _busy || _lines.isEmpty ? null : _save),
        ],
      ),
    );
  }
}
