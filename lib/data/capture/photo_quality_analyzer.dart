import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:image/image.dart' as img;

import '../../domain/capture/photo_quality_report.dart';

abstract class PhotoQualityAnalyzer {
  Future<PhotoQualityReport> analyze(String sourcePath);
}

class IsolatePhotoQualityAnalyzer implements PhotoQualityAnalyzer {
  IsolatePhotoQualityAnalyzer({
    this.minBrightness = 55,
    this.minSharpness = 12,
  });

  final double minBrightness;
  final double minSharpness;

  @override
  Future<PhotoQualityReport> analyze(String sourcePath) async {
    final result = await Isolate.run(
      () => _analyzeSync(
        sourcePath: sourcePath,
        minBrightness: minBrightness,
        minSharpness: minSharpness,
      ),
    );

    return PhotoQualityReport(
      isOk: result.isOk,
      brightness: result.brightness,
      sharpness: result.sharpness,
      hint: result.hint,
    );
  }
}

class _QualityTuple {
  final bool isOk;
  final double brightness;
  final double sharpness;
  final String hint;

  const _QualityTuple({
    required this.isOk,
    required this.brightness,
    required this.sharpness,
    required this.hint,
  });
}

_QualityTuple _analyzeSync({
  required String sourcePath,
  required double minBrightness,
  required double minSharpness,
}) {
  try {
    final bytes = File(sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      return const _QualityTuple(
        isOk: true,
        brightness: 999,
        sharpness: 999,
        hint: 'No se pudo analizar la calidad; se guardara la foto.',
      );
    }

    final small = img.copyResize(decoded, width: 200);
    final brightness = _estimateBrightness(small);
    final sharpness = _estimateSharpness(small);

    final isOk = brightness >= minBrightness && sharpness >= minSharpness;

    String hint = 'Calidad aceptable.';
    if (brightness < minBrightness && sharpness < minSharpness) {
      hint = 'La foto esta oscura y borrosa.';
    } else if (brightness < minBrightness) {
      hint = 'La foto esta oscura.';
    } else if (sharpness < minSharpness) {
      hint = 'La foto parece borrosa.';
    }

    return _QualityTuple(
      isOk: isOk,
      brightness: brightness,
      sharpness: sharpness,
      hint: hint,
    );
  } catch (_) {
    return const _QualityTuple(
      isOk: true,
      brightness: 999,
      sharpness: 999,
      hint: 'Error analizando calidad; se guardara la foto.',
    );
  }
}

double _estimateBrightness(img.Image image) {
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

double _estimateSharpness(img.Image image) {
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
