import '../../data/projects/project_model_builder.dart';
import '../../data/projects/project_export_packager.dart';
import '../../domain/projects/project_model.dart';
import '../../domain/projects/project_processing.dart';

typedef ProjectStatusUpdater =
    void Function(String projectId, ProjectStatus status);
typedef ExportPackagePathUpdater =
    void Function(String projectId, String? packagePath);
typedef ProcessingStateUpdater =
    void Function(String projectId, ProjectProcessingState state);
typedef ModelPathUpdater = void Function(String projectId, String? modelPath);

class ProjectProcessingResult {
  const ProjectProcessingResult._({
    required this.success,
    this.message,
    this.model,
  });

  final bool success;
  final String? message;
  final ProjectGeneratedModel? model;

  factory ProjectProcessingResult.success(ProjectGeneratedModel model) {
    return ProjectProcessingResult._(
      success: true,
      message: 'Modelo generado correctamente.',
      model: model,
    );
  }

  factory ProjectProcessingResult.failure(String message) {
    return ProjectProcessingResult._(success: false, message: message);
  }
}

class ProjectExportResult {
  const ProjectExportResult._({
    required this.success,
    this.message,
    this.package,
  });

  final bool success;
  final String? message;
  final ProjectExportPackage? package;

  factory ProjectExportResult.success(ProjectExportPackage package) {
    return ProjectExportResult._(
      success: true,
      message: 'Paquete de exportacion listo.',
      package: package,
    );
  }

  factory ProjectExportResult.failure(String message) {
    return ProjectExportResult._(success: false, message: message);
  }
}

class ProjectExportController {
  ProjectExportController({
    required ProjectModelBuilder modelBuilder,
    required ProjectExportPackager packager,
    required ProjectStatusUpdater updateStatus,
    required ProcessingStateUpdater updateProcessingState,
    required ModelPathUpdater setModelPath,
    required ExportPackagePathUpdater setLastExportPackagePath,
  }) : _modelBuilder = modelBuilder,
       _packager = packager,
       _updateStatus = updateStatus,
       _updateProcessingState = updateProcessingState,
       _setModelPath = setModelPath,
       _setLastExportPackagePath = setLastExportPackagePath;

  final ProjectModelBuilder _modelBuilder;
  final ProjectExportPackager _packager;
  final ProjectStatusUpdater _updateStatus;
  final ProcessingStateUpdater _updateProcessingState;
  final ModelPathUpdater _setModelPath;
  final ExportPackagePathUpdater _setLastExportPackagePath;

  Future<ProjectProcessingResult> processProject(ProjectModel project) async {
    _updateStatus(project.id, ProjectStatus.processing);
    _updateProcessingState(
      project.id,
      ProjectProcessingState(
        stage: ProcessingStage.queued,
        progress: 0.08,
        message: 'Proyecto agregado a la cola local',
        updatedAt: DateTime.now(),
      ),
    );

    try {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: ProcessingStage.preparing,
          progress: 0.22,
          message: 'Preparando capturas y metadatos',
          updatedAt: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 220));
      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: ProcessingStage.reconstructing,
          progress: 0.56,
          message: 'Generando reconstruccion inicial',
          updatedAt: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 220));
      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: ProcessingStage.texturing,
          progress: 0.84,
          message: 'Aplicando configuracion de texturas',
          updatedAt: DateTime.now(),
        ),
      );

      final model = await _modelBuilder.buildModel(project);
      _setModelPath(project.id, model.modelPath);
      _updateStatus(project.id, ProjectStatus.modelGenerated);
      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: ProcessingStage.completed,
          progress: 1,
          message: 'Modelo local disponible',
          updatedAt: DateTime.now(),
        ),
      );
      return ProjectProcessingResult.success(model);
    } catch (_) {
      _updateStatus(project.id, ProjectStatus.error);
      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: ProcessingStage.failed,
          progress: 0,
          message: 'No se pudo generar el modelo local',
          updatedAt: DateTime.now(),
        ),
      );
      return ProjectProcessingResult.failure(
        'No se pudo completar el procesamiento del proyecto.',
      );
    }
  }

  Future<ProjectExportResult> exportProject(ProjectModel project) async {
    _updateStatus(project.id, ProjectStatus.processing);
    _updateProcessingState(
      project.id,
      ProjectProcessingState(
        stage: ProcessingStage.packaging,
        progress: 0.35,
        message: 'Empaquetando capturas para exportacion',
        updatedAt: DateTime.now(),
      ),
    );

    try {
      final package = await _packager.buildPackage(project);
      _setLastExportPackagePath(project.id, package.packagePath);
      _updateStatus(project.id, ProjectStatus.exported);
      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: ProcessingStage.completed,
          progress: 1,
          message: 'Exportacion completada',
          updatedAt: DateTime.now(),
        ),
      );
      return ProjectExportResult.success(package);
    } catch (_) {
      _updateStatus(project.id, ProjectStatus.error);
      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: ProcessingStage.failed,
          progress: 0,
          message: 'No se pudo generar el paquete de exportacion',
          updatedAt: DateTime.now(),
        ),
      );
      return ProjectExportResult.failure(
        'No se pudo generar el paquete de exportacion.',
      );
    }
  }
}
