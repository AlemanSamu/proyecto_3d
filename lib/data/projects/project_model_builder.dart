import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/projects/project_export_config.dart';
import '../../domain/projects/project_model.dart';

class ProjectGeneratedModel {
  const ProjectGeneratedModel({
    required this.modelPath,
    required this.createdAt,
    required this.format,
  });

  final String modelPath;
  final DateTime createdAt;
  final String format;
}

abstract class ProjectModelBuilder {
  Future<ProjectGeneratedModel> buildModel(ProjectModel project);
}

class LocalStubProjectModelBuilder implements ProjectModelBuilder {
  @override
  Future<ProjectGeneratedModel> buildModel(ProjectModel project) async {
    final now = DateTime.now();
    final docs = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(
      '${docs.path}${Platform.pathSeparator}generated_models'
      '${Platform.pathSeparator}${project.id}',
    );
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final format = project.exportConfig.targetFormat.label.toLowerCase();
    final file = File(
      '${modelsDir.path}${Platform.pathSeparator}'
      'model_${now.millisecondsSinceEpoch}.$format.json',
    );

    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'kind': 'placeholder_generated_model',
      'generatedAt': now.toIso8601String(),
      'projectId': project.id,
      'projectName': project.name,
      'targetFormat': project.exportConfig.targetFormat.value,
      'qualityPreset': project.exportConfig.qualityPreset.value,
      'textureQuality': project.exportConfig.textureQuality.value,
      'geometryQuality': project.exportConfig.geometryQuality.value,
      'captureCount': project.photos.length,
      'acceptedCaptures': project.coverage.acceptedPhotos,
      'notes':
          'Artefacto local generado como placeholder para la pantalla '
          'de modelos y futuras integraciones de visor.',
    };

    await file.writeAsString(jsonEncode(payload), flush: true);
    return ProjectGeneratedModel(
      modelPath: file.path,
      createdAt: now,
      format: project.exportConfig.targetFormat.label,
    );
  }
}
