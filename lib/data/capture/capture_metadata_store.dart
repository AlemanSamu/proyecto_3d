import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CaptureMetadataEntry {
  const CaptureMetadataEntry({
    required this.projectId,
    required this.imagePath,
    required this.captureStartTime,
    required this.captureEndTime,
    required this.captureDurationMs,
    required this.capturedAt,
    required this.profile,
    required this.suggestedLevel,
    required this.captureIndex,
    required this.cameraResolutionPreset,
    required this.fileSizeBytes,
    required this.qualityGateEnabled,
    required this.realtimeAnalysisEnabled,
    required this.width,
    required this.height,
    required this.stable,
    required this.warnings,
  });

  final String projectId;
  final String imagePath;
  final DateTime captureStartTime;
  final DateTime captureEndTime;
  final int captureDurationMs;
  final DateTime capturedAt;
  final String profile;
  final String suggestedLevel;
  final int captureIndex;
  final String cameraResolutionPreset;
  final int fileSizeBytes;
  final bool qualityGateEnabled;
  final bool realtimeAnalysisEnabled;
  final int width;
  final int height;
  final bool stable;
  final List<String> warnings;

  Map<String, dynamic> toJson() {
    return {
      'imagePath': imagePath,
      'projectId': projectId,
      'capture_start_time': captureStartTime.toIso8601String(),
      'capture_end_time': captureEndTime.toIso8601String(),
      'capture_duration_ms': captureDurationMs,
      'capturedAt': capturedAt.toIso8601String(),
      'profile': profile,
      'suggestedLevel': suggestedLevel,
      'captureIndex': captureIndex,
      'camera_resolution_preset': cameraResolutionPreset,
      'quality_gate_enabled': qualityGateEnabled,
      'realtime_analysis_enabled': realtimeAnalysisEnabled,
      'resolution': {'width': width, 'height': height},
      'image_width': width,
      'image_height': height,
      'file_size_bytes': fileSizeBytes,
      'stable': stable,
      'warnings': warnings,
    };
  }
}

class CaptureSessionSummary {
  const CaptureSessionSummary({
    required this.projectId,
    required this.profile,
    required this.totalPhotos,
    required this.averageCaptureDurationMs,
    required this.maxCaptureDurationMs,
    required this.minCaptureDurationMs,
    required this.slowCapturesCount,
    required this.recommendedProfileForDevice,
    required this.generatedAt,
  });

  final String projectId;
  final String profile;
  final int totalPhotos;
  final int averageCaptureDurationMs;
  final int maxCaptureDurationMs;
  final int minCaptureDurationMs;
  final int slowCapturesCount;
  final String recommendedProfileForDevice;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'profile': profile,
      'total_photos': totalPhotos,
      'average_capture_duration_ms': averageCaptureDurationMs,
      'max_capture_duration_ms': maxCaptureDurationMs,
      'min_capture_duration_ms': minCaptureDurationMs,
      'slow_captures_count': slowCapturesCount,
      'recommended_profile_for_device': recommendedProfileForDevice,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}

abstract class CaptureMetadataStore {
  Future<void> appendEntry({
    required String projectId,
    required CaptureMetadataEntry entry,
  });

  Future<void> writeSessionSummary({
    required String projectId,
    required CaptureSessionSummary summary,
  });
}

class LocalCaptureMetadataStore implements CaptureMetadataStore {
  @override
  Future<void> appendEntry({
    required String projectId,
    required CaptureMetadataEntry entry,
  }) async {
    try {
      final file = await _metadataFile(projectId);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      final payload = await _readPayload(file);
      payload['photos'].add(entry.toJson());
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // Metadata is best effort and should not block capture flow.
    }
  }

  @override
  Future<void> writeSessionSummary({
    required String projectId,
    required CaptureSessionSummary summary,
  }) async {
    try {
      final file = await _metadataFile(projectId);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final payload = await _readPayload(file);
      payload['session_summary'] = summary.toJson();
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // Best effort only.
    }
  }

  Future<File> _metadataFile(String projectId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final projectDir = Directory(
      '${docsDir.path}${Platform.pathSeparator}captures'
      '${Platform.pathSeparator}$projectId',
    );
    return File(
      '${projectDir.path}${Platform.pathSeparator}capture_metadata.json',
    );
  }

  Future<Map<String, dynamic>> _readPayload(File file) async {
    if (!await file.exists()) {
      return <String, dynamic>{
        'photos': <Map<String, dynamic>>[],
        'session_summary': null,
      };
    }
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{
        'photos': <Map<String, dynamic>>[],
        'session_summary': null,
      };
    }
    final decoded = jsonDecode(raw);
    final photos = <Map<String, dynamic>>[];
    Object? sessionSummary;

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          photos.add(item);
        } else if (item is Map) {
          photos.add(Map<String, dynamic>.from(item));
        }
      }
      return <String, dynamic>{
        'photos': photos,
        'session_summary': null,
      };
    }

    if (decoded is Map) {
      final rawPhotos = decoded['photos'];
      if (rawPhotos is List) {
        for (final item in rawPhotos) {
          if (item is Map<String, dynamic>) {
            photos.add(item);
          } else if (item is Map) {
            photos.add(Map<String, dynamic>.from(item));
          }
        }
      }
      sessionSummary = decoded['session_summary'];
    }

    return <String, dynamic>{
      'photos': photos,
      'session_summary': sessionSummary,
    };
  }
}

int readFileSizeBytes(String imagePath) {
  try {
    final file = File(imagePath);
    if (!file.existsSync()) return 0;
    return file.lengthSync();
  } catch (_) {
    return 0;
  }
}

String suggestProfileForDevice({
  required String profileUsed,
  required int averageCaptureDurationMs,
  required bool sessionLooksStable,
}) {
  if (profileUsed == 'maxima_calidad' && averageCaptureDurationMs > 2500) {
    return 'estable';
  }
  if (profileUsed == 'estable' && averageCaptureDurationMs > 1800) {
    return 'rapido';
  }
  if (profileUsed == 'rapido' && sessionLooksStable) {
    return 'rapido';
  }
  if (profileUsed == 'maxima_calidad') {
    return 'maxima_calidad';
  }
  if (profileUsed == 'estable') {
    return 'estable';
  }
  return 'rapido';
}

({int width, int height}) readImageResolution(String imagePath) {
  try {
    final bytes = File(imagePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return (width: 0, height: 0);
    return (width: decoded.width, height: decoded.height);
  } catch (_) {
    return (width: 0, height: 0);
  }
}
