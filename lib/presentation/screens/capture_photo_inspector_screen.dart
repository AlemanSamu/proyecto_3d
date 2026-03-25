import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/capture/capture_photo.dart';
import '../providers/project_providers.dart';
import '../utils/presentation_formatters.dart';
import '../widgets/app_info_chip.dart';
import '../widgets/app_section_badge.dart';
import '../widgets/app_surface_card.dart';
import 'capture_review_workspace_screen.dart';

class CapturePhotoInspectorScreen extends ConsumerWidget {
  const CapturePhotoInspectorScreen({
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
        appBar: AppBar(title: const Text('Captura')),
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
        appBar: AppBar(title: const Text('Captura')),
        body: const Center(child: Text('Captura no encontrada.')),
      );
    }

    final statusColor = photo.flaggedForRetake
        ? const Color(0xFFFFB347)
        : (photo.accepted ? const Color(0xFF57D684) : const Color(0xFFBBC3D5));
    final statusLabel = photo.flaggedForRetake
        ? 'Retake'
        : (photo.accepted ? 'Aceptada' : 'Pendiente');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspeccion de captura'),
        actions: [
          IconButton(
            tooltip: 'Revision',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CaptureReviewWorkspaceScreen(projectId: projectId),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          AppSurfaceCard(
            title: project.name,
            subtitle: formatCaptureDescriptor(
              level: photo.level,
              angleDeg: photo.angleDeg,
            ),
            trailing: AppSectionBadge(
              label: statusLabel,
              color: statusColor,
              icon: Icons.analytics_outlined,
            ),
            child: Column(
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppInfoChip(
                      label: 'Brillo ${photo.brightness.toStringAsFixed(1)}',
                      color: const Color(0xFF4D92FF),
                      icon: Icons.light_mode_outlined,
                    ),
                    AppInfoChip(
                      label: 'Detalle ${photo.sharpness.toStringAsFixed(1)}',
                      color: const Color(0xFF8F7BFF),
                      icon: Icons.center_focus_strong_outlined,
                    ),
                    AppInfoChip(
                      label: formatDateTime(photo.createdAt),
                      color: const Color(0xFF41D4B8),
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppSurfaceCard(
            title: 'Decision de revision',
            subtitle:
                'Actualiza el estado de la captura dentro del lote actual',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Marcar como aceptada'),
                  subtitle: const Text(
                    'Incluye esta captura en el paquete final del proyecto.',
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
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Solicitar retake'),
                  subtitle: const Text(
                    'Marca esta captura para repetirse en una proxima sesion.',
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
        ],
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
          'La captura se eliminara del proyecto y del almacenamiento local.',
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
