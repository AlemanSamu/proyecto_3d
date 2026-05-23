import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/presentation/screens/export_workbench_screen.dart';
import 'package:proyecto_3d/presentation/screens/model_viewer_screen.dart';
import 'package:proyecto_3d/presentation/screens/project_workspace_screen.dart';
import 'package:proyecto_3d/presentation/screens/projects_hub_screen.dart';

void main() {
  test('las pantallas principales compilan', () {
    const projectsScreen = ProjectsHubScreen();
    const workspaceScreen = ProjectWorkspaceScreen(projectId: 'project-1');
    const workbenchScreen = ExportWorkbenchScreen(projectId: 'project-1');
    const viewerScreen = ModelViewerScreen(projectId: 'project-1');

    expect(projectsScreen, isNotNull);
    expect(workspaceScreen, isNotNull);
    expect(workbenchScreen, isNotNull);
    expect(viewerScreen, isNotNull);
  });
}
