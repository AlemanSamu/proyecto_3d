import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/projects/project_model.dart';
import '../../../domain/projects/reconstruction_result.dart';
import '../../../domain/projects/project_workflow.dart';
import '../../providers/project_providers.dart';
import '../../utils/presentation_formatters.dart';
import '../capture/capture_screen.dart';
import '../model_viewer_screen.dart';
import '../project_workspace_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final sorted = [...projects]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: sorted.isEmpty
          ? const Center(child: Text('No hay proyectos registrados.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final project = sorted[index];
                final thumb = _thumbnailPath(project);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: thumb == null
                                ? Container(
                                    color: const Color(0xFF101721),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.photo_outlined),
                                  )
                                : Image.file(
                                    File(thumb),
                                    fit: BoxFit.cover,
                                    cacheWidth: 280,
                                    cacheHeight: 280,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(formatDateTime(project.updatedAt)),
                              const SizedBox(height: 4),
                              Text(project.reconstructionResult.label),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _openResult(context, project),
                                      child: const Text('Ver resultado'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => CaptureScreen(
                                              initialProjectId: project.id,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Reintentar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String? _thumbnailPath(ProjectModel project) {
    if (project.coverImagePath != null && project.coverImagePath!.isNotEmpty) {
      return project.coverImagePath;
    }
    if (project.photos.isEmpty) return null;
    return project.photos.last.thumbnailPath;
  }

  Future<void> _openResult(BuildContext context, ProjectModel project) async {
    if (project.hasGeneratedModel) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ModelViewerScreen(projectId: project.id),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectWorkspaceScreen(projectId: project.id),
      ),
    );
  }
}
