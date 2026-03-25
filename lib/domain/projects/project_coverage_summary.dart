import '../capture/capture_photo.dart';

class ProjectCoverageSummary {
  const ProjectCoverageSummary({
    required this.totalPhotos,
    required this.acceptedPhotos,
    required this.flaggedForRetake,
    required this.uniqueAngles,
    required this.uniqueLevels,
    required this.minRecommendedPhotos,
    required this.completion,
  });

  static const empty = ProjectCoverageSummary(
    totalPhotos: 0,
    acceptedPhotos: 0,
    flaggedForRetake: 0,
    uniqueAngles: 0,
    uniqueLevels: 0,
    minRecommendedPhotos: 24,
    completion: 0,
  );

  final int totalPhotos;
  final int acceptedPhotos;
  final int flaggedForRetake;
  final int uniqueAngles;
  final int uniqueLevels;
  final int minRecommendedPhotos;
  final double completion;

  int get pendingReviewPhotos => totalPhotos - acceptedPhotos;
  bool get hasMinimumCoverage => acceptedPhotos >= minRecommendedPhotos;

  ProjectCoverageSummary copyWith({
    int? totalPhotos,
    int? acceptedPhotos,
    int? flaggedForRetake,
    int? uniqueAngles,
    int? uniqueLevels,
    int? minRecommendedPhotos,
    double? completion,
  }) {
    return ProjectCoverageSummary(
      totalPhotos: totalPhotos ?? this.totalPhotos,
      acceptedPhotos: acceptedPhotos ?? this.acceptedPhotos,
      flaggedForRetake: flaggedForRetake ?? this.flaggedForRetake,
      uniqueAngles: uniqueAngles ?? this.uniqueAngles,
      uniqueLevels: uniqueLevels ?? this.uniqueLevels,
      minRecommendedPhotos: minRecommendedPhotos ?? this.minRecommendedPhotos,
      completion: completion ?? this.completion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalPhotos': totalPhotos,
      'acceptedPhotos': acceptedPhotos,
      'flaggedForRetake': flaggedForRetake,
      'uniqueAngles': uniqueAngles,
      'uniqueLevels': uniqueLevels,
      'minRecommendedPhotos': minRecommendedPhotos,
      'completion': completion,
    };
  }

  factory ProjectCoverageSummary.fromJson(Map<String, dynamic> json) {
    return ProjectCoverageSummary(
      totalPhotos: json['totalPhotos'] as int? ?? 0,
      acceptedPhotos: json['acceptedPhotos'] as int? ?? 0,
      flaggedForRetake: json['flaggedForRetake'] as int? ?? 0,
      uniqueAngles: json['uniqueAngles'] as int? ?? 0,
      uniqueLevels: json['uniqueLevels'] as int? ?? 0,
      minRecommendedPhotos: json['minRecommendedPhotos'] as int? ?? 24,
      completion: _asDouble(json['completion']),
    );
  }

  factory ProjectCoverageSummary.fromPhotos(
    List<CapturePhoto> photos, {
    int minRecommendedPhotos = 24,
  }) {
    final accepted = photos.where((photo) => photo.accepted).length;
    final flagged = photos.where((photo) => photo.flaggedForRetake).length;
    final angles = <int>{
      for (final photo in photos)
        if (photo.angleDeg != null) photo.angleDeg!,
    };
    final levels = <String>{
      for (final photo in photos)
        if (photo.level != null && photo.level!.isNotEmpty) photo.level!,
    };

    final completion = photos.isEmpty
        ? 0.0
        : (accepted / minRecommendedPhotos).clamp(0.0, 1.0);

    return ProjectCoverageSummary(
      totalPhotos: photos.length,
      acceptedPhotos: accepted,
      flaggedForRetake: flagged,
      uniqueAngles: angles.length,
      uniqueLevels: levels.length,
      minRecommendedPhotos: minRecommendedPhotos,
      completion: completion,
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
