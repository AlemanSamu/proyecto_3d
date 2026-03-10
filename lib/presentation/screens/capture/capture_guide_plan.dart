import 'dart:math';

enum CaptureLevel { high, mid, low }

extension CaptureLevelX on CaptureLevel {
  String get key => switch (this) {
    CaptureLevel.high => 'top',
    CaptureLevel.mid => 'mid',
    CaptureLevel.low => 'low',
  };

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
  static final List<CaptureGuideStep> alternating24 = _buildAlternating24();

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

  static List<CaptureGuideStep> _buildAlternating24() {
    final steps = <CaptureGuideStep>[];

    for (int angle = 0; angle < 360; angle += 30) {
      steps.add(CaptureGuideStep(level: CaptureLevel.mid, angleDeg: angle));
      if (angle % 60 == 0) {
        steps.add(CaptureGuideStep(level: CaptureLevel.high, angleDeg: angle));
      } else {
        steps.add(CaptureGuideStep(level: CaptureLevel.low, angleDeg: angle));
      }
    }

    return steps;
  }

  static CaptureGuideStep stepForCaptureCount(int captureCount) {
    if (alternating24.isEmpty) {
      return const CaptureGuideStep(level: CaptureLevel.mid, angleDeg: 0);
    }
    final index = min(captureCount, alternating24.length - 1);
    return alternating24[index];
  }
}
