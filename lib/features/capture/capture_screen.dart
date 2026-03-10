import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../projects/project_model.dart';
import '../projects/project_store.dart';
import 'capture_controller.dart';
import 'guided_camera_screen.dart';
import 'pose_library.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  final String projectId;
  const CaptureScreen({super.key, required this.projectId});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  static const int _targetRecommendedPhotos = 48;

  bool _busy = false;
  late final CaptureController _controller;

  late final List<PoseStep> _poses = PoseLibrary.default36();

  @override
  void initState() {
    super.initState();
    _controller = CaptureController(
      projectId: widget.projectId,
      permissions: DeviceCapturePermissions(),
      camera: DeviceCaptureCamera(),
      qualityAnalyzer: IsolateCaptureQualityAnalyzer(),
      fileStorage: LocalCaptureFileStorage(),
      gallerySaver: GallerySaverCaptureGallery(),
      projectStore: RiverpodCaptureProjectStore(
        ref.read(projectsProvider.notifier),
      ),
    );
  }

  Future<void> _openGuidedCamera({
    required ScanProject project,
    required PoseStep startPose,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => GuidedCameraScreen(
            projectId: widget.projectId,
            controller: _controller,
            poses: _poses,
            initialPoseId: startPose.id,
            initialCompletedPoseIds: project.posePhotos.keys.toSet(),
            initialPosePhotos: Map<String, String>.from(project.posePhotos),
            targetRecommended: _targetRecommendedPhotos,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    ScanProject? project;
    for (final item in projects) {
      if (item.id == widget.projectId) {
        project = item;
        break;
      }
    }

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Captura 3D')),
        body: const Center(child: Text('Proyecto no encontrado.')),
      );
    }

    final nextIndex = _poses.indexWhere(
      (pose) => !project!.posePhotos.containsKey(pose.id),
    );
    final currentIndex = nextIndex == -1 ? _poses.length - 1 : nextIndex;
    final currentPose = _poses[currentIndex];

    final doneCount = project.posePhotos.length;
    final total = _poses.length;
    final allDone = doneCount == total;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            tooltip: 'Reiniciar pose actual',
            onPressed: allDone
                ? null
                : () async {
                    final filePath = project!.posePhotos[currentPose.id];
                    await _controller.removePosePhoto(
                      poseId: currentPose.id,
                      filePath: filePath,
                    );
                  },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: allDone
            ? null
            : (_busy
                  ? null
                  : () => _openGuidedCamera(
                      project: project!,
                      startPose: currentPose,
                    )),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt),
        label: Text(allDone ? 'Completado' : 'Tomar foto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _TopProgress(done: doneCount, total: total),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PoseDial(
                      angleDeg: currentPose.angleDeg,
                      level: currentPose.level,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            allDone
                                ? 'Listo.'
                                : 'Siguiente: ${currentPose.title}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            allDone
                                ? 'Ya capturaste todas las poses.'
                                : currentPose.instruction,
                          ),
                          const SizedBox(height: 10),
                          if (!allDone)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  label: Text(
                                    'Angulo: ${currentPose.angleDeg} deg',
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    'Altura: ${currentPose.level.label}',
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
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _poses.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final pose = _poses[i];
                  final path = project!.posePhotos[pose.id];
                  final done = path != null;

                  return Card(
                    child: ListTile(
                      leading: done
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_previewPath(path)),
                                width: 52,
                                height: 52,
                                cacheWidth: 104,
                                cacheHeight: 104,
                                filterQuality: FilterQuality.low,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image),
                              ),
                            )
                          : _MiniPoseIcon(
                              level: pose.level,
                              angle: pose.angleDeg,
                            ),
                      title: Text(pose.title),
                      subtitle: Text(
                        '${pose.level.label} - ${pose.angleDeg} deg',
                      ),
                      trailing: done
                          ? IconButton(
                              tooltip: 'Repetir esta pose',
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      await _controller.removePosePhoto(
                                        poseId: pose.id,
                                        filePath: path,
                                      );
                                      _toast('Pose marcada para repetir.');
                                    },
                              icon: const Icon(Icons.refresh),
                            )
                          : IconButton(
                              tooltip: 'Tomar esta pose ahora',
                              onPressed: _busy
                                  ? null
                                  : () => _openGuidedCamera(
                                      project: project!,
                                      startPose: pose,
                                    ),
                              icon: const Icon(Icons.camera_alt),
                            ),
                      tileColor: (!allDone && pose.id == currentPose.id)
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewPath(String path) {
    final thumb = LocalCaptureFileStorage.thumbnailPathFor(path);
    if (File(thumb).existsSync()) return thumb;
    return path;
  }
}

class _TopProgress extends StatelessWidget {
  final int done;
  final int total;
  const _TopProgress({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = (done / max(1, total)).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progreso: $done / $total',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: p),
                  const SizedBox(height: 6),
                  Text(
                    done < total
                        ? 'Tip: manten distancia constante y gira alrededor del objeto.'
                        : 'Set completo. Puedes pasar al paso de procesado.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              done < total ? Icons.directions_walk : Icons.check_circle,
              size: 34,
            ),
          ],
        ),
      ),
    );
  }
}

class _PoseDial extends StatelessWidget {
  final int angleDeg;
  final PoseLevel level;

  const _PoseDial({required this.angleDeg, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('$angleDeg deg', style: Theme.of(context).textTheme.titleMedium),
          Positioned(
            bottom: 6,
            child: Text(
              level.short,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPoseIcon extends StatelessWidget {
  final PoseLevel level;
  final int angle;
  const _MiniPoseIcon({required this.level, required this.angle});

  @override
  Widget build(BuildContext context) {
    final icon = switch (level) {
      PoseLevel.low => Icons.south,
      PoseLevel.mid => Icons.horizontal_rule,
      PoseLevel.top => Icons.north,
    };

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 1),
            Text(
              '$angle deg',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontSize: 10, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}
