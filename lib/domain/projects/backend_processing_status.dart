import 'project_processing.dart';

enum BackendJobState { unknown, queued, running, completed, failed }

class BackendProcessingStatus {
  const BackendProcessingStatus({
    required this.rawStatus,
    required this.state,
    required this.progress,
    required this.message,
    this.modelUrl,
    this.modelFormat,
    required this.updatedAt,
  });

  final String rawStatus;
  final BackendJobState state;
  final double progress;
  final String message;
  final String? modelUrl;
  final String? modelFormat;
  final DateTime updatedAt;

  bool get isTerminal =>
      state == BackendJobState.completed || state == BackendJobState.failed;
  bool get isCompleted => state == BackendJobState.completed;
  bool get isFailed => state == BackendJobState.failed;
  bool get isActive =>
      state == BackendJobState.queued || state == BackendJobState.running;

  ProcessingStage get stage {
    if (isFailed) return ProcessingStage.failed;
    if (isCompleted) return ProcessingStage.completed;

    if (state == BackendJobState.queued) {
      return ProcessingStage.queued;
    }

    final status = rawStatus.toLowerCase();
    if (status.contains('prepare')) return ProcessingStage.preparing;
    if (status.contains('texture')) return ProcessingStage.texturing;
    if (status.contains('packag')) return ProcessingStage.packaging;
    if (status.contains('recon') ||
        status.contains('mesh') ||
        status.contains('geometry')) {
      return ProcessingStage.reconstructing;
    }

    return isActive ? ProcessingStage.reconstructing : ProcessingStage.idle;
  }

  factory BackendProcessingStatus.fromJson(Map<String, dynamic> json) {
    final statusText = _readString(json, const [
          'status',
          'state',
          'stage',
          'jobStatus',
          'job_status',
        ]) ??
        'unknown';
    final status = statusText.toLowerCase();

    final modelMap = _readMap(json, const ['model', 'result', 'output']);
    final modelUrl =
        _readString(
          json,
          const ['modelUrl', 'model_url', 'model_download_url', 'downloadUrl'],
        ) ??
        _readString(modelMap, const ['url', 'downloadUrl', 'download_url']);
    final modelFormat =
        _readString(
          json,
          const ['modelFormat', 'model_format', 'output_format', 'format'],
        ) ??
        _readString(modelMap, const ['format', 'extension']);

    final progress = _readProgress(json);
    final message = _readString(json, const [
          'message',
          'detail',
          'description',
          'error',
          'error_message',
        ]) ??
        _readString(modelMap, const ['message']) ??
        (statusText.isEmpty ? 'Sin estado remoto.' : statusText);

    final normalizedState = _stateFromRawStatus(status);

    return BackendProcessingStatus(
      rawStatus: statusText,
      state: modelUrl != null && normalizedState != BackendJobState.failed
          ? BackendJobState.completed
          : normalizedState,
      progress: progress,
      message: message,
      modelUrl: modelUrl,
      modelFormat: modelFormat,
      updatedAt: DateTime.now(),
    );
  }

  static BackendJobState _stateFromRawStatus(String raw) {
    if (raw.contains('error') ||
        raw.contains('fail') ||
        raw.contains('cancel')) {
      return BackendJobState.failed;
    }

    if (raw.contains('done') ||
        raw.contains('complete') ||
        raw.contains('success') ||
        raw.contains('finished')) {
      return BackendJobState.completed;
    }

    if (raw.contains('queue') || raw.contains('pending') || raw.contains('ready') || raw == 'created') {
      return BackendJobState.queued;
    }

    if (raw.contains('running') ||
        raw.contains('processing') ||
        raw.contains('prepare') ||
        raw.contains('recon') ||
        raw.contains('texture') ||
        raw.contains('packag')) {
      return BackendJobState.running;
    }

    return BackendJobState.unknown;
  }

  static double _readProgress(Map<String, dynamic> source) {
    final raw = _readValue(source, const [
      'progress',
      'percent',
      'percentage',
      'completion',
    ]);

    double value = 0;
    if (raw is num) value = raw.toDouble();
    if (raw is String) value = double.tryParse(raw) ?? 0;
    if (value > 1) value = value / 100;
    return value.clamp(0, 1).toDouble();
  }

  static String? _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _readMap(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static Object? _readValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      final value = source[key];
      if (value != null) return value;
    }
    return null;
  }
}
