import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/features/projects/project_model.dart';
import 'package:proyecto_3d/features/projects/project_store.dart';

class FakeProjectStorage implements ProjectStorage {
  List<ScanProject> _projects;
  int writeCalls = 0;

  FakeProjectStorage({List<ScanProject>? initial})
    : _projects = List<ScanProject>.from(initial ?? const []);

  @override
  Future<List<ScanProject>> readProjects() async {
    return List<ScanProject>.from(_projects);
  }

  @override
  Future<void> writeProjects(List<ScanProject> projects) async {
    writeCalls++;
    _projects = [
      for (final project in projects)
        project.copyWith(
          posePhotos: Map<String, String>.from(project.posePhotos),
        ),
    ];
  }

  List<ScanProject> get projects => List<ScanProject>.from(_projects);
}

class RaceyProjectStorage implements ProjectStorage {
  List<ScanProject> _projects = const [];
  int writeCalls = 0;

  @override
  Future<List<ScanProject>> readProjects() async {
    return List<ScanProject>.from(_projects);
  }

  @override
  Future<void> writeProjects(List<ScanProject> projects) async {
    writeCalls++;
    final delay = switch (writeCalls) {
      1 => Duration.zero,
      2 => const Duration(milliseconds: 80),
      _ => const Duration(milliseconds: 10),
    };

    await Future<void>.delayed(delay);
    _projects = [
      for (final project in projects)
        project.copyWith(
          posePhotos: Map<String, String>.from(project.posePhotos),
        ),
    ];
  }

  List<ScanProject> get projects => List<ScanProject>.from(_projects);
}

void main() {
  test('ScanProject serializa y deserializa', () {
    final project = ScanProject(
      id: 'project-1',
      name: 'Escaneo demo',
      createdAt: DateTime.parse('2026-03-02T12:00:00.000Z'),
      posePhotos: const {'mid_0': '/tmp/mid_0.jpg'},
    );

    final roundTrip = ScanProject.fromJson(project.toJson());

    expect(roundTrip.id, project.id);
    expect(roundTrip.name, project.name);
    expect(roundTrip.createdAt, project.createdAt);
    expect(roundTrip.posePhotos['mid_0'], '/tmp/mid_0.jpg');
  });

  test('ProjectsNotifier carga desde storage', () async {
    final storedProject = ScanProject(
      id: 'stored-1',
      name: 'Escaneo guardado',
      createdAt: DateTime.parse('2026-03-01T12:00:00.000Z'),
      posePhotos: const {},
    );
    final storage = FakeProjectStorage(initial: [storedProject]);
    final notifier = ProjectsNotifier(storage);

    await notifier.load();

    expect(notifier.state.length, 1);
    expect(notifier.state.first.id, 'stored-1');
  });

  test('ProjectsNotifier crea, actualiza y persiste fotos', () async {
    final storage = FakeProjectStorage();
    final notifier = ProjectsNotifier(storage);
    await notifier.load();

    final created = notifier.createNewProject();
    notifier.setPosePhoto(created.id, 'mid_0', '/app/captures/mid_0.jpg');
    notifier.removePosePhoto(created.id, 'mid_0');
    await Future<void>.delayed(Duration.zero);

    final persisted = storage.projects.first;
    expect(storage.writeCalls, greaterThanOrEqualTo(3));
    expect(persisted.id, created.id);
    expect(persisted.posePhotos, isEmpty);
  });

  test('ProjectsNotifier serializa escrituras y conserva el ultimo estado', () async {
    final storage = RaceyProjectStorage();
    final notifier = ProjectsNotifier(storage);
    await notifier.load();

    final created = notifier.createNewProject();
    notifier.setPosePhoto(created.id, 'mid_0', '/app/captures/mid_0.jpg');
    notifier.removePosePhoto(created.id, 'mid_0');
    await Future<void>.delayed(const Duration(milliseconds: 160));

    expect(storage.writeCalls, 3);
    expect(storage.projects, hasLength(1));
    expect(storage.projects.first.posePhotos, isEmpty);
  });
}
