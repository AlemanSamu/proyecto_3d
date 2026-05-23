enum CaptureProfile { rapido, estable, maximaCalidad }

enum CaptureResolution { high, veryHigh, ultraHigh, max }

extension CaptureResolutionX on CaptureResolution {
  String get label => switch (this) {
    CaptureResolution.high => 'Alta',
    CaptureResolution.veryHigh => '1080p real',
    CaptureResolution.ultraHigh => '4K / Ultra',
    CaptureResolution.max => 'Maxima del dispositivo',
  };

  String get compactLabel => switch (this) {
    CaptureResolution.high => 'Alta',
    CaptureResolution.veryHigh => '1080p',
    CaptureResolution.ultraHigh => '4K',
    CaptureResolution.max => 'Max',
  };

  String get shortHint => switch (this) {
    CaptureResolution.high => 'Captura rapida con menor peso.',
    CaptureResolution.veryHigh => 'Buen minimo para reconstruccion dense.',
    CaptureResolution.ultraHigh => 'Mas detalle para COLMAP.',
    CaptureResolution.max => 'Usa la mejor resolucion disponible.',
  };

  static CaptureResolution fromKey(String? key) {
    return switch (key) {
      'high' => CaptureResolution.high,
      'veryHigh' => CaptureResolution.veryHigh,
      'ultraHigh' => CaptureResolution.ultraHigh,
      'max' => CaptureResolution.max,
      _ => CaptureResolution.max,
    };
  }
}

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
    CaptureProfile.rapido => 20,
    CaptureProfile.estable => 20,
    CaptureProfile.maximaCalidad => 20,
  };

  int get recommendedIdealPhotos => switch (this) {
    CaptureProfile.rapido => 36,
    CaptureProfile.estable => 40,
    CaptureProfile.maximaCalidad => 45,
  };

  List<String> get warnings => const [
    'Evita reflejos',
    'No uses zoom',
    'Manten buena iluminacion',
    'No repitas el mismo angulo',
  ];

  static CaptureProfile fromKey(String? key) {
    return switch (key) {
      'rapido' => CaptureProfile.rapido,
      'estable' => CaptureProfile.estable,
      'maxima_calidad' => CaptureProfile.maximaCalidad,
      _ => CaptureProfile.estable,
    };
  }
}
