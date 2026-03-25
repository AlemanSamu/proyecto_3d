import '../capture/capture_photo.dart';
import 'project_coverage_summary.dart';
import 'project_export_config.dart';
import 'project_pose_info.dart';
import 'project_processing.dart';

enum ProjectStatus {
  draft,
  capturing,
  reviewReady,
  readyToProcess,
  processing,
  modelGenerated,
  exported,
  error,
}

extension ProjectStatusX on ProjectStatus {
  String get value => switch (this) {
    ProjectStatus.draft => 'draft',
    ProjectStatus.capturing => 'capturing',
    ProjectStatus.reviewReady => 'reviewReady',
    ProjectStatus.readyToProcess => 'readyToProcess',
    ProjectStatus.processing => 'processing',
    ProjectStatus.modelGenerated => 'modelGenerated',
    ProjectStatus.exported => 'exported',
    ProjectStatus.error => 'error',
  };

  String get label => switch (this) {
    ProjectStatus.draft => 'Borrador',
    ProjectStatus.capturing => 'Capturando',
    ProjectStatus.reviewReady => 'Lista para revision',
    ProjectStatus.readyToProcess => 'Listo para procesar',
    ProjectStatus.processing => 'Procesando',
    ProjectStatus.modelGenerated => 'Modelo generado',
    ProjectStatus.exported => 'Exportado',
    ProjectStatus.error => 'Error',
  };

  bool get isAdvancedStage {
    return this == ProjectStatus.processing ||
        this == ProjectStatus.modelGenerated ||
        this == ProjectStatus.exported ||
        this == ProjectStatus.error;
  }

  static ProjectStatus fromValue(String? value) {
    return switch (value) {
      'draft' => ProjectStatus.draft,
      'capturing' => ProjectStatus.capturing,
      'reviewReady' => ProjectStatus.reviewReady,
      'readyToProcess' => ProjectStatus.readyToProcess,
      'processing' => ProjectStatus.processing,
      'done' => ProjectStatus.modelGenerated,
      'modelGenerated' => ProjectStatus.modelGenerated,
      'exported' => ProjectStatus.exported,
      'error' => ProjectStatus.error,
      _ => ProjectStatus.draft,
    };
  }
}

class ProjectModel {
  ProjectModel({
    required this.id,
    required this.name,
    required this.createdAt,
    String? description,
    DateTime? updatedAt,
    ProjectStatus? status,
    String? coverImagePath,
    List<CapturePhoto>? photos,
    List<String>? imagePaths,
    ProjectExportConfig? exportConfig,
    ProjectProcessingConfig? processingConfig,
    ProjectProcessingState? processingState,
    Map<String, ProjectPoseInfo>? poses,
    ProjectCoverageSummary? coverage,
    this.modelPath,
    this.lastExportPackagePath,
  }) : description = description?.trim() ?? '',
       updatedAt = updatedAt ?? createdAt,
       photos = photos ?? _photosFromImagePaths(imagePaths) ?? const [],
       exportConfig = exportConfig ?? const ProjectExportConfig(),
       processingConfig = processingConfig ?? const ProjectProcessingConfig(),
       processingState = processingState ?? ProjectProcessingState(),
       poses =
           poses ??
           _buildPoseSummary(
             photos ?? _photosFromImagePaths(imagePaths) ?? const [],
           ),
       coverage =
           coverage ??
           ProjectCoverageSummary.fromPhotos(
             photos ?? _photosFromImagePaths(imagePaths) ?? const [],
           ),
       coverImagePath =
           coverImagePath ??
           _latestCoverPath(
             photos ?? _photosFromImagePaths(imagePaths) ?? const [],
           ),
       status =
           status ??
           _suggestStatus(
             photos: photos ?? _photosFromImagePaths(imagePaths) ?? const [],
             processingState: processingState,
             modelPath: modelPath,
             lastExportPackagePath: lastExportPackagePath,
           );

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectStatus status;
  final String? coverImagePath;
  final List<CapturePhoto> photos;
  final ProjectExportConfig exportConfig;
  final ProjectProcessingConfig processingConfig;
  final ProjectProcessingState processingState;
  final Map<String, ProjectPoseInfo> poses;
  final ProjectCoverageSummary coverage;
  final String? modelPath;
  final String? lastExportPackagePath;

  DateTime? get lastCaptureAt {
    if (photos.isEmpty) return null;
    return photos
        .map((photo) => photo.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  List<String> get imagePaths {
    return [for (final photo in photos) photo.originalPath];
  }

  int get photoCount => photos.length;

  ProjectModel copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
    ProjectStatus? status,
    String? coverImagePath,
    bool clearCoverImagePath = false,
    List<CapturePhoto>? photos,
    ProjectExportConfig? exportConfig,
    ProjectProcessingConfig? processingConfig,
    ProjectProcessingState? processingState,
    Map<String, ProjectPoseInfo>? poses,
    ProjectCoverageSummary? coverage,
    String? modelPath,
    bool clearModelPath = false,
    String? lastExportPackagePath,
    bool clearLastExportPackagePath = false,
    List<String>? imagePaths,
  }) {
    final nextPhotos =
        photos ?? _photosFromImagePaths(imagePaths) ?? this.photos;
    final nextCoverage =
        coverage ?? ProjectCoverageSummary.fromPhotos(nextPhotos);
    final nextPoses = poses ?? _buildPoseSummary(nextPhotos);
    final nextCover = clearCoverImagePath
        ? null
        : coverImagePath ?? this.coverImagePath ?? _latestCoverPath(nextPhotos);
    final nextModelPath = clearModelPath ? null : (modelPath ?? this.modelPath);
    final nextPackagePath = clearLastExportPackagePath
        ? null
        : (lastExportPackagePath ?? this.lastExportPackagePath);

    return ProjectModel(
      id: id,
      name: _normalizedName(name) ?? this.name,
      description: description?.trim() ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status:
          status ??
          _suggestStatus(
            photos: nextPhotos,
            processingState: processingState ?? this.processingState,
            modelPath: nextModelPath,
            lastExportPackagePath: nextPackagePath,
          ),
      coverImagePath: nextCover,
      photos: nextPhotos,
      exportConfig: exportConfig ?? this.exportConfig,
      processingConfig: processingConfig ?? this.processingConfig,
      processingState: processingState ?? this.processingState,
      poses: nextPoses,
      coverage: nextCoverage,
      modelPath: nextModelPath,
      lastExportPackagePath: nextPackagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.value,
      'coverImagePath': coverImagePath,
      'photos': [for (final photo in photos) photo.toJson()],
      'imagePaths': imagePaths,
      'exportConfig': exportConfig.toJson(),
      'processingConfig': processingConfig.toJson(),
      'processingState': processingState.toJson(),
      'poses': {
        for (final entry in poses.entries) entry.key: entry.value.toJson(),
      },
      'coverage': coverage.toJson(),
      'modelPath': modelPath,
      'lastExportPackagePath': lastExportPackagePath,
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final parsedPhotos = _readPhotos(json, createdAt);
    final parsedCoverage = _readCoverage(json, parsedPhotos);
    final parsedModelPath = json['modelPath'] as String?;
    final parsedPackage = json['lastExportPackagePath'] as String?;

    return ProjectModel(
      id: json['id'] as String? ?? '',
      name: _normalizedName(json['name'] as String?) ?? 'Proyecto',
      description: json['description'] as String? ?? '',
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt,
      status: ProjectStatusX.fromValue(json['status'] as String?),
      coverImagePath:
          json['coverImagePath'] as String? ?? _latestCoverPath(parsedPhotos),
      photos: parsedPhotos,
      exportConfig: _readExportConfig(json),
      processingConfig: _readProcessingConfig(json),
      processingState: _readProcessingState(json),
      poses: _readPoseInfo(json, parsedPhotos),
      coverage: parsedCoverage,
      modelPath: parsedModelPath,
      lastExportPackagePath: parsedPackage,
    );
  }

  static List<CapturePhoto> _readPhotos(
    Map<String, dynamic> json,
    DateTime createdAt,
  ) {
    final photos = <CapturePhoto>[];
    final rawPhotos = json['photos'];

    if (rawPhotos is List) {
      for (final raw in rawPhotos) {
        if (raw is Map<String, dynamic>) {
          final photo = CapturePhoto.fromJson(raw);
          if (photo.id.isNotEmpty && photo.originalPath.isNotEmpty) {
            photos.add(photo);
          }
          continue;
        }

        if (raw is Map) {
          final photo = CapturePhoto.fromJson(Map<String, dynamic>.from(raw));
          if (photo.id.isNotEmpty && photo.originalPath.isNotEmpty) {
            photos.add(photo);
          }
        }
      }
    }

    if (photos.isNotEmpty) return photos;

    final rawPaths = json['imagePaths'];
    if (rawPaths is List) {
      int index = 0;
      for (final item in rawPaths) {
        if (item is String && item.isNotEmpty) {
          photos.add(
            CapturePhoto.legacy(
              id: 'legacy_$index',
              originalPath: item,
              createdAt: createdAt,
            ),
          );
          index++;
        }
      }
    }

    return photos;
  }

  static ProjectCoverageSummary _readCoverage(
    Map<String, dynamic> json,
    List<CapturePhoto> photos,
  ) {
    final rawCoverage = json['coverage'];
    if (rawCoverage is Map<String, dynamic>) {
      return ProjectCoverageSummary.fromJson(rawCoverage);
    }
    if (rawCoverage is Map) {
      return ProjectCoverageSummary.fromJson(
        Map<String, dynamic>.from(rawCoverage),
      );
    }
    return ProjectCoverageSummary.fromPhotos(photos);
  }

  static ProjectExportConfig _readExportConfig(Map<String, dynamic> json) {
    final raw = json['exportConfig'];
    if (raw is Map<String, dynamic>) {
      return ProjectExportConfig.fromJson(raw);
    }
    if (raw is Map) {
      return ProjectExportConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    return const ProjectExportConfig();
  }

  static ProjectProcessingConfig _readProcessingConfig(
    Map<String, dynamic> json,
  ) {
    final raw = json['processingConfig'];
    if (raw is Map<String, dynamic>) {
      return ProjectProcessingConfig.fromJson(raw);
    }
    if (raw is Map) {
      return ProjectProcessingConfig.fromJson(Map<String, dynamic>.from(raw));
    }
    return const ProjectProcessingConfig();
  }

  static ProjectProcessingState _readProcessingState(
    Map<String, dynamic> json,
  ) {
    final raw = json['processingState'];
    if (raw is Map<String, dynamic>) {
      return ProjectProcessingState.fromJson(raw);
    }
    if (raw is Map) {
      return ProjectProcessingState.fromJson(Map<String, dynamic>.from(raw));
    }
    return ProjectProcessingState();
  }

  static Map<String, ProjectPoseInfo> _readPoseInfo(
    Map<String, dynamic> json,
    List<CapturePhoto> photos,
  ) {
    final raw = json['poses'];
    if (raw is Map) {
      final parsed = <String, ProjectPoseInfo>{};
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          final pose = ProjectPoseInfo.fromJson(value);
          if (pose.poseId.isNotEmpty) {
            parsed[key] = pose;
          }
          continue;
        }
        if (value is Map) {
          final pose = ProjectPoseInfo.fromJson(
            Map<String, dynamic>.from(value),
          );
          if (pose.poseId.isNotEmpty) {
            parsed[key] = pose;
          }
        }
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return _buildPoseSummary(photos);
  }

  static Map<String, ProjectPoseInfo> _buildPoseSummary(
    List<CapturePhoto> photos,
  ) {
    final grouped = <String, List<CapturePhoto>>{};
    for (final photo in photos) {
      final poseId = photo.poseId;
      if (poseId == null || poseId.isEmpty) continue;
      grouped.putIfAbsent(poseId, () => <CapturePhoto>[]).add(photo);
    }

    return {
      for (final entry in grouped.entries)
        entry.key: ProjectPoseInfo(
          poseId: entry.key,
          captureCount: entry.value.length,
          lastCapturedAt: _latestCaptureDate(entry.value),
        ),
    };
  }

  static DateTime? _latestCaptureDate(List<CapturePhoto> photos) {
    if (photos.isEmpty) return null;
    return photos
        .map((photo) => photo.createdAt)
        .reduce((current, next) => current.isAfter(next) ? current : next);
  }

  static String? _latestCoverPath(List<CapturePhoto> photos) {
    if (photos.isEmpty) return null;
    final sorted = [...photos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.thumbnailPath.isNotEmpty
        ? sorted.first.thumbnailPath
        : sorted.first.originalPath;
  }

  static List<CapturePhoto>? _photosFromImagePaths(List<String>? imagePaths) {
    if (imagePaths == null) return null;
    final now = DateTime.now();
    return [
      for (int i = 0; i < imagePaths.length; i++)
        if (imagePaths[i].trim().isNotEmpty)
          CapturePhoto.legacy(
            id: 'legacy_copy_$i',
            originalPath: imagePaths[i].trim(),
            createdAt: now,
          ),
    ];
  }

  static String? _normalizedName(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static ProjectStatus _suggestStatus({
    required List<CapturePhoto> photos,
    required ProjectProcessingState? processingState,
    required String? modelPath,
    required String? lastExportPackagePath,
  }) {
    if (lastExportPackagePath != null && lastExportPackagePath.isNotEmpty) {
      return ProjectStatus.exported;
    }
    if (modelPath != null && modelPath.isNotEmpty) {
      return ProjectStatus.modelGenerated;
    }
    if (processingState?.isActive ?? false) {
      return ProjectStatus.processing;
    }
    if (photos.isEmpty) return ProjectStatus.draft;
    final coverage = ProjectCoverageSummary.fromPhotos(photos);
    if (coverage.acceptedPhotos < coverage.minRecommendedPhotos) {
      return ProjectStatus.capturing;
    }
    if (coverage.flaggedForRetake > 0 || coverage.pendingReviewPhotos > 0) {
      return ProjectStatus.reviewReady;
    }
    return ProjectStatus.readyToProcess;
  }
}
