enum CaptureProfile { rapido, estable, maximaCalidad }

extension CaptureProfileX on CaptureProfile {
  String get key => switch (this) {
    CaptureProfile.rapido => 'rapido',
    CaptureProfile.estable => 'estable',
    CaptureProfile.maximaCalidad => 'maxima_calidad',
  };

  String get label => switch (this) {
    CaptureProfile.rapido => 'Rapido',
    CaptureProfile.estable => 'Estable',
    CaptureProfile.maximaCalidad => 'Maxima calidad',
  };

  String get shortHint => switch (this) {
    CaptureProfile.rapido => 'Prioriza velocidad con validacion basica.',
    CaptureProfile.estable => 'Balance entre velocidad y estabilidad.',
    CaptureProfile.maximaCalidad => 'Prioriza nitidez y consistencia.',
  };

  int get minIntervalMs => switch (this) {
    CaptureProfile.rapido => 380,
    CaptureProfile.estable => 700,
    CaptureProfile.maximaCalidad => 1050,
  };

  int get preShotWaitMs => switch (this) {
    CaptureProfile.rapido => 70,
    CaptureProfile.estable => 110,
    CaptureProfile.maximaCalidad => 180,
  };

  int get stabilityProbeMs => switch (this) {
    CaptureProfile.rapido => 180,
    CaptureProfile.estable => 350,
    CaptureProfile.maximaCalidad => 520,
  };

  double get stabilityThreshold => switch (this) {
    CaptureProfile.rapido => 0.42,
    CaptureProfile.estable => 0.55,
    CaptureProfile.maximaCalidad => 0.68,
  };

  int get recommendedMinPhotos => switch (this) {
    CaptureProfile.rapido => 30,
    CaptureProfile.estable => 36,
    CaptureProfile.maximaCalidad => 45,
  };

  int get recommendedIdealPhotos => switch (this) {
    CaptureProfile.rapido => 45,
    CaptureProfile.estable => 52,
    CaptureProfile.maximaCalidad => 60,
  };

  List<String> get warnings => const [
    'Evita reflejos',
    'No uses zoom',
    'Manten buena iluminacion',
    'No repitas el mismo angulo',
  ];
}
