enum ProcessingProfile { fastPreview, balanced, highFidelity }

extension ProcessingProfileX on ProcessingProfile {
  String get value => switch (this) {
    ProcessingProfile.fastPreview => 'fastPreview',
    ProcessingProfile.balanced => 'balanced',
    ProcessingProfile.highFidelity => 'highFidelity',
  };

  String get label => switch (this) {
    ProcessingProfile.fastPreview => 'Vista previa rapida',
    ProcessingProfile.balanced => 'Balanceado',
    ProcessingProfile.highFidelity => 'Alta fidelidad',
  };

  static ProcessingProfile fromValue(String? value) {
    return switch (value) {
      'fastPreview' => ProcessingProfile.fastPreview,
      'highFidelity' => ProcessingProfile.highFidelity,
      _ => ProcessingProfile.balanced,
    };
  }
}

enum ProcessingStage {
  idle,
  queued,
  preparing,
  reconstructing,
  texturing,
  packaging,
  completed,
  failed,
}

extension ProcessingStageX on ProcessingStage {
  String get value => switch (this) {
    ProcessingStage.idle => 'idle',
    ProcessingStage.queued => 'queued',
    ProcessingStage.preparing => 'preparing',
    ProcessingStage.reconstructing => 'reconstructing',
    ProcessingStage.texturing => 'texturing',
    ProcessingStage.packaging => 'packaging',
    ProcessingStage.completed => 'completed',
    ProcessingStage.failed => 'failed',
  };

  String get label => switch (this) {
    ProcessingStage.idle => 'Sin iniciar',
    ProcessingStage.queued => 'En cola',
    ProcessingStage.preparing => 'Preparando datos',
    ProcessingStage.reconstructing => 'Reconstruyendo geometria',
    ProcessingStage.texturing => 'Generando texturas',
    ProcessingStage.packaging => 'Empaquetando salida',
    ProcessingStage.completed => 'Completado',
    ProcessingStage.failed => 'Error',
  };

  static ProcessingStage fromValue(String? value) {
    return switch (value) {
      'queued' => ProcessingStage.queued,
      'preparing' => ProcessingStage.preparing,
      'reconstructing' => ProcessingStage.reconstructing,
      'texturing' => ProcessingStage.texturing,
      'packaging' => ProcessingStage.packaging,
      'completed' => ProcessingStage.completed,
      'failed' => ProcessingStage.failed,
      _ => ProcessingStage.idle,
    };
  }
}

class ProjectProcessingConfig {
  const ProjectProcessingConfig({
    this.profile = ProcessingProfile.balanced,
    this.removeBackground = false,
    this.removeFloatingArtifacts = true,
    this.generatePbrTextures = true,
    this.optimizeForMobile = true,
  });

  final ProcessingProfile profile;
  final bool removeBackground;
  final bool removeFloatingArtifacts;
  final bool generatePbrTextures;
  final bool optimizeForMobile;

  ProjectProcessingConfig copyWith({
    ProcessingProfile? profile,
    bool? removeBackground,
    bool? removeFloatingArtifacts,
    bool? generatePbrTextures,
    bool? optimizeForMobile,
  }) {
    return ProjectProcessingConfig(
      profile: profile ?? this.profile,
      removeBackground: removeBackground ?? this.removeBackground,
      removeFloatingArtifacts:
          removeFloatingArtifacts ?? this.removeFloatingArtifacts,
      generatePbrTextures: generatePbrTextures ?? this.generatePbrTextures,
      optimizeForMobile: optimizeForMobile ?? this.optimizeForMobile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.value,
      'removeBackground': removeBackground,
      'removeFloatingArtifacts': removeFloatingArtifacts,
      'generatePbrTextures': generatePbrTextures,
      'optimizeForMobile': optimizeForMobile,
    };
  }

  factory ProjectProcessingConfig.fromJson(Map<String, dynamic> json) {
    return ProjectProcessingConfig(
      profile: ProcessingProfileX.fromValue(json['profile'] as String?),
      removeBackground: json['removeBackground'] as bool? ?? false,
      removeFloatingArtifacts: json['removeFloatingArtifacts'] as bool? ?? true,
      generatePbrTextures: json['generatePbrTextures'] as bool? ?? true,
      optimizeForMobile: json['optimizeForMobile'] as bool? ?? true,
    );
  }
}

class ProjectProcessingState {
  ProjectProcessingState({
    this.stage = ProcessingStage.idle,
    this.progress = 0,
    this.message = 'Pendiente',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final ProcessingStage stage;
  final double progress;
  final String message;
  final DateTime updatedAt;

  bool get isActive {
    return stage == ProcessingStage.queued ||
        stage == ProcessingStage.preparing ||
        stage == ProcessingStage.reconstructing ||
        stage == ProcessingStage.texturing ||
        stage == ProcessingStage.packaging;
  }

  ProjectProcessingState copyWith({
    ProcessingStage? stage,
    double? progress,
    String? message,
    DateTime? updatedAt,
  }) {
    return ProjectProcessingState(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage': stage.value,
      'progress': progress,
      'message': message,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProjectProcessingState.fromJson(Map<String, dynamic> json) {
    return ProjectProcessingState(
      stage: ProcessingStageX.fromValue(json['stage'] as String?),
      progress: _parseDouble(json['progress']).clamp(0.0, 1.0).toDouble(),
      message: json['message'] as String? ?? 'Pendiente',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static double _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
