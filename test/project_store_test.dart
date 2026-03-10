import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/data/projects/project_repository.dart';
import 'package:proyecto_3d/domain/projects/project_model.dart';
import 'package:proyecto_3d/presentation/providers/project_providers.dart';

class FakeProjectRepository implements ProjectRepository {
  List<ProjectModel> _projects;
  int writeCalls = 0;

  FakeProjectRepository({List<ProjectModel>? initial})
    : _projects = List<ProjectModel>.from(initial ?? const []);

  @override
  Future<List<ProjectModel>> readProjects() async {
    return List<ProjectModel>.from(_projects);
  }

  @override
  Future<void> writeProjects(List<ProjectModel> projects) async {
    writeCalls++;
    _projects = [
      for (final project in projects)
        project.copyWith(imagePaths: List<String>.from(project.imagePaths)),
    ];
  }

  List<ProjectModel> get projects => List<ProjectModel>.from(_projects);
}

class RaceyProjectRepository implements ProjectRepository {
  List<ProjectModel> _projects = const [];
  int writeCalls = 0;

  @override
  Future<List<ProjectModel>> readProjects() async {
    return List<ProjectModel>.from(_projects);
  }

  @override
  Future<void> writeProjects(List<ProjectModel> projects) async {
    writeCalls++;
    final delay = switch (writeCalls) {
      1 => Duration.zero,
      2 => const Duration(milliseconds: 80),
      _ => const Duration(milliseconds: 10),
    };

    await Future<void>.delayed(delay);
    _projects = [
      for (final project in projects)
        project.copyWith(imagePaths: List<String>.from(project.imagePaths)),
    ];
  }

  List<ProjectModel> get projects => List<ProjectModel>.from(_projects);
}

void main() {
  test('ProjectModel serializa y deserializa', () {
    final project = ProjectModel(
      id: 'project-1',
      name: 'Escaneo demo',
      createdAt: DateTime.parse('2026-03-02T12:00:00.000Z'),
      imagePaths: const ['/tmp/mid_0.jpg'],
      modelPath: '/tmp/model.glb',
      status: ProjectStatus.done,
    );

    final roundTrip = ProjectModel.fromJson(project.toJson());

    expect(roundTrip.id, project.id);
    expect(roundTrip.name, project.name);
    expect(roundTrip.createdAt, project.createdAt);
    expect(roundTrip.imagePaths, project.imagePaths);
    expect(roundTrip.modelPath, project.modelPath);
    expect(roundTrip.status, project.status);
  });

  test('ProjectsNotifier carga desde repository', () async {
    final storedProject = ProjectModel(
      id: 'stored-1',
      name: 'Escaneo guardado',
      createdAt: DateTime.parse('2026-03-01T12:00:00.000Z'),
      imagePaths: const [],
      modelPath: null,
      status: ProjectStatus.capturing,
    );
    final repo = FakeProjectRepository(initial: [storedProject]);
    final notifier = ProjectsNotifier(repo);

    await notifier.load();

    expect(notifier.state.length, 1);
    expect(notifier.state.first.id, 'stored-1');
  });

  test('ProjectsNotifier crea, actualiza y persiste imagenes', () async {
    final repo = FakeProjectRepository();
    final notifier = ProjectsNotifier(repo);
    await notifier.load();

    final created = notifier.createProject(name: 'Proyecto demo');
    notifier.addImagePath(created.id, '/app/captures/mid_0.jpg');
    notifier.removeImagePath(created.id, '/app/captures/mid_0.jpg');
    await Future<void>.delayed(Duration.zero);

    final persisted = repo.projects.first;
    expect(repo.writeCalls, greaterThanOrEqualTo(3));
    expect(persisted.id, created.id);
    expect(persisted.imagePaths, isEmpty);
  });

  test(
    'ProjectsNotifier serializa escrituras y conserva el ultimo estado',
    () async {
      final repo = RaceyProjectRepository();
      final notifier = ProjectsNotifier(repo);
      await notifier.load();

      final created = notifier.createProject(name: 'Proyecto demo');
      notifier.addImagePath(created.id, '/app/captures/mid_0.jpg');
      notifier.removeImagePath(created.id, '/app/captures/mid_0.jpg');
      await Future<void>.delayed(const Duration(milliseconds: 160));

      expect(repo.writeCalls, 3);
      expect(repo.projects, hasLength(1));
      expect(repo.projects.first.imagePaths, isEmpty);
    },
  );
}
