import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/lock_screen.dart';
import 'features/dashboard/main_shell.dart';
import 'features/onboarding/onboarding_screen.dart';

class LocalBizApp extends ConsumerWidget {
  const LocalBizApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'LocalBiz AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const BootGate(),
      builder: (context, child) {
        return _SecurityLayer(child: child ?? const SizedBox());
      },
    );
  }
}

/// Tracks activity for auto-lock and draws the lock screen above every route.
class _SecurityLayer extends ConsumerStatefulWidget {
  final Widget child;
  const _SecurityLayer({required this.child});
  @override
  ConsumerState<_SecurityLayer> createState() => _SecurityLayerState();
}

class _SecurityLayerState extends ConsumerState<_SecurityLayer>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final svcAsync = ref.read(servicesProvider);
    if (!svcAsync.hasValue) return;
    final auth = ref.read(authProvider);
    if (!auth.ready || auth.locked || auth.session == null) return;
    final mins = await svcAsync.requireValue.settings.getInt('auto_lock_minutes', def: 5);
    if (mins <= 0) return;
    final idle = DateTime.now().difference(ref.read(authProvider.notifier).lastActivity);
    if (idle.inMinutes >= mins) ref.read(authProvider.notifier).lock();
  }

  @override
  Widget build(BuildContext context) {
    final svcAsync = ref.watch(servicesProvider);
    final locked = svcAsync.hasValue
        ? ref.watch(authProvider.select((a) => a.ready && a.locked))
        : false;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (ref.read(servicesProvider).hasValue) {
          ref.read(authProvider.notifier).touch();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (locked) const Positioned.fill(child: LockScreen()),
        ],
      ),
    );
  }
}

class BootGate extends ConsumerWidget {
  const BootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(servicesProvider);
    return svc.when(
      loading: () => const _Splash(),
      error: (e, st) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not open the secure database.\n\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 16)),
          ),
        ),
      ),
      data: (_) {
        final auth = ref.watch(authProvider);
        if (!auth.ready) return const _Splash();
        final profile = ref.watch(profileProvider);
        return profile.when(
          loading: () => const _Splash(),
          error: (e, st) => Scaffold(body: Center(child: Text('$e'))),
          data: (p) {
            if (p == null) return const OnboardingScreen();
            if (auth.session == null) return const _Splash();
            return const MainShell();
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront, size: 72, color: AppColors.primary),
              SizedBox(height: 12),
              Text('LocalBiz AI',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
}
