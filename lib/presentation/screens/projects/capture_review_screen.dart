import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/capture/capture_photo.dart';
import '../../../domain/projects/project_workflow.dart';
import '../../providers/project_providers.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/coverage_summary_panel.dart';
import '../capture/capture_screen.dart';
import 'capture_photo_preview_screen.dart';

enum CaptureReviewFilter { all, accepted, flagged, pending }

class CaptureReviewScreen extends ConsumerStatefulWidget {
  const CaptureReviewScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<CaptureReviewScreen> createState() =>
      _CaptureReviewScreenState();
}

class _CaptureReviewScreenState extends ConsumerState<CaptureReviewScreen> {
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
      appBar: AppBar(
        title: const Text('Revision de capturas'),
        actions: [
          IconButton(
            tooltip: 'Recapturar',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CaptureScreen(initialProjectId: project.id),
                ),
              );
            },
            icon: const Icon(Icons.camera_alt_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppPageHeader(
            title: project.name,
            subtitle:
                'Valida capturas, marca retakes y deja el proyecto listo para procesamiento.',
            badge: _ReviewBadge(label: project.primaryActionLabel),
          ),
          const SizedBox(height: 12),
          CoverageSummaryPanel(summary: project.coverage),
          const SizedBox(height: 12),
          AppSurfaceCard(
            title: 'Resumen de revision',
            subtitle: 'Estado operativo del lote actual',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ReviewMetric(
                        label: 'Aceptadas',
                        value: '${review.accepted}',
                        color: const Color(0xFF57D684),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReviewMetric(
                        label: 'Retake',
                        value: '${review.flagged}',
                        color: const Color(0xFFFFB347),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReviewMetric(
                        label: 'Pendientes',
                        value: '${review.pending}',
                        color: const Color(0xFFBBC3D5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReviewMetric(
                        label: 'Faltantes',
                        value: '${review.missing}',
                        color: const Color(0xFF4D92FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CaptureScreen(initialProjectId: project.id),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Retomar captura'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _resetFlagged(project.id),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset retake'),
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
              ButtonSegment(value: CaptureReviewFilter.all, label: Text('Todo')),
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
                childAspectRatio: 0.73,
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
                        builder: (_) => CapturePhotoPreviewScreen(
                          projectId: project.id,
                          photoId: photo.id,
                        ),
                      ),
                    );
                  },
                  onAccept: () {
                    ref.read(projectsProvider.notifier).updatePhotoReview(
                          projectId: project.id,
                          photoId: photo.id,
                          accepted: true,
                          flaggedForRetake: false,
                        );
                  },
                  onRetake: () {
                    ref.read(projectsProvider.notifier).updatePhotoReview(
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
      ref.read(projectsProvider.notifier).updatePhotoReview(
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
              const SizedBox(height: 6),
              Text(
                '${photo.level ?? '--'} - ${photo.angleDeg?.toString() ?? '--'} deg',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'B ${photo.brightness.toStringAsFixed(0)} - D ${photo.sharpness.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
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

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({
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
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
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

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF8F7BFF).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF8F7BFF).withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
