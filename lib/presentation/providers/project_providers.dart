import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/capture/project_capture_storage.dart';
import '../../data/projects/project_export_packager.dart';
import '../../data/projects/project_model_builder.dart';
import '../../data/projects/local_project_repository.dart';
import '../../data/projects/project_repository.dart';
import '../../domain/capture/capture_photo.dart';
import '../../domain/projects/project_coverage_summary.dart';
import '../../domain/projects/project_export_config.dart';
import '../../domain/projects/project_model.dart';
import '../../domain/projects/project_processing.dart';
import '../controllers/project_export_controller.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return LocalProjectRepository();
});

final projectCaptureStorageProvider = Provider<ProjectCaptureStorage>((ref) {
  return LocalProjectCaptureStorage();
});

final projectExportPackagerProvider = Provider<ProjectExportPackager>((ref) {
  return LocalStubProjectExportPackager();
});

final projectModelBuilderProvider = Provider<ProjectModelBuilder>((ref) {
  return LocalStubProjectModelBuilder();
});

final projectsProvider =
    StateNotifierProvider<ProjectsNotifier, List<ProjectModel>>((ref) {
      final notifier = ProjectsNotifier(
        ref.read(projectRepositoryProvider),
        captureStorage: ref.read(projectCaptureStorageProvider),
      );
      notifier.load();
      return notifier;
    });

final projectByIdProvider = Provider.family<ProjectModel?, String>((
  ref,
  projectId,
) {
  final projects = ref.watch(projectsProvider);
  for (final project in projects) {
    if (project.id == projectId) return project;
  }
  return null;
});

final projectExportControllerProvider = Provider<ProjectExportController>((
  ref,
) {
  final notifier = ref.read(projectsProvider.notifier);
  return ProjectExportController(
    modelBuilder: ref.read(projectModelBuilderProvider),
    packager: ref.read(projectExportPackagerProvider),
    updateStatus: notifier.updateStatus,
    updateProcessingState: notifier.updateProcessingState,
    setModelPath: notifier.setModelPath,
    setLastExportPackagePath: notifier.setLastExportPackagePath,
  );
});

class ProjectsNotifier extends StateNotifier<List<ProjectModel>> {
  ProjectsNotifier(this._repository, {ProjectCaptureStorage? captureStorage})
    : _captureStorage = captureStorage ?? LocalProjectCaptureStorage(),
      super(const []);

  final ProjectRepository _repository;
  final ProjectCaptureStorage _captureStorage;
  final _uuid = const Uuid();
  bool _loaded = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final loaded = await _repository.readProjects();
    if (state.isEmpty) {
      state = loaded;
      return;
    }

    final merged = <String, ProjectModel>{
      for (final item in loaded) item.id: item,
      for (final item in state) item.id: item,
    };
    state = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _persist();
  }

  ProjectModel? findById(String projectId) {
    for (final project in state) {
      if (project.id == projectId) return project;
    }
    return null;
  }

  ProjectModel createProject({String? name, String description = ''}) {
    final now = DateTime.now();
    final project = ProjectModel(
      id: _uuid.v4(),
      name: _normalizeName(name) ?? _defaultName(),
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
      status: ProjectStatus.draft,
      coverImagePath: null,
      photos: const [],
      exportConfig: const ProjectExportConfig(),
      processingConfig: const ProjectProcessingConfig(),
      processingState: ProjectProcessingState(),
      poses: const {},
      coverage: ProjectCoverageSummary.fromPhotos(const []),
      modelPath: null,
    );

    state = [project, ...state];
    _persist();
    return project;
  }

  void updateProjectDetails({
    required String projectId,
    String? name,
    String? description,
    String? coverImagePath,
    bool clearCoverImagePath = false,
  }) {
    final normalizedName = _normalizeName(name);
    final normalizedDescription = _normalizeDescription(description);
    _updateProject(projectId, (project) {
      return project.copyWith(
        name: normalizedName,
        description: normalizedDescription,
        coverImagePath: coverImagePath,
        clearCoverImagePath: clearCoverImagePath,
        updatedAt: DateTime.now(),
      );
    });
  }

  void addImagePath(
    String projectId,
    String imagePath, {
    String? poseId,
    int? angleDeg,
    String? level,
    double brightness = 0,
    double sharpness = 0,
    bool accepted = true,
    bool flaggedForRetake = false,
  }) {
    final normalized = imagePath.trim();
    if (normalized.isEmpty) return;

    addCapturePhoto(
      projectId,
      CapturePhoto(
        id: _uuid.v4(),
        originalPath: normalized,
        thumbnailPath: LocalProjectCaptureStorage.thumbnailPathFor(normalized),
        poseId: poseId,
        angleDeg: angleDeg,
        level: level,
        brightness: brightness,
        sharpness: sharpness,
        accepted: accepted,
        flaggedForRetake: flaggedForRetake,
        createdAt: DateTime.now(),
      ),
    );
  }

  void addCapturePhoto(String projectId, CapturePhoto photo) {
    _updateProject(projectId, (project) {
      final nextPhotos = [...project.photos, photo];
      return project.copyWith(
        photos: nextPhotos,
        coverImagePath:
            project.coverImagePath ??
            (photo.thumbnailPath.isNotEmpty
                ? photo.thumbnailPath
                : photo.originalPath),
        status: _deriveWorkflowStatus(project, nextPhotos),
        updatedAt: DateTime.now(),
      );
    });
  }

  void removeImagePath(String projectId, String imagePath) {
    _updateProject(projectId, (project) {
      final nextPhotos = [
        for (final photo in project.photos)
          if (photo.originalPath != imagePath) photo,
      ];
      return project.copyWith(
        photos: nextPhotos,
        status: _deriveWorkflowStatus(project, nextPhotos),
        updatedAt: DateTime.now(),
      );
    });
  }

  void removeCapturePhoto(String projectId, String photoId) {
    _updateProject(projectId, (project) {
      final nextPhotos = [
        for (final photo in project.photos)
          if (photo.id != photoId) photo,
      ];
      return project.copyWith(
        photos: nextPhotos,
        status: _deriveWorkflowStatus(project, nextPhotos),
        updatedAt: DateTime.now(),
      );
    });
  }

  void updatePhotoReview({
    required String projectId,
    required String photoId,
    bool? accepted,
    bool? flaggedForRetake,
  }) {
    _updateProject(projectId, (project) {
      final nextPhotos = [
        for (final photo in project.photos)
          if (photo.id == photoId)
            photo.copyWith(
              accepted: accepted,
              flaggedForRetake: flaggedForRetake,
            )
          else
            photo,
      ];
      return project.copyWith(
        photos: nextPhotos,
        status: _deriveWorkflowStatus(project, nextPhotos),
        updatedAt: DateTime.now(),
      );
    });
  }

  void updatePhotoMetadata({
    required String projectId,
    required String photoId,
    String? poseId,
    bool clearPoseId = false,
    int? angleDeg,
    bool clearAngleDeg = false,
    String? level,
    bool clearLevel = false,
  }) {
    _updateProject(projectId, (project) {
      final nextPhotos = [
        for (final photo in project.photos)
          if (photo.id == photoId)
            photo.copyWith(
              poseId: poseId,
              clearPoseId: clearPoseId,
              angleDeg: angleDeg,
              clearAngleDeg: clearAngleDeg,
              level: level,
              clearLevel: clearLevel,
            )
          else
            photo,
      ];
      return project.copyWith(
        photos: nextPhotos,
        status: _deriveWorkflowStatus(project, nextPhotos),
        updatedAt: DateTime.now(),
      );
    });
  }

  void updateExportConfig(String projectId, ProjectExportConfig config) {
    _updateProject(projectId, (project) {
      final shouldPromote =
          project.status == ProjectStatus.reviewReady ||
          project.status == ProjectStatus.readyToProcess;
      return project.copyWith(
        exportConfig: config,
        status: shouldPromote ? ProjectStatus.readyToProcess : project.status,
        updatedAt: DateTime.now(),
      );
    });
  }

  void updateProcessingConfig(
    String projectId,
    ProjectProcessingConfig config,
  ) {
    _updateProject(projectId, (project) {
      return project.copyWith(
        processingConfig: config,
        updatedAt: DateTime.now(),
      );
    });
  }

  void updateProcessingState(String projectId, ProjectProcessingState state) {
    _updateProject(projectId, (project) {
      return project.copyWith(
        processingState: state,
        updatedAt: DateTime.now(),
      );
    });
  }

  void setLastExportPackagePath(String projectId, String? packagePath) {
    _updateProject(projectId, (project) {
      return project.copyWith(
        lastExportPackagePath: packagePath,
        clearLastExportPackagePath: packagePath == null,
        status: packagePath == null ? project.status : ProjectStatus.exported,
        processingState: project.processingState.copyWith(
          stage: packagePath == null
              ? project.processingState.stage
              : ProcessingStage.completed,
          progress: packagePath == null ? project.processingState.progress : 1,
          message: packagePath == null
              ? project.processingState.message
              : 'Paquete exportado',
          updatedAt: DateTime.now(),
        ),
        updatedAt: DateTime.now(),
      );
    });
  }

  void updateStatus(String projectId, ProjectStatus status) {
    _updateProject(projectId, (project) {
      final processingState = switch (status) {
        ProjectStatus.processing => project.processingState.copyWith(
          stage: project.processingState.stage == ProcessingStage.idle
              ? ProcessingStage.queued
              : project.processingState.stage,
          progress: project.processingState.progress == 0
              ? 0.05
              : project.processingState.progress,
          message: 'Procesamiento en curso',
          updatedAt: DateTime.now(),
        ),
        ProjectStatus.error => project.processingState.copyWith(
          stage: ProcessingStage.failed,
          message: 'Se detecto un error en el pipeline',
          updatedAt: DateTime.now(),
        ),
        _ => project.processingState,
      };
      return project.copyWith(
        status: status,
        processingState: processingState,
        updatedAt: DateTime.now(),
      );
    });
  }

  void setModelPath(String projectId, String? modelPath) {
    _updateProject(projectId, (project) {
      return project.copyWith(
        modelPath: modelPath,
        clearModelPath: modelPath == null,
        status: modelPath == null
            ? project.status
            : ProjectStatus.modelGenerated,
        processingState: modelPath == null
            ? project.processingState
            : project.processingState.copyWith(
                stage: ProcessingStage.completed,
                progress: 1,
                message: 'Modelo generado',
                updatedAt: DateTime.now(),
              ),
        updatedAt: DateTime.now(),
      );
    });
  }

  void deleteProject(String projectId) {
    ProjectModel? removedProject;
    final next = <ProjectModel>[];
    for (final project in state) {
      if (project.id == projectId) {
        removedProject = project;
        continue;
      }
      next.add(project);
    }

    state = next;
    _persist();

    if (removedProject != null) {
      unawaited(_cleanupProjectFiles(removedProject));
    }
  }

  String _defaultName() {
    return 'Proyecto ${state.length + 1}';
  }

  String? _normalizeName(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    return value;
  }

  String? _normalizeDescription(String? raw) {
    if (raw == null) return null;
    return raw.trim();
  }

  void _updateProject(
    String projectId,
    ProjectModel Function(ProjectModel project) transform,
  ) {
    bool changed = false;
    final nextState = [
      for (final project in state)
        if (project.id == projectId)
          () {
            changed = true;
            return transform(project);
          }()
        else
          project,
    ];

    if (!changed) return;
    state = nextState;
    _persist();
  }

  void _persist() {
    final snapshot = [
      for (final project in state)
        project.copyWith(
          photos: [for (final photo in project.photos) photo.copyWith()],
          poses: {
            for (final entry in project.poses.entries)
              entry.key: entry.value.copyWith(),
          },
          exportConfig: project.exportConfig.copyWith(),
          processingConfig: project.processingConfig.copyWith(),
          processingState: project.processingState.copyWith(),
          coverage: project.coverage.copyWith(),
        ),
    ];
    _writeQueue = _writeQueue
        .then((_) => _repository.writeProjects(snapshot))
        .catchError((_) {});
  }

  Future<void> _cleanupProjectFiles(ProjectModel project) async {
    try {
      for (final photo in project.photos) {
        await _captureStorage.deleteIfExists(photo.originalPath);
      }

      final modelPath = project.modelPath;
      if (modelPath != null && modelPath.isNotEmpty) {
        await _captureStorage.deleteIfExists(modelPath);
      }

      final packagePath = project.lastExportPackagePath;
      if (packagePath != null && packagePath.isNotEmpty) {
        await _captureStorage.deleteIfExists(packagePath);
      }

      await _captureStorage.deleteProjectData(project.id);
    } catch (_) {
      // best effort cleanup
    }
  }

  ProjectStatus _deriveWorkflowStatus(
    ProjectModel previous,
    List<CapturePhoto> photos,
  ) {
    if (previous.status.isAdvancedStage && photos.isNotEmpty) {
      return previous.status;
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
