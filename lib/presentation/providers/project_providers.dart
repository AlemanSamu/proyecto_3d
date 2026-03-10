import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/capture/project_capture_storage.dart';
import '../../data/projects/local_project_repository.dart';
import '../../data/projects/project_repository.dart';
import '../../domain/projects/project_model.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return LocalProjectRepository();
});

final projectCaptureStorageProvider = Provider<ProjectCaptureStorage>((ref) {
  return LocalProjectCaptureStorage();
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

class ProjectsNotifier extends StateNotifier<List<ProjectModel>> {
  ProjectsNotifier(
    this._repository, {
    ProjectCaptureStorage? captureStorage,
  }) : _captureStorage = captureStorage ?? LocalProjectCaptureStorage(),
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

  ProjectModel createProject({String? name}) {
    final project = ProjectModel(
      id: _uuid.v4(),
      name: name?.trim().isNotEmpty == true ? name!.trim() : _defaultName(),
      createdAt: DateTime.now(),
      imagePaths: const [],
      modelPath: null,
      status: ProjectStatus.capturing,
    );

    state = [project, ...state];
    _persist();
    return project;
  }

  void addImagePath(String projectId, String imagePath) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(imagePaths: [...project.imagePaths, imagePath])
        else
          project,
    ];
    _persist();
  }

  void removeImagePath(String projectId, String imagePath) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(
            imagePaths: [
              for (final path in project.imagePaths)
                if (path != imagePath) path,
            ],
          )
        else
          project,
    ];
    _persist();
  }

  void updateStatus(String projectId, ProjectStatus status) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(status: status)
        else
          project,
    ];
    _persist();
  }

  void setModelPath(String projectId, String? modelPath) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(
            modelPath: modelPath,
            clearModelPath: modelPath == null,
            status: modelPath == null ? project.status : ProjectStatus.done,
          )
        else
          project,
    ];
    _persist();
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
      unawaited(_cleanupProjectFiles(removedProject!));
    }
  }

  String _defaultName() {
    return 'Proyecto ${state.length + 1}';
  }

  void _persist() {
    final snapshot = [
      for (final project in state)
        project.copyWith(imagePaths: List<String>.from(project.imagePaths)),
    ];
    _writeQueue = _writeQueue
        .then((_) => _repository.writeProjects(snapshot))
        .catchError((_) {});
  }

  Future<void> _cleanupProjectFiles(ProjectModel project) async {
    try {
      for (final imagePath in project.imagePaths) {
        await _captureStorage.deleteIfExists(imagePath);
      }

      final modelPath = project.modelPath;
      if (modelPath != null && modelPath.isNotEmpty) {
        await _captureStorage.deleteIfExists(modelPath);
      }

      await _captureStorage.deleteProjectData(project.id);
    } catch (_) {
      // best effort cleanup
    }
  }
}
