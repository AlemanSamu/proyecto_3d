import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/projects/project_model.dart';
import '../../providers/project_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final notifier = ref.read(projectsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Proyectos')),
      body: projects.isEmpty
          ? const Center(child: Text('No hay proyectos registrados.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, index) {
                final project = projects[index];
                final color = _statusColor(project.status, Theme.of(context));

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(Icons.folder_open, color: color),
                    ),
                    title: Text(project.name),
                    subtitle: Text(
                      '${_formatDate(project.createdAt)} | ${project.status.label}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar proyecto'),
                            content: Text(
                              'Se eliminaran ${project.imagePaths.length} capturas de "${project.name}". Esta accion no se puede deshacer.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !context.mounted) return;
                        notifier.deleteProject(project.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Proyecto eliminado.')),
                        );
                      },
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: projects.length,
            ),
    );
  }

  String _formatDate(DateTime value) {
    final d = value.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} $hh:$mi';
  }

  Color _statusColor(ProjectStatus status, ThemeData theme) {
    return switch (status) {
      ProjectStatus.draft => const Color(0xFF9AA5BD),
      ProjectStatus.capturing => theme.colorScheme.primary,
      ProjectStatus.reviewReady => const Color(0xFF8F7BFF),
      ProjectStatus.readyToProcess => const Color(0xFF4D92FF),
      ProjectStatus.processing => Colors.orangeAccent,
      ProjectStatus.modelGenerated => const Color(0xFF41D4B8),
      ProjectStatus.exported => Colors.lightGreenAccent,
      ProjectStatus.error => Colors.redAccent,
    };
  }
}
