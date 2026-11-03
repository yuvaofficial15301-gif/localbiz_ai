import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../assistant/assistant_screen.dart';
import '../billing/billing_screen.dart';
import '../history/history_screen.dart';
import '../products/products_screen.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    final pages = const [
      HomeScreen(),
      ProductsScreen(),
      BillingScreen(),
      HistoryScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      floatingActionButton: tab == 0
          ? null
          : FloatingActionButton(
              heroTag: 'assistant_fab',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => openAssistant(context),
              child: const Icon(Icons.mic, size: 30),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(tabProvider.notifier).state = i,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: tr(ref, 'nav_home')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: tr(ref, 'nav_products')),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: tr(ref, 'nav_billing')),
          NavigationDestination(icon: const Icon(Icons.history), selectedIcon: const Icon(Icons.history), label: tr(ref, 'nav_history')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: tr(ref, 'nav_settings')),
        ],
      ),
    );
  }
}
