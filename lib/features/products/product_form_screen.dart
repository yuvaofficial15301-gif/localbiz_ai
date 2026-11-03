import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _alt, _cat, _retail, _whole, _stock,
      _min, _barcode, _desc, _unitCustom;
  String _unit = 'kg';
  bool _active = true;
  DateTime? _expiry;
  bool _busy = false;

  bool get _edit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _alt = TextEditingController(text: p?.altNames ?? '');
    _cat = TextEditingController(text: p?.category ?? '');
    _retail = TextEditingController(text: Money.plain(p?.retail));
    _whole = TextEditingController(text: Money.plain(p?.wholesale));
    _stock = TextEditingController(text: p == null ? '' : Qty.format(p.stockMilli));
    _min = TextEditingController(text: p == null ? '' : Qty.format(p.minStockMilli));
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    final u = p?.unit ?? 'kg';
    if (Units.standard.contains(u)) {
      _unit = u;
      _unitCustom = TextEditingController();
    } else {
      _unit = 'custom';
      _unitCustom = TextEditingController(text: u);
    }
    _active = p?.active ?? true;
    if (p?.expiry != null && p!.expiry!.isNotEmpty) {
      _expiry = DateTime.tryParse(p.expiry!);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _alt, _cat, _retail, _whole, _stock, _min, _barcode, _desc, _unitCustom]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _priceVal(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return Money.parse(v) == null ? 'Enter a valid amount' : null;
  }

  String? _qtyVal(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return Qty.parse(v) == null ? 'Enter a valid number' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final unit = _unit == 'custom' ? _unitCustom.text.trim() : _unit;
    if (unit.isEmpty) {
      toast(context, 'Enter a unit', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final s = sess(ref);
      final svc = ref.read(svcProvider);
      final input = ProductInput(
        name: _name.text,
        altNames: _alt.text,
        category: _cat.text,
        unit: unit,
        retail: _retail.text.trim().isEmpty ? null : Money.parse(_retail.text),
        wholesale: s.can(Perm.viewWholesale) && _whole.text.trim().isNotEmpty
            ? Money.parse(_whole.text)
            : null,
        stockMilli: _stock.text.trim().isEmpty ? 0 : Qty.parse(_stock.text)!,
        minStockMilli: _min.text.trim().isEmpty ? 0 : Qty.parse(_min.text)!,
        barcode: _barcode.text,
        description: _desc.text,
        expiry: _expiry == null ? null : dateOnly(_expiry!),
        active: _active,
      );
      if (_edit) {
        await svc.products.update(s, widget.product!.id, input);
      } else {
        await svc.products.create(s, input);
      }
      ref.read(refreshProvider.notifier).state++;
      if (mounted) Navigator.pop(context);
    } on AppError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(authProvider).session!;
    final seeWholesale = s.can(Perm.viewWholesale);
    return Scaffold(
      appBar: AppBar(title: Text(_edit ? 'Edit product' : 'Add product')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Product name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _alt,
              decoration: const InputDecoration(
                  labelText: 'Other names (comma separated)',
                  helperText: 'e.g. arisi, அரிசி — helps the voice assistant'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cat,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unit,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: [
                for (final u in Units.standard) DropdownMenuItem(value: u, child: Text(u)),
                const DropdownMenuItem(value: 'custom', child: Text('Custom unit…')),
              ],
              onChanged: (v) => setState(() => _unit = v ?? 'kg'),
            ),
            if (_unit == 'custom') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitCustom,
                decoration: const InputDecoration(labelText: 'Custom unit name'),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _retail,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Retail price (${Money.symbol})'),
              validator: _priceVal,
            ),
            if (seeWholesale) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _whole,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Wholesale price (${Money.symbol}) — owner only'),
                validator: _priceVal,
              ),
            ],
            if (!_edit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _stock,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Opening stock'),
                validator: _qtyVal,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Minimum stock (low-stock alert)'),
              validator: _qtyVal,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(labelText: 'Barcode (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _expiry ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _expiry = d);
              },
              icon: const Icon(Icons.event_busy),
              label: Text(_expiry == null
                  ? 'Expiry date (optional)'
                  : 'Expires ${dateOnly(_expiry!)}'),
            ),
            if (_expiry != null)
              TextButton(
                  onPressed: () => setState(() => _expiry = null),
                  child: const Text('Clear expiry date')),
            SwitchListTile(
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 12),
            BigButton(_busy ? '…' : 'Save', icon: Icons.check, onPressed: _busy ? null : _save),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
