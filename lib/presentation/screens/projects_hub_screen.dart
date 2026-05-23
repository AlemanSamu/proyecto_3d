import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projects/project_model.dart';
import '../../domain/projects/reconstruction_result.dart';
import '../../domain/projects/project_workflow.dart';
import '../providers/project_providers.dart';
import '../utils/presentation_formatters.dart';
import '../widgets/app_surface_card.dart';
import 'capture/capture_screen.dart';
import 'model_viewer_screen.dart';
import 'project_workspace_screen.dart';

class ProjectsHubScreen extends ConsumerWidget {
  const ProjectsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final sorted = [...projects]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Text(
          'Historial',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tus escaneos recientes y su resultado.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        if (sorted.isEmpty)
          const AppSurfaceCard(subtitle: 'Aun no hay escaneos guardados.')
        else
          for (final project in sorted) ...[
            _HistoryCard(project: project),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbnailPath(project);
    final reconstruction = project.reconstructionResult;

    return AppSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 88,
              height: 88,
              child: thumb == null
                  ? Container(
                      color: const Color(0xFF101721),
                      alignment: Alignment.center,
                      child: const Icon(Icons.photo_outlined),
                    )
                  : Image.file(
                      File(thumb),
                      fit: BoxFit.cover,
                      cacheWidth: 320,
                      cacheHeight: 320,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF101721),
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDateTime(project.updatedAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    reconstruction.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openResult(context, project),
                        child: const Text('Ver resultado'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CaptureScreen(initialProjectId: project.id),
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
    );
  }

  String? _thumbnailPath(ProjectModel project) {
    if (project.coverImagePath != null && project.coverImagePath!.isNotEmpty) {
      return project.coverImagePath;
    }
    if (project.photos.isEmpty) return null;
    final latest = project.photos.last;
    if (latest.thumbnailPath.isNotEmpty) return latest.thumbnailPath;
    return null;
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
