// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Uso: dart run tools/analyze_capture_metadata.dart <ruta_capture_metadata.json>');
    exit(1);
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('No existe: ${file.path}');
    exit(2);
  }

  final decoded = jsonDecode(file.readAsStringSync());
  final photos = _readPhotos(decoded);
  if (photos.isEmpty) {
    print('Sin fotos en metadata.');
    return;
  }

  final profileCounts = <String, int>{};
  final warningsCounts = <String, int>{};
  int totalDuration = 0;
  int totalWidth = 0;
  int totalHeight = 0;
  int slowCount = 0;

  for (final p in photos) {
    final profile = (p['profile'] ?? 'unknown').toString();
    profileCounts[profile] = (profileCounts[profile] ?? 0) + 1;

    final duration = (p['capture_duration_ms'] is num)
        ? (p['capture_duration_ms'] as num).toInt()
        : 0;
    totalDuration += duration;
    if (duration > 2500) slowCount++;

    final width = (p['image_width'] is num)
        ? (p['image_width'] as num).toInt()
        : 0;
    final height = (p['image_height'] is num)
        ? (p['image_height'] as num).toInt()
        : 0;
    totalWidth += width;
    totalHeight += height;

    final warnings = p['warnings'];
    if (warnings is List) {
      for (final w in warnings) {
        final key = w.toString();
        warningsCounts[key] = (warningsCounts[key] ?? 0) + 1;
      }
    }
  }

  final total = photos.length;
  final avgDuration = (totalDuration / total).round();
  final avgWidth = (totalWidth / total).round();
  final avgHeight = (totalHeight / total).round();
  final dominantProfile = profileCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

  final recommended = _recommendProfile(dominantProfile, avgDuration, slowCount, total);

  print('Perfil dominante: $dominantProfile');
  print('Cantidad de fotos: $total');
  print('Tiempo promedio (ms): $avgDuration');
  print('Resolucion promedio: ${avgWidth}x$avgHeight');
  print('Fotos lentas (>2500ms): $slowCount');
  print('Advertencias frecuentes:');
  if (warningsCounts.isEmpty) {
    print('- Ninguna');
  } else {
    final sorted = warningsCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(6)) {
      print('- ${e.key}: ${e.value}');
    }
  }
  print('Perfil recomendado: $recommended');
}

List<Map<String, dynamic>> _readPhotos(dynamic decoded) {
  if (decoded is List) {
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  if (decoded is Map && decoded['photos'] is List) {
    return (decoded['photos'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

String _recommendProfile(String profile, int avgDurationMs, int slowCount, int total) {
  if (profile == 'maxima_calidad' && avgDurationMs > 2500) return 'estable';
  if (profile == 'estable' && avgDurationMs > 1800) return 'rapido';
  if (profile == 'rapido' && slowCount <= (total * 0.2)) return 'rapido';
  if (profile == 'maxima_calidad') return 'maxima_calidad';
  if (profile == 'estable') return 'estable';
  return 'rapido';
}
