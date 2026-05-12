import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

abstract class ProjectCaptureStorage {
  Future<String?> copyToProject({
    required String projectId,
    required String sourcePath,
  });

  Future<void> deleteIfExists(String path);
  Future<void> deleteProjectData(String projectId);
}

class LocalProjectCaptureStorage implements ProjectCaptureStorage {
  static const int _thumbSize = 256;

  @override
  Future<String?> copyToProject({
    required String projectId,
    required String sourcePath,
  }) async {
    try {
      final projectDir = await _projectDirectory(projectId);

      if (!await projectDir.exists()) {
        await projectDir.create(recursive: true);
      }

      if (sourcePath.startsWith(projectDir.path)) {
        await _ensureThumbnail(sourcePath);
        return sourcePath;
      }

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _normalizedExtension(sourcePath);
      final targetPath =
          '${projectDir.path}${Platform.pathSeparator}img_$stamp$extension';

      final savedPath = await _copyOriginalImage(
        sourcePath: sourcePath,
        targetPath: targetPath,
      );
      if (savedPath == null) return null;

      await _ensureThumbnail(savedPath);
      return savedPath;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();

      final thumb = File(thumbnailPathFor(path));
      if (await thumb.exists()) await thumb.delete();
    } catch (_) {
      // best effort cleanup
    }
  }

  @override
  Future<void> deleteProjectData(String projectId) async {
    try {
      final projectDir = await _projectDirectory(projectId);
      if (await projectDir.exists()) {
        await projectDir.delete(recursive: true);
      }
    } catch (_) {
      // best effort cleanup
    }
  }

  static String thumbnailPathFor(String originalPath) {
    final dot = originalPath.lastIndexOf('.');
    final base = dot <= 0 ? originalPath : originalPath.substring(0, dot);
    return '${base}_thumb.jpg';
  }

  Future<String?> _copyOriginalImage({
    required String sourcePath,
    required String targetPath,
  }) async {
    try {
      final copied = await File(sourcePath).copy(targetPath);
      return copied.path;
    } catch (_) {
      return null;
    }
  }

  String _normalizedExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot >= path.length - 1) return '.jpg';
    final raw = path.substring(dot).toLowerCase();
    switch (raw) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
      case '.heic':
      case '.heif':
        return raw;
      default:
        return '.jpg';
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

      final thumbnail = img.copyResize(decoded, width: _thumbSize);
      final encoded = img.encodeJpg(thumbnail, quality: 78);
      await thumbFile.writeAsBytes(encoded, flush: true);
    } catch (_) {
      // Thumbnail is optional, do not fail main flow.
    }
  }

  Future<Directory> _projectDirectory(String projectId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory(
      '${docsDir.path}${Platform.pathSeparator}captures'
      '${Platform.pathSeparator}$projectId',
    );
  }
}
