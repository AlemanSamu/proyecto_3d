import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/capture/capture_photo.dart';
import '../../../domain/projects/project_model.dart';
import '../../../domain/projects/project_workflow.dart';
import '../../providers/project_providers.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/coverage_summary_panel.dart';
import '../../widgets/pipeline_panel.dart';
import '../../widgets/project_form_dialog.dart';
import '../../widgets/status_badge.dart';
import '../capture/capture_screen.dart';
import 'capture_photo_preview_screen.dart';
import 'capture_review_screen.dart';
import 'export_configuration_screen.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectByIdProvider(projectId));
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proyecto')),
        body: const Center(child: Text('No se encontro el proyecto.')),
      );
    }

    final orderedPhotos = [...project.photos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del proyecto'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _editProject(context, ref, project),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _HeroCard(project: project),
          const SizedBox(height: 12),
          _MainActions(project: project),
          const SizedBox(height: 12),
          CoverageSummaryPanel(summary: project.coverage),
          const SizedBox(height: 12),
          PipelinePanel(project: project),
          if (project.poses.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PosesPanel(project: project),
          ],
          const SizedBox(height: 12),
          _RecentCapturesPanel(project: project, photos: orderedPhotos),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final coverPath =
        project.coverImagePath ??
        (project.photos.isNotEmpty ? project.photos.last.thumbnailPath : null);

    return AppSurfaceCard(
      title: project.name,
      subtitle: project.primaryActionDescription,
      trailing: StatusBadge(status: project.status),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1.7,
              child: coverPath == null || coverPath.isEmpty
                  ? Container(
                      color: const Color(0xFF101520),
                      alignment: Alignment.center,
                      child: const Icon(Icons.view_in_ar_rounded, size: 52),
                    )
                  : Image.file(
                      File(coverPath),
                      fit: BoxFit.cover,
                      cacheWidth: 980,
                      cacheHeight: 560,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF101520),
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  text: 'Creado ${_formatDate(project.createdAt)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetaChip(
                  icon: Icons.update_rounded,
                  text: 'Actualizado ${_formatDate(project.updatedAt)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ProjectMetric(
                  label: 'Aceptadas',
                  value: '${project.coverage.acceptedPhotos}',
                  color: const Color(0xFF57D684),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProjectMetric(
                  label: 'Retake',
                  value: '${project.coverage.flaggedForRetake}',
                  color: const Color(0xFFFFB347),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProjectMetric(
                  label: 'Faltantes',
                  value: '${project.missingRecommendedPhotos}',
                  color: const Color(0xFF4D92FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final d = value.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}

class _MainActions extends StatelessWidget {
  const _MainActions({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      title: 'Acciones principales',
      subtitle: 'Continua el flujo recomendado del producto',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CaptureScreen(initialProjectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Capturar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CaptureReviewScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Revision'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExportConfigurationScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Procesamiento'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExportConfigurationScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Exportacion'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PosesPanel extends StatelessWidget {
  const _PosesPanel({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final entries = project.poses.entries.toList()
      ..sort((a, b) => b.value.captureCount.compareTo(a.value.captureCount));

    return AppSurfaceCard(
      title: 'Poses registradas',
      subtitle: 'Resumen de posiciones detectadas durante la captura',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in entries)
            _Pill(text: '${entry.key} - ${entry.value.captureCount}'),
        ],
      ),
    );
  }
}

class _RecentCapturesPanel extends StatelessWidget {
  const _RecentCapturesPanel({required this.project, required this.photos});

  final ProjectModel project;
  final List<CapturePhoto> photos;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      title: 'Ultimas capturas',
      subtitle: '${project.photos.length} capturas totales',
      child: project.photos.isEmpty
          ? const Text('Aun no hay capturas registradas.')
          : SizedBox(
              height: 126,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length.clamp(0, 12),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final photo = photos[index];
                  final path = photo.thumbnailPath.isNotEmpty
                      ? photo.thumbnailPath
                      : photo.originalPath;

                  return SizedBox(
                    width: 110,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CapturePhotoPreviewScreen(
                              projectId: project.id,
                              photoId: photo.id,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFF101520),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${photo.level ?? '--'} - ${photo.angleDeg?.toString() ?? '--'} deg',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectMetric extends StatelessWidget {
  const _ProjectMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6C8EFF).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF6C8EFF).withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> _editProject(
  BuildContext context,
  WidgetRef ref,
  ProjectModel project,
) async {
  final payload = await showProjectFormDialog(
    context,
    title: 'Editar proyecto',
    confirmLabel: 'Guardar',
    initialName: project.name,
    initialDescription: project.description,
  );

  if (payload == null) return;

  ref.read(projectsProvider.notifier).updateProjectDetails(
        projectId: project.id,
        name: payload.name,
        description: payload.description,
      );
}
