import '../../core/services/camera_permission_service.dart';
import '../../data/capture/camera_capture_service.dart';
import '../../data/capture/capture_metadata_store.dart';
import '../../data/capture/gallery_save_service.dart';
import '../../data/capture/photo_quality_analyzer.dart';
import '../../data/capture/project_capture_storage.dart';
import '../../domain/capture/photo_quality_report.dart';
import '../providers/project_providers.dart';

class CaptureFlowResult {
  final String? message;
  final bool shouldOpenSettings;
  final bool saved;

  const CaptureFlowResult({
    this.message,
    this.shouldOpenSettings = false,
    this.saved = false,
  });
}

class CaptureFlowController {
  CaptureFlowController({
    required CameraPermissionService permissionService,
    required CameraCaptureService cameraService,
    required PhotoQualityAnalyzer qualityAnalyzer,
    required ProjectCaptureStorage storage,
    required GallerySaveService gallerySaver,
    required ProjectsNotifier projectsNotifier,
    CaptureMetadataStore? metadataStore,
  }) : _permissionService = permissionService,
       _cameraService = cameraService,
       _qualityAnalyzer = qualityAnalyzer,
       _storage = storage,
       _gallerySaver = gallerySaver,
       _projectsNotifier = projectsNotifier,
       _metadataStore = metadataStore ?? LocalCaptureMetadataStore();

  final CameraPermissionService _permissionService;
  final CameraCaptureService _cameraService;
  final PhotoQualityAnalyzer _qualityAnalyzer;
  final ProjectCaptureStorage _storage;
  final GallerySaveService _gallerySaver;
  final ProjectsNotifier _projectsNotifier;
  final CaptureMetadataStore _metadataStore;

  Future<CaptureFlowResult> captureForProject({
    required String projectId,
    required bool autoQuality,
    required Future<bool> Function(PhotoQualityReport report)
    confirmLowQualitySave,
    String? poseId,
    int? angleDeg,
    String? level,
    double? brightness,
    double? sharpness,
    bool accepted = true,
    bool flaggedForRetake = false,
  }) async {
    final permission = await _permissionService.request();
    final granted =
        permission == CameraPermissionState.granted ||
        permission == CameraPermissionState.limited;

    if (!granted) {
      return CaptureFlowResult(
        message: permission == CameraPermissionState.permanentlyDenied
            ? 'Permiso de camara bloqueado. Abre Ajustes.'
            : 'Permiso de camara denegado.',
        shouldOpenSettings:
            permission == CameraPermissionState.permanentlyDenied,
      );
    }

    final sourcePath = await _cameraService.capturePhotoPath();
    if (sourcePath == null) {
      return const CaptureFlowResult(message: 'Captura cancelada.');
    }

    return processCapturedFile(
      projectId: projectId,
      sourcePath: sourcePath,
      autoQuality: autoQuality,
      confirmLowQualitySave: confirmLowQualitySave,
      poseId: poseId,
      angleDeg: angleDeg,
      level: level,
      brightness: brightness,
      sharpness: sharpness,
      accepted: accepted,
      flaggedForRetake: flaggedForRetake,
    );
  }

  Future<CaptureFlowResult> processCapturedFile({
    required String projectId,
    required String sourcePath,
    required bool autoQuality,
    required Future<bool> Function(PhotoQualityReport report)
    confirmLowQualitySave,
    String? poseId,
    int? angleDeg,
    String? level,
    double? brightness,
    double? sharpness,
    bool accepted = true,
    bool flaggedForRetake = false,
    String? captureProfile,
    int? captureIndex,
    bool? stable,
    List<String>? localWarnings,
    DateTime? captureStartTime,
    DateTime? captureEndTime,
    int? captureDurationMs,
    String? cameraResolutionPreset,
    bool? qualityGateEnabled,
    bool? realtimeAnalysisEnabled,
  }) async {
    PhotoQualityReport? qualityReport;

    if (autoQuality) {
      qualityReport = await _qualityAnalyzer.analyze(sourcePath);
      if (!qualityReport.isOk) {
        final keep = await confirmLowQualitySave(qualityReport);
        if (!keep) {
          return const CaptureFlowResult(message: 'Captura descartada.');
        }
      }
    }

    final localPath = await _storage.copyToProject(
      projectId: projectId,
      sourcePath: sourcePath,
    );
    if (localPath == null) {
      return const CaptureFlowResult(
        message: 'No se pudo guardar la imagen en el proyecto.',
      );
    }

    final resolution = readImageResolution(localPath);
    _projectsNotifier.addImagePath(
      projectId,
      localPath,
      poseId: poseId,
      angleDeg: angleDeg,
      level: level,
      brightness: brightness ?? qualityReport?.brightness ?? 0,
      sharpness: sharpness ?? qualityReport?.sharpness ?? 0,
      width: resolution.width,
      height: resolution.height,
      warnings: localWarnings ?? const [],
      accepted: accepted,
      flaggedForRetake: flaggedForRetake,
    );

    final fileSize = readFileSizeBytes(localPath);
    final end = captureEndTime ?? DateTime.now();
    final start =
        captureStartTime ??
        end.subtract(Duration(milliseconds: captureDurationMs ?? 0));
    final durationMs =
        captureDurationMs ??
        end.difference(start).inMilliseconds.clamp(0, 600000);
    await _metadataStore.appendEntry(
      projectId: projectId,
      entry: CaptureMetadataEntry(
        projectId: projectId,
        imagePath: localPath,
        captureStartTime: start,
        captureEndTime: end,
        captureDurationMs: durationMs,
        capturedAt: DateTime.now(),
        profile: captureProfile ?? 'estable',
        suggestedLevel: level ?? 'mid',
        captureIndex: captureIndex ?? 0,
        cameraResolutionPreset: cameraResolutionPreset ?? 'unknown',
        fileSizeBytes: fileSize,
        qualityGateEnabled: qualityGateEnabled ?? false,
        realtimeAnalysisEnabled: realtimeAnalysisEnabled ?? false,
        width: resolution.width,
        height: resolution.height,
        stable: stable ?? true,
        warnings: localWarnings ?? const [],
      ),
    );

    final savedToGallery = await _gallerySaver.saveImage(localPath);
    if (!savedToGallery) {
      return const CaptureFlowResult(
        message: 'Imagen guardada en proyecto, pero no en galeria.',
        saved: true,
      );
    }

    return const CaptureFlowResult(
      message: 'Imagen capturada y guardada.',
      saved: true,
    );
  }

  Future<void> removeImage({
    required String projectId,
    required String imagePath,
  }) async {
    await _storage.deleteIfExists(imagePath);
    _projectsNotifier.removeImagePath(projectId, imagePath);
  }

  Future<void> writeSessionSummary({
    required String projectId,
    required String profileUsed,
    required List<int> captureDurationsMs,
    required int stableCaptures,
  }) async {
    if (captureDurationsMs.isEmpty) return;
    final maxMs = captureDurationsMs.reduce((a, b) => a > b ? a : b);
    final minMs = captureDurationsMs.reduce((a, b) => a < b ? a : b);
    final total = captureDurationsMs.fold<int>(0, (acc, v) => acc + v);
    final avg = (total / captureDurationsMs.length).round();
    final slowCount = captureDurationsMs.where((ms) => ms > 2500).length;
    final stableEnough = stableCaptures >= (captureDurationsMs.length * 0.7);
    final recommended = suggestProfileForDevice(
      profileUsed: profileUsed,
      averageCaptureDurationMs: avg,
      sessionLooksStable: stableEnough,
    );

    await _metadataStore.writeSessionSummary(
      projectId: projectId,
      summary: CaptureSessionSummary(
        projectId: projectId,
        profile: profileUsed,
        totalPhotos: captureDurationsMs.length,
        averageCaptureDurationMs: avg,
        maxCaptureDurationMs: maxMs,
        minCaptureDurationMs: minMs,
        slowCapturesCount: slowCount,
        recommendedProfileForDevice: recommended,
        generatedAt: DateTime.now(),
      ),
    );
  }
}
