import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../widgets/capture_guidance_ring.dart';
import 'capture_guide_plan.dart';
import 'capture_profile.dart';

class GuidedCameraShot {
  const GuidedCameraShot({
    required this.sourcePath,
    this.poseId,
    this.angleDeg,
    this.level,
    this.brightness,
    this.detail,
    this.width,
    this.height,
    required this.stable,
    this.warnings = const [],
    required this.profile,
    required this.qualityOk,
    required this.captureStartTime,
    required this.captureEndTime,
    required this.captureDurationMs,
    required this.cameraResolutionPreset,
    required this.qualityGateEnabled,
    required this.realtimeAnalysisEnabled,
  });

  final String sourcePath;
  final String? poseId;
  final int? angleDeg;
  final String? level;
  final double? brightness;
  final double? detail;
  final int? width;
  final int? height;
  final bool stable;
  final List<String> warnings;
  final CaptureProfile profile;
  final bool qualityOk;
  final DateTime captureStartTime;
  final DateTime captureEndTime;
  final int captureDurationMs;
  final String cameraResolutionPreset;
  final bool qualityGateEnabled;
  final bool realtimeAnalysisEnabled;
}

class GuidedCameraSessionResult {
  const GuidedCameraSessionResult({required this.shots});

  final List<GuidedCameraShot> shots;
}

enum _SceneQuality { analyzing, good, warning, critical }

enum _DistanceBand { unknown, far, optimal, close }

enum _PendingSessionDecision { keepCapturing, discard, saveAndExit }

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
    required this.captureProfile,
    required this.existingLevelCounts,
  });

  final String projectName;
  final int captureIndex;
  final int targetMinPhotos;
  final int targetMaxPhotos;
  final String levelKey;
  final String levelLabel;
  final int angleDeg;
  final bool requireLiveQualityGate;
  final CaptureProfile captureProfile;
  final Map<String, int> existingLevelCounts;

  @override
  State<GuidedCameraScreen> createState() => _GuidedCameraScreenState();
}

class _GuidedCameraScreenState extends State<GuidedCameraScreen> {
  static const _minBrightness = 55.0;
  static const _minDetail = 12.0;
  static const _metricEpsilon = 0.5;
  static const _simpleUi = true;

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
  DateTime _lastShotAt = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastAverageHash;
  final List<GuidedCameraShot> _sessionShots = <GuidedCameraShot>[];

  int get _capturedTotal => widget.captureIndex + _sessionShots.length;
  int get _recommendedMinPhotos => max(30, widget.captureProfile.recommendedMinPhotos);
  int get _recommendedIdealPhotos => widget.captureProfile.recommendedIdealPhotos;
  CaptureGuideStep get _nextStep =>
      CaptureGuidePlan.stepForCaptureCount(_capturedTotal);
  Duration get _minShotInterval =>
      Duration(milliseconds: widget.captureProfile.minIntervalMs);
  Duration get _stabilityProbeWindow =>
      Duration(milliseconds: widget.captureProfile.stabilityProbeMs);
  Duration get _preShotWait =>
      Duration(milliseconds: widget.captureProfile.preShotWaitMs);
  double get _stabilityThreshold => widget.captureProfile.stabilityThreshold;
  int get _analysisStep => switch (widget.captureProfile) {
    CaptureProfile.rapido => 10,
    CaptureProfile.estable => 8,
    CaptureProfile.maximaCalidad => 6,
  };
  Duration get _analysisInterval => switch (widget.captureProfile) {
    CaptureProfile.rapido => const Duration(milliseconds: 420),
    CaptureProfile.estable => const Duration(milliseconds: 300),
    CaptureProfile.maximaCalidad => const Duration(milliseconds: 240),
  };
  ResolutionPreset get _cameraResolutionPreset => switch (widget.captureProfile) {
    CaptureProfile.rapido => ResolutionPreset.high,
    CaptureProfile.estable => ResolutionPreset.veryHigh,
    CaptureProfile.maximaCalidad => ResolutionPreset.max,
  };
  bool get _realtimeAnalysisEnabled =>
      widget.requireLiveQualityGate || widget.captureProfile != CaptureProfile.rapido;

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
  String get _captureStateLabel {
    if (_capturedTotal < _recommendedMinPhotos) return 'Insuficiente';
    if (_capturedTotal < 45) return 'Aceptable';
    if (_capturedTotal < 60) return 'Bueno';
    return 'Excelente';
  }

  String get _rotatingTip {
    const tips = [
      'Manten el objeto centrado',
      'Toma fotos alrededor del objeto',
      'Cambia un poco la altura',
      'Evita reflejos',
      'No uses zoom',
      'Manten buena iluminacion',
      'No repitas el mismo angulo',
    ];
    return tips[_capturedTotal % tips.length];
  }

  Map<String, int> get _levelCounts {
    final counts = <String, int>{
      'low': widget.existingLevelCounts['low'] ?? 0,
      'mid': widget.existingLevelCounts['mid'] ?? 0,
      'top': widget.existingLevelCounts['top'] ?? 0,
    };
    for (final shot in _sessionShots) {
      final level = shot.level;
      if (level == null || !counts.containsKey(level)) continue;
      counts[level] = (counts[level] ?? 0) + 1;
    }
    return counts;
  }

  String _levelStatus(String key) {
    final count = _levelCounts[key] ?? 0;
    if (count >= 10) return 'Completo';
    if (count >= 4) return 'En progreso';
    return 'Pendiente';
  }

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
        unawaited(_handleCloseRequested());
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
      onClose: _capturing ? null : _handleCloseRequested,
    );

    if (_initializing || _errorText != null) {
      return Column(children: [topBar, const Spacer()]);
    }

    final guidance = _activeGuidance;

    if (_simpleUi) {
      return _buildSimpleOverlay(topBar, guidance);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final ringWidth = (constraints.maxWidth - 68).clamp(210.0, 420.0);
        final showExtraGuidance = constraints.maxHeight > 760;

        return Column(
          children: [
            topBar,
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: SizedBox(
                width: ringWidth,
                height: ringWidth,
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
            SizedBox(height: showExtraGuidance ? 18 : 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GuidanceBanner(message: guidance),
                  const SizedBox(height: 8),
                  Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HudPill(
                    label: 'Perfil',
                    value: widget.captureProfile.label,
                  ),
                  _HudPill(label: 'Nivel', value: _nextStep.level.label),
                  _HudPill(label: 'Sector', value: '${_nextStep.angleDeg} deg'),
                  _HudPill(label: 'Distancia', value: _distanceLabel),
                  _HudPill(
                    label: 'Progreso',
                    value: '$_capturedTotal/$_recommendedIdealPhotos',
                  ),
                  _HudPill(
                    label: 'Estado',
                    value: _captureStateLabel,
                  ),
                ],
              ),
                  if (showExtraGuidance) ...[
                    const SizedBox(height: 8),
                    _GuidanceBanner(
                      message: _GuidanceMessage(
                        text: _rotatingTip,
                        color: const Color(0xFF76A7FF),
                        icon: Icons.lightbulb_outline_rounded,
                      ),
                      compact: true,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HudPill(
                          label: 'Nivel bajo',
                          value: _levelStatus('low'),
                        ),
                        _HudPill(
                          label: 'Nivel medio',
                          value: _levelStatus('mid'),
                        ),
                        _HudPill(
                          label: 'Nivel alto',
                          value: _levelStatus('top'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
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
                      label: _sessionShots.isEmpty
                          ? 'Finalizar'
                          : 'Guardar lote',
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
      },
    );
  }

  Widget _buildSimpleOverlay(Widget topBar, _GuidanceMessage guidance) {
    final statusText = _simpleStatusText();
    return Column(
      children: [
        topBar,
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: guidance.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: guidance.color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _HudPill(label: 'Fotos', value: '$_capturedTotal'),
                  const SizedBox(width: 8),
                  _HudPill(label: 'Perfil', value: widget.captureProfile.label),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Spacer(),
                  GestureDetector(
                    onTap: _isCaptureAllowed ? _takePicture : _handleBlockedShot,
                    child: _ShutterButton(
                      enabled: _isCaptureAllowed,
                      capturing: _capturing,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 132,
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

  String _simpleStatusText() {
    if (_capturing) return 'Estabilizando';
    if (_stability < _stabilityThreshold) return 'Estabilizando';
    if (_quality == _SceneQuality.good) return 'Buena toma';
    if (_nextStep.level == CaptureLevel.high) return 'Sube altura';
    return 'Mueve alrededor';
  }

  _GuidanceMessage _buildLiveGuidance() {
    if (_quality == _SceneQuality.critical) {
      if ((_brightness ?? 0) < (_minBrightness * 0.72)) {
        return const _GuidanceMessage(
          text: 'Sube la iluminacion antes de disparar',
          color: Color(0xFFFFB347),
          icon: Icons.wb_sunny_outlined,
        );
      }
      return const _GuidanceMessage(
        text: 'Acercate al objeto para ganar detalle',
        color: Color(0xFFFFB347),
        icon: Icons.zoom_in_rounded,
      );
    }

    if (_stability < 0.45) {
      return const _GuidanceMessage(
        text: 'Estabiliza la camara y vuelve a intentar',
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
        _cameraResolutionPreset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await _configureControllerForCapture(controller);
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
    if (!_realtimeAnalysisEnabled) {
      return;
    }
    try {
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (_) {
      _streaming = false;
    }
  }

  Future<void> _configureControllerForCapture(CameraController controller) async {
    try {
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {
      // Some devices do not expose all controls.
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
      final prevBrightness = _brightness;
      final prevDetail = _detail;
      final changedEnough =
          prevBrightness == null ||
          prevDetail == null ||
          (prevBrightness - metrics.brightness).abs() > _metricEpsilon ||
          (prevDetail - metrics.detail).abs() > _metricEpsilon;
      if (!changedEnough) return;
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
      final captureStart = DateTime.now();
      final now = captureStart;
      if (now.difference(_lastShotAt) < _minShotInterval) {
        _showTemporaryGuidance(
          const _GuidanceMessage(
            text: 'Espera un instante entre tomas',
            color: Color(0xFFFFB347),
            icon: Icons.timer_outlined,
          ),
        );
        return;
      }

      if (!await _waitForStableScene()) {
        _showTemporaryGuidance(
          const _GuidanceMessage(
            text: 'Espera, estabilizando camara...',
            color: Color(0xFFFFB347),
            icon: Icons.motion_photos_pause_rounded,
          ),
        );
        return;
      }

      await _stopImageStreamIfNeeded();
      await _configureControllerForCapture(controller);
      await Future<void>.delayed(_preShotWait);
      final shot = await controller.takePicture();
      final captureEnd = DateTime.now();
      final captureDurationMs = captureEnd
          .difference(captureStart)
          .inMilliseconds
          .clamp(0, 600000)
          .toInt();
      _lastShotAt = captureEnd;
      if (!mounted) return;
      final diagnostics = await _analyzeShot(path: shot.path);
      final accepted = await _validateShot(shot.path, diagnostics);
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
            width: diagnostics.width,
            height: diagnostics.height,
            stable: _stability >= _stabilityThreshold,
            warnings: diagnostics.warnings,
            profile: widget.captureProfile,
            qualityOk: _quality == _SceneQuality.good,
            captureStartTime: captureStart,
            captureEndTime: captureEnd,
            captureDurationMs: captureDurationMs,
            cameraResolutionPreset: _cameraResolutionPreset.name,
            qualityGateEnabled: widget.requireLiveQualityGate,
            realtimeAnalysisEnabled: _realtimeAnalysisEnabled,
          ),
        );
        _lastAverageHash = diagnostics.averageHash;
        _showCaptureFx = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        setState(() => _showCaptureFx = false);
      });
      _showTemporaryGuidance(
        const _GuidanceMessage(
          text: 'Captura confirmada. Usa Guardar lote para dejarla en el proyecto.',
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

  Future<bool> _waitForStableScene() async {
    if (_quality == _SceneQuality.critical) return false;
    if (_stability >= _stabilityThreshold) return true;

    final start = DateTime.now();
    while (DateTime.now().difference(start) < _stabilityProbeWindow) {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!mounted) return false;
      if (_quality == _SceneQuality.critical) return false;
      if (_stability >= _stabilityThreshold) return true;
    }
    return false;
  }

  Future<_ShotDiagnostics> _analyzeShot({required String path}) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return const _ShotDiagnostics.empty();

      final small = img.copyResize(decoded, width: 96);
      final brightness = _estimateBrightnessImage(small);
      final sharpness = _estimateSharpnessImage(small);
      final hash = _averageHash8(small);
      final similarity = _lastAverageHash == null
          ? 0.0
          : _hashSimilarity(_lastAverageHash!, hash);

      final warnings = <String>[];
      if (brightness < 48) warnings.add('demasiado_oscura');
      if (brightness > 212) warnings.add('demasiado_clara');
      if (sharpness < 8.5) warnings.add('borrosa');
      if (similarity > 0.93) warnings.add('muy_parecida_a_anterior');

      return _ShotDiagnostics(
        width: decoded.width,
        height: decoded.height,
        averageHash: hash,
        warnings: warnings,
      );
    } catch (_) {
      return const _ShotDiagnostics.empty();
    }
  }

  double _estimateBrightnessImage(img.Image image) {
    double sum = 0;
    final count = image.width * image.height;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);
        sum += (0.2126 * px.r + 0.7152 * px.g + 0.0722 * px.b);
      }
    }
    return sum / max(1, count);
  }

  double _estimateSharpnessImage(img.Image image) {
    double sum = 0;
    int count = 0;
    int lumAt(int x, int y) {
      final px = image.getPixel(x, y);
      return (0.2126 * px.r + 0.7152 * px.g + 0.0722 * px.b).round();
    }

    for (int y = 0; y < image.height - 1; y++) {
      for (int x = 0; x < image.width - 1; x++) {
        final l = lumAt(x, y);
        final dx = (l - lumAt(x + 1, y)).abs();
        final dy = (l - lumAt(x, y + 1)).abs();
        sum += dx + dy;
        count++;
      }
    }
    return sum / max(1, count);
  }

  int _averageHash8(img.Image image) {
    final resized = img.copyResize(image, width: 8, height: 8);
    final luminances = <double>[];
    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        final px = resized.getPixel(x, y);
        luminances.add(0.2126 * px.r + 0.7152 * px.g + 0.0722 * px.b);
      }
    }
    final avg = luminances.reduce((a, b) => a + b) / luminances.length;
    int hash = 0;
    for (int i = 0; i < luminances.length; i++) {
      if (luminances[i] >= avg) {
        hash |= (1 << i);
      }
    }
    return hash;
  }

  double _hashSimilarity(int a, int b) {
    final xor = a ^ b;
    int distance = 0;
    for (int i = 0; i < 64; i++) {
      if (((xor >> i) & 1) == 1) distance++;
    }
    return 1 - (distance / 64.0);
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
              text: 'Espera, estabilizando camara...',
              color: Color(0xFFFFB347),
              icon: Icons.motion_photos_pause_rounded,
            ),
    );
  }

  Future<bool> _validateShot(String path, _ShotDiagnostics diagnostics) async {
    final guidance = _activeGuidance;
    if (!mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.92,
          ),
          child: SingleChildScrollView(
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
                    aspectRatio: 1.1,
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
                      value:
                          _detail == null ? '--' : _detail!.toStringAsFixed(0),
                    ),
                    _HudPill(
                      label: 'Estabilidad',
                      value: '${(_stability * 100).round()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (diagnostics.warnings.isNotEmpty) ...[
                  Text(
                    'Advertencias: ${diagnostics.warnings.join(', ')}',
                    style: const TextStyle(color: Color(0xFFFFB347), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Repetir'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Confirmar captura'),
                      ),
                    ),
                  ],
                ),
                if (_sessionShots.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${_sessionShots.length} capturas siguen en el lote. Usa "Guardar lote" para dejarlas en el proyecto.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
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
    final checklist = _buildFinishChecklist();
    final shouldFinalize = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checklist de captura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fotos totales: $_capturedTotal'),
            Text('Estado global: $_captureStateLabel'),
            const SizedBox(height: 8),
            for (final line in checklist) Text('- $line'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar capturando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (shouldFinalize != true) return;

    _submitted = true;
    await _stopImageStreamIfNeeded();
    if (!mounted) return;
    Navigator.of(context).pop(GuidedCameraSessionResult(shots: _sessionShots));
  }

  List<String> _buildFinishChecklist() {
    final lines = <String>[];
    lines.add('Estado: $_captureStateLabel');
    if (_capturedTotal < _recommendedMinPhotos) {
      lines.add('Faltan fotos');
    }
    final low = _levelStatus('low');
    final top = _levelStatus('top');
    if (top == 'Pendiente') {
      lines.add('Toma algunas desde arriba');
    } else if (low == 'Pendiente') {
      lines.add('Toma algunas desde abajo');
    } else if (_captureStateLabel == 'Insuficiente') {
      lines.add('Toma algunas mas alrededor');
    } else {
      lines.add('Puedes finalizar');
    }
    return lines;
  }

  Future<void> _handleCloseRequested() async {
    if (_capturing || !mounted) return;
    if (_sessionShots.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final decision = await showDialog<_PendingSessionDecision>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hay capturas pendientes'),
        content: Text(
          'Tienes ${_sessionShots.length} capturas confirmadas en el lote actual. '
          'Si sales sin guardarlas, se descartaran.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(
                _PendingSessionDecision.keepCapturing,
              );
            },
            child: const Text('Seguir'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(_PendingSessionDecision.discard);
            },
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(_PendingSessionDecision.saveAndExit);
            },
            child: const Text('Guardar lote'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    switch (decision) {
      case _PendingSessionDecision.saveAndExit:
        await _finishSession();
        return;
      case _PendingSessionDecision.discard:
        Navigator.of(context).pop();
        return;
      case _PendingSessionDecision.keepCapturing:
      case null:
        return;
    }
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

class _ShotDiagnostics {
  const _ShotDiagnostics({
    required this.width,
    required this.height,
    required this.averageHash,
    required this.warnings,
  });

  const _ShotDiagnostics.empty()
    : width = 0,
      height = 0,
      averageHash = 0,
      warnings = const [];

  final int width;
  final int height;
  final int averageHash;
  final List<String> warnings;
}
