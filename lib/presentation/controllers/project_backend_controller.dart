import '../../data/services/backend_api_exception.dart';
import '../../data/services/local_backend_api_service.dart';
import '../../domain/projects/backend_processing_status.dart';
import '../../domain/projects/project_export_config.dart';
import '../../domain/projects/project_model.dart';
import '../../domain/projects/project_processing.dart';
import 'project_export_controller.dart';

typedef RemoteProjectIdUpdater =
    void Function(String projectId, String? remoteProjectId);
typedef RemoteSyncStateUpdater =
    void Function(
      String projectId, {
      String? remoteStatus,
      bool clearRemoteStatus,
      String? remoteModelUrl,
      bool clearRemoteModelUrl,
      String? remoteErrorMessage,
      bool clearRemoteErrorMessage,
    });

class BackendSubmissionResult {
  const BackendSubmissionResult._({
    required this.success,
    required this.message,
    this.remoteProjectId,
  });

  final bool success;
  final String message;
  final String? remoteProjectId;

  factory BackendSubmissionResult.success({
    required String remoteProjectId,
    String message = 'Procesamiento remoto iniciado.',
  }) {
    return BackendSubmissionResult._(
      success: true,
      message: message,
      remoteProjectId: remoteProjectId,
    );
  }

  factory BackendSubmissionResult.failure(String message) {
    return BackendSubmissionResult._(success: false, message: message);
  }
}

class BackendStatusResult {
  const BackendStatusResult._({
    required this.success,
    required this.message,
    this.status,
    this.modelPath,
  });

  final bool success;
  final String message;
  final BackendProcessingStatus? status;
  final String? modelPath;

  bool get isCompleted => status?.isCompleted == true;
  bool get isFailed => status?.isFailed == true;

  factory BackendStatusResult.success({
    required BackendProcessingStatus status,
    String? modelPath,
  }) {
    return BackendStatusResult._(
      success: true,
      message: status.message,
      status: status,
      modelPath: modelPath,
    );
  }

  factory BackendStatusResult.failure(String message) {
    return BackendStatusResult._(success: false, message: message);
  }
}

class ProjectBackendController {
  ProjectBackendController({
    required LocalBackendApiService apiService,
    required ProjectStatusUpdater updateStatus,
    required ProcessingStateUpdater updateProcessingState,
    required ModelPathUpdater setModelPath,
    required RemoteProjectIdUpdater setRemoteProjectId,
    required RemoteSyncStateUpdater updateRemoteSyncState,
  }) : _apiService = apiService,
       _updateStatus = updateStatus,
       _updateProcessingState = updateProcessingState,
       _setModelPath = setModelPath,
       _setRemoteProjectId = setRemoteProjectId,
       _updateRemoteSyncState = updateRemoteSyncState;

  final LocalBackendApiService _apiService;
  final ProjectStatusUpdater _updateStatus;
  final ProcessingStateUpdater _updateProcessingState;
  final ModelPathUpdater _setModelPath;
  final RemoteProjectIdUpdater _setRemoteProjectId;
  final RemoteSyncStateUpdater _updateRemoteSyncState;

  Future<BackendSubmissionResult> submitForProcessing(
    ProjectModel project, {
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    if (project.photos.isEmpty) {
      return BackendSubmissionResult.failure(
        'No hay imagenes para subir al backend.',
      );
    }

    _updateStatus(project.id, ProjectStatus.processing);
    _updateRemoteSyncState(
      project.id,
      clearRemoteErrorMessage: true,
      clearRemoteStatus: false,
      clearRemoteModelUrl: false,
    );
    _updateProcessingState(
      project.id,
      ProjectProcessingState(
        stage: ProcessingStage.queued,
        progress: 0.06,
        message: 'Preparando proyecto remoto...',
        updatedAt: DateTime.now(),
      ),
    );

    try {
      final remoteId =
          project.remoteProjectId ??
          await _apiService.createProject(
            localProjectId: project.id,
            name: project.name,
            description: project.description,
            exportConfig: project.exportConfig,
            processingConfig: project.processingConfig,
          );
      _setRemoteProjectId(project.id, remoteId);

      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: ProcessingStage.preparing,
          progress: 0.18,
          message: 'Subiendo imagenes al backend...',
          updatedAt: DateTime.now(),
        ),
      );

      await _apiService.uploadImages(
        remoteProjectId: remoteId,
        imagePaths: project.imagePaths,
        onProgress: (sent, total) {
          final ratio = total == 0 ? 0 : (sent / total).clamp(0, 1).toDouble();
          final progress = 0.18 + (ratio * 0.4);
          _updateProcessingState(
            project.id,
            ProjectProcessingState(
              stage: ProcessingStage.preparing,
              progress: progress,
              message: 'Subiendo imagenes ($sent/$total)',
              updatedAt: DateTime.now(),
            ),
          );
          onUploadProgress?.call(sent, total);
        },
      );

      await _apiService.startProcessing(
        remoteProjectId: remoteId,
        exportConfig: project.exportConfig,
        processingConfig: project.processingConfig,
      );

      _updateRemoteSyncState(
        project.id,
        remoteStatus: 'processing',
        clearRemoteErrorMessage: true,
        clearRemoteModelUrl: false,
      );
      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: ProcessingStage.reconstructing,
          progress: 0.62,
          message: 'Procesamiento remoto iniciado.',
          updatedAt: DateTime.now(),
        ),
      );

      return BackendSubmissionResult.success(
        remoteProjectId: remoteId,
        message: 'Imagenes enviadas. El backend inicio el procesamiento.',
      );
    } on BackendApiException catch (error) {
      _applySubmissionFailure(project.id, error.message);
      return BackendSubmissionResult.failure(error.message);
    } catch (_) {
      const message = 'No se pudo iniciar el procesamiento remoto.';
      _applySubmissionFailure(project.id, message);
      return BackendSubmissionResult.failure(message);
    }
  }

  Future<BackendStatusResult> refreshStatus(ProjectModel project) async {
    final remoteProjectId = project.remoteProjectId;
    if (remoteProjectId == null || remoteProjectId.trim().isEmpty) {
      return BackendStatusResult.failure(
        'El proyecto no tiene id remoto asociado.',
      );
    }

    try {
      final status = await _apiService.fetchStatus(
        remoteProjectId: remoteProjectId,
      );

      _updateRemoteSyncState(
        project.id,
        remoteStatus: status.rawStatus,
        remoteModelUrl: status.modelUrl,
        clearRemoteErrorMessage: true,
        clearRemoteModelUrl: status.modelUrl == null,
      );
      _updateProcessingState(
        project.id,
        ProjectProcessingState(
          stage: status.stage,
          progress: status.isCompleted
              ? 1
              : status.progress.clamp(0, 1).toDouble(),
          message: status.message,
          updatedAt: DateTime.now(),
        ),
      );

      if (status.isFailed) {
        _updateStatus(project.id, ProjectStatus.error);
        _updateRemoteSyncState(
          project.id,
          remoteErrorMessage: status.message,
          clearRemoteStatus: false,
          clearRemoteModelUrl: false,
          clearRemoteErrorMessage: false,
        );
        return BackendStatusResult.success(status: status);
      }

      if (!status.isCompleted) {
        _updateStatus(project.id, ProjectStatus.processing);
        return BackendStatusResult.success(status: status);
      }

      final modelPath = await _apiService.downloadModelToProject(
        remoteProjectId: remoteProjectId,
        localProjectId: project.id,
        preferredFormat: project.exportConfig.targetFormat.value,
        preferredModelUrl: status.modelUrl,
      );
      _setModelPath(project.id, modelPath);
      _updateStatus(project.id, ProjectStatus.modelGenerated);

      return BackendStatusResult.success(status: status, modelPath: modelPath);
    } on BackendApiException catch (error) {
      _updateRemoteSyncState(
        project.id,
        remoteErrorMessage: error.message,
        clearRemoteStatus: false,
        clearRemoteModelUrl: false,
        clearRemoteErrorMessage: false,
      );
      return BackendStatusResult.failure(error.message);
    } catch (_) {
      const message = 'No se pudo consultar el estado remoto.';
      _updateRemoteSyncState(
        project.id,
        remoteErrorMessage: message,
        clearRemoteStatus: false,
        clearRemoteModelUrl: false,
        clearRemoteErrorMessage: false,
      );
      return BackendStatusResult.failure(message);
    }
  }

  void _applySubmissionFailure(String projectId, String message) {
    _updateStatus(projectId, ProjectStatus.error);
    _updateProcessingState(
      projectId,
      ProjectProcessingState(
        stage: ProcessingStage.failed,
        progress: 0,
        message: message,
        updatedAt: DateTime.now(),
      ),
    );
    _updateRemoteSyncState(
      projectId,
      remoteErrorMessage: message,
      clearRemoteStatus: false,
      clearRemoteModelUrl: false,
      clearRemoteErrorMessage: false,
    );
  }
}
