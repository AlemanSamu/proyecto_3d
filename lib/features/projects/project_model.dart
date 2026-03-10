class ScanProject {
  final String id;
  final String name;
  final DateTime createdAt;

  /// Mapa: poseId -> path de la foto tomada para esa pose
  final Map<String, String> posePhotos;

  const ScanProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.posePhotos,
  });

  int get photoCount => posePhotos.length;

  ScanProject copyWith({String? name, Map<String, String>? posePhotos}) {
    return ScanProject(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      posePhotos: posePhotos ?? this.posePhotos,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'posePhotos': posePhotos,
    };
  }

  factory ScanProject.fromJson(Map<String, dynamic> json) {
    final rawPosePhotos = json['posePhotos'];
    final posePhotos = <String, String>{};

    if (rawPosePhotos is Map) {
      for (final entry in rawPosePhotos.entries) {
        if (entry.key is String && entry.value is String) {
          posePhotos[entry.key as String] = entry.value as String;
        }
      }
    }

    return ScanProject(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Escaneo',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      posePhotos: posePhotos,
    );
  }
}
