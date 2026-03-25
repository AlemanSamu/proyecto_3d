import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/capture/capture_photo.dart';
import '../../domain/projects/project_workflow.dart';
import '../providers/project_providers.dart';
import '../utils/presentation_formatters.dart';
import '../widgets/app_info_chip.dart';
import '../widgets/app_metric_card.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_section_badge.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/coverage_summary_panel.dart';
import 'capture/capture_screen.dart';
import 'capture_photo_inspector_screen.dart';
import 'export_workbench_screen.dart';

enum CaptureReviewFilter { all, accepted, flagged, pending }

class CaptureReviewWorkspaceScreen extends ConsumerStatefulWidget {
  const CaptureReviewWorkspaceScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<CaptureReviewWorkspaceScreen> createState() =>
      _CaptureReviewWorkspaceScreenState();
}

class _CaptureReviewWorkspaceScreenState
    extends ConsumerState<CaptureReviewWorkspaceScreen> {
  CaptureReviewFilter _filter = CaptureReviewFilter.all;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Revision de capturas')),
        body: const Center(child: Text('No se encontro el proyecto.')),
      );
    }

    final review = project.reviewSummary;
    final photos = _applyFilter(project.photos);

    return Scaffold(
      appBar: AppBar(title: const Text('Revision de capturas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          AppPageHeader(
            title: project.name,
            subtitle:
                'Valida capturas, marca retakes y deja el proyecto listo para procesamiento y salida.',
            trailing: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CaptureScreen(initialProjectId: project.id),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Retomar captura'),
            ),
            badge: AppSectionBadge(
              label: project.primaryActionLabel,
              color: const Color(0xFF8F7BFF),
              icon: Icons.fact_check_outlined,
            ),
          ),
          const SizedBox(height: 12),
          CoverageSummaryPanel(summary: project.coverage),
          const SizedBox(height: 12),
          AppSurfaceCard(
            title: 'Control del lote',
            subtitle: 'Estado operativo de las capturas registradas',
            child: Column(
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 148,
                      child: AppMetricCard(
                        label: 'Aceptadas',
                        value: '${review.accepted}',
                        accent: const Color(0xFF57D684),
                      ),
                    ),
                    SizedBox(
                      width: 148,
                      child: AppMetricCard(
                        label: 'Retake',
                        value: '${review.flagged}',
                        accent: const Color(0xFFFFB347),
                      ),
                    ),
                    SizedBox(
                      width: 148,
                      child: AppMetricCard(
                        label: 'Pendientes',
                        value: '${review.pending}',
                        accent: const Color(0xFFBBC3D5),
                      ),
                    ),
                    SizedBox(
                      width: 148,
                      child: AppMetricCard(
                        label: 'Faltantes',
                        value: '${review.missing}',
                        accent: const Color(0xFF4D92FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 220,
                      child: OutlinedButton.icon(
                        onPressed: () => _resetFlagged(project.id),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Limpiar retakes'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: FilledButton.icon(
                        onPressed: project.coverage.acceptedPhotos == 0
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ExportWorkbenchScreen(
                                      projectId: project.id,
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Preparar salida'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<CaptureReviewFilter>(
            showSelectedIcon: false,
            selected: {_filter},
            segments: const [
              ButtonSegment(
                value: CaptureReviewFilter.all,
                label: Text('Todo'),
              ),
              ButtonSegment(
                value: CaptureReviewFilter.accepted,
                label: Text('Aceptadas'),
              ),
              ButtonSegment(
                value: CaptureReviewFilter.pending,
                label: Text('Pendientes'),
              ),
              ButtonSegment(
                value: CaptureReviewFilter.flagged,
                label: Text('Retake'),
              ),
            ],
            onSelectionChanged: (value) {
              if (value.isEmpty) return;
              setState(() => _filter = value.first);
            },
          ),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            const AppSurfaceCard(
              subtitle: 'No hay capturas en el filtro seleccionado.',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (_, index) {
                final photo = photos[index];
                return _ReviewPhotoCard(
                  photo: photo,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CapturePhotoInspectorScreen(
                          projectId: project.id,
                          photoId: photo.id,
                        ),
                      ),
                    );
                  },
                  onAccept: () {
                    ref
                        .read(projectsProvider.notifier)
                        .updatePhotoReview(
                          projectId: project.id,
                          photoId: photo.id,
                          accepted: true,
                          flaggedForRetake: false,
                        );
                  },
                  onRetake: () {
                    ref
                        .read(projectsProvider.notifier)
                        .updatePhotoReview(
                          projectId: project.id,
                          photoId: photo.id,
                          accepted: false,
                          flaggedForRetake: true,
                        );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  List<CapturePhoto> _applyFilter(List<CapturePhoto> photos) {
    final ordered = [...photos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final photo in ordered)
        if (_matchesFilter(photo)) photo,
    ];
  }

  bool _matchesFilter(CapturePhoto photo) {
    return switch (_filter) {
      CaptureReviewFilter.all => true,
      CaptureReviewFilter.accepted => photo.accepted && !photo.flaggedForRetake,
      CaptureReviewFilter.pending => !photo.accepted && !photo.flaggedForRetake,
      CaptureReviewFilter.flagged => photo.flaggedForRetake,
    };
  }

  void _resetFlagged(String projectId) {
    final project = ref.read(projectByIdProvider(projectId));
    if (project == null) return;
    for (final photo in project.photos) {
      if (!photo.flaggedForRetake) continue;
      ref
          .read(projectsProvider.notifier)
          .updatePhotoReview(
            projectId: projectId,
            photoId: photo.id,
            accepted: false,
            flaggedForRetake: false,
          );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marcaciones de retake reiniciadas.')),
    );
  }
}

class _ReviewPhotoCard extends StatelessWidget {
  const _ReviewPhotoCard({
    required this.photo,
    required this.onOpen,
    required this.onAccept,
    required this.onRetake,
  });

  final CapturePhoto photo;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final statusColor = photo.flaggedForRetake
        ? const Color(0xFFFFA565)
        : (photo.accepted ? const Color(0xFF57D684) : const Color(0xFFBBC3D5));
    final statusLabel = photo.flaggedForRetake
        ? 'Retake'
        : (photo.accepted ? 'Aceptada' : 'Pendiente');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171D2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(
                            photo.thumbnailPath.isNotEmpty
                                ? photo.thumbnailPath
                                : photo.originalPath,
                          ),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 560,
                          cacheHeight: 560,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFF101520),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: AppSectionBadge(
                        label: statusLabel,
                        color: statusColor,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatCaptureDescriptor(
                  level: photo.level,
                  angleDeg: photo.angleDeg,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AppInfoChip(
                    label: 'B ${photo.brightness.toStringAsFixed(0)}',
                    color: const Color(0xFF4D92FF),
                    icon: Icons.light_mode_outlined,
                  ),
                  AppInfoChip(
                    label: 'D ${photo.sharpness.toStringAsFixed(0)}',
                    color: const Color(0xFF8F7BFF),
                    icon: Icons.center_focus_strong_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                      label: const Text('Aceptar'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onRetake,
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: const Text('Retake'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
