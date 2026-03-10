import 'dart:math';

enum CaptureLevel { high, mid, low }

extension CaptureLevelX on CaptureLevel {
  String get label => switch (this) {
    CaptureLevel.high => 'Alta',
    CaptureLevel.mid => 'Media',
    CaptureLevel.low => 'Baja',
  };

  double get yFactor => switch (this) {
    CaptureLevel.high => -0.42,
    CaptureLevel.mid => 0.0,
    CaptureLevel.low => 0.42,
  };
}

class CaptureGuideStep {
  final CaptureLevel level;
  final int angleDeg;

  const CaptureGuideStep({required this.level, required this.angleDeg});
}

class CaptureGuidePlan {
  static final List<CaptureGuideStep> default36 = _buildDefault36();

  static List<CaptureGuideStep> _buildDefault36() {
    final steps = <CaptureGuideStep>[];

    for (int angle = 0; angle < 360; angle += 30) {
      steps.add(CaptureGuideStep(level: CaptureLevel.mid, angleDeg: angle));
    }
    for (int angle = 0; angle < 360; angle += 30) {
      steps.add(CaptureGuideStep(level: CaptureLevel.high, angleDeg: angle));
    }
    for (int angle = 0; angle < 360; angle += 30) {
      steps.add(CaptureGuideStep(level: CaptureLevel.low, angleDeg: angle));
    }

    return steps;
  }

  static CaptureGuideStep stepForCaptureCount(int captureCount) {
    if (default36.isEmpty) {
      return const CaptureGuideStep(level: CaptureLevel.mid, angleDeg: 0);
    }
    final index = min(captureCount, default36.length - 1);
    return default36[index];
  }
}
