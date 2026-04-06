import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/presentation/screens/export_workbench_screen.dart';
import 'package:proyecto_3d/presentation/screens/model_viewer_screen.dart';
import 'package:proyecto_3d/presentation/screens/project_workspace_screen.dart';
import 'package:proyecto_3d/presentation/screens/projects/export_configuration_screen.dart';
import 'package:proyecto_3d/presentation/screens/projects/projects_screen.dart';

Future<void> _noopOpenProject(String projectId) async {}

void main() {
  test('las pantallas principales compilan', () {
    final projectsScreen = ProjectsScreen(onOpenProject: _noopOpenProject);
    const workspaceScreen = ProjectWorkspaceScreen(projectId: 'project-1');
    const workbenchScreen = ExportWorkbenchScreen(projectId: 'project-1');
    const legacyScreen = ExportConfigurationScreen(projectId: 'project-1');
    const viewerScreen = ModelViewerScreen(projectId: 'project-1');

    expect(projectsScreen, isNotNull);
    expect(workspaceScreen, isNotNull);
    expect(workbenchScreen, isNotNull);
    expect(legacyScreen, isNotNull);
    expect(viewerScreen, isNotNull);
  });
}