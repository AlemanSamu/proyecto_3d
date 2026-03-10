import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:image/image.dart' as img;

const double minBrightness = 55; // 0..255
const double minSharpness = 12; // heuristica

class QualityReport {
  final bool isOk;
  final double brightness;
  final double sharpness;
  final String hint;

  const QualityReport({
    required this.isOk,
    required this.brightness,
    required this.sharpness,
    required this.hint,
  });

  factory QualityReport.fromMap(Map<String, Object> map) {
    return QualityReport(
      isOk: map['isOk'] as bool? ?? true,
      brightness: (map['brightness'] as num?)?.toDouble() ?? 999,
      sharpness: (map['sharpness'] as num?)?.toDouble() ?? 999,
      hint: map['hint'] as String? ?? 'No pude analizar; guardando.',
    );
  }
}

Future<QualityReport> analyzeQualityFromPath(String filePath) async {
  final report = await Isolate.run(() => _analyzeQualitySync(filePath));
  return QualityReport.fromMap(report);
}

Map<String, Object> _analyzeQualitySync(String filePath) {
  try {
    final bytes = File(filePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return _fallbackReport('No pude analizar; guardando.');
    }

    final small = img.copyResize(decoded, width: 200);
    final brightness = _estimateBrightness(small);
    final sharpness = _estimateSharpness(small);
    final ok = brightness >= minBrightness && sharpness >= minSharpness;

    String hint = 'Se ve bien.';
    if (brightness < minBrightness && sharpness < minSharpness) {
      hint = 'Esta oscura y movida. Usa mas luz y celular firme.';
    } else if (brightness < minBrightness) {
      hint = 'Esta muy oscura. Busca mas luz o evita contraluz.';
    } else if (sharpness < minSharpness) {
      hint = 'Se ve borrosa. Apoyate y espera enfoque.';
    }

    return {
      'isOk': ok,
      'brightness': brightness,
      'sharpness': sharpness,
      'hint': hint,
    };
  } catch (_) {
    return _fallbackReport('Error analizando; guardando.');
  }
}

Map<String, Object> _fallbackReport(String hint) {
  return {
    'isOk': true,
    'brightness': 999.0,
    'sharpness': 999.0,
    'hint': hint,
  };
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
      sum += (dx + dy);
      count++;
    }
  }
  return sum / max(1, count);
}
