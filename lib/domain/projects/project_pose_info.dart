class ProjectPoseInfo {
  const ProjectPoseInfo({
    required this.poseId,
    required this.captureCount,
    this.lastCapturedAt,
  });

  final String poseId;
  final int captureCount;
  final DateTime? lastCapturedAt;

  ProjectPoseInfo copyWith({
    int? captureCount,
    DateTime? lastCapturedAt,
    bool clearLastCapturedAt = false,
  }) {
    return ProjectPoseInfo(
      poseId: poseId,
      captureCount: captureCount ?? this.captureCount,
      lastCapturedAt: clearLastCapturedAt
          ? null
          : (lastCapturedAt ?? this.lastCapturedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poseId': poseId,
      'captureCount': captureCount,
      'lastCapturedAt': lastCapturedAt?.toIso8601String(),
    };
  }

  factory ProjectPoseInfo.fromJson(Map<String, dynamic> json) {
    return ProjectPoseInfo(
      poseId: json['poseId'] as String? ?? '',
      captureCount: json['captureCount'] as int? ?? 0,
      lastCapturedAt: DateTime.tryParse(
        json['lastCapturedAt'] as String? ?? '',
      ),
    );
  }
}
