import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ai/local_llm/llm_service.dart';
import '../../core/database/app_database.dart';
import '../../core/l10n/languages.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _open(BuildContext c, Widget w) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authProvider).session!;
    Widget tile(IconData i, String t, String sub, VoidCallback f) => Card(
          child: ListTile(
            leading: Icon(i, color: AppColors.primary, size: 28),
            title: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Text(sub),
            trailing: const Icon(Icons.chevron_right),
            onTap: f,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'nav_settings'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (s.can(Perm.editShop))
            tile(Icons.storefront, 'Shop profile', 'Name, address, phone, currency', () => _open(context, const ProfilePage())),
          tile(Icons.language, 'Language', Languages.byCode(ref.watch(langProvider)).name, () => _open(context, const LanguagePage())),
          tile(Icons.record_voice_over, 'Voice settings', 'Offline recognition, spoken replies', () => _open(context, const VoicePage())),
          tile(Icons.memory, 'AI model', 'Optional on-device language model', () => _open(context, const ModelPage())),
          tile(Icons.receipt, 'Billing & tax', 'Tax rate, negative stock', () => _open(context, const BillingSettingsPage())),
          tile(Icons.security, 'Security', 'PIN, fingerprint, auto-lock', () => _open(context, const SecurityPage())),
          if (s.can(Perm.manageUsers))
            tile(Icons.group, 'Staff & permissions', 'Managers and employees', () => _open(context, const StaffPage())),
          if (s.can(Perm.backup))
            tile(Icons.backup, 'Backup & restore', 'Encrypted backup to share or save', () => _open(context, const BackupPage())),
          tile(Icons.notifications, 'Notifications', 'Low stock, expiry, backup reminder', () => _open(context, const NotificationsPage())),
          if (s.can(Perm.viewProducts) || s.can(Perm.viewReports))
            tile(Icons.ios_share, 'Data export', 'Products and transactions (CSV)', () => _open(context, const ExportPage())),
          if (s.can(Perm.security))
            tile(Icons.fact_check, 'Audit log', 'Who changed what', () => _open(context, const AuditPage())),
          tile(Icons.info_outline, 'About', 'Version and privacy', () => _open(context, const AboutPage())),
          const SizedBox(height: 8),
          BigButton('Lock now', icon: Icons.lock, outlined: true,
              onPressed: () => ref.read(authProvider.notifier).lock()),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ profile

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _owner = TextEditingController();
  final _shop = TextEditingController();
  final _phone = TextEditingController();
  final _addr = TextEditingController();
  final _cat = TextEditingController();
  String _currency = '₹';
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      ref.read(svcProvider).shop.profile().then((pr) {
        if (pr == null || !mounted) return;
        setState(() {
          _owner.text = pr.ownerName;
          _shop.text = pr.shopName;
          _phone.text = pr.phone;
          _addr.text = pr.address;
          _cat.text = pr.category;
          _currency = pr.currency;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Shopkeeper name')),
        const SizedBox(height: 12),
        TextField(controller: _shop, decoration: const InputDecoration(labelText: 'Shop name')),
        const SizedBox(height: 12),
        TextField(controller: _cat, decoration: const InputDecoration(labelText: 'Category')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 12),
        TextField(controller: _addr, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: ['₹', r'$', '€', 'Rs '].contains(_currency) ? _currency : '₹',
          decoration: const InputDecoration(labelText: 'Currency'),
          items: const [
            DropdownMenuItem(value: '₹', child: Text('₹  Indian Rupee')),
            DropdownMenuItem(value: r'$', child: Text(r'$  US Dollar')),
            DropdownMenuItem(value: '€', child: Text('€  Euro')),
            DropdownMenuItem(value: 'Rs ', child: Text('Rs  Rupee (text)')),
          ],
          onChanged: (v) => setState(() => _currency = v ?? '₹'),
        ),
        const SizedBox(height: 20),
        BigButton('Save', icon: Icons.check, onPressed: () async {
          try {
            await ref.read(svcProvider).shop.update(sess(ref),
                ownerName: _owner.text, shopName: _shop.text, category: _cat.text,
                phone: _phone.text, address: _addr.text, currency: _currency);
            Money.symbol = _currency;
            ref.read(refreshProvider.notifier).state++;
            if (context.mounted) Navigator.pop(context);
          } on AppError catch (e) {
            if (context.mounted) toast(context, e.message, error: true);
          }
        }),
      ]),
    );
  }
}

// ------------------------------------------------------------------ language

class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(langProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        for (final l in Languages.all)
          Card(
            child: RadioListTile<String>(
              value: l.code,
              groupValue: cur,
              title: Text(l.native, style: const TextStyle(fontSize: 20)),
              subtitle: Text(l.name),
              onChanged: (v) async {
                if (v == null) return;
                ref.read(langProvider.notifier).state = v;
                await ref.read(svcProvider).shop.update(sess(ref), language: v);
              },
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
              'Assistant replies use this language. If you speak or type in another '
              'Indian script, the assistant answers in that language.',
              style: TextStyle(color: AppColors.muted, fontSize: 15)),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ voice

class VoicePage extends ConsumerStatefulWidget {
  const VoicePage({super.key});
  @override
  ConsumerState<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends ConsumerState<VoicePage> {
  bool _offline = true;
  bool _tts = true;
  Map<String, String> _status = {};
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final st = ref.read(svcProvider).settings;
    st.getBool('voice_offline_only', def: true).then((v) => setState(() => _offline = v));
    st.getBool('tts_enabled', def: true).then((v) => setState(() => _tts = v));
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final v = ref.read(svcProvider).voice;
    final res = <String, String>{};
    for (final l in Languages.all) {
      final stt = await v.resolveLocale(l.speechLocale);
      final tts = await v.ttsSupports(l.ttsLocale);
      res[l.code] = 'Listening: ${stt == null ? 'not found on this phone' : 'available ($stt)'}  •  '
          'Speaking: ${tts ? 'available' : 'not found'}';
    }
    if (mounted) setState(() {
      _status = res;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.read(svcProvider).settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Voice settings')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        SwitchListTile(
          title: const Text('Offline speech recognition only'),
          subtitle: const Text('Blocks online recognition. If a language pack is missing, you can type instead.'),
          value: _offline,
          onChanged: (v) async {
            setState(() => _offline = v);
            await st.setBool('voice_offline_only', v);
          },
        ),
        SwitchListTile(
          title: const Text('Speak replies aloud'),
          value: _tts,
          onChanged: (v) async {
            setState(() => _tts = v);
            await st.setBool('tts_enabled', v);
          },
        ),
        const SectionTitle('Language support on this phone'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
              'This lists what the phone reports. It does not prove recognition accuracy. '
              'Install offline speech packs in Android Settings → Google → Speech / Voice typing.',
              style: TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(height: 8),
        BigButton(_checking ? 'Checking…' : 'Check support', icon: Icons.fact_check, outlined: true,
            onPressed: _checking ? null : _check),
        for (final l in Languages.all)
          if (_status[l.code] != null)
            Card(child: ListTile(title: Text('${l.native}  (${l.name})'), subtitle: Text(_status[l.code]!))),
      ]),
    );
  }
}

// ------------------------------------------------------------------ AI model

class ModelPage extends ConsumerStatefulWidget {
  const ModelPage({super.key});
  @override
  ConsumerState<ModelPage> createState() => _ModelPageState();
}

class _ModelPageState extends ConsumerState<ModelPage> {
  LlmStatus? _st;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await ref.read(svcProvider).llm.status();
    if (mounted) setState(() => _st = s);
  }

  Future<void> _import() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      if (r == null || r.files.single.path == null) return;
      setState(() => _progress = 0);
      await ref.read(svcProvider).llm.importModel(r.files.single.path!,
          onProgress: (v) {
        if (mounted) setState(() => _progress = v);
      });
      if (mounted) toast(context, 'Model copied to app storage.');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _progress = null);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _st;
    return Scaffold(
      appBar: AppBar(title: const Text('AI model')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'LocalBiz AI works fully without a language model: a built-in command '
            'engine handles prices, stock, billing and reports. An optional on-device '
            'model can help with unclear sentences. It can only suggest a structured '
            'command; all numbers and changes still come from your database and are '
            'permission-checked.',
            style: TextStyle(fontSize: 16)),
        const SectionTitle('Status'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: st == null
                ? const LinearProgressIndicator()
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st.message, style: const TextStyle(fontSize: 17)),
                    if (st.path != null) Text(p.basename(st.path!), style: const TextStyle(color: AppColors.muted)),
                    if (st.bytes != null) Text('Size: ${(st.bytes! / (1024 * 1024)).toStringAsFixed(0)} MB'),
                    if (st.deviceRamKb != null)
                      Text('Phone memory: ${(st.deviceRamKb! / (1024 * 1024)).toStringAsFixed(1)} GB'),
                  ]),
          ),
        ),
        const SectionTitle('Suggested models (GGUF)'),
        const Text('• ${LocalLlmService.recommendedModel}\n• ${LocalLlmService.smallerModel}',
            style: TextStyle(fontSize: 15)),
        const SizedBox(height: 8),
        const Text(
            'This build has no inference runtime bundled, so an imported model is stored '
            'and checked but not yet executed.',
            style: TextStyle(color: AppColors.warning, fontSize: 15)),
        const SizedBox(height: 16),
        if (_progress != null) LinearProgressIndicator(value: _progress),
        const SizedBox(height: 8),
        BigButton('Import model file (.gguf)', icon: Icons.upload_file, onPressed: _progress != null ? null : _import),
        const SizedBox(height: 10),
        if (st != null && st.path != null)
          BigButton('Remove model', icon: Icons.delete_outline, outlined: true, onPressed: () async {
            if (await askConfirm(context, 'Remove model?', 'The model file will be deleted from this phone.', danger: true, ok: 'Remove')) {
              await ref.read(svcProvider).llm.removeModel();
              await _refresh();
            }
          }),
      ]),
    );
  }
}

// ------------------------------------------------------------------ billing settings

class BillingSettingsPage extends ConsumerStatefulWidget {
  const BillingSettingsPage({super.key});
  @override
  ConsumerState<BillingSettingsPage> createState() => _BillingSettingsPageState();
}

class _BillingSettingsPageState extends ConsumerState<BillingSettingsPage> {
  final _tax = TextEditingController();
  final _taxName = TextEditingController();
  bool _neg = false;

  @override
  void initState() {
    super.initState();
    final st = ref.read(svcProvider).settings;
    st.getInt('tax_percent_bp').then((v) => setState(() => _tax.text = Money.plain(v)));
    st.get('tax_name').then((v) => setState(() => _taxName.text = v ?? 'Tax'));
    st.getBool('allow_negative_stock').then((v) => setState(() => _neg = v));
  }

  @override
  Widget build(BuildContext context) {
    final s = sess(ref);
    final owner = s.can(Perm.security);
    return Scaffold(
      appBar: AppBar(title: const Text('Billing & tax')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _taxName,
          enabled: owner,
          decoration: const InputDecoration(labelText: 'Tax name (e.g. GST)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tax,
          enabled: owner,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Tax rate %  (0 = no tax)'),
        ),
        SwitchListTile(
          title: const Text('Allow negative stock'),
          subtitle: const Text('Lets a bill be saved even if stock is not enough.'),
          value: _neg,
          onChanged: owner ? (v) => setState(() => _neg = v) : null,
        ),
        if (owner)
          BigButton('Save', icon: Icons.check, onPressed: () async {
            final bp = Money.parse(_tax.text.isEmpty ? '0' : _tax.text);
            if (bp == null || bp > 10000) {
              toast(context, 'Enter a valid tax rate', error: true);
              return;
            }
            final st = ref.read(svcProvider).settings;
            await st.setInt('tax_percent_bp', bp);
            await st.set('tax_name', _taxName.text.trim().isEmpty ? 'Tax' : _taxName.text.trim());
            await st.setBool('allow_negative_stock', _neg);
            ref.read(refreshProvider.notifier).state++;
            if (context.mounted) toast(context, 'Saved');
          })
        else
          const Text('Only the owner can change these settings.'),
      ]),
    );
  }
}

// ------------------------------------------------------------------ security

class SecurityPage extends ConsumerStatefulWidget {
  const SecurityPage({super.key});
  @override
  ConsumerState<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends ConsumerState<SecurityPage> {
  bool _bio = false;
  int _lock = 5;

  @override
  void initState() {
    super.initState();
    final st = ref.read(svcProvider).settings;
    st.getBool('biometric_enabled').then((v) => setState(() => _bio = v));
    st.getInt('auto_lock_minutes', def: 5).then((v) => setState(() => _lock = v));
  }

  Future<void> _changePin() async {
    final s = sess(ref);
    final oldPin = await askPin(context, title: 'Current PIN');
    if (oldPin == null || !mounted) return;
    final newPin = await askPin(context, title: 'New PIN (4 to 6 digits)');
    if (newPin == null || !mounted) return;
    final again = await askPin(context, title: 'Repeat new PIN');
    if (again != newPin) {
      if (mounted) toast(context, 'PINs do not match', error: true);
      return;
    }
    try {
      await ref.read(svcProvider).users.changePin(s, s.userId, oldPin, newPin);
      if (mounted) toast(context, 'PIN changed');
    } on AppError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _toggleBio(bool v) async {
    final s = sess(ref);
    if (!s.isOwner) {
      toast(context, 'Only the owner can enable biometric unlock.', error: true);
      return;
    }
    if (v) {
      try {
        final a = LocalAuthentication();
        if (!await a.isDeviceSupported()) {
          if (mounted) toast(context, 'No fingerprint or face lock is set up on this phone.', error: true);
          return;
        }
        final ok = await a.authenticate(
          localizedReason: 'Confirm to enable biometric unlock',
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
        );
        if (!ok) return;
      } catch (e) {
        if (mounted) toast(context, 'Biometric error: $e', error: true);
        return;
      }
    }
    await ref.read(svcProvider).settings.setBool('biometric_enabled', v);
    setState(() => _bio = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: ListTile(
          leading: const Icon(Icons.pin),
          title: const Text('Change my PIN'),
          onTap: _changePin,
        )),
        Card(child: SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: const Text('Fingerprint / face unlock'),
          subtitle: const Text('Owner only. The PIN always works too.'),
          value: _bio,
          onChanged: _toggleBio,
        )),
        Card(child: ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('Auto-lock after'),
          trailing: DropdownButton<int>(
            value: [1, 2, 5, 10, 30].contains(_lock) ? _lock : 5,
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 min')),
              DropdownMenuItem(value: 2, child: Text('2 min')),
              DropdownMenuItem(value: 5, child: Text('5 min')),
              DropdownMenuItem(value: 10, child: Text('10 min')),
              DropdownMenuItem(value: 30, child: Text('30 min')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _lock = v);
              await ref.read(svcProvider).settings.setInt('auto_lock_minutes', v);
            },
          ),
        )),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
              'Your shop data is stored in an encrypted database on this phone. The '
              'encryption key is kept in the Android Keystore. After 5 wrong PINs the '
              'app locks for a while.',
              style: TextStyle(color: AppColors.muted, fontSize: 15)),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ staff

class StaffPage extends ConsumerStatefulWidget {
  const StaffPage({super.key});
  @override
  ConsumerState<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<StaffPage> {
  List<UserRec> _users = [];
  String _role = 'manager';
  Map<String, bool> _perms = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = sess(ref);
    final svc = ref.read(svcProvider);
    final u = await svc.users.listAll(s);
    final pm = await svc.users.rolePermissions(s, _role);
    if (mounted) setState(() {
      _users = u;
      _perms = pm;
    });
  }

  Future<void> _add() async {
    final name = await askText(context, 'Staff name', label: 'Name');
    if (name == null || !mounted) return;
    String role = 'employee';
    final r = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Role'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'manager'), child: const Text('Manager', style: TextStyle(fontSize: 18))),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'employee'), child: const Text('Employee', style: TextStyle(fontSize: 18))),
      ]),
    );
    if (r == null || !mounted) return;
    role = r;
    final pin = await askPin(context, title: 'Set a PIN for $name');
    if (pin == null) return;
    try {
      await ref.read(svcProvider).users.create(sess(ref), name, role, pin);
      await _load();
    } on AppError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  static const _labels = {
    'view_products': 'View products',
    'edit_products': 'Add / edit products',
    'delete_products': 'Delete products',
    'edit_retail_price': 'Change retail prices',
    'create_bill': 'Create bills',
    'view_reports': 'View sales reports',
    'manage_stock': 'Change stock',
    'manage_purchases': 'Record purchases',
    'backup_restore': 'Backup & restore',
  };

  @override
  Widget build(BuildContext context) {
    final s = sess(ref);
    return Scaffold(
      appBar: AppBar(title: const Text('Staff & permissions')),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: 'add_staff', onPressed: _add, icon: const Icon(Icons.person_add), label: const Text('Add staff')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        for (final u in _users)
          Card(
            child: ListTile(
              leading: Icon(u.role == 'owner' ? Icons.verified_user : Icons.person),
              title: Text(u.name),
              subtitle: Text(u.role + (u.active ? '' : ' (disabled)')),
              trailing: u.role == 'owner'
                  ? null
                  : Switch(
                      value: u.active,
                      onChanged: (v) async {
                        await ref.read(svcProvider).users.setActive(s, u.id, v);
                        await _load();
                      },
                    ),
            ),
          ),
        const SectionTitle('What each role can do'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'manager', label: Text('Manager')),
            ButtonSegment(value: 'employee', label: Text('Employee')),
          ],
          selected: {_role},
          onSelectionChanged: (v) {
            _role = v.first;
            _load();
          },
        ),
        for (final e in _labels.entries)
          SwitchListTile(
            title: Text(e.value),
            value: _perms[e.key] ?? false,
            onChanged: (v) async {
              await ref.read(svcProvider).users.setRolePermission(s, _role, e.key, v);
              await _load();
            },
          ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
              'Wholesale prices, owner details, security settings and staff management '
              'are reserved for the owner and cannot be given to anyone else.',
              style: TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

// ------------------------------------------------------------------ backup

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  List<FileSystemEntity> _files = [];
  String? _last;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(svcProvider);
    final f = await svc.backup.listBackups();
    final l = await svc.settings.get('last_backup');
    if (mounted) setState(() {
      _files = f;
      _last = l;
    });
  }

  Future<String?> _pass(String title) => askText(context, title, label: 'Backup passphrase', obscure: true);

  Future<void> _create() async {
    final pass = await _pass('Choose a backup passphrase');
    if (pass == null || !mounted) return;
    final again = await _pass('Repeat the passphrase');
    if (again != pass) {
      if (mounted) toast(context, 'Passphrases do not match', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final info = await ref.read(svcProvider).backup.createBackup(sess(ref), pass);
      if (!mounted) return;
      toast(context, 'Backup created and verified (${(info.bytes / 1024).toStringAsFixed(0)} KB).');
      await Share.shareXFiles([XFile(info.path)],
          text: 'LocalBiz AI backup. Keep your passphrase safe.');
    } on AppError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, 'Backup failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _restore({String? path}) async {
    var file = path;
    if (file == null) {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      if (r == null || r.files.single.path == null) return;
      file = r.files.single.path!;
    }
    if (!mounted) return;
    final ok = await askConfirm(
        context,
        'Restore this backup?',
        'This REPLACES all current shop data (products, bills, users, PINs) with the backup. '
        'A safety backup of the current data is made first. You will need to sign in again.',
        ok: 'Restore',
        danger: true);
    if (!ok || !mounted) return;
    final pass = await _pass('Backup passphrase');
    if (pass == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(svcProvider).backup.restore(sess(ref), file, pass);
      ref.read(refreshProvider.notifier).state++;
      if (mounted) toast(context, 'Restore complete. Please sign in again.');
      ref.read(authProvider.notifier).lock();
    } on AppError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, 'Restore failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(String path) async {
    final pass = await _pass('Backup passphrase');
    if (pass == null) return;
    try {
      final info = await ref.read(svcProvider).backup.verify(path, pass);
      if (mounted) {
        toast(context,
            'Backup OK: ${info.counts['products'] ?? 0} products, ${info.counts['bills'] ?? 0} bills, created ${info.createdAt.substring(0, 16)}');
      }
    } on AppError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: const Color(0xFFFFF8E1),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
                'If your phone is lost or damaged, locally stored data may be lost unless you have a backup.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        Text(_last == null ? 'No backup made yet.' : 'Last backup: ${shortDate(_last!)}',
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        BigButton(_busy ? 'Working…' : 'Create encrypted backup',
            icon: Icons.backup, onPressed: _busy ? null : _create),
        const SizedBox(height: 10),
        BigButton('Restore from a backup file', icon: Icons.restore, outlined: true,
            onPressed: _busy ? null : () => _restore()),
        const SectionTitle('Backups on this phone'),
        if (_files.isEmpty) const Text('None yet.'),
        for (final f in _files)
          Card(
            child: ListTile(
              title: Text(p.basename(f.path), style: const TextStyle(fontSize: 14)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'verify') await _verify(f.path);
                  if (v == 'restore') await _restore(path: f.path);
                  if (v == 'share') await Share.shareXFiles([XFile(f.path)]);
                },
                itemBuilder: (c) => const [
                  PopupMenuItem(value: 'verify', child: Text('Verify')),
                  PopupMenuItem(value: 'share', child: Text('Share / save elsewhere')),
                  PopupMenuItem(value: 'restore', child: Text('Restore')),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ notifications

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final Map<String, bool> _on = {};
  int _backupDays = 7;

  @override
  void initState() {
    super.initState();
    final st = ref.read(svcProvider).settings;
    for (final k in ['notif_low_stock', 'notif_expiry', 'notif_backup']) {
      st.getBool(k, def: true).then((v) => setState(() => _on[k] = v));
    }
    st.getInt('backup_reminder_days', def: 7).then((v) => setState(() => _backupDays = v));
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.read(svcProvider).settings;
    Widget sw(String k, String t, String sub) => SwitchListTile(
          title: Text(t),
          subtitle: Text(sub),
          value: _on[k] ?? true,
          onChanged: (v) async {
            setState(() => _on[k] = v);
            await st.setBool(k, v);
          },
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(children: [
        sw('notif_low_stock', 'Low stock', 'At most once a day'),
        sw('notif_expiry', 'Expiring products', 'At most once a day'),
        sw('notif_backup', 'Backup reminder', 'When a backup is overdue'),
        ListTile(
          title: const Text('Remind me to back up every'),
          trailing: DropdownButton<int>(
            value: [1, 3, 7, 14, 30].contains(_backupDays) ? _backupDays : 7,
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 day')),
              DropdownMenuItem(value: 3, child: Text('3 days')),
              DropdownMenuItem(value: 7, child: Text('7 days')),
              DropdownMenuItem(value: 14, child: Text('14 days')),
              DropdownMenuItem(value: 30, child: Text('30 days')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _backupDays = v);
              await st.setInt('backup_reminder_days', v);
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Alerts are checked when you open and unlock the app. Nothing is sent over the internet.',
              style: TextStyle(color: AppColors.muted)),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ export

class ExportPage extends ConsumerWidget {
  const ExportPage({super.key});

  Future<void> _share(BuildContext context, String name, String csv) async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, name));
    await f.writeAsString(csv);
    await Share.shareXFiles([XFile(f.path)]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = sess(ref);
    final svc = ref.read(svcProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Data export')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (s.can(Perm.viewProducts))
          BigButton('Export products (CSV)', icon: Icons.inventory_2, onPressed: () async {
            try {
              await _share(context, 'localbiz_products.csv', await svc.products.exportCsv(s));
            } on AppError catch (e) {
              if (context.mounted) toast(context, e.message, error: true);
            }
          }),
        const SizedBox(height: 12),
        if (s.can(Perm.viewReports))
          BigButton('Export transactions (CSV)', icon: Icons.receipt_long, outlined: true, onPressed: () async {
            try {
              await _share(context, 'localbiz_transactions.csv', await svc.reports.exportTransactionsCsv(s));
            } on AppError catch (e) {
              if (context.mounted) toast(context, e.message, error: true);
            }
          }),
        const SizedBox(height: 16),
        const Text('Wholesale prices are only included in product exports for the owner.',
            style: TextStyle(color: AppColors.muted)),
      ]),
    );
  }
}

// ------------------------------------------------------------------ audit

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = sess(ref);
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: FutureBuilder<List<AuditRec>>(
        future: ref.read(svcProvider).audit.recent(s, limit: 200),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final l = snap.data!;
          return ListView.builder(
            itemCount: l.length,
            itemBuilder: (c, i) => ListTile(
              dense: true,
              title: Text('${l[i].action}  ${l[i].detail}'),
              subtitle: Text('${shortDate(l[i].at)}  •  ${l[i].user}'),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ about

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (c, snap) {
          final v = snap.hasData ? '${snap.data!.version} (${snap.data!.buildNumber})' : '…';
          return ListView(padding: const EdgeInsets.all(20), children: [
            const Icon(Icons.storefront, size: 64, color: AppColors.primary),
            const SizedBox(height: 8),
            const Center(child: Text('LocalBiz AI', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
            Center(child: Text('Version $v', style: const TextStyle(fontSize: 16))),
            const SizedBox(height: 20),
            const Text(
                'Offline smart shop assistant. Your shop data, prices and bills are stored '
                'only on this phone in an encrypted database. The app does not request the '
                'internet permission and never sends shop data to any server.',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            const Text('Database schema version: ${AppDatabase.schemaVersion}'),
          ]);
        },
      ),
    );
  }
}
