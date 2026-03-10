import 'dart:io';

import 'package:camera/camera.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../projects/project_store.dart';
import 'pose_library.dart';
import 'quality_analyzer.dart';

class CaptureActionResult {
  const CaptureActionResult({
    this.message,
    this.saved = false,
    this.storedPath,
  });

  final String? message;
  final bool saved;
  final String? storedPath;
}

abstract class CapturePermissions {
  Future<bool> ensureCapturePermissions();
}

class DeviceCapturePermissions implements CapturePermissions {
  @override
  Future<bool> ensureCapturePermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) return false;

    if (Platform.isIOS) {
      final photosStatus = await Permission.photosAddOnly.request();
      return photosStatus.isGranted || photosStatus.isLimited;
    }

    if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted || photosStatus.isLimited) return true;

      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }

    return true;
  }
}

abstract class CaptureCamera {
  Future<String?> takePhotoPath();
}

class DeviceCaptureCamera implements CaptureCamera {
  DeviceCaptureCamera({this.resolutionPreset = ResolutionPreset.high});

  final ResolutionPreset resolutionPreset;

  @override
  Future<String?> takePhotoPath() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        selected,
        resolutionPreset,
        enableAudio: false,
      );
      await controller.initialize();
      final shot = await controller.takePicture();
      return shot.path;
    } catch (_) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }
}

/// Legacy name kept to avoid breaking old imports/usages.
class ImagePickerCaptureCamera extends DeviceCaptureCamera {
  ImagePickerCaptureCamera({super.resolutionPreset = ResolutionPreset.high});
}

abstract class CaptureQualityAnalyzer {
  Future<QualityReport> analyze(String filePath);
}

class IsolateCaptureQualityAnalyzer implements CaptureQualityAnalyzer {
  @override
  Future<QualityReport> analyze(String filePath) {
    return analyzeQualityFromPath(filePath);
  }
}

abstract class CaptureFileStorage {
  Future<String?> storeCapture({
    required String projectId,
    required String sourcePath,
    required String poseId,
  });

  Future<void> deleteIfExists(String? path);
}

class LocalCaptureFileStorage implements CaptureFileStorage {
  static const int _maxWidth = 2000;
  static const int _jpgQuality = 85;
  static const int _thumbSize = 256;

  @override
  Future<String?> storeCapture({
    required String projectId,
    required String sourcePath,
    required String poseId,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final projectDir = Directory(
        '${docsDir.path}${Platform.pathSeparator}captures'
        '${Platform.pathSeparator}$projectId',
      );
      if (!await projectDir.exists()) {
        await projectDir.create(recursive: true);
      }

      if (sourcePath.startsWith(projectDir.path)) {
        await _ensureThumbnail(sourcePath);
        return sourcePath;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath =
          '${projectDir.path}${Platform.pathSeparator}${poseId}_$stamp.jpg';

      final optimizedPath = await _writeOptimizedImage(
        sourcePath: sourcePath,
        targetPath: targetPath,
      );
      if (optimizedPath == null) return null;

      await _ensureThumbnail(optimizedPath);
      return optimizedPath;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      final thumb = File(thumbnailPathFor(path));
      if (await thumb.exists()) {
        await thumb.delete();
      }
    } catch (_) {
      // Best effort cleanup.
    }
  }

  static String thumbnailPathFor(String originalPath) {
    final dot = originalPath.lastIndexOf('.');
    final base = dot <= 0 ? originalPath : originalPath.substring(0, dot);
    return '${base}_thumb.jpg';
  }

  Future<String?> _writeOptimizedImage({
    required String sourcePath,
    required String targetPath,
  }) async {
    try {
      final sourceBytes = await File(sourcePath).readAsBytes();
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) {
        final copied = await File(sourcePath).copy(targetPath);
        return copied.path;
      }

      final resized = decoded.width > _maxWidth
          ? img.copyResize(decoded, width: _maxWidth)
          : decoded;

      final encoded = img.encodeJpg(resized, quality: _jpgQuality);
      await File(targetPath).writeAsBytes(encoded, flush: true);
      return targetPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureThumbnail(String fullPath) async {
    final thumbPath = thumbnailPathFor(fullPath);
    final thumbFile = File(thumbPath);
    if (await thumbFile.exists()) return;

    try {
      final bytes = await File(fullPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      final thumb = img.copyResize(decoded, width: _thumbSize);
      final encoded = img.encodeJpg(thumb, quality: 78);
      await thumbFile.writeAsBytes(encoded, flush: true);
    } catch (_) {
      // Thumbnail is optional.
    }
  }
}

abstract class CaptureGallerySaver {
  Future<bool> save(String path);
}

class GallerySaverCaptureGallery implements CaptureGallerySaver {
  @override
  Future<bool> save(String path) async {
    return await GallerySaver.saveImage(path, albumName: 'Captura3D') == true;
  }
}

abstract class CaptureProjectStore {
  void setPosePhoto(String projectId, String poseId, String path);
  void removePosePhoto(String projectId, String poseId);
}

class RiverpodCaptureProjectStore implements CaptureProjectStore {
  RiverpodCaptureProjectStore(this._notifier);

  final ProjectsNotifier _notifier;

  @override
  void removePosePhoto(String projectId, String poseId) {
    _notifier.removePosePhoto(projectId, poseId);
  }

  @override
  void setPosePhoto(String projectId, String poseId, String path) {
    _notifier.setPosePhoto(projectId, poseId, path);
  }
}

class CaptureController {
  CaptureController({
    required this.projectId,
    required CapturePermissions permissions,
    required CaptureCamera camera,
    required CaptureQualityAnalyzer qualityAnalyzer,
    required CaptureFileStorage fileStorage,
    required CaptureGallerySaver gallerySaver,
    required CaptureProjectStore projectStore,
  }) : _permissions = permissions,
       _camera = camera,
       _qualityAnalyzer = qualityAnalyzer,
       _fileStorage = fileStorage,
       _gallerySaver = gallerySaver,
       _projectStore = projectStore;

  final String projectId;
  final CapturePermissions _permissions;
  final CaptureCamera _camera;
  final CaptureQualityAnalyzer _qualityAnalyzer;
  final CaptureFileStorage _fileStorage;
  final CaptureGallerySaver _gallerySaver;
  final CaptureProjectStore _projectStore;

  Future<CaptureActionResult> takeForPose({
    required PoseStep pose,
    required Future<bool> Function(QualityReport report) confirmLowQuality,
  }) async {
    try {
      final hasPermissions = await _permissions.ensureCapturePermissions();
      if (!hasPermissions) {
        return const CaptureActionResult(
          message: 'Necesito permisos de camara y fotos.',
        );
      }

      final sourcePath = await _camera.takePhotoPath();
      if (sourcePath == null) {
        return const CaptureActionResult();
      }

      return processCapturedPathForPose(
        pose: pose,
        sourcePath: sourcePath,
        confirmLowQuality: confirmLowQuality,
      );
    } catch (_) {
      return const CaptureActionResult(
        message: 'Ocurrio un error al procesar la foto.',
      );
    }
  }

  Future<CaptureActionResult> processCapturedPathForPose({
    required PoseStep pose,
    required String sourcePath,
    required Future<bool> Function(QualityReport report) confirmLowQuality,
  }) async {
    try {
      final quality = await _qualityAnalyzer.analyze(sourcePath);
      if (!quality.isOk) {
        final keep = await confirmLowQuality(quality);
        if (!keep) {
          return const CaptureActionResult();
        }
      }

      final localPath = await _fileStorage.storeCapture(
        projectId: projectId,
        sourcePath: sourcePath,
        poseId: pose.id,
      );
      if (localPath == null) {
        return const CaptureActionResult(
          message: 'No pude guardar la foto localmente.',
        );
      }

      _projectStore.setPosePhoto(projectId, pose.id, localPath);

      final savedToGallery = await _gallerySaver.save(localPath);
      if (!savedToGallery) {
        return CaptureActionResult(
          message: 'Foto guardada en app, pero no en galeria.',
          saved: true,
          storedPath: localPath,
        );
      }

      if (quality.isOk) {
        return CaptureActionResult(
          message: 'Foto guardada.',
          saved: true,
          storedPath: localPath,
        );
      }
      return CaptureActionResult(
        message: 'Foto guardada con calidad baja.',
        saved: true,
        storedPath: localPath,
      );
    } catch (_) {
      return const CaptureActionResult(
        message: 'Ocurrio un error al procesar la foto.',
      );
    }
  }

  /// Entry point used by the guided continuous camera session.
  Future<CaptureActionResult> saveGuidedShot({
    required PoseStep pose,
    required String sourcePath,
    required Future<bool> Function(QualityReport report) confirmLowQuality,
  }) {
    return processCapturedPathForPose(
      pose: pose,
      sourcePath: sourcePath,
      confirmLowQuality: confirmLowQuality,
    );
  }

  Future<void> removePosePhoto({
    required String poseId,
    required String? filePath,
  }) async {
    await _fileStorage.deleteIfExists(filePath);
    _projectStore.removePosePhoto(projectId, poseId);
  }
}
