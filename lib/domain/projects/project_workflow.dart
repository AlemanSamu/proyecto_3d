import 'project_model.dart';
import 'project_export_config.dart';
import 'project_processing.dart';

enum ProjectFlowStepId { project, capture, review, process, model, export }

enum ProjectFlowStepState { completed, current, pending, blocked, error }

enum ProjectPrimaryActionIntent {
  capture,
  review,
  process,
  models,
  export,
  troubleshoot,
}

class ProjectFlowStep {
  const ProjectFlowStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final ProjectFlowStepId id;
  final String title;
  final String subtitle;
  final ProjectFlowStepState state;
}

class ProjectReviewSummary {
  const ProjectReviewSummary({
    required this.accepted,
    required this.flagged,
    required this.pending,
    required this.missing,
  });

  final int accepted;
  final int flagged;
  final int pending;
  final int missing;
}

extension ProjectWorkflowX on ProjectModel {
  int get missingRecommendedPhotos {
    final missing = coverage.minRecommendedPhotos - coverage.acceptedPhotos;
    return missing.clamp(0, coverage.minRecommendedPhotos);
  }

  ProjectReviewSummary get reviewSummary {
    return ProjectReviewSummary(
      accepted: coverage.acceptedPhotos,
      flagged: coverage.flaggedForRetake,
      pending: coverage.pendingReviewPhotos.clamp(0, coverage.totalPhotos),
      missing: missingRecommendedPhotos,
    );
  }

  bool get canStartProcessing {
    return status == ProjectStatus.readyToProcess ||
        status == ProjectStatus.processing ||
        status == ProjectStatus.modelGenerated ||
        status == ProjectStatus.exported;
  }

  bool get hasGeneratedModel {
    return (modelPath ?? '').trim().isNotEmpty ||
        status == ProjectStatus.modelGenerated ||
        status == ProjectStatus.exported;
  }

  ProjectPrimaryActionIntent get primaryActionIntent {
    return switch (status) {
      ProjectStatus.draft => ProjectPrimaryActionIntent.capture,
      ProjectStatus.capturing => ProjectPrimaryActionIntent.capture,
      ProjectStatus.reviewReady => ProjectPrimaryActionIntent.review,
      ProjectStatus.readyToProcess => ProjectPrimaryActionIntent.process,
      ProjectStatus.processing => ProjectPrimaryActionIntent.process,
      ProjectStatus.modelGenerated => ProjectPrimaryActionIntent.models,
      ProjectStatus.exported => ProjectPrimaryActionIntent.export,
      ProjectStatus.error => ProjectPrimaryActionIntent.troubleshoot,
    };
  }

  String get primaryActionLabel {
    return switch (status) {
      ProjectStatus.draft => 'Comenzar captura',
      ProjectStatus.capturing => 'Continuar captura',
      ProjectStatus.reviewReady => 'Revisar capturas',
      ProjectStatus.readyToProcess => 'Configurar procesamiento',
      ProjectStatus.processing => 'Ver pipeline',
      ProjectStatus.modelGenerated => 'Abrir modelo',
      ProjectStatus.exported => 'Ver paquete exportado',
      ProjectStatus.error => 'Revisar error',
    };
  }

  String get primaryActionDescription {
    return switch (status) {
      ProjectStatus.draft =>
        'El proyecto esta listo para iniciar la captura guiada.',
      ProjectStatus.capturing =>
        'Captura las vistas sugeridas hasta alcanzar la cobertura minima.',
      ProjectStatus.reviewReady =>
        'Valida las capturas y marca retakes antes de procesar.',
      ProjectStatus.readyToProcess =>
        'Define calidad, destino y perfil antes de generar el modelo.',
      ProjectStatus.processing =>
        'El pipeline esta generando los artefactos del proyecto.',
      ProjectStatus.modelGenerated =>
        'El modelo ya fue generado y puede prepararse para exportacion.',
      ProjectStatus.exported =>
        'El paquete final ya esta listo para ser entregado o sincronizado.',
      ProjectStatus.error =>
        'Se detecto un problema en el pipeline del proyecto.',
    };
  }

  List<ProjectFlowStep> get workflowSteps {
    return [
      ProjectFlowStep(
        id: ProjectFlowStepId.project,
        title: 'Proyecto',
        subtitle: description.isEmpty
            ? 'Proyecto preparado para captura guiada'
            : description,
        state: ProjectFlowStepState.completed,
      ),
      ProjectFlowStep(
        id: ProjectFlowStepId.capture,
        title: 'Captura',
        subtitle: '${coverage.totalPhotos} tomas registradas',
        state: _captureStepState(),
      ),
      ProjectFlowStep(
        id: ProjectFlowStepId.review,
        title: 'Revision',
        subtitle:
            '${coverage.acceptedPhotos} aceptadas - ${coverage.flaggedForRetake} retake',
        state: _reviewStepState(),
      ),
      ProjectFlowStep(
        id: ProjectFlowStepId.process,
        title: 'Procesamiento',
        subtitle: _processingSubtitle(),
        state: _processStepState(),
      ),
      ProjectFlowStep(
        id: ProjectFlowStepId.model,
        title: 'Modelo',
        subtitle: hasGeneratedModel
            ? 'Artefacto local disponible'
            : 'Pendiente de generacion',
        state: _modelStepState(),
      ),
      ProjectFlowStep(
        id: ProjectFlowStepId.export,
        title: 'Exportacion',
        subtitle: (lastExportPackagePath ?? '').isEmpty
            ? 'Paquete aun no generado'
            : 'Paquete disponible para entrega',
        state: _exportStepState(),
      ),
    ];
  }

  ProjectFlowStepState _captureStepState() {
    if (status == ProjectStatus.error) return ProjectFlowStepState.error;
    if (coverage.totalPhotos == 0) return ProjectFlowStepState.current;
    if (status == ProjectStatus.draft || status == ProjectStatus.capturing) {
      return ProjectFlowStepState.current;
    }
    return ProjectFlowStepState.completed;
  }

  ProjectFlowStepState _reviewStepState() {
    if (status == ProjectStatus.error) return ProjectFlowStepState.error;
    if (coverage.totalPhotos == 0) {
      return ProjectFlowStepState.blocked;
    }
    if (status == ProjectStatus.reviewReady) {
      return ProjectFlowStepState.current;
    }
    if (status == ProjectStatus.readyToProcess ||
        status == ProjectStatus.processing ||
        status == ProjectStatus.modelGenerated ||
        status == ProjectStatus.exported) {
      return ProjectFlowStepState.completed;
    }
    return ProjectFlowStepState.pending;
  }

  ProjectFlowStepState _processStepState() {
    if (status == ProjectStatus.error ||
        processingState.stage == ProcessingStage.failed) {
      return ProjectFlowStepState.error;
    }
    if (status == ProjectStatus.processing ||
        processingState.isActive ||
        processingState.stage == ProcessingStage.completed) {
      return status == ProjectStatus.processing
          ? ProjectFlowStepState.current
          : ProjectFlowStepState.completed;
    }
    if (status == ProjectStatus.readyToProcess) {
      return ProjectFlowStepState.current;
    }
    if (coverage.acceptedPhotos == 0) return ProjectFlowStepState.blocked;
    return ProjectFlowStepState.pending;
  }

  ProjectFlowStepState _modelStepState() {
    if (status == ProjectStatus.error) return ProjectFlowStepState.error;
    if (hasGeneratedModel) return ProjectFlowStepState.completed;
    if (status == ProjectStatus.processing) return ProjectFlowStepState.pending;
    if (canStartProcessing) return ProjectFlowStepState.current;
    return ProjectFlowStepState.blocked;
  }

  ProjectFlowStepState _exportStepState() {
    if (status == ProjectStatus.error) return ProjectFlowStepState.error;
    if ((lastExportPackagePath ?? '').isNotEmpty ||
        status == ProjectStatus.exported) {
      return ProjectFlowStepState.completed;
    }
    if (hasGeneratedModel) return ProjectFlowStepState.current;
    if (canStartProcessing) return ProjectFlowStepState.pending;
    return ProjectFlowStepState.blocked;
  }

  String _processingSubtitle() {
    if (processingState.stage != ProcessingStage.idle) {
      return '${processingState.stage.label} - '
          '${(processingState.progress * 100).round()}%';
    }
    return '${processingConfig.profile.label} - '
        '${exportConfig.targetFormat.label}';
  }
}
