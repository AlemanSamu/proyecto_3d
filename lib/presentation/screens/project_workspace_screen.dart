import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/capture/capture_photo.dart';
import '../../domain/projects/project_export_config.dart';
import '../../domain/projects/project_model.dart';
import '../../domain/projects/project_processing.dart';
import '../../domain/projects/project_workflow.dart';
import '../providers/project_providers.dart';
import '../utils/presentation_formatters.dart';
import '../widgets/app_info_chip.dart';
import '../widgets/app_metric_card.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_section_badge.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/coverage_summary_panel.dart';
import '../widgets/pipeline_panel.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/status_badge.dart';
import 'capture/capture_screen.dart';
import 'capture_photo_inspector_screen.dart';
import 'capture_review_workspace_screen.dart';
import 'export_workbench_screen.dart';

class ProjectWorkspaceScreen extends ConsumerWidget {
  const ProjectWorkspaceScreen({super.key, required this.projectId});

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
        title: const Text('Proyecto'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _editProject(context, ref, project),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          AppPageHeader(
            title: project.name,
            subtitle: project.primaryActionDescription,
            trailing: FilledButton.icon(
              onPressed: () => _openPrimaryAction(context, project),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(project.primaryActionLabel),
            ),
            badge: AppSectionBadge(
              label: project.status.label,
              color: StatusBadge.colorFor(project.status),
              icon: Icons.radar_rounded,
            ),
          ),
          const SizedBox(height: 16),
          _ProjectHeroCard(project: project),
          const SizedBox(height: 12),
          CoverageSummaryPanel(summary: project.coverage),
          const SizedBox(height: 12),
          PipelinePanel(project: project),
          const SizedBox(height: 12),
          _OutputReadinessPanel(project: project),
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

  Future<void> _openPrimaryAction(BuildContext context, ProjectModel project) {
    switch (project.primaryActionIntent) {
      case ProjectPrimaryActionIntent.capture:
        return Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaptureScreen(initialProjectId: project.id),
          ),
        );
      case ProjectPrimaryActionIntent.review:
      case ProjectPrimaryActionIntent.troubleshoot:
        return Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaptureReviewWorkspaceScreen(projectId: project.id),
          ),
        );
      case ProjectPrimaryActionIntent.process:
      case ProjectPrimaryActionIntent.models:
      case ProjectPrimaryActionIntent.export:
        return Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExportWorkbenchScreen(projectId: project.id),
          ),
        );
    }
  }
}

class _ProjectHeroCard extends StatelessWidget {
  const _ProjectHeroCard({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final coverPath =
        project.coverImagePath ??
        (project.photos.isNotEmpty ? project.photos.last.thumbnailPath : null);

    return AppSurfaceCard(
      title: 'Resumen',
      subtitle: project.description.isEmpty
          ? 'Proyecto listo para seguir el flujo guiado.'
          : project.description,
      trailing: StatusBadge(status: project.status, compact: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 1.75,
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppInfoChip(
                icon: Icons.calendar_today_outlined,
                label: 'Creado ${formatShortDate(project.createdAt)}',
                color: const Color(0xFF7A8CFF),
              ),
              AppInfoChip(
                icon: Icons.update_rounded,
                label: 'Actualizado ${formatShortDate(project.updatedAt)}',
                color: const Color(0xFF76A7FF),
              ),
              AppInfoChip(
                icon: Icons.photo_library_outlined,
                label: '${project.photos.length} capturas',
                color: const Color(0xFF4FD3C1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 148,
                child: AppMetricCard(
                  label: 'Aceptadas',
                  value: '${project.coverage.acceptedPhotos}',
                  accent: const Color(0xFF57D684),
                ),
              ),
              SizedBox(
                width: 148,
                child: AppMetricCard(
                  label: 'Retake',
                  value: '${project.coverage.flaggedForRetake}',
                  accent: const Color(0xFFFFB347),
                ),
              ),
              SizedBox(
                width: 148,
                child: AppMetricCard(
                  label: 'Faltantes',
                  value: '${project.missingRecommendedPhotos}',
                  accent: const Color(0xFF76A7FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 210,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CaptureScreen(initialProjectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Captura guiada'),
                ),
              ),
              SizedBox(
                width: 210,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CaptureReviewWorkspaceScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Revision'),
                ),
              ),
              SizedBox(
                width: 210,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExportWorkbenchScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Salida'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutputReadinessPanel extends StatelessWidget {
  const _OutputReadinessPanel({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final destination =
        project.exportConfig.destinationPath?.trim().isNotEmpty == true
        ? project.exportConfig.destinationPath!
        : project.exportConfig.destination.label;

    return AppSurfaceCard(
      title: 'Salida',
      subtitle: 'Estado actual del paquete y del modelo local.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 148,
                child: AppMetricCard(
                  label: 'Formato',
                  value: project.exportConfig.targetFormat.label,
                  accent: const Color(0xFF7A8CFF),
                ),
              ),
              SizedBox(
                width: 148,
                child: AppMetricCard(
                  label: 'Perfil',
                  value: project.processingConfig.profile.label,
                  accent: const Color(0xFF76A7FF),
                ),
              ),
              SizedBox(
                width: 148,
                child: AppMetricCard(
                  label: 'Modelo',
                  value: project.hasGeneratedModel ? 'Listo' : 'Pendiente',
                  accent: project.hasGeneratedModel
                      ? const Color(0xFF4FD3C1)
                      : const Color(0xFFFFB347),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OutputLine(label: 'Destino', value: destination),
                _OutputLine(
                  label: 'Modelo local',
                  value: project.modelPath ?? 'Aun no generado',
                ),
                _OutputLine(
                  label: 'Ultimo paquete',
                  value: project.lastExportPackagePath ?? 'Sin exportacion',
                ),
              ],
            ),
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
      subtitle: 'Resumen de posiciones capturadas durante la sesion.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in entries)
            AppInfoChip(
              label: '${entry.key} - ${entry.value.captureCount}',
              color: const Color(0xFF76A7FF),
              icon: Icons.threesixty_rounded,
            ),
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
      title: 'Capturas recientes',
      subtitle: '${project.photos.length} capturas registradas en el proyecto.',
      child: project.photos.isEmpty
          ? const Text('Aun no hay capturas registradas.')
          : SizedBox(
              height: 146,
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
                    width: 124,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CapturePhotoInspectorScreen(
                              projectId: project.id,
                              photoId: photo.id,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
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
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatCaptureDescriptor(
                                level: photo.level,
                                angleDeg: photo.angleDeg,
                              ),
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

class _OutputLine extends StatelessWidget {
  const _OutputLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

  ref
      .read(projectsProvider.notifier)
      .updateProjectDetails(
        projectId: project.id,
        name: payload.name,
        description: payload.description,
      );
}
