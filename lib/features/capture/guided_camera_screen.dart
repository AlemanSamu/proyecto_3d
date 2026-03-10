import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'capture_controller.dart';
import 'pose_library.dart';
import 'quality_analyzer.dart';

class GuidedCameraScreen extends StatefulWidget {
  const GuidedCameraScreen({
    super.key,
    required this.projectId,
    required this.controller,
    required this.poses,
    required this.initialCompletedPoseIds,
    this.initialPosePhotos = const {},
    this.initialPoseId,
    this.targetRecommended = 48,
  });

  final String projectId;
  final CaptureController controller;
  final List<PoseStep> poses;
  final Set<String> initialCompletedPoseIds;
  final Map<String, String> initialPosePhotos;
  final String? initialPoseId;
  final int targetRecommended;

  @override
  State<GuidedCameraScreen> createState() => _GuidedCameraScreenState();
}

enum _PhotoAction { replace, delete, goToPose }

class _GuidedCameraScreenState extends State<GuidedCameraScreen>
    with WidgetsBindingObserver {
  static const Duration _frameSamplingInterval = Duration(milliseconds: 260);
  static const int _frameStep = 8;

  CameraController? _cameraController;
  bool _initializing = true;
  bool _capturing = false;
  bool _streaming = false;
  bool _assistEnabled = true;
  bool _analyzingFrame = false;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _error;

  late final Map<String, String> _posePhotoPaths = Map<String, String>.from(
    widget.initialPosePhotos,
  );
  late final Set<String> _donePoseIds = <String>{
    ...widget.initialCompletedPoseIds,
    ..._posePhotoPaths.keys,
  };
  late int _currentPoseIndex = _resolveInitialPoseIndex();

  double? _liveBrightness;
  double? _liveSharpness;

  bool get _allDone => _donePoseIds.length >= widget.poses.length;
  bool get _hasLiveMetrics => _liveBrightness != null && _liveSharpness != null;

  bool get _isBlockedByQuality {
    if (!_assistEnabled || !_hasLiveMetrics) return false;
    return (_liveBrightness ?? 0) < minBrightness ||
        (_liveSharpness ?? 0) < minSharpness;
  }

  PoseStep? get _currentPose {
    if (_allDone || widget.poses.isEmpty) return null;
    if (_currentPoseIndex < 0 || _currentPoseIndex >= widget.poses.length) {
      return null;
    }
    return widget.poses[_currentPoseIndex];
  }

  List<_CapturedThumb> get _capturedThumbs {
    final list = <_CapturedThumb>[];
    for (final pose in widget.poses) {
      final fullPath = _posePhotoPaths[pose.id];
      if (fullPath == null) continue;
      list.add(_CapturedThumb(pose: pose, previewPath: _previewPath(fullPath)));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopImageStreamIfNeeded();
      controller.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopImageStreamIfNeeded();
    _cameraController?.dispose();
    super.dispose();
  }

  int _resolveInitialPoseIndex() {
    if (widget.poses.isEmpty) return 0;

    if (widget.initialPoseId != null) {
      final requested = widget.poses.indexWhere(
        (pose) => pose.id == widget.initialPoseId,
      );
      if (requested >= 0 &&
          !_donePoseIds.contains(widget.poses[requested].id)) {
        return requested;
      }
    }

    final firstPending = widget.poses.indexWhere(
      (pose) => !_donePoseIds.contains(pose.id),
    );
    if (firstPending >= 0) return firstPending;

    return widget.poses.length - 1;
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _error = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'No hay camaras disponibles.';
          _initializing = false;
        });
        return;
      }

      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      await _startImageStreamIfNeeded();

      setState(() => _initializing = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo iniciar la camara.';
        _initializing = false;
      });
    }
  }

  Future<void> _startImageStreamIfNeeded() async {
    final controller = _cameraController;
    if (controller == null) return;
    if (!controller.value.isInitialized || _streaming) return;

    try {
      await controller.startImageStream(_onCameraImage);
      _streaming = true;
    } catch (_) {
      _streaming = false;
    }
  }

  Future<void> _stopImageStreamIfNeeded() async {
    final controller = _cameraController;
    if (controller == null) return;
    if (!_streaming || !controller.value.isInitialized) return;

    try {
      await controller.stopImageStream();
    } catch (_) {
      // Ignore: camera plugin can throw if stream is already stopped.
    } finally {
      _streaming = false;
    }
  }

  void _onCameraImage(CameraImage image) {
    if (!mounted || _capturing || _analyzingFrame) return;

    final now = DateTime.now();
    if (now.difference(_lastFrameTime) < _frameSamplingInterval) return;

    _lastFrameTime = now;
    _analyzingFrame = true;

    try {
      final metrics = _estimateLiveMetrics(image);
      if (metrics == null || !mounted) return;
      setState(() {
        _liveBrightness = metrics.brightness;
        _liveSharpness = metrics.sharpness;
      });
    } finally {
      _analyzingFrame = false;
    }
  }

  _FrameMetrics? _estimateLiveMetrics(CameraImage image) {
    if (image.planes.isEmpty) return null;
    if (image.width <= _frameStep || image.height <= _frameStep) return null;

    final format = image.format.group;

    double lumaAt(int x, int y) {
      if (format == ImageFormatGroup.bgra8888) {
        final plane = image.planes[0];
        final bytes = plane.bytes;
        final rowStride = plane.bytesPerRow;
        final index = y * rowStride + x * 4;
        if (index < 0 || index + 2 >= bytes.length) return 0;
        final b = bytes[index].toDouble();
        final g = bytes[index + 1].toDouble();
        final r = bytes[index + 2].toDouble();
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
      }

      final yPlane = image.planes[0];
      final bytes = yPlane.bytes;
      final rowStride = yPlane.bytesPerRow;
      final pixelStride = yPlane.bytesPerPixel ?? 1;
      final index = y * rowStride + x * pixelStride;
      if (index < 0 || index >= bytes.length) return 0;
      return bytes[index].toDouble();
    }

    final maxX = image.width - _frameStep;
    final maxY = image.height - _frameStep;
    double brightnessSum = 0;
    double sharpnessSum = 0;
    int samples = 0;

    for (int y = 0; y < maxY; y += _frameStep) {
      for (int x = 0; x < maxX; x += _frameStep) {
        final current = lumaAt(x, y);
        final right = lumaAt(x + _frameStep, y);
        final down = lumaAt(x, y + _frameStep);
        brightnessSum += current;
        sharpnessSum += (current - right).abs() + (current - down).abs();
        samples++;
      }
    }

    if (samples == 0) return null;
    return _FrameMetrics(
      brightness: brightnessSum / samples,
      sharpness: sharpnessSum / samples,
    );
  }

  Future<void> _captureAndAdvance() async {
    final pose = _currentPose;
    final controller = _cameraController;
    if (pose == null || controller == null || _capturing) return;

    if (_isBlockedByQuality) {
      _showSnack('Mejora iluminacion o estabilidad.');
      return;
    }

    setState(() => _capturing = true);

    try {
      await HapticFeedback.lightImpact();
      await _stopImageStreamIfNeeded();

      final shot = await controller.takePicture();
      final result = await widget.controller.saveGuidedShot(
        pose: pose,
        sourcePath: shot.path,
        confirmLowQuality: _askKeepBad,
      );

      if (!mounted) return;

      if (result.saved) {
        setState(() {
          if (result.storedPath != null && result.storedPath!.isNotEmpty) {
            _posePhotoPaths[pose.id] = result.storedPath!;
          }
          _donePoseIds.add(pose.id);
        });
        _advanceToNextPose();
      }

      if (result.message != null) {
        _showSnack(result.message!);
      }
    } catch (_) {
      _showSnack('No se pudo tomar la foto.');
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
      await _startImageStreamIfNeeded();
    }
  }

  void _advanceToNextPose() {
    if (_allDone) return;

    final total = widget.poses.length;
    final start = (_currentPoseIndex + 1) % total;
    int idx = start;

    do {
      if (!_donePoseIds.contains(widget.poses[idx].id)) {
        if (!mounted) return;
        setState(() => _currentPoseIndex = idx);
        return;
      }
      idx = (idx + 1) % total;
    } while (idx != start);
  }

  void _focusPose(PoseStep pose) {
    final index = widget.poses.indexWhere((item) => item.id == pose.id);
    if (index < 0 || !mounted) return;
    setState(() => _currentPoseIndex = index);
  }

  Future<void> _deletePosePhoto(
    PoseStep pose, {
    required bool focusPoseAfterDelete,
  }) async {
    final fullPath = _posePhotoPaths[pose.id];
    if (fullPath == null) return;

    await widget.controller.removePosePhoto(
      poseId: pose.id,
      filePath: fullPath,
    );
    if (!mounted) return;

    setState(() {
      _posePhotoPaths.remove(pose.id);
      _donePoseIds.remove(pose.id);
      if (focusPoseAfterDelete) {
        final index = widget.poses.indexWhere((item) => item.id == pose.id);
        if (index >= 0) _currentPoseIndex = index;
      }
    });
  }

  Future<void> _openPhotoActionPanel(PoseStep pose) async {
    final fullPath = _posePhotoPaths[pose.id];
    if (fullPath == null || !mounted) return;

    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: const Color(0xFF111216),
      showDragHandle: true,
      builder: (ctx) {
        final previewPath = _previewPath(fullPath);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(previewPath),
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                        cacheWidth: 180,
                        cacheHeight: 180,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${pose.level.label} | ${pose.angleDeg} deg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Cambiar foto'),
                  subtitle: const Text(
                    'Marca esta pose para volver a capturar.',
                  ),
                  onTap: () => Navigator.of(ctx).pop(_PhotoAction.replace),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Eliminar foto'),
                  subtitle: const Text('Borra la foto y su miniatura.'),
                  onTap: () => Navigator.of(ctx).pop(_PhotoAction.delete),
                ),
                ListTile(
                  leading: const Icon(Icons.track_changes_rounded),
                  title: const Text('Ir a esta pose'),
                  subtitle: const Text('La guia se movera a este punto.'),
                  onTap: () => Navigator.of(ctx).pop(_PhotoAction.goToPose),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;
    if (action == _PhotoAction.goToPose) {
      _focusPose(pose);
      return;
    }

    await _deletePosePhoto(pose, focusPoseAfterDelete: true);
    if (!mounted) return;

    if (action == _PhotoAction.replace) {
      _showSnack('Pose lista para recaptura. Toma una nueva foto.');
    } else {
      _showSnack('Foto eliminada.');
    }
  }

  Future<bool> _askKeepBad(QualityReport report) async {
    final keep = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calidad baja detectada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Luz: ${report.brightness.toStringAsFixed(1)}/255 '
              '(min ${minBrightness.toStringAsFixed(0)})',
            ),
            Text(
              'Nitidez: ${report.sharpness.toStringAsFixed(1)} '
              '(min ${minSharpness.toStringAsFixed(0)})',
            ),
            const SizedBox(height: 10),
            Text(report.hint),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Repetir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar igual'),
          ),
        ],
      ),
    );
    return keep == true;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camara guiada'),
        content: const Text(
          'Gira alrededor del objeto con pasos suaves. Mantente en el nivel '
          'indicado y revisa Luz/Nitidez antes de disparar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _previewPath(String fullPath) {
    final thumb = LocalCaptureFileStorage.thumbnailPathFor(fullPath);
    if (File(thumb).existsSync()) return thumb;
    return fullPath;
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _initializeCamera,
                    child: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final camera = _cameraController;
    if (camera == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Camara no disponible')),
      );
    }

    final pose = _currentPose;
    final doneCount = _donePoseIds.length;
    final totalPoses = max(1, widget.poses.length);
    final progress = (doneCount / totalPoses).clamp(0.0, 1.0);
    final recommendedProgress = (doneCount / max(1, widget.targetRecommended))
        .clamp(0.0, 1.0);
    final qualityMessage = _isBlockedByQuality
        ? 'Mejora iluminacion o estabilidad.'
        : 'Buena iluminacion.';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(camera),
          const _TopBottomVignette(),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _OrbitGuidePainter(
                  poses: widget.poses,
                  donePoseIds: _donePoseIds,
                  currentPoseId: pose?.id,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _CenterReticle(
                levelLabel: pose?.level.label ?? 'Completo',
                angleLabel: pose == null ? '--' : '${pose.angleDeg}\u00b0',
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  _TopGuideHud(
                    doneCount: doneCount,
                    totalPoses: totalPoses,
                    targetRecommended: widget.targetRecommended,
                    currentPose: pose,
                    onBack: () => Navigator.of(context).pop(),
                    onHelp: _showHelp,
                  ),
                  const Spacer(),
                  _BottomCapturePanel(
                    assistEnabled: _assistEnabled,
                    blockedByQuality: _isBlockedByQuality,
                    brightness: _liveBrightness,
                    sharpness: _liveSharpness,
                    qualityMessage: qualityMessage,
                    onToggleAssist: () =>
                        setState(() => _assistEnabled = !_assistEnabled),
                    onCapture: _allDone ? null : _captureAndAdvance,
                    capturing: _capturing,
                    thumbs: _capturedThumbs,
                    currentPoseId: pose?.id,
                    progress: progress,
                    recommendedProgress: recommendedProgress,
                    onThumbTap: _openPhotoActionPanel,
                  ),
                ],
              ),
            ),
          ),
          if (_allDone)
            _CompletedOverlay(onClose: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _TopBottomVignette extends StatelessWidget {
  const _TopBottomVignette();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.78),
          ],
          stops: const [0.0, 0.2, 0.6, 1.0],
        ),
      ),
    );
  }
}

class _TopGuideHud extends StatelessWidget {
  const _TopGuideHud({
    required this.doneCount,
    required this.totalPoses,
    required this.targetRecommended,
    required this.currentPose,
    required this.onBack,
    required this.onHelp,
  });

  final int doneCount;
  final int totalPoses;
  final int targetRecommended;
  final PoseStep? currentPose;
  final VoidCallback onBack;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final subtitle = currentPose == null
        ? 'Captura completa'
        : '${currentPose!.level.label} | ${currentPose!.angleDeg}\u00b0';

    return Column(
      children: [
        Row(
          children: [
            _CircleIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
            const Spacer(),
            const Text(
              'Camara Guiada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            _CircleIconButton(icon: Icons.help_outline_rounded, onTap: onHelp),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Toma fotos continuas para crear el modelo 3D',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.86)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF9A73FF), width: 2),
            color: Colors.black.withValues(alpha: 0.35),
          ),
          child: Text(
            '$doneCount / $targetRecommended fotos',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFE0E0E0),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          'Cobertura: $doneCount / $totalPoses poses',
          style: const TextStyle(color: Color(0xFFC5C5C5), fontSize: 12),
        ),
      ],
    );
  }
}

class _BottomCapturePanel extends StatelessWidget {
  const _BottomCapturePanel({
    required this.assistEnabled,
    required this.blockedByQuality,
    required this.brightness,
    required this.sharpness,
    required this.qualityMessage,
    required this.onToggleAssist,
    required this.onCapture,
    required this.capturing,
    required this.thumbs,
    required this.currentPoseId,
    required this.progress,
    required this.recommendedProgress,
    required this.onThumbTap,
  });

  final bool assistEnabled;
  final bool blockedByQuality;
  final double? brightness;
  final double? sharpness;
  final String qualityMessage;
  final VoidCallback onToggleAssist;
  final VoidCallback? onCapture;
  final bool capturing;
  final List<_CapturedThumb> thumbs;
  final String? currentPoseId;
  final double progress;
  final double recommendedProgress;
  final Future<void> Function(PoseStep pose) onThumbTap;

  @override
  Widget build(BuildContext context) {
    final brightnessOk = (brightness ?? 0) >= minBrightness;
    final sharpnessOk = (sharpness ?? 0) >= minSharpness;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: 'Luz',
                value: brightness == null
                    ? '...'
                    : '${brightness!.toStringAsFixed(0)}/255',
                ok: brightness == null || brightnessOk,
              ),
              _MetricPill(
                label: 'Nitidez',
                value: sharpness == null
                    ? '...'
                    : sharpness!.toStringAsFixed(1),
                ok: sharpness == null || sharpnessOk,
              ),
              _MetricPill(
                label: 'Asistencia',
                value: assistEnabled ? 'ON' : 'OFF',
                ok: !assistEnabled || !blockedByQuality,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            qualityMessage,
            style: TextStyle(
              color: blockedByQuality ? Colors.orangeAccent : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _CapturedStrip(
            thumbs: thumbs,
            currentPoseId: currentPoseId,
            onThumbTap: onThumbTap,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: recommendedProgress,
              minHeight: 3,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF9A73FF),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _CircleIconButton(
                icon: assistEnabled
                    ? Icons.assistant_photo_rounded
                    : Icons.assistant_photo_outlined,
                onTap: onToggleAssist,
              ),
              const Spacer(),
              _ShutterButton(capturing: capturing, onTap: onCapture),
              const Spacer(),
              const SizedBox(width: 44, height: 44),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapturedStrip extends StatelessWidget {
  const _CapturedStrip({
    required this.thumbs,
    required this.currentPoseId,
    required this.onThumbTap,
  });

  final List<_CapturedThumb> thumbs;
  final String? currentPoseId;
  final Future<void> Function(PoseStep pose) onThumbTap;

  @override
  Widget build(BuildContext context) {
    if (thumbs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Aun no hay fotos. Captura la primera toma.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: thumbs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = thumbs[index];
          final isCurrent = item.pose.id == currentPoseId;

          return GestureDetector(
            onTap: () => onThumbTap(item.pose),
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? const Color(0xFF9A73FF) : Colors.white24,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(
                      File(item.previewPath),
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      cacheHeight: 120,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
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
}

class _CenterReticle extends StatelessWidget {
  const _CenterReticle({required this.levelLabel, required this.angleLabel});

  final String levelLabel;
  final String angleLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 208,
            height: 208,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(width: 42, height: 2, color: Colors.white70),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(width: 2, height: 42, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$levelLabel | $angleLabel',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF79FFB3) : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.capturing, required this.onTap});

  final bool capturing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 94,
        height: 94,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7B61FF), Color(0xFF3E31B8)],
          ),
          border: Border.all(color: Colors.white70, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B61FF).withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: capturing
              ? const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 34,
                ),
        ),
      ),
    );
  }
}

class _CompletedOverlay extends StatelessWidget {
  const _CompletedOverlay({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.58),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161722),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF79FFB3),
              size: 56,
            ),
            const SizedBox(height: 10),
            const Text(
              'Captura completa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ya puedes revisar y editar cualquier foto tocando las miniaturas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFC5C5C5)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                child: const Text('Volver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitGuidePainter extends CustomPainter {
  _OrbitGuidePainter({
    required this.poses,
    required this.donePoseIds,
    required this.currentPoseId,
  });

  final List<PoseStep> poses;
  final Set<String> donePoseIds;
  final String? currentPoseId;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 24);
    final radius = min(size.width, size.height) * 0.24;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white30
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius, linePaint);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 1.15),
      linePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 1.4,
        height: radius * 2.1,
      ),
      linePaint,
    );

    for (final pose in poses) {
      final angleRad = (pose.angleDeg - 90) * pi / 180;
      final levelOffset = switch (pose.level) {
        PoseLevel.top => -36.0,
        PoseLevel.mid => 0.0,
        PoseLevel.low => 36.0,
      };
      final point = Offset(
        center.dx + cos(angleRad) * radius,
        center.dy + sin(angleRad) * (radius * 0.64) + levelOffset,
      );

      final isDone = donePoseIds.contains(pose.id);
      final isCurrent = pose.id == currentPoseId;
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isDone
            ? const Color(0xFF7B61FF)
            : (isCurrent ? Colors.white : Colors.white30);

      canvas.drawCircle(point, isCurrent ? 6 : 4.5, dotPaint);
      if (isCurrent) {
        canvas.drawCircle(
          point,
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Colors.white54,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitGuidePainter oldDelegate) {
    return oldDelegate.currentPoseId != currentPoseId ||
        oldDelegate.donePoseIds.length != donePoseIds.length;
  }
}

class _CapturedThumb {
  const _CapturedThumb({required this.pose, required this.previewPath});

  final PoseStep pose;
  final String previewPath;
}

class _FrameMetrics {
  const _FrameMetrics({required this.brightness, required this.sharpness});

  final double brightness;
  final double sharpness;
}
