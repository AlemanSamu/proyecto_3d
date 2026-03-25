class CapturePhoto {
  CapturePhoto({
    required this.id,
    required this.originalPath,
    required this.thumbnailPath,
    this.poseId,
    this.angleDeg,
    this.level,
    required this.brightness,
    required this.sharpness,
    required this.accepted,
    required this.flaggedForRetake,
    required this.createdAt,
  });

  final String id;
  final String originalPath;
  final String thumbnailPath;
  final String? poseId;
  final int? angleDeg;
  final String? level;
  final double brightness;
  final double sharpness;
  final bool accepted;
  final bool flaggedForRetake;
  final DateTime createdAt;

  bool get hasPose => poseId != null && poseId!.isNotEmpty;

  CapturePhoto copyWith({
    String? originalPath,
    String? thumbnailPath,
    String? poseId,
    bool clearPoseId = false,
    int? angleDeg,
    bool clearAngleDeg = false,
    String? level,
    bool clearLevel = false,
    double? brightness,
    double? sharpness,
    bool? accepted,
    bool? flaggedForRetake,
    DateTime? createdAt,
  }) {
    return CapturePhoto(
      id: id,
      originalPath: originalPath ?? this.originalPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      poseId: clearPoseId ? null : (poseId ?? this.poseId),
      angleDeg: clearAngleDeg ? null : (angleDeg ?? this.angleDeg),
      level: clearLevel ? null : (level ?? this.level),
      brightness: brightness ?? this.brightness,
      sharpness: sharpness ?? this.sharpness,
      accepted: accepted ?? this.accepted,
      flaggedForRetake: flaggedForRetake ?? this.flaggedForRetake,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalPath': originalPath,
      'thumbnailPath': thumbnailPath,
      'poseId': poseId,
      'angleDeg': angleDeg,
      'level': level,
      'brightness': brightness,
      'sharpness': sharpness,
      'accepted': accepted,
      'flaggedForRetake': flaggedForRetake,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CapturePhoto.fromJson(Map<String, dynamic> json) {
    final originalPath = json['originalPath'] as String? ?? '';
    return CapturePhoto(
      id: json['id'] as String? ?? '',
      originalPath: originalPath,
      thumbnailPath:
          json['thumbnailPath'] as String? ??
          defaultThumbnailPath(originalPath),
      poseId: json['poseId'] as String?,
      angleDeg: _asInt(json['angleDeg']),
      level: json['level'] as String?,
      brightness: _asDouble(json['brightness']),
      sharpness: _asDouble(json['sharpness']),
      accepted: json['accepted'] as bool? ?? true,
      flaggedForRetake: json['flaggedForRetake'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static CapturePhoto legacy({
    required String id,
    required String originalPath,
    required DateTime createdAt,
  }) {
    return CapturePhoto(
      id: id,
      originalPath: originalPath,
      thumbnailPath: defaultThumbnailPath(originalPath),
      brightness: 0,
      sharpness: 0,
      accepted: true,
      flaggedForRetake: false,
      createdAt: createdAt,
    );
  }

  static String defaultThumbnailPath(String originalPath) {
    final dot = originalPath.lastIndexOf('.');
    final base = dot <= 0 ? originalPath : originalPath.substring(0, dot);
    return '${base}_thumb.jpg';
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
