import '../../domain/projects/project_model.dart';

abstract class ProjectRepository {
  Future<List<ProjectModel>> readProjects();
  Future<void> writeProjects(List<ProjectModel> projects);
}
