import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

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
    required this.captureResolution,
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
  final CaptureResolution captureResolution;
  final Map<String, int> existingLevelCounts;

  @override
  State<GuidedCameraScreen> createState() => _GuidedCameraScreenState();
}

class _GuidedCameraScreenState extends State<GuidedCameraScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;
  String _message = 'Mueve alrededor';
  final List<GuidedCameraShot> _sessionShots = <GuidedCameraShot>[];
  DateTime _lastShotAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<int> _recentHashes = <int>[];

  static const _ringTargets = <String, (int min, int max)>{
    'low': (10, 15),
    'mid': (12, 18),
    'top': (10, 15),
  };

  int get _capturedTotal => widget.captureIndex + _sessionShots.length;

  Duration get _minShotInterval =>
      Duration(milliseconds: widget.captureProfile.minIntervalMs);

  ResolutionPreset get _cameraResolutionPreset =>
      switch (widget.captureResolution) {
        CaptureResolution.high => ResolutionPreset.high,
        CaptureResolution.veryHigh => ResolutionPreset.veryHigh,
        CaptureResolution.ultraHigh => ResolutionPreset.ultraHigh,
        CaptureResolution.max => ResolutionPreset.max,
      };

  Map<String, int> get _levelCounts {
    final counts = <String, int>{
      'low': widget.existingLevelCounts['low'] ?? 0,
      'mid': widget.existingLevelCounts['mid'] ?? 0,
      'top': widget.existingLevelCounts['top'] ?? 0,
    };
    for (final shot in _sessionShots) {
      final level = shot.level;
      if (level == null) continue;
      counts[level] = (counts[level] ?? 0) + 1;
    }
    return counts;
  }

  String get _currentRingKey {
    final counts = _levelCounts;
    for (final key in const ['low', 'mid', 'top']) {
      final target = _ringTargets[key]!;
      if ((counts[key] ?? 0) < target.$1) return key;
    }

    String fallback = 'top';
    var minRatio = 1.0;
    for (final key in const ['low', 'mid', 'top']) {
      final count = counts[key] ?? 0;
      final target = _ringTargets[key]!;
      final ratio = (count / target.$2).clamp(0.0, 1.0);
      if (ratio < minRatio) {
        minRatio = ratio;
        fallback = key;
      }
    }
    return fallback;
  }

  String get _currentRingLabel => switch (_currentRingKey) {
    'low' => 'Bajo',
    'mid' => 'Medio',
    _ => 'Alto',
  };

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        Colors.black.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(child: _buildOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _capturing ? null : _close,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Fotos: $_capturedTotal',
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
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Anillo $_currentRingLabel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ringProgress('low', 'Bajo'),
                const SizedBox(height: 6),
                _ringProgress('mid', 'Medio'),
                const SizedBox(height: 6),
                _ringProgress('top', 'Alto'),
              ],
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _capturing ? null : _takePicture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 102,
                  height: 102,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Center(
                        child: _capturing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.black,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sessionShots.isEmpty ? null : _finish,
                  child: const Text('Finalizar captura'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ringProgress(String key, String label) {
    final counts = _levelCounts;
    final count = counts[key] ?? 0;
    final target = _ringTargets[key]!;
    final progress = (count / target.$2).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label: $count',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Text(
              '${target.$1}-${target.$2}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress, minHeight: 6),
        ),
      ],
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No se detecto una camara disponible.';
          _initializing = false;
        });
        return;
      }

      final controller = CameraController(
        cameras.first,
        _cameraResolutionPreset,
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo iniciar la camara.';
        _initializing = false;
      });
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (_capturing || controller == null || !controller.value.isInitialized) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastShotAt) < _minShotInterval) {
      setState(() => _message = 'Espera un momento y vuelve a capturar');
      return;
    }

    setState(() {
      _capturing = true;
      _message = 'Analizando foto...';
    });

    final captureStart = DateTime.now();
    try {
      final shotFile = await controller.takePicture();
      final captureEnd = DateTime.now();
      final diagnostics = await _analyzeShot(
        shotFile.path,
        previousHashes: _recentHashes,
      );

      final warnings = diagnostics.warnings;
      final severe = diagnostics.severe;
      final hasWarnings = warnings.isNotEmpty;

      if (severe) {
        final keep = await _confirmCriticalShot(warnings);
        if (!keep) {
          await _deleteIfExists(shotFile.path);
          if (!mounted) return;
          setState(() {
            _capturing = false;
            _message = 'Mejor luz';
          });
          return;
        }
      }

      if (diagnostics.hash != null) {
        _recentHashes.add(diagnostics.hash!);
        if (_recentHashes.length > 8) {
          _recentHashes.removeAt(0);
        }
      }

      final shot = GuidedCameraShot(
        sourcePath: shotFile.path,
        poseId: null,
        angleDeg: (_capturedTotal * 24) % 360,
        level: _currentRingKey,
        brightness: diagnostics.brightness,
        detail: diagnostics.sharpness,
        width: diagnostics.width,
        height: diagnostics.height,
        stable: true,
        warnings: warnings,
        profile: widget.captureProfile,
        qualityOk: !severe,
        captureStartTime: captureStart,
        captureEndTime: captureEnd,
        captureDurationMs: captureEnd.difference(captureStart).inMilliseconds,
        cameraResolutionPreset: widget.captureResolution.name,
        qualityGateEnabled: widget.requireLiveQualityGate,
        realtimeAnalysisEnabled: true,
      );

      _sessionShots.add(shot);
      _lastShotAt = DateTime.now();

      if (!mounted) return;
      setState(() {
        _capturing = false;
        if (severe) {
          _message = 'Mejor luz';
        } else if (hasWarnings) {
          _message = 'Guardada con aviso';
        } else {
          _message = _nextMessage();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _message = 'No se pudo capturar. Intenta de nuevo';
      });
    }
  }

  String _nextMessage() {
    final ring = _currentRingKey;
    if (ring == 'low') return 'Mueve alrededor';
    if (ring == 'mid') return 'Buena foto';
    return 'Sube un poco';
  }

  Future<bool> _confirmCriticalShot(List<String> warnings) async {
    if (!mounted) return false;
    final warningText = warnings.isEmpty
        ? 'Foto muy oscura o borrosa.'
        : warnings.join(', ');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calidad baja'),
        content: Text('$warningText. Recomendamos repetir la foto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Repetir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar de todos modos'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _finish() async {
    if (_sessionShots.isEmpty) return;
    Navigator.of(context).pop(GuidedCameraSessionResult(shots: _sessionShots));
  }

  Future<void> _close() async {
    if (_sessionShots.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir de captura'),
        content: const Text(
          'Hay fotos en el lote actual. Si sales, se perderan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir capturando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      for (final shot in _sessionShots) {
        await _deleteIfExists(shot.sourcePath);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // best effort cleanup
    }
  }

  Future<_ShotDiagnostics> _analyzeShot(
    String path, {
    required List<int> previousHashes,
  }) async {
    return Isolate.run(
      () => _analyzeShotSync(path, previousHashes: previousHashes),
    );
  }

  static Future<_ShotDiagnostics> _analyzeShotSync(
    String path, {
    required List<int> previousHashes,
  }) async {
    return Future<_ShotDiagnostics>(() {
      try {
        final bytes = File(path).readAsBytesSync();
        final image = img.decodeImage(bytes);
        if (image == null) return const _ShotDiagnostics.empty();

        final resized = img.copyResize(image, width: min(220, image.width));
        final brightness = _estimateBrightness(resized);
        final sharpness = _estimateSharpness(resized);
        final hash = _averageHash(resized);
        final mp = (image.width * image.height) / 1000000;

        final warnings = <String>[];
        bool severe = false;

        if (brightness < 45) {
          warnings.add('demasiado_oscura');
          severe = true;
        } else if (brightness < 55) {
          warnings.add('luz_baja');
        }

        if (sharpness < 8) {
          warnings.add('borrosa');
          severe = true;
        } else if (sharpness < 12) {
          warnings.add('nitidez_baja');
        }

        if (mp < 1.2) {
          warnings.add('resolucion_muy_baja');
          severe = true;
        } else if (mp < 2.0) {
          warnings.add('resolucion_baja');
        }

        for (final previous in previousHashes) {
          if (_hammingDistance(hash, previous) <= 4) {
            warnings.add('foto_repetida');
            break;
          }
        }

        return _ShotDiagnostics(
          brightness: brightness,
          sharpness: sharpness,
          width: image.width,
          height: image.height,
          hash: hash,
          warnings: warnings,
          severe: severe,
        );
      } catch (_) {
        return const _ShotDiagnostics.empty();
      }
    });
  }

  static double _estimateBrightness(img.Image image) {
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

  static double _estimateSharpness(img.Image image) {
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

  static int _averageHash(img.Image image) {
    final small = img.copyResize(image, width: 8, height: 8);
    final values = <int>[];
    var total = 0;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final px = small.getPixel(x, y);
        final lum = (0.2126 * px.r + 0.7152 * px.g + 0.0722 * px.b).round();
        values.add(lum);
        total += lum;
      }
    }

    final avg = total / 64;
    var hash = 0;
    for (int i = 0; i < values.length; i++) {
      if (values[i] >= avg) {
        hash |= (1 << i);
      }
    }
    return hash;
  }

  static int _hammingDistance(int a, int b) {
    var value = a ^ b;
    var count = 0;
    while (value != 0) {
      value &= value - 1;
      count++;
    }
    return count;
  }
}

class _ShotDiagnostics {
  const _ShotDiagnostics({
    required this.brightness,
    required this.sharpness,
    required this.width,
    required this.height,
    required this.hash,
    required this.warnings,
    required this.severe,
  });

  const _ShotDiagnostics.empty()
    : brightness = 70,
      sharpness = 14,
      width = 0,
      height = 0,
      hash = null,
      warnings = const [],
      severe = false;

  final double brightness;
  final double sharpness;
  final int width;
  final int height;
  final int? hash;
  final List<String> warnings;
  final bool severe;
}
