import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../daily_report/daily_report_screen.dart';
import '../project/project_repository.dart';
import '../project/selected_project_controller.dart';
import '../settings/settings_screen.dart';
import '../work_orders/work_order_list_screen.dart';
import 'home_shell_providers.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _titles = ['Radni nalozi', 'Dnevni izvještaj', 'Postavke'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(activeProjectsProvider);
    ref.watch(selectedProjectIdProvider);

    final index = ref.watch(homeShellTabProvider);
    final project = ref.watch(selectedProjectProvider);
    final showProjectSubtitle = index <= 1 && project != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[index]),
        bottom: showProjectSubtitle
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      project.shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              )
            : null,
      ),
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
