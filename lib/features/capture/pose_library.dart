enum PoseLevel { low, mid, top }

extension PoseLevelX on PoseLevel {
  String get label => switch (this) {
    PoseLevel.low => 'Bajo',
    PoseLevel.mid => 'Medio',
    PoseLevel.top => 'Alto',
  };

  String get short => switch (this) {
    PoseLevel.low => 'LOW',
    PoseLevel.mid => 'MID',
    PoseLevel.top => 'TOP',
  };
}

class PoseStep {
  final String id;
  final String title;
  final PoseLevel level;
  final int angleDeg;
  final String instruction;

  const PoseStep({
    required this.id,
    required this.title,
    required this.level,
    required this.angleDeg,
    required this.instruction,
  });
}

class PoseLibrary {
  static List<PoseStep> default18() {
    return default36();
  }

  static List<PoseStep> default36() {
    final list = <PoseStep>[];

    for (int angle = 0; angle < 360; angle += 30) {
      list.add(
        PoseStep(
          id: 'mid_$angle',
          title: 'Alrededor (media) $angle deg',
          level: PoseLevel.mid,
          angleDeg: angle,
          instruction:
              'Manten el objeto centrado. Distancia constante. Gira hasta ~$angle deg.',
        ),
      );
    }

    for (int angle = 0; angle < 360; angle += 30) {
      list.add(
        PoseStep(
          id: 'top_$angle',
          title: 'Desde arriba $angle deg',
          level: PoseLevel.top,
          angleDeg: angle,
          instruction:
              'Inclina el celular hacia abajo (vista superior). No te acerques demasiado.',
        ),
      );
    }

    for (int angle = 0; angle < 360; angle += 30) {
      list.add(
        PoseStep(
          id: 'low_$angle',
          title: 'Desde abajo $angle deg',
          level: PoseLevel.low,
          angleDeg: angle,
          instruction:
              'Baja el celular y apunta un poco hacia arriba. Evita sombras fuertes.',
        ),
      );
    }

    return list;
  }
}
