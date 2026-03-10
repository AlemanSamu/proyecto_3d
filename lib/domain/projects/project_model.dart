enum ProjectStatus { capturing, processing, done, error }

extension ProjectStatusX on ProjectStatus {
  String get label => switch (this) {
    ProjectStatus.capturing => 'capturing',
    ProjectStatus.processing => 'processing',
    ProjectStatus.done => 'done',
    ProjectStatus.error => 'error',
  };

  static ProjectStatus fromValue(String? value) {
    return switch (value) {
      'capturing' => ProjectStatus.capturing,
      'processing' => ProjectStatus.processing,
      'done' => ProjectStatus.done,
      'error' => ProjectStatus.error,
      _ => ProjectStatus.capturing,
    };
  }
}

class ProjectModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<String> imagePaths;
  final String? modelPath;
  final ProjectStatus status;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.imagePaths,
    required this.modelPath,
    required this.status,
  });

  ProjectModel copyWith({
    String? name,
    List<String>? imagePaths,
    String? modelPath,
    bool clearModelPath = false,
    ProjectStatus? status,
  }) {
    return ProjectModel(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      imagePaths: imagePaths ?? this.imagePaths,
      modelPath: clearModelPath ? null : (modelPath ?? this.modelPath),
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'imagePaths': imagePaths,
      'modelPath': modelPath,
      'status': status.label,
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final imagePaths = <String>[];
    final rawPaths = json['imagePaths'];
    if (rawPaths is List) {
      for (final path in rawPaths) {
        if (path is String && path.isNotEmpty) imagePaths.add(path);
      }
    }

    return ProjectModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Proyecto',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      imagePaths: imagePaths,
      modelPath: json['modelPath'] as String?,
      status: ProjectStatusX.fromValue(json['status'] as String?),
    );
  }
}
