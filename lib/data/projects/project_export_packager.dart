import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/projects/project_export_config.dart';
import '../../domain/projects/project_model.dart';
import '../../domain/projects/project_processing.dart';

class ProjectExportPackage {
  const ProjectExportPackage({
    required this.packagePath,
    required this.createdAt,
    required this.photoCount,
    required this.sizeBytes,
  });

  final String packagePath;
  final DateTime createdAt;
  final int photoCount;
  final int sizeBytes;
}

abstract class ProjectExportPackager {
  Future<ProjectExportPackage> buildPackage(ProjectModel project);
}

class LocalStubProjectExportPackager implements ProjectExportPackager {
  @override
  Future<ProjectExportPackage> buildPackage(ProjectModel project) async {
    final now = DateTime.now();
    final docs = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(
      '${docs.path}${Platform.pathSeparator}exports'
      '${Platform.pathSeparator}${project.id}',
    );
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final extension = project.exportConfig.compressPackage
        ? 'zip.json'
        : 'json';
    final packagePath =
        '${exportsDir.path}${Platform.pathSeparator}'
        'package_${now.millisecondsSinceEpoch}.$extension';

    final includeMetadata = project.exportConfig.includeMetadata;
    final includeImages = project.exportConfig.includeImages;
    final includeThumbnails = project.exportConfig.includeThumbnails;

    final images = includeImages
        ? [
            for (final photo in project.photos)
              {
                'id': photo.id,
                'path': photo.originalPath,
                'createdAt': photo.createdAt.toIso8601String(),
              },
          ]
        : const [];
    final thumbnails = includeThumbnails
        ? [
            for (final photo in project.photos)
              {'id': photo.id, 'path': photo.thumbnailPath},
          ]
        : const [];

    final payload = <String, dynamic>{
      'schemaVersion': 2,
      'packageType': 'capture_bundle',
      'createdAt': now.toIso8601String(),
      'project': {
        'id': project.id,
        'name': project.name,
        'description': project.description,
        'status': project.status.value,
        'coverImagePath': project.coverImagePath,
        'createdAt': project.createdAt.toIso8601String(),
        'updatedAt': project.updatedAt.toIso8601String(),
        'photoCount': project.photoCount,
        'coverage': project.coverage.toJson(),
      },
      'exportConfig': project.exportConfig.toJson(),
      'captures': includeMetadata
          ? [for (final photo in project.photos) photo.toJson()]
          : [
              for (final photo in project.photos)
                {
                  'id': photo.id,
                  'createdAt': photo.createdAt.toIso8601String(),
                },
            ],
      'assets': {'images': images, 'thumbnails': thumbnails},
      'metadata': includeMetadata
          ? {
              'poses': {
                for (final entry in project.poses.entries)
                  entry.key: entry.value.toJson(),
              },
              'pipeline': {
                'targetFormat': project.exportConfig.targetFormat.value,
                'qualityPreset': project.exportConfig.qualityPreset.value,
                'textureQuality': project.exportConfig.textureQuality.value,
                'geometryQuality': project.exportConfig.geometryQuality.value,
                'scaleUnit': project.exportConfig.scaleUnit.value,
                'destination': project.exportConfig.destination.value,
                'destinationPath': project.exportConfig.destinationPath,
                'includeNormals': project.exportConfig.includeNormals,
                'processingProfile': project.processingConfig.profile.value,
                'source': 'mobile-capture-app',
                'readyForBackend': true,
              },
            }
          : const {},
      'stats': {
        'acceptedPhotos': project.coverage.acceptedPhotos,
        'flaggedForRetake': project.coverage.flaggedForRetake,
        'imagesIncluded': images.length,
        'thumbnailsIncluded': thumbnails.length,
        'processingStage': project.processingState.stage.value,
        'processingProgress': project.processingState.progress,
      },
      'integration': {
        'kind': 'stub',
        'consumer': 'private-3d-backend',
        'message':
            'Paquete simulado listo para backend privado de reconstruccion 3D.',
      },
    };

    final file = File(packagePath);
    await file.writeAsString(jsonEncode(payload), flush: true);
    final sizeBytes = await file.length();

    return ProjectExportPackage(
      packagePath: file.path,
      createdAt: now,
      photoCount: project.photos.length,
      sizeBytes: sizeBytes,
    );
  }
}
