import '../../core/services/camera_permission_service.dart';
import '../../data/capture/camera_capture_service.dart';
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
  }) : _permissionService = permissionService,
       _cameraService = cameraService,
       _qualityAnalyzer = qualityAnalyzer,
       _storage = storage,
       _gallerySaver = gallerySaver,
       _projectsNotifier = projectsNotifier;

  final CameraPermissionService _permissionService;
  final CameraCaptureService _cameraService;
  final PhotoQualityAnalyzer _qualityAnalyzer;
  final ProjectCaptureStorage _storage;
  final GallerySaveService _gallerySaver;
  final ProjectsNotifier _projectsNotifier;

  Future<CaptureFlowResult> captureForProject({
    required String projectId,
    required bool autoQuality,
    required Future<bool> Function(PhotoQualityReport report)
    confirmLowQualitySave,
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
    );
  }

  Future<CaptureFlowResult> processCapturedFile({
    required String projectId,
    required String sourcePath,
    required bool autoQuality,
    required Future<bool> Function(PhotoQualityReport report)
    confirmLowQualitySave,
  }) async {
    if (autoQuality) {
      final report = await _qualityAnalyzer.analyze(sourcePath);
      if (!report.isOk) {
        final keep = await confirmLowQualitySave(report);
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

    _projectsNotifier.addImagePath(projectId, localPath);

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
}
