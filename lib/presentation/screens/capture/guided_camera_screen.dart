import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class GuidedCameraShot {
  const GuidedCameraShot({
    required this.sourcePath,
    this.brightness,
    this.detail,
    required this.qualityOk,
  });

  final String sourcePath;
  final double? brightness;
  final double? detail;
  final bool qualityOk;
}

class GuidedCameraSessionResult {
  const GuidedCameraSessionResult({required this.shots});

  final List<GuidedCameraShot> shots;
}

enum _SessionShotAction { replace, delete }

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
  static const _analysisInterval = Duration(milliseconds: 260);
  static const _maxAutoGuideShift = 0.22;
  static const _maxManualGuideShift = 0.36;

  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  bool _streaming = false;
  bool _assistEnabled = true;
  bool _processingFrame = false;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _errorText;

  double? _brightness;
  double? _detail;
  Offset _autoGuideOffset = Offset.zero;
  Offset _manualGuideOffset = Offset.zero;
  double _manualAngleOffsetDeg = 0;
  double _autoOrbRotationDeg = 0;
  double? _lastBalanceX;
  double? _lastBalanceY;
  bool _guideTouched = false;
  final List<GuidedCameraShot> _sessionShots = <GuidedCameraShot>[];

  int get _capturedTotal => widget.captureIndex + _sessionShots.length;
  int get _baseGuideAngleDeg => (widget.angleDeg + (_sessionShots.length * 30)) % 360;
  int get _guideAngleDeg {
    final value = (_baseGuideAngleDeg + _manualAngleOffsetDeg.round()) % 360;
    return value < 0 ? value + 360 : value;
  }

  Offset get _guideAlignment {
    final x = _clamp(
      _manualGuideOffset.dx + _autoGuideOffset.dx,
      -_maxManualGuideShift,
      _maxManualGuideShift,
    );
    final y = _clamp(
      _targetYOffset(widget.levelKey) +
          _manualGuideOffset.dy +
          _autoGuideOffset.dy,
      -0.75,
      0.75,
    );
    return Offset(x, y);
  }

  double get _guideRotationRad {
    final rotationDeg = _manualAngleOffsetDeg + _autoOrbRotationDeg;
    return rotationDeg * pi / 180;
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorText = 'No hay camaras disponibles.';
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
    if (controller == null) return;
    if (!controller.value.isInitialized || _streaming) return;

    try {
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (_) {}
  }

  Future<void> _stopImageStreamIfNeeded() async {
    final controller = _controller;
    if (controller == null) return;
    if (!controller.value.isInitialized || !_streaming) return;

    try {
      await controller.stopImageStream();
    } catch (_) {
      // Ignore: plugin can throw when stream is already stopped.
    } finally {
      _streaming = false;
    }
  }

  void _onFrame(CameraImage image) {
    if (!mounted || _processingFrame || _capturing) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _analysisInterval) return;

    _lastFrameAt = now;
    _processingFrame = true;

    try {
      final metrics = _estimateMetrics(image);
      if (metrics == null || !mounted) return;
      setState(() {
        _brightness = metrics.brightness;
        _detail = metrics.detail;
        _updateGuideFromMetrics(metrics);
      });
    } finally {
      _processingFrame = false;
    }
  }

  _FrameMetrics? _estimateMetrics(CameraImage image) {
    if (image.planes.isEmpty) return null;
    if (image.width <= _analysisStep || image.height <= _analysisStep) {
      return null;
    }

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

      final plane = image.planes[0];
      final bytes = plane.bytes;
      final rowStride = plane.bytesPerRow;
      final pixelStride = plane.bytesPerPixel ?? 1;
      final index = y * rowStride + x * pixelStride;
      if (index < 0 || index >= bytes.length) return 0;
      return bytes[index].toDouble();
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
        final l = lumaAt(x, y);
        final right = lumaAt(x + _analysisStep, y);
        final down = lumaAt(x, y + _analysisStep);

        brightnessSum += l;
        detailSum += (l - right).abs() + (l - down).abs();
        if (x < halfX) {
          leftSum += l;
          leftCount++;
        } else {
          rightSum += l;
          rightCount++;
        }
        if (y < halfY) {
          topSum += l;
          topCount++;
        } else {
          bottomSum += l;
          bottomCount++;
        }
        samples++;
      }
    }

    if (samples == 0) return null;
    final leftAvg = leftSum / max(1, leftCount);
    final rightAvg = rightSum / max(1, rightCount);
    final topAvg = topSum / max(1, topCount);
    final bottomAvg = bottomSum / max(1, bottomCount);

    return _FrameMetrics(
      brightness: brightnessSum / samples,
      detail: detailSum / samples,
      balanceX: _clamp((rightAvg - leftAvg) / 255, -1, 1),
      balanceY: _clamp((bottomAvg - topAvg) / 255, -1, 1),
    );
  }

  bool get _hasMetrics => _brightness != null && _detail != null;
  bool get _brightnessOk => (_brightness ?? 0) >= _minBrightness;
  bool get _detailOk => (_detail ?? 0) >= _minDetail;
  bool get _qualityOk => !_hasMetrics || (_brightnessOk && _detailOk);

  bool get _canCapture {
    final controller = _controller;
    if (controller == null) return false;
    if (!controller.value.isInitialized || _capturing) return false;
    if (!_assistEnabled || !widget.requireLiveQualityGate) return true;
    return _qualityOk;
  }

  void _updateGuideFromMetrics(_FrameMetrics metrics) {
    if (_lastBalanceX != null && _lastBalanceY != null) {
      final dx = _clamp(metrics.balanceX - _lastBalanceX!, -0.18, 0.18);
      final dy = _clamp(metrics.balanceY - _lastBalanceY!, -0.18, 0.18);

      final targetX = _clamp(
        _autoGuideOffset.dx + (dx * 0.95),
        -_maxAutoGuideShift,
        _maxAutoGuideShift,
      );
      final targetY = _clamp(
        _autoGuideOffset.dy + (dy * 0.95),
        -_maxAutoGuideShift,
        _maxAutoGuideShift,
      );
      _autoGuideOffset = Offset(
        (_autoGuideOffset.dx * 0.34) + (targetX * 0.66),
        (_autoGuideOffset.dy * 0.34) + (targetY * 0.66),
      );
      _autoOrbRotationDeg = _clamp(_autoOrbRotationDeg + (dx * 58), -45, 45);
    }

    _autoGuideOffset = Offset(
      _autoGuideOffset.dx * 0.96,
      _autoGuideOffset.dy * 0.96,
    );
    _autoOrbRotationDeg *= 0.93;
    _lastBalanceX = metrics.balanceX;
    _lastBalanceY = metrics.balanceY;
  }

  void _onGuidePanUpdate(DragUpdateDetails details, Size size) {
    if (!mounted) return;
    final dx = details.delta.dx / (size.width * 0.5);
    final dy = details.delta.dy / (size.height * 0.5);
    setState(() {
      _guideTouched = true;
      _manualGuideOffset = Offset(
        _clamp(
          _manualGuideOffset.dx + dx,
          -_maxManualGuideShift,
          _maxManualGuideShift,
        ),
        _clamp(
          _manualGuideOffset.dy + dy,
          -_maxManualGuideShift,
          _maxManualGuideShift,
        ),
      );
    });
  }

  void _onGuideDoubleTap() {
    if (!mounted) return;
    setState(() {
      _guideTouched = true;
      _manualGuideOffset = Offset.zero;
      _manualAngleOffsetDeg = 0;
    });
    _showSnack('Guia centrada.');
  }

  void _onGuideTapDown(TapDownDetails details, Size size) {
    if (!mounted) return;
    final center = Offset(
      size.width / 2 + (_guideAlignment.dx * size.width * 0.25),
      size.height / 2 + (_guideAlignment.dy * size.height * 0.25),
    );
    final vector = details.localPosition - center;
    final distance = vector.distance;
    final ringRadius = min(size.width, size.height) * 0.28;
    final nearRing = (distance - ringRadius).abs() <= 42;

    setState(() {
      _guideTouched = true;
      if (nearRing) {
        final tappedDeg = (atan2(vector.dy, vector.dx) * 180 / pi + 360) % 360;
        _manualAngleOffsetDeg = _signedAngleDelta(_baseGuideAngleDeg, tappedDeg);
      } else {
        _manualGuideOffset = Offset(
          _clamp(
            (details.localPosition.dx - (size.width / 2)) / (size.width * 0.5),
            -_maxManualGuideShift,
            _maxManualGuideShift,
          ),
          _clamp(
            ((details.localPosition.dy - (size.height / 2)) /
                    (size.height * 0.5)) -
                _targetYOffset(widget.levelKey),
            -_maxManualGuideShift,
            _maxManualGuideShift,
          ),
        );
      }
    });
  }

  double _signedAngleDelta(double fromDeg, double toDeg) {
    final delta = ((toDeg - fromDeg + 540) % 360) - 180;
    return delta < -180 ? delta + 360 : delta;
  }

  double _clamp(double value, double minValue, double maxValue) {
    return value.clamp(minValue, maxValue).toDouble();
  }

  Future<void> _takePicture() async {
    if (!_canCapture) {
      _showSnack('Mejora iluminacion o estabilidad.');
      return;
    }

    final controller = _controller;
    if (controller == null) return;

    setState(() => _capturing = true);

    try {
      await _stopImageStreamIfNeeded();
      final shot = await controller.takePicture();
      if (!mounted) return;

      setState(() {
        _sessionShots.add(
          GuidedCameraShot(
            sourcePath: shot.path,
            brightness: _brightness,
            detail: _detail,
            qualityOk: _qualityOk,
          ),
        );
      });

      if (_capturedTotal >= widget.targetMaxPhotos) {
        _showSnack('Meta alcanzada. Puedes finalizar o seguir capturando.');
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

  Future<void> _deleteShotAt(int index) async {
    if (index < 0 || index >= _sessionShots.length) return;
    final removed = _sessionShots.removeAt(index);
    try {
      final file = File(removed.sourcePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // best effort cleanup
    }
  }

  Future<void> _openShotActions(int index) async {
    final action = await showModalBottomSheet<_SessionShotAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Cambiar foto'),
              onTap: () => Navigator.of(ctx).pop(_SessionShotAction.replace),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Eliminar foto'),
              onTap: () => Navigator.of(ctx).pop(_SessionShotAction.delete),
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;
    await _deleteShotAt(index);
    if (!mounted) return;

    setState(() {});
    if (action == _SessionShotAction.replace) {
      _showSnack('Foto eliminada. Toma una nueva para reemplazarla.');
    } else {
      _showSnack('Foto eliminada.');
    }
  }

  void _finishSession() {
    if (!mounted) return;
    Navigator.of(context).pop(
      GuidedCameraSessionResult(
        shots: List<GuidedCameraShot>.from(_sessionShots),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double _targetYOffset(String levelKey) {
    return switch (levelKey) {
      'top' => -0.45,
      'low' => 0.45,
      _ => 0.0,
    };
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (_streaming) {
        controller.stopImageStream().catchError((_) {});
      }
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorText != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorText!, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Camara no disponible')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _finishSession();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) => _onGuidePanUpdate(details, size),
                    onDoubleTap: _onGuideDoubleTap,
                    onTapDown: (details) => _onGuideTapDown(details, size),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _GuideOrbPainter(
                              capturedCount: _capturedTotal,
                              targetCount: widget.targetMaxPhotos,
                              alignmentOffset: _guideAlignment,
                              rotationRad: _guideRotationRad,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                        IgnorePointer(
                          child: _TargetReticle(
                            alignmentOffset: _guideAlignment,
                            levelLabel: widget.levelLabel,
                            angleDeg: _guideAngleDeg,
                          ),
                        ),
                        Positioned(
                          top: 90,
                          left: 0,
                          right: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            opacity: _guideTouched ? 0.45 : 0.86,
                            child: const Center(
                              child: _GuideHintChip(
                                text: 'Arrastra la guia. Doble toque para centrar.',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopPanel(),
                    const Spacer(),
                    _buildBottomPanel(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPanel() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _finishSession,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.4),
              ),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            const Spacer(),
            const Text(
              'Camara Guiada',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 30 / 2,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                _showSnack(
                  'Arrastra la guia, toca el aro para orientar y usa doble toque para centrar.',
                );
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.4),
              ),
              icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            border: Border.all(color: const Color(0xFF9A73FF), width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$_capturedTotal / ${widget.targetMaxPhotos} fotos',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    final brightnessLabel = _hasMetrics
        ? '${_brightness!.toStringAsFixed(0)}/255'
        : 'calculando';
    final detailLabel = _hasMetrics
        ? _detail!.toStringAsFixed(1)
        : 'calculando';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: 'Luz',
                value: brightnessLabel,
                ok: _hasMetrics ? _brightnessOk : true,
              ),
              _StatusPill(
                label: 'Nitidez',
                value: detailLabel,
                ok: _hasMetrics ? _detailOk : true,
              ),
              _StatusPill(
                label: 'Asistencia',
                value: _assistEnabled ? 'on' : 'off',
                ok: !_assistEnabled || _qualityOk,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _assistEnabled && !_qualityOk
                ? 'Mejora iluminacion o estabilidad.'
                : 'Buena iluminacion.',
            style: TextStyle(
              color: _assistEnabled && !_qualityOk
                  ? Colors.orangeAccent
                  : Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          _buildSessionStrip(),
          const SizedBox(height: 8),
          const Text(
            'Toca una miniatura para cambiar o eliminar la foto.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () =>
                    setState(() => _assistEnabled = !_assistEnabled),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  _assistEnabled
                      ? Icons.assistant_photo_rounded
                      : Icons.assistant_photo_outlined,
                ),
              ),
              GestureDetector(
                onTap: _canCapture ? _takePicture : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _canCapture ? Colors.white : Colors.white38,
                      width: 4,
                    ),
                    gradient: _canCapture
                        ? const LinearGradient(
                            colors: [Color(0xFF7B61FF), Color(0xFF3E31B8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: !_canCapture ? Colors.white24 : null,
                  ),
                  child: _capturing
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
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
              IconButton(
                onPressed: _finishSession,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStrip() {
    if (_sessionShots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Aun no hay fotos en la sesion.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sessionShots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final shot = _sessionShots[index];
          return GestureDetector(
            onTap: () => _openShotActions(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.file(
                    File(shot.sourcePath),
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                    cacheHeight: 160,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 62, height: 62),
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
                        Icons.edit_rounded,
                        size: 12,
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

class _TargetReticle extends StatelessWidget {
  const _TargetReticle({
    required this.alignmentOffset,
    required this.levelLabel,
    required this.angleDeg,
  });

  final Offset alignmentOffset;
  final String levelLabel;
  final int angleDeg;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(alignmentOffset.dx, alignmentOffset.dy),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                ),
                Center(
                  child: Container(width: 32, height: 2, color: Colors.white70),
                ),
                Center(
                  child: Container(width: 2, height: 32, color: Colors.white70),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.open_with_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$levelLabel | $angleDeg deg',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.greenAccent.shade400 : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GuideHintChip extends StatelessWidget {
  const _GuideHintChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _GuideOrbPainter extends CustomPainter {
  _GuideOrbPainter({
    required this.capturedCount,
    required this.targetCount,
    required this.alignmentOffset,
    required this.rotationRad,
  });

  final int capturedCount;
  final int targetCount;
  final Offset alignmentOffset;
  final double rotationRad;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      (size.width / 2) + (alignmentOffset.dx * size.width * 0.25),
      (size.height / 2) + (alignmentOffset.dy * size.height * 0.25),
    );
    final radius = min(size.width, size.height) * 0.28;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white30;
    canvas.drawCircle(center, radius, ring);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 1.1),
      ring,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.3, height: radius * 2),
      ring,
    );

    final points = min(max(targetCount, 12), 80);
    for (int i = 0; i < points; i++) {
      final angle = ((i / points) * pi * 2) + rotationRad;
      final p = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * (radius * 0.62),
      );
      final done = i < capturedCount;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = done ? const Color(0xFF7B61FF) : Colors.white30;
      canvas.drawCircle(p, done ? 4.4 : 3.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuideOrbPainter oldDelegate) {
    return oldDelegate.capturedCount != capturedCount ||
        oldDelegate.targetCount != targetCount ||
        oldDelegate.alignmentOffset != alignmentOffset ||
        oldDelegate.rotationRad != rotationRad;
  }
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
