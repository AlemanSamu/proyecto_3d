import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/projects/project_model.dart';
import 'project_repository.dart';

const _projectsFileName = 'projects_v2.json';

class LocalProjectRepository implements ProjectRepository {
  @override
  Future<List<ProjectModel>> readProjects() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return const [];

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final projects = <ProjectModel>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final project = ProjectModel.fromJson(entry);
          if (project.id.isNotEmpty) projects.add(project);
          continue;
        }

        if (entry is Map) {
          final project = ProjectModel.fromJson(
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
  Future<void> writeProjects(List<ProjectModel> projects) async {
    final file = await _resolveFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final payload = jsonEncode([
      for (final project in projects) project.toJson(),
    ]);
    await file.writeAsString(payload);
  }

  Future<File> _resolveFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}${Platform.pathSeparator}$_projectsFileName');
  }
}
