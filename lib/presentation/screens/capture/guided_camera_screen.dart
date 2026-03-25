import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../widgets/capture_guidance_ring.dart';
import 'capture_guide_plan.dart';

class GuidedCameraShot {
  const GuidedCameraShot({
    required this.sourcePath,
    this.poseId,
    this.angleDeg,
    this.level,
    this.brightness,
    this.detail,
    required this.qualityOk,
  });

  final String sourcePath;
  final String? poseId;
  final int? angleDeg;
  final String? level;
  final double? brightness;
  final double? detail;
  final bool qualityOk;
}

class GuidedCameraSessionResult {
  const GuidedCameraSessionResult({required this.shots});

  final List<GuidedCameraShot> shots;
}

enum _SceneQuality { analyzing, good, warning, critical }

enum _DistanceBand { unknown, far, optimal, close }

class GuidedCameraScreen extends StatefulWidget {
  const GuidedCameraScreen({
    super.key,
    required this.projectName,
    required this.captureIndex,
    required this.targetMinPhotos,
    required this.targetMaxPhotos,
    required this.levelKey,
    required this.levelLabel,
    required this.angleDeg,
    required this.requireLiveQualityGate,
  });

  final String projectName;
  final int captureIndex;
  final int targetMinPhotos;
  final int targetMaxPhotos;
  final String levelKey;
  final String levelLabel;
  final int angleDeg;
  final bool requireLiveQualityGate;

  @override
  State<GuidedCameraScreen> createState() => _GuidedCameraScreenState();
}

class _GuidedCameraScreenState extends State<GuidedCameraScreen> {
  static const _minBrightness = 55.0;
  static const _minDetail = 12.0;
  static const _analysisStep = 8;
  static const _analysisInterval = Duration(milliseconds: 280);

  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  bool _streaming = false;
  bool _processingFrame = false;
  bool _submitted = false;
  bool _showCaptureFx = false;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  double? _brightness;
  double? _detail;
  double _stability = 1;
  double? _lastBalanceX;
  double? _lastBalanceY;
  String? _errorText;
  Timer? _promptTimer;
  _GuidanceMessage? _temporaryGuidance;
  final List<GuidedCameraShot> _sessionShots = <GuidedCameraShot>[];

  int get _capturedTotal => widget.captureIndex + _sessionShots.length;
  CaptureGuideStep get _nextStep =>
      CaptureGuidePlan.stepForCaptureCount(_capturedTotal);

  _SceneQuality get _quality {
    if (_brightness == null || _detail == null) return _SceneQuality.analyzing;
    if (_brightness! < (_minBrightness * 0.72) ||
        _detail! < (_minDetail * 0.7)) {
      return _SceneQuality.critical;
    }
    if (_brightness! < _minBrightness ||
        _detail! < _minDetail ||
        _stability < 0.45) {
      return _SceneQuality.warning;
    }
    return _SceneQuality.good;
  }

  bool get _isCaptureAllowed {
    final controller = _controller;
    if (_capturing || controller == null || !controller.value.isInitialized) {
      return false;
    }
    if (!widget.requireLiveQualityGate) return true;
    return _quality == _SceneQuality.analyzing ||
        _quality == _SceneQuality.good;
  }

  List<int> get _capturedSectors {
    final sectors = <int>{};
    for (final shot in _sessionShots) {
      final angle = shot.angleDeg;
      if (angle == null) continue;
      sectors.add((((angle % 360) + 360) % 360) ~/ 30 * 30);
    }
    return sectors.toList()..sort();
  }

  double get _coverageProgress {
    if (widget.targetMinPhotos == 0) return 0;
    return (_capturedTotal / widget.targetMinPhotos).clamp(0.0, 1.0);
  }

  _DistanceBand get _distanceBand {
    if (_detail == null) return _DistanceBand.unknown;
    if (_detail! < (_minDetail * 0.82)) return _DistanceBand.far;
    if (_detail! > (_minDetail * 2.1)) return _DistanceBand.close;
    return _DistanceBand.optimal;
  }

  String get _distanceLabel => switch (_distanceBand) {
    _DistanceBand.unknown => '--',
    _DistanceBand.far => 'Lejos',
    _DistanceBand.optimal => 'Ok',
    _DistanceBand.close => 'Cerca',
  };

  Offset get _objectOffset => Offset(
    (_lastBalanceX ?? 0).clamp(-1.0, 1.0),
    (_lastBalanceY ?? 0).clamp(-1.0, 1.0),
  );

  _GuidanceMessage get _activeGuidance =>
      _temporaryGuidance ?? _buildLiveGuidance();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    if (!_submitted) unawaited(_cleanupUnsavedShots());
    unawaited(_stopImageStreamIfNeeded());
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_capturing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _capturing) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildCameraLayer()),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.34),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.64),
                        ],
                        stops: const [0, 0.38, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: _buildOverlay()),
              if (_showCaptureFx)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorText != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  Widget _buildOverlay() {
    final topBar = _TopHud(
      projectName: widget.projectName,
      capturedTotal: _capturedTotal,
      targetMinPhotos: widget.targetMinPhotos,
      sessionShotCount: _sessionShots.length,
      progress: _coverageProgress,
      onClose: _capturing ? null : () => Navigator.of(context).pop(),
    );

    if (_initializing || _errorText != null) {
      return Column(children: [topBar, const Spacer()]);
    }

    final guidance = _activeGuidance;

    return Column(
      children: [
        topBar,
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CaptureGuidanceRing(
                  capturedSectors: _capturedSectors,
                  suggestedAngle: _nextStep.angleDeg,
                  highlightColor: guidance.color,
                  objectOffset: _objectOffset,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.42),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${_nextStep.level.label} - ${_nextStep.angleDeg} deg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GuidanceBanner(message: guidance),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HudPill(label: 'Nivel', value: _nextStep.level.label),
                  _HudPill(label: 'Sector', value: '${_nextStep.angleDeg} deg'),
                  _HudPill(label: 'Distancia', value: _distanceLabel),
                  _HudPill(
                    label: 'Progreso',
                    value: '$_capturedTotal/${widget.targetMinPhotos}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _ControlButton(
                      icon: Icons.photo_library_outlined,
                      label: _sessionShots.isEmpty
                          ? 'Lote'
                          : 'Lote ${_sessionShots.length}',
                      onTap: _openSessionShotsSheet,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isCaptureAllowed
                        ? _takePicture
                        : _handleBlockedShot,
                    child: _ShutterButton(
                      enabled: _isCaptureAllowed,
                      capturing: _capturing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ControlButton(
                      icon: Icons.check_rounded,
                      label: 'Finalizar',
                      emphasized: _sessionShots.isNotEmpty,
                      onTap: _finishSession,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  _GuidanceMessage _buildLiveGuidance() {
    if (_quality == _SceneQuality.critical) {
      if ((_brightness ?? 0) < (_minBrightness * 0.72)) {
        return const _GuidanceMessage(
          text: 'Busca un poco mas de luz',
          color: Color(0xFFFFB347),
          icon: Icons.wb_sunny_outlined,
        );
      }
      return const _GuidanceMessage(
        text: 'Acercate un poco al objeto',
        color: Color(0xFFFFB347),
        icon: Icons.zoom_in_rounded,
      );
    }

    if (_stability < 0.45) {
      return const _GuidanceMessage(
        text: 'Falta estabilidad',
        color: Color(0xFFFFB347),
        icon: Icons.motion_photos_pause_rounded,
      );
    }

    final balanceX = _lastBalanceX ?? 0;
    if (balanceX > 0.14) {
      return const _GuidanceMessage(
        text: 'Mueve la camara a la izquierda',
        color: Color(0xFF76A7FF),
        icon: Icons.west_rounded,
      );
    }
    if (balanceX < -0.14) {
      return const _GuidanceMessage(
        text: 'Mueve la camara a la derecha',
        color: Color(0xFF76A7FF),
        icon: Icons.east_rounded,
      );
    }

    final balanceY = _lastBalanceY ?? 0;
    if (balanceY > 0.16) {
      return const _GuidanceMessage(
        text: 'Sube un poco la camara',
        color: Color(0xFF76A7FF),
        icon: Icons.north_rounded,
      );
    }
    if (balanceY < -0.16) {
      return const _GuidanceMessage(
        text: 'Baja un poco la camara',
        color: Color(0xFF76A7FF),
        icon: Icons.south_rounded,
      );
    }

    if (_quality == _SceneQuality.good) {
      return const _GuidanceMessage(
        text: 'Lista para capturar',
        color: Color(0xFF57D684),
        icon: Icons.check_circle_outline_rounded,
      );
    }

    return const _GuidanceMessage(
      text: 'Manten el objeto dentro del anillo',
      color: Color(0xFFC3CAD9),
      icon: Icons.track_changes_rounded,
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorText = 'No se encontraron camaras disponibles.';
          _initializing = false;
        });
        return;
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      await _startImageStreamIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'No se pudo iniciar la camara.';
        _initializing = false;
      });
    }
  }

  Future<void> _startImageStreamIfNeeded() async {
    final controller = _controller;
    if (controller == null || _streaming || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (_) {
      _streaming = false;
    }
  }

  Future<void> _stopImageStreamIfNeeded() async {
    final controller = _controller;
    if (controller == null || !_streaming || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.stopImageStream();
    } catch (_) {
      // ignore race conditions
    } finally {
      _streaming = false;
    }
  }

  void _onFrame(CameraImage image) {
    if (!mounted || _capturing || _processingFrame) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _analysisInterval) return;
    _lastFrameAt = now;
    _processingFrame = true;
    try {
      final metrics = _estimateMetrics(image);
      if (metrics == null || !mounted) return;
      final stability = _estimateStability(metrics.balanceX, metrics.balanceY);
      setState(() {
        _brightness = metrics.brightness;
        _detail = metrics.detail;
        _stability = stability;
        _lastBalanceX = metrics.balanceX;
        _lastBalanceY = metrics.balanceY;
      });
    } finally {
      _processingFrame = false;
    }
  }

  double _estimateStability(double balanceX, double balanceY) {
    if (_lastBalanceX == null || _lastBalanceY == null) return _stability;
    final movement =
        ((balanceX - _lastBalanceX!).abs() + (balanceY - _lastBalanceY!).abs())
            .clamp(0.0, 0.42);
    final instant = 1 - (movement / 0.42);
    return (_stability * 0.58) + (instant * 0.42);
  }

  _FrameMetrics? _estimateMetrics(CameraImage image) {
    if (image.planes.isEmpty) return null;
    if (image.width <= _analysisStep || image.height <= _analysisStep) {
      return null;
    }

    double lumaAt(int x, int y) {
      if (image.format.group == ImageFormatGroup.bgra8888) {
        final plane = image.planes[0];
        final index = y * plane.bytesPerRow + (x * 4);
        if (index < 0 || index + 2 >= plane.bytes.length) return 0;
        final b = plane.bytes[index].toDouble();
        final g = plane.bytes[index + 1].toDouble();
        final r = plane.bytes[index + 2].toDouble();
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
      }
      final plane = image.planes[0];
      final pixelStride = plane.bytesPerPixel ?? 1;
      final index = y * plane.bytesPerRow + (x * pixelStride);
      if (index < 0 || index >= plane.bytes.length) return 0;
      return plane.bytes[index].toDouble();
    }

    final maxX = image.width - _analysisStep;
    final maxY = image.height - _analysisStep;
    double brightnessSum = 0;
    double detailSum = 0;
    double leftSum = 0;
    double rightSum = 0;
    double topSum = 0;
    double bottomSum = 0;
    int leftCount = 0;
    int rightCount = 0;
    int topCount = 0;
    int bottomCount = 0;
    int samples = 0;
    final halfX = image.width / 2;
    final halfY = image.height / 2;

    for (int y = 0; y < maxY; y += _analysisStep) {
      for (int x = 0; x < maxX; x += _analysisStep) {
        final luma = lumaAt(x, y);
        final right = lumaAt(x + _analysisStep, y);
        final down = lumaAt(x, y + _analysisStep);
        brightnessSum += luma;
        detailSum += (luma - right).abs() + (luma - down).abs();
        samples++;
        if (x < halfX) {
          leftSum += luma;
          leftCount++;
        } else {
          rightSum += luma;
          rightCount++;
        }
        if (y < halfY) {
          topSum += luma;
          topCount++;
        } else {
          bottomSum += luma;
          bottomCount++;
        }
      }
    }

    if (samples == 0) return null;

    return _FrameMetrics(
      brightness: brightnessSum / samples,
      detail: detailSum / samples,
      balanceX:
          ((rightSum / max(1, rightCount) - leftSum / max(1, leftCount)) / 255)
              .clamp(-1.0, 1.0)
              .toDouble(),
      balanceY:
          ((bottomSum / max(1, bottomCount) - topSum / max(1, topCount)) / 255)
              .clamp(-1.0, 1.0)
              .toDouble(),
    );
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (!_isCaptureAllowed || controller == null) {
      _handleBlockedShot();
      return;
    }

    setState(() => _capturing = true);
    try {
      await _stopImageStreamIfNeeded();
      final shot = await controller.takePicture();
      if (!mounted) return;
      final accepted = await _validateShot(shot.path);
      if (!mounted) return;
      if (!accepted) {
        await _deleteIfExists(shot.path);
        _showTemporaryGuidance(
          const _GuidanceMessage(
            text: 'Repite la toma',
            color: Color(0xFFFFB347),
            icon: Icons.replay_rounded,
          ),
        );
        return;
      }
      final step = _nextStep;
      setState(() {
        _sessionShots.add(
          GuidedCameraShot(
            sourcePath: shot.path,
            poseId: '${step.level.key}_${step.angleDeg}',
            angleDeg: step.angleDeg,
            level: step.level.key,
            brightness: _brightness,
            detail: _detail,
            qualityOk: _quality == _SceneQuality.good,
          ),
        );
        _showCaptureFx = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        setState(() => _showCaptureFx = false);
      });
      _showTemporaryGuidance(
        const _GuidanceMessage(
          text: 'Buena captura',
          color: Color(0xFF57D684),
          icon: Icons.check_circle_outline_rounded,
        ),
      );
    } catch (_) {
      _showTemporaryGuidance(
        const _GuidanceMessage(
          text: 'No se pudo capturar la toma',
          color: Color(0xFFFF7777),
          icon: Icons.error_outline_rounded,
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
      await _startImageStreamIfNeeded();
    }
  }

  void _handleBlockedShot() {
    _showTemporaryGuidance(
      _quality == _SceneQuality.critical
          ? const _GuidanceMessage(
              text: 'La escena aun no esta lista',
              color: Color(0xFFFF7777),
              icon: Icons.block_rounded,
            )
          : const _GuidanceMessage(
              text: 'Espera una escena mas estable',
              color: Color(0xFFFFB347),
              icon: Icons.motion_photos_pause_rounded,
            ),
    );
  }

  Future<bool> _validateShot(String path) async {
    final guidance = _activeGuidance;

    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Revision inmediata',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'Confirma si esta toma entra al lote actual.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1.35,
                  child: Image.file(File(path), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              _GuidanceBanner(message: guidance, compact: true),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HudPill(
                    label: 'Brillo',
                    value: _brightness == null
                        ? '--'
                        : _brightness!.toStringAsFixed(0),
                  ),
                  _HudPill(
                    label: 'Detalle',
                    value: _detail == null ? '--' : _detail!.toStringAsFixed(0),
                  ),
                  _HudPill(
                    label: 'Estabilidad',
                    value: '${(_stability * 100).round()}%',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Descartar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Guardar toma'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> _openSessionShotsSheet() async {
    if (_sessionShots.isEmpty) {
      _showTemporaryGuidance(
        const _GuidanceMessage(
          text: 'Aun no hay capturas en este lote',
          color: Color(0xFFC3CAD9),
          icon: Icons.photo_library_outlined,
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lote temporal',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '${_sessionShots.length} capturas listas para guardarse en el proyecto.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sessionShots.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final shot = _sessionShots[index];
                    return GestureDetector(
                      onLongPress: () => _removeShot(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(shot.sourcePath),
                          width: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFF101520),
                            child: SizedBox(
                              width: 96,
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manten pulsada una captura para eliminarla y repetir la toma.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeShot(int index) async {
    if (index < 0 || index >= _sessionShots.length) return;
    final removed = _sessionShots.removeAt(index);
    await _deleteIfExists(removed.sourcePath);
    if (!mounted) return;
    setState(() {});
    _showTemporaryGuidance(
      const _GuidanceMessage(
        text: 'Repite la toma',
        color: Color(0xFFFFB347),
        icon: Icons.replay_rounded,
      ),
    );
  }

  Future<void> _finishSession() async {
    if (_sessionShots.isEmpty) {
      _showTemporaryGuidance(
        const _GuidanceMessage(
          text: 'Toma al menos una captura antes de finalizar',
          color: Color(0xFFC3CAD9),
          icon: Icons.info_outline_rounded,
        ),
      );
      return;
    }
    _submitted = true;
    await _stopImageStreamIfNeeded();
    if (!mounted) return;
    Navigator.of(context).pop(GuidedCameraSessionResult(shots: _sessionShots));
  }

  void _showTemporaryGuidance(_GuidanceMessage message) {
    _promptTimer?.cancel();
    if (!mounted) return;
    setState(() => _temporaryGuidance = message);
    _promptTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _temporaryGuidance = null);
    });
  }

  Future<void> _cleanupUnsavedShots() async {
    for (final shot in _sessionShots) {
      await _deleteIfExists(shot.sourcePath);
    }
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // best effort
    }
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.projectName,
    required this.capturedTotal,
    required this.targetMinPhotos,
    required this.sessionShotCount,
    required this.progress,
    required this.onClose,
  });

  final String projectName;
  final int capturedTotal;
  final int targetMinPhotos;
  final int sessionShotCount;
  final double progress;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$capturedTotal / $targetMinPhotos objetivo minimo',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '$sessionShotCount en lote',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF76A7FF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner({required this.message, this.compact = false});

  final _GuidanceMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: message.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: message.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(message.icon, size: 18, color: message.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.text,
              style: TextStyle(
                color: compact ? Colors.white : message.color,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: Colors.white70),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: emphasized
              ? const Color(0xFF76A7FF)
              : Colors.black.withValues(alpha: 0.36),
          foregroundColor: Colors.white,
          elevation: 0,
          side: BorderSide(
            color: emphasized ? Colors.transparent : Colors.white12,
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.enabled, required this.capturing});

  final bool enabled;
  final bool capturing;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled ? Colors.white.withValues(alpha: 0.08) : Colors.white10,
        border: Border.all(
          color: enabled ? Colors.white : Colors.white30,
          width: 3,
        ),
        boxShadow: [
          if (enabled)
            BoxShadow(
              color: const Color(0xFF76A7FF).withValues(alpha: 0.3),
              blurRadius: 26,
            ),
        ],
      ),
      child: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled
                  ? const [Colors.white, Color(0xFFE7F0FF)]
                  : [Colors.white38, Colors.white24],
            ),
          ),
          child: Center(
            child: capturing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Icon(
                    Icons.camera_alt_rounded,
                    color: enabled ? Colors.black : Colors.black54,
                    size: 30,
                  ),
          ),
        ),
      ),
    );
  }
}

class _GuidanceMessage {
  const _GuidanceMessage({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;
}

class _FrameMetrics {
  const _FrameMetrics({
    required this.brightness,
    required this.detail,
    required this.balanceX,
    required this.balanceY,
  });

  final double brightness;
  final double detail;
  final double balanceX;
  final double balanceY;
}
