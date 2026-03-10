import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'project_model.dart';

const _projectsFileName = 'scan_projects.json';

final projectStorageProvider = Provider<ProjectStorage>((ref) {
  return FileProjectStorage();
});

final projectsProvider =
    StateNotifierProvider<ProjectsNotifier, List<ScanProject>>((ref) {
      final notifier = ProjectsNotifier(ref.read(projectStorageProvider));
      notifier.load();
      return notifier;
    });

abstract class ProjectStorage {
  Future<List<ScanProject>> readProjects();
  Future<void> writeProjects(List<ScanProject> projects);
}

class FileProjectStorage implements ProjectStorage {
  @override
  Future<List<ScanProject>> readProjects() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return const [];

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final projects = <ScanProject>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final project = ScanProject.fromJson(entry);
          if (project.id.isNotEmpty) projects.add(project);
          continue;
        }

        if (entry is Map) {
          final project = ScanProject.fromJson(
            Map<String, dynamic>.from(entry),
          );
          if (project.id.isNotEmpty) projects.add(project);
        }
      }

      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return projects;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> writeProjects(List<ScanProject> projects) async {
    final file = await _resolveFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final payload = jsonEncode([for (final p in projects) p.toJson()]);
    await file.writeAsString(payload);
  }

  Future<File> _resolveFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}${Platform.pathSeparator}$_projectsFileName');
  }
}

class ProjectsNotifier extends StateNotifier<List<ScanProject>> {
  ProjectsNotifier(this._storage) : super(const []);

  final ProjectStorage _storage;
  final _uuid = const Uuid();
  bool _loaded = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final loadedProjects = await _storage.readProjects();
    if (state.isEmpty) {
      state = loadedProjects;
      return;
    }

    // If user created data before load finished, merge by id.
    final merged = <String, ScanProject>{
      for (final p in loadedProjects) p.id: p,
      for (final p in state) p.id: p,
    };
    state = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _persist();
  }

  ScanProject createNewProject() {
    final project = ScanProject(
      id: _uuid.v4(),
      name: 'Escaneo ${state.length + 1}',
      createdAt: DateTime.now(),
      posePhotos: const {},
    );
    state = [project, ...state];
    _persist();
    return project;
  }

  void setPosePhoto(String projectId, String poseId, String path) {
    state = [
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(posePhotos: {...p.posePhotos, poseId: path})
        else
          p,
    ];
    _persist();
  }

  void removePosePhoto(String projectId, String poseId) {
    state = [
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(
            posePhotos: Map<String, String>.from(p.posePhotos)..remove(poseId),
          )
        else
          p,
    ];
    _persist();
  }

  void _persist() {
    final snapshot = _snapshotForPersist(state);
    _writeQueue = _writeQueue
        .then((_) => _storage.writeProjects(snapshot))
        .catchError((_) {});
  }

  List<ScanProject> _snapshotForPersist(List<ScanProject> projects) {
    return [
      for (final project in projects)
        project.copyWith(
          posePhotos: Map<String, String>.from(project.posePhotos),
        ),
    ];
  }
}
