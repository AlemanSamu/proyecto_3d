import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/projects/project_model.dart';
import '../../providers/project_providers.dart';

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final doneProjects = [
      for (final project in projects)
        if (project.status == ProjectStatus.done && project.modelPath != null)
          project,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Modelos 3D')),
      body: doneProjects.isEmpty
          ? const Center(
              child: Text('Aun no hay modelos generados para visualizar.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, index) {
                final project = doneProjects[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.view_in_ar),
                    title: Text(project.name),
                    subtitle: Text(project.modelPath ?? 'Sin ruta de modelo'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Visor 3D se integra en el siguiente objetivo.',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: doneProjects.length,
            ),
    );
  }
}
