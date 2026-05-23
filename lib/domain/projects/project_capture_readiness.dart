import 'dart:math';

import 'project_model.dart';

class ProjectCaptureReadiness {
  const ProjectCaptureReadiness({
    required this.totalPhotos,
    required this.acceptedPhotos,
    required this.lowAngleCount,
    required this.midAngleCount,
    required this.highAngleCount,
    required this.averageBrightness,
    required this.averageSharpness,
    required this.averageMegapixels,
    required this.warningCounts,
  });

  static const int minimumPhotos = 20;
  static const int idealMinPhotos = 36;
  static const int idealMaxPhotos = 45;

  final int totalPhotos;
  final int acceptedPhotos;
  final int lowAngleCount;
  final int midAngleCount;
  final int highAngleCount;
  final double averageBrightness;
  final double averageSharpness;
  final double averageMegapixels;
  final Map<String, int> warningCounts;

  bool get hasMinimumPhotos => acceptedPhotos >= minimumPhotos;
  bool get hasIdealPhotos =>
      acceptedPhotos >= idealMinPhotos && acceptedPhotos <= idealMaxPhotos;
  bool get hasBalancedLevels =>
      lowAngleCount > 0 && midAngleCount > 0 && highAngleCount > 0;
  int get missingMinimumPhotos =>
      max(0, minimumPhotos - acceptedPhotos).clamp(0, minimumPhotos);

  String get primaryMessage {
    if (!hasMinimumPhotos) return 'Faltan $missingMinimumPhotos fotos';
    if ((warningCounts['borrosa'] ?? 0) >= 4) {
      return 'Hay varias fotos borrosas';
    }
    if (highAngleCount < 8) return 'Puedes mejorar con mas fotos desde arriba';
    return 'Listo para enviar';
  }

  List<String> get suggestions {
    final items = <String>[];
    if (!hasMinimumPhotos) {
      items.add('Minimo recomendado: $minimumPhotos fotos.');
    }
    if (acceptedPhotos < idealMinPhotos) {
      items.add('Ideal para COLMAP: $idealMinPhotos-$idealMaxPhotos fotos.');
    }
    if (lowAngleCount == 0) {
      items.add('Toma otra desde abajo.');
    }
    if (midAngleCount == 0) {
      items.add('Buen angulo medio pendiente.');
    }
    if (highAngleCount == 0) {
      items.add('Toma otra desde arriba.');
    }
    if ((warningCounts['borrosa'] ?? 0) > 0) {
      items.add('Foto borrosa detectada.');
    }
    if ((warningCounts['demasiado_oscura'] ?? 0) > 0) {
      items.add('Mejor luz.');
    }
    if (items.isEmpty) {
      items.add('Sigue moviendote alrededor del objeto.');
    }
    return items;
  }

  factory ProjectCaptureReadiness.fromProject(ProjectModel project) {
    final accepted = project.photos.where((photo) => photo.accepted).toList();
    var brightnessTotal = 0.0;
    var sharpnessTotal = 0.0;
    var megapixelsTotal = 0.0;
    var low = 0;
    var mid = 0;
    var high = 0;
    final warnings = <String, int>{};

    for (final photo in accepted) {
      brightnessTotal += photo.brightness;
      sharpnessTotal += photo.sharpness;
      if (photo.width > 0 && photo.height > 0) {
        megapixelsTotal += (photo.width * photo.height) / 1000000;
      }
      switch (photo.level) {
        case 'low':
          low++;
          break;
        case 'high':
        case 'top':
          high++;
          break;
        default:
          mid++;
      }
      for (final warning in photo.warnings) {
        warnings[warning] = (warnings[warning] ?? 0) + 1;
      }
    }

    final count = max(accepted.length, 1);
    return ProjectCaptureReadiness(
      totalPhotos: project.photos.length,
      acceptedPhotos: accepted.length,
      lowAngleCount: low,
      midAngleCount: mid,
      highAngleCount: high,
      averageBrightness: brightnessTotal / count,
      averageSharpness: sharpnessTotal / count,
      averageMegapixels: megapixelsTotal / count,
      warningCounts: Map.unmodifiable(warnings),
    );
  }
}
