import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/data/projects/project_repository.dart';
import 'package:proyecto_3d/domain/projects/project_model.dart';
import 'package:proyecto_3d/presentation/providers/project_providers.dart';
import 'package:proyecto_3d/presentation/screens/capture/capture_screen.dart';

class InMemoryProjectRepository implements ProjectRepository {
  InMemoryProjectRepository({List<ProjectModel>? initial})
    : _projects = List<ProjectModel>.from(initial ?? const []);

  List<ProjectModel> _projects;

  @override
  Future<List<ProjectModel>> readProjects() async {
    return List<ProjectModel>.from(_projects);
  }

  @override
  Future<void> writeProjects(List<ProjectModel> projects) async {
    _projects = [
      for (final project in projects)
        project.copyWith(imagePaths: List<String>.from(project.imagePaths)),
    ];
  }

  List<ProjectModel> get projects => List<ProjectModel>.from(_projects);
}

Widget _buildApp(InMemoryProjectRepository repo) {
  return ProviderScope(
    overrides: [projectRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: CaptureScreen()),
  );
}

void main() {
  testWidgets('muestra secciones base del modulo de captura', (tester) async {
    final repo = InMemoryProjectRepository();
    await tester.pumpWidget(_buildApp(repo));
    await tester.pump();

    expect(find.text('Modulo de captura'), findsOneWidget);
    expect(find.text('Guia rapida'), findsOneWidget);
    expect(find.text('Asistencia en vivo'), findsOneWidget);
    expect(find.text('Proyecto activo'), findsOneWidget);
  });

  testWidgets('permite crear proyecto y dejarlo activo', (tester) async {
    final repo = InMemoryProjectRepository();
    await tester.pumpWidget(_buildApp(repo));
    await tester.pump();

    await tester.tap(find.text('Nuevo proyecto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Nombre del proyecto'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Mesa prueba');
    await tester.tap(find.text('Crear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Seleccionar proyecto'), findsOneWidget);
    expect(find.textContaining('Mesa prueba'), findsWidgets);
    expect(find.textContaining('estado: capturing'), findsOneWidget);
  });

  testWidgets('muestra proyecto existente y acciones principales', (
    tester,
  ) async {
    final project = ProjectModel(
      id: 'project-1',
      name: 'Escaneo demo',
      createdAt: DateTime.parse('2026-03-03T12:00:00.000Z'),
      imagePaths: const ['C:/no-existe/c1.jpg'],
      modelPath: null,
      status: ProjectStatus.capturing,
    );
    final repo = InMemoryProjectRepository(initial: [project]);

    await tester.pumpWidget(_buildApp(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Seleccionar proyecto'), findsOneWidget);
    expect(find.textContaining('estado: capturing'), findsOneWidget);
  });
}
