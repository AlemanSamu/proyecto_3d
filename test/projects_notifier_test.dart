import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/data/capture/project_capture_storage.dart';
import 'package:proyecto_3d/data/projects/project_repository.dart';
import 'package:proyecto_3d/domain/projects/project_model.dart';
import 'package:proyecto_3d/presentation/providers/project_providers.dart';

class InMemoryProjectRepository implements ProjectRepository {
  List<ProjectModel> _projects = const [];

  @override
  Future<List<ProjectModel>> readProjects() async {
    return List<ProjectModel>.from(_projects);
  }

  @override
  Future<void> writeProjects(List<ProjectModel> projects) async {
    _projects = List<ProjectModel>.from(projects);
  }
}

class SpyCaptureStorage implements ProjectCaptureStorage {
  final List<String> deletedPaths = <String>[];
  final List<String> deletedProjects = <String>[];

  @override
  Future<String?> copyToProject({
    required String projectId,
    required String sourcePath,
  }) async {
    return sourcePath;
  }

  @override
  Future<void> deleteIfExists(String path) async {
    deletedPaths.add(path);
  }

  @override
  Future<void> deleteProjectData(String projectId) async {
    deletedProjects.add(projectId);
  }
}

class ThrowingCaptureStorage implements ProjectCaptureStorage {
  @override
  Future<String?> copyToProject({
    required String projectId,
    required String sourcePath,
  }) async {
    return sourcePath;
  }

  @override
  Future<void> deleteIfExists(String path) async {
    throw Exception('io error');
  }

  @override
  Future<void> deleteProjectData(String projectId) async {
    throw Exception('io error');
  }
}

void main() {
  test('deleteProject elimina estado y limpia archivos del proyecto', () async {
    final storage = SpyCaptureStorage();
    final notifier = ProjectsNotifier(
      InMemoryProjectRepository(),
      captureStorage: storage,
    );

    final project = notifier.createProject(name: 'Proyecto test');
    notifier.addImagePath(project.id, '/tmp/cap_1.jpg');
    notifier.addImagePath(project.id, '/tmp/cap_2.jpg');
    notifier.setModelPath(project.id, '/tmp/model.glb');

    notifier.deleteProject(project.id);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.where((item) => item.id == project.id), isEmpty);
    expect(storage.deletedPaths, contains('/tmp/cap_1.jpg'));
    expect(storage.deletedPaths, contains('/tmp/cap_2.jpg'));
    expect(storage.deletedPaths, contains('/tmp/model.glb'));
    expect(storage.deletedProjects, [project.id]);
  });

  test('deleteProject mantiene estado consistente si falla limpieza', () async {
    final notifier = ProjectsNotifier(
      InMemoryProjectRepository(),
      captureStorage: ThrowingCaptureStorage(),
    );

    final project = notifier.createProject(name: 'Proyecto test');
    notifier.addImagePath(project.id, '/tmp/cap_1.jpg');

    notifier.deleteProject(project.id);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.where((item) => item.id == project.id), isEmpty);
  });
}
