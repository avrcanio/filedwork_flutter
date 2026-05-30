import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'project_models.dart';
import 'project_repository.dart';
import 'selected_project_controller.dart';

/// Traka za odabir aktivnog projekta (bez opcije „Svi projekti”).
class ProjectSelectorBar extends ConsumerWidget {
  const ProjectSelectorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(activeProjectsProvider);
    final selected = ref.watch(selectedProjectProvider);

    return projectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Greška pri učitavanju projekata: $e'),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nema aktivnih projekata.'),
          );
        }

        final label = selected?.shortLabel ?? 'Odaberi projekt';
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: projects.length == 1
                  ? null
                  : () => _showProjectPicker(context, ref, projects, selected),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (projects.length > 1)
                      Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProjectPicker(
    BuildContext context,
    WidgetRef ref,
    List<FieldworkProject> projects,
    FieldworkProject? selected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Projekt',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final isSelected = project.id == selected?.id;
                    return ListTile(
                      leading: Text(
                        '#${project.id}',
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      title: Text(project.name),
                      subtitle: project.clientName.isNotEmpty
                          ? Text(project.clientName)
                          : null,
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(ctx).colorScheme.primary,
                            )
                          : null,
                      selected: isSelected,
                      onTap: () async {
                        await ref
                            .read(selectedProjectIdProvider.notifier)
                            .setProject(project.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
