import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/languages.dart';
import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/security/security_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _owner = TextEditingController();
  final _shop = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  String _category = 'Grocery shop';
  String _lang = 'en';
  String _currency = '₹';
  DateTime? _opening;
  bool _busy = false;

  static const categories = [
    'Grocery shop', 'Vegetable shop', 'Bakery', 'Stationery shop',
    'Medical shop', 'Clothing shop', 'Hardware shop', 'General store',
    'Wholesale / retail business', 'Other',
  ];

  @override
  void dispose() {
    for (final c in [_owner, _shop, _phone, _address, _pin, _pin2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final svc = ref.read(svcProvider);
      await svc.shop.register(
        ownerName: _owner.text,
        shopName: _shop.text,
        category: _category,
        phone: _phone.text,
        address: _address.text,
        language: _lang,
        currency: _currency,
        openingDate: _opening == null ? null : dateOnly(_opening!),
        pin: _pin.text,
      );
      ref.read(langProvider.notifier).state = _lang;
      await ref.read(authProvider.notifier).loginAfterRegister();
      ref.read(refreshProvider.notifier).state++;
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
    String t(String k) => S.t(_lang, k);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.storefront, size: 64, color: AppColors.primary),
              const SizedBox(height: 8),
              Text('Welcome to LocalBiz AI',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text(
                'Set up your shop. Everything stays on this phone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 16),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _lang,
                decoration: const InputDecoration(labelText: 'Preferred language'),
                items: [
                  for (final l in Languages.all)
                    DropdownMenuItem(value: l.code, child: Text('${l.native}  (${l.name})')),
                ],
                onChanged: (v) => setState(() => _lang = v ?? 'en'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _owner,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Shopkeeper name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shop,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Shop name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Shop category'),
                items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number (optional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Shop address (optional)'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: const [
                  DropdownMenuItem(value: '₹', child: Text('₹  Indian Rupee (INR)')),
                  DropdownMenuItem(value: r'$', child: Text(r'$  US Dollar')),
                  DropdownMenuItem(value: '€', child: Text('€  Euro')),
                  DropdownMenuItem(value: 'Rs ', child: Text('Rs  Rupee (text)')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? '₹'),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _opening ?? DateTime.now(),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _opening = d);
                },
                icon: const Icon(Icons.event),
                label: Text(_opening == null
                    ? 'Shop opening date (optional)'
                    : 'Opened on ${dateOnly(_opening!)}'),
              ),
              const SectionTitle('Owner PIN (4 to 6 digits)'),
              TextFormField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Create PIN *'),
                validator: (v) =>
                    SecurityService.validPin(v ?? '') ? null : 'Use 4 to 6 digits',
              ),
              TextFormField(
                controller: _pin2,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Confirm PIN *'),
                validator: (v) => v == _pin.text ? null : 'PINs do not match',
              ),
              const SizedBox(height: 8),
              const Text(
                'Your PIN protects wholesale prices and owner details. '
                'If you forget it, it cannot be recovered without a backup.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              BigButton(_busy ? '…' : t('save'),
                  icon: Icons.check, onPressed: _busy ? null : _submit),
            ],
          ),
        ),
      ),
    );
  }
}
