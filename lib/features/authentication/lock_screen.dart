import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  List<UserRec> _users = [];
  int? _userId;
  String _msg = '';
  bool _bio = false;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final users = await ref.read(authProvider.notifier).loginChoices();
    final bio = await ref.read(svcProvider).settings.getBool('biometric_enabled');
    if (!mounted) return;
    setState(() {
      _users = users;
      _userId = users.isEmpty ? null : users.first.id;
      _bio = bio;
    });
    if (bio) _biometric();
  }

  Future<void> _biometric() async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return;
      final ok = await auth.authenticate(
        localizedReason: 'Unlock LocalBiz AI',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok) {
        await ref.read(authProvider.notifier).loginOwnerBiometric();
      }
    } catch (_) {
      if (mounted) setState(() => _msg = 'Biometric unavailable. Use your PIN.');
    }
  }

  Future<void> _digit(String d) async {
    if (_busy || _pin.length >= 6) return;
    setState(() {
      _pin += d;
      _msg = '';
    });
  }

  Future<void> _submit() async {
    if (_pin.length < 4 || _userId == null || _busy) return;
    setState(() => _busy = true);
    final err = await ref.read(authProvider.notifier).loginPin(_userId!, _pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin = '';
      if (err == 'wrong') _msg = 'Wrong PIN. Try again.';
      if (err == 'locked') _msg = 'Too many attempts. Please wait.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final until = auth.lockedUntil;
    final wait = (until != null && until.isAfter(DateTime.now()))
        ? until.difference(DateTime.now()).inSeconds
        : 0;
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: AppColors.primary),
                const SizedBox(height: 8),
                const Text('LocalBiz AI',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 4),
                const Text('Enter your PIN', style: TextStyle(fontSize: 18)),
                if (_users.length > 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final u in _users)
                        ChoiceChip(
                          label: Text('${u.name} (${u.role})'),
                          selected: _userId == u.id,
                          onSelected: (_) => setState(() {
                            _userId = u.id;
                            _pin = '';
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 6; i++)
                      Container(
                        margin: const EdgeInsets.all(6),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length ? AppColors.primary : Colors.transparent,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 24,
                  child: Text(
                    wait > 0 ? 'Locked for $wait s' : _msg,
                    style: const TextStyle(color: AppColors.error, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 8),
                _pad(wait > 0),
                if (_bio)
                  TextButton.icon(
                    onPressed: _biometric,
                    icon: const Icon(Icons.fingerprint, size: 30),
                    label: const Text('Use fingerprint / face', style: TextStyle(fontSize: 17)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pad(bool disabled) {
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: 78,
            height: 64,
            child: ElevatedButton(
              onPressed: disabled ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.text,
                elevation: 1,
              ),
              child: icon != null
                  ? Icon(icon)
                  : Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            ),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9']
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in row) key(d, onTap: () => _digit(d))],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key('', icon: Icons.backspace_outlined, onTap: () {
              if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
            }),
            key('0', onTap: () => _digit('0')),
            key('', icon: Icons.check_circle, onTap: _submit),
          ],
        ),
      ],
    );
  }
}
