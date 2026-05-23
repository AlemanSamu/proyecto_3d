import 'dart:io';

import 'project_model.dart';

enum ReconstructionResultKind { real, partial, approximate, error, pending }

extension ReconstructionResultKindX on ReconstructionResultKind {
  String get label => switch (this) {
    ReconstructionResultKind.real => 'Reconstruccion real',
    ReconstructionResultKind.partial => 'Reconstruccion parcial',
    ReconstructionResultKind.approximate => 'Modelo aproximado',
    ReconstructionResultKind.error => 'Error',
    ReconstructionResultKind.pending => 'Pendiente',
  };
}

extension ProjectReconstructionX on ProjectModel {
  ReconstructionResultKind get reconstructionResult {
    if (status == ProjectStatus.error ||
        (remoteErrorMessage ?? '').isNotEmpty) {
      return ReconstructionResultKind.error;
    }

    final normalizedRemoteStatus = (remoteStatus ?? '').toLowerCase();
    if (_containsAny(normalizedRemoteStatus, const ['partial', 'parcial'])) {
      return ReconstructionResultKind.partial;
    }

    final hasModel =
        (modelPath ?? '').trim().isNotEmpty ||
        (remoteModelUrl ?? '').trim().isNotEmpty;

    if (!hasModel) {
      return ReconstructionResultKind.pending;
    }

    if (_looksLikeSimulatedGlb(modelPath)) {
      return ReconstructionResultKind.approximate;
    }

    if (_containsAny(normalizedRemoteStatus, const [
      'approx',
      'fallback',
      'simulated',
      'preview',
      'placeholder',
    ])) {
      return ReconstructionResultKind.approximate;
    }

    if (_containsAny(normalizedRemoteStatus, const [
      'completed',
      'success',
      'done',
      'finished',
      'dense',
      'reconstruct',
    ])) {
      return ReconstructionResultKind.real;
    }

    return hasModel
        ? ReconstructionResultKind.approximate
        : ReconstructionResultKind.pending;
  }

  static bool _containsAny(String source, List<String> tokens) {
    for (final token in tokens) {
      if (source.contains(token)) return true;
    }
    return false;
  }

  static bool _looksLikeSimulatedGlb(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    try {
      final bytes = File(path).readAsBytesSync();
      const marker = 'SIMULATED_GLB';
      if (bytes.length < marker.length) return false;
      final head = String.fromCharCodes(bytes.take(marker.length));
      return head == marker;
    } catch (_) {
      return false;
    }
  }
}
