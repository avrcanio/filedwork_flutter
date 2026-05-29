import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../daily_report/daily_report_screen.dart';
import '../settings/settings_screen.dart';
import '../work_orders/work_order_list_screen.dart';
import 'home_shell_providers.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _titles = ['Radni nalozi', 'Dnevni izvještaj', 'Postavke'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeShellTabProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_titles[index])),
      body: IndexedStack(
        index: index,
        children: const [
          WorkOrderListScreen(),
          DailyReportScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(homeShellTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Nalozi',
          ),
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Izvještaj',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Postavke',
          ),
        ],
      ),
    );
  }
}
