import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/capture/capture_photo.dart';
import '../../providers/project_providers.dart';
import 'capture_review_screen.dart';

class CapturePhotoPreviewScreen extends ConsumerWidget {
  const CapturePhotoPreviewScreen({
    super.key,
    required this.projectId,
    required this.photoId,
  });

  final String projectId;
  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(
      projectsProvider.select((projects) {
        for (final item in projects) {
          if (item.id == projectId) return item;
        }
        return null;
      }),
    );

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Foto')),
        body: const Center(child: Text('Proyecto no encontrado.')),
      );
    }

    CapturePhoto? photo;
    for (final item in project.photos) {
      if (item.id == photoId) {
        photo = item;
        break;
      }
    }

    if (photo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Foto')),
        body: const Center(child: Text('Foto no encontrada.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview de captura'),
        actions: [
          IconButton(
            tooltip: 'Revision',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CaptureReviewScreen(projectId: projectId),
                ),
              );
            },
            icon: const Icon(Icons.fact_check_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: () => _confirmDelete(context, ref, photo!),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141C2A), Color(0xFF0C1018)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.file(
                  File(photo.originalPath),
                  fit: BoxFit.cover,
                  cacheWidth: 1280,
                  cacheHeight: 1280,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF101520),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _PhotoInfoCard(photo: photo),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('Aceptada'),
                    subtitle: const Text(
                      'Incluye esta captura en el paquete final',
                    ),
                    value: photo.accepted && !photo.flaggedForRetake,
                    onChanged: (value) {
                      ref
                          .read(projectsProvider.notifier)
                          .updatePhotoReview(
                            projectId: projectId,
                            photoId: photo!.id,
                            accepted: value,
                            flaggedForRetake: value
                                ? false
                                : photo.flaggedForRetake,
                          );
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    title: const Text('Marcar para recaptura'),
                    subtitle: const Text(
                      'Marca esta foto para retake en campo',
                    ),
                    value: photo.flaggedForRetake,
                    onChanged: (value) {
                      ref
                          .read(projectsProvider.notifier)
                          .updatePhotoReview(
                            projectId: projectId,
                            photoId: photo!.id,
                            accepted: value ? false : photo.accepted,
                            flaggedForRetake: value,
                          );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(projectsProvider.notifier)
                          .updatePhotoReview(
                            projectId: projectId,
                            photoId: photo!.id,
                            accepted: true,
                            flaggedForRetake: false,
                          );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Aceptar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(projectsProvider.notifier)
                          .updatePhotoReview(
                            projectId: projectId,
                            photoId: photo!.id,
                            accepted: false,
                            flaggedForRetake: true,
                          );
                    },
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Retake'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CaptureReviewScreen(projectId: projectId),
                  ),
                );
              },
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('Volver a revision'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CapturePhoto photo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar captura'),
        content: const Text(
          'La foto se eliminara del proyecto y del almacenamiento local.',
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

    if (confirmed != true) return;

    await ref
        .read(projectCaptureStorageProvider)
        .deleteIfExists(photo.originalPath);
    ref.read(projectsProvider.notifier).removeCapturePhoto(projectId, photo.id);

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Captura eliminada.')));
    }
  }
}

class _PhotoInfoCard extends StatelessWidget {
  const _PhotoInfoCard({required this.photo});

  final CapturePhoto photo;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'Pose: ${photo.poseId ?? '--'}',
      'Angulo: ${photo.angleDeg?.toString() ?? '--'} deg',
      'Nivel: ${photo.level ?? '--'}',
      'Brillo: ${photo.brightness.toStringAsFixed(1)}',
      'Nitidez: ${photo.sharpness.toStringAsFixed(1)}',
      'Fecha: ${_formatDate(photo.createdAt)}',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metadata', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final d = value.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} $hh:$min';
  }
}
