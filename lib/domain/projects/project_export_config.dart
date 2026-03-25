enum ExportTargetFormat { glb, obj, fbx, usdz }

extension ExportTargetFormatX on ExportTargetFormat {
  String get value => switch (this) {
    ExportTargetFormat.glb => 'glb',
    ExportTargetFormat.obj => 'obj',
    ExportTargetFormat.fbx => 'fbx',
    ExportTargetFormat.usdz => 'usdz',
  };

  String get label => switch (this) {
    ExportTargetFormat.glb => 'GLB',
    ExportTargetFormat.obj => 'OBJ',
    ExportTargetFormat.fbx => 'FBX',
    ExportTargetFormat.usdz => 'USDZ',
  };

  static ExportTargetFormat fromValue(String? value) {
    return switch (value) {
      'obj' => ExportTargetFormat.obj,
      'fbx' => ExportTargetFormat.fbx,
      'usdz' => ExportTargetFormat.usdz,
      _ => ExportTargetFormat.glb,
    };
  }
}

enum ExportQualityPreset { preview, balanced, high, cinematic }

extension ExportQualityPresetX on ExportQualityPreset {
  String get value => switch (this) {
    ExportQualityPreset.preview => 'preview',
    ExportQualityPreset.balanced => 'balanced',
    ExportQualityPreset.high => 'high',
    ExportQualityPreset.cinematic => 'cinematic',
  };

  String get label => switch (this) {
    ExportQualityPreset.preview => 'Vista previa',
    ExportQualityPreset.balanced => 'Balanceada',
    ExportQualityPreset.high => 'Alta',
    ExportQualityPreset.cinematic => 'Cinematica',
  };

  static ExportQualityPreset fromValue(String? value) {
    return switch (value) {
      'preview' => ExportQualityPreset.preview,
      'high' => ExportQualityPreset.high,
      'cinematic' => ExportQualityPreset.cinematic,
      _ => ExportQualityPreset.balanced,
    };
  }
}

enum TextureQuality { none, basic, detailed, ultra }

extension TextureQualityX on TextureQuality {
  String get value => switch (this) {
    TextureQuality.none => 'none',
    TextureQuality.basic => 'basic',
    TextureQuality.detailed => 'detailed',
    TextureQuality.ultra => 'ultra',
  };

  String get label => switch (this) {
    TextureQuality.none => 'Sin texturas',
    TextureQuality.basic => 'Basicas',
    TextureQuality.detailed => 'Detalladas',
    TextureQuality.ultra => 'Ultra',
  };

  static TextureQuality fromValue(String? value) {
    return switch (value) {
      'none' => TextureQuality.none,
      'basic' => TextureQuality.basic,
      'ultra' => TextureQuality.ultra,
      _ => TextureQuality.detailed,
    };
  }
}

enum GeometryQuality { low, medium, high, ultra }

extension GeometryQualityX on GeometryQuality {
  String get value => switch (this) {
    GeometryQuality.low => 'low',
    GeometryQuality.medium => 'medium',
    GeometryQuality.high => 'high',
    GeometryQuality.ultra => 'ultra',
  };

  String get label => switch (this) {
    GeometryQuality.low => 'Baja',
    GeometryQuality.medium => 'Media',
    GeometryQuality.high => 'Alta',
    GeometryQuality.ultra => 'Ultra',
  };

  static GeometryQuality fromValue(String? value) {
    return switch (value) {
      'low' => GeometryQuality.low,
      'high' => GeometryQuality.high,
      'ultra' => GeometryQuality.ultra,
      _ => GeometryQuality.medium,
    };
  }
}

enum ExportScaleUnit { meter, centimeter, millimeter }

extension ExportScaleUnitX on ExportScaleUnit {
  String get value => switch (this) {
    ExportScaleUnit.meter => 'meter',
    ExportScaleUnit.centimeter => 'centimeter',
    ExportScaleUnit.millimeter => 'millimeter',
  };

  String get label => switch (this) {
    ExportScaleUnit.meter => 'Metros',
    ExportScaleUnit.centimeter => 'Centimetros',
    ExportScaleUnit.millimeter => 'Milimetros',
  };

  static ExportScaleUnit fromValue(String? value) {
    return switch (value) {
      'meter' => ExportScaleUnit.meter,
      'millimeter' => ExportScaleUnit.millimeter,
      _ => ExportScaleUnit.centimeter,
    };
  }
}

enum ExportDestination { localDevice, localServer }

extension ExportDestinationX on ExportDestination {
  String get value => switch (this) {
    ExportDestination.localDevice => 'localDevice',
    ExportDestination.localServer => 'localServer',
  };

  String get label => switch (this) {
    ExportDestination.localDevice => 'Dispositivo local',
    ExportDestination.localServer => 'Servidor local',
  };

  static ExportDestination fromValue(String? value) {
    return switch (value) {
      'localServer' => ExportDestination.localServer,
      _ => ExportDestination.localDevice,
    };
  }
}

class ProjectExportConfig {
  const ProjectExportConfig({
    this.targetFormat = ExportTargetFormat.glb,
    this.qualityPreset = ExportQualityPreset.balanced,
    this.textureQuality = TextureQuality.detailed,
    this.geometryQuality = GeometryQuality.medium,
    this.scaleUnit = ExportScaleUnit.centimeter,
    this.destination = ExportDestination.localDevice,
    this.destinationPath,
    this.includeImages = true,
    this.includeThumbnails = true,
    this.includeMetadata = true,
    this.compressPackage = true,
    this.includeNormals = true,
  });

  final ExportTargetFormat targetFormat;
  final ExportQualityPreset qualityPreset;
  final TextureQuality textureQuality;
  final GeometryQuality geometryQuality;
  final ExportScaleUnit scaleUnit;
  final ExportDestination destination;
  final String? destinationPath;
  final bool includeImages;
  final bool includeThumbnails;
  final bool includeMetadata;
  final bool compressPackage;
  final bool includeNormals;

  ProjectExportConfig copyWith({
    ExportTargetFormat? targetFormat,
    ExportQualityPreset? qualityPreset,
    TextureQuality? textureQuality,
    GeometryQuality? geometryQuality,
    ExportScaleUnit? scaleUnit,
    ExportDestination? destination,
    String? destinationPath,
    bool clearDestinationPath = false,
    bool? includeImages,
    bool? includeThumbnails,
    bool? includeMetadata,
    bool? compressPackage,
    bool? includeNormals,
  }) {
    return ProjectExportConfig(
      targetFormat: targetFormat ?? this.targetFormat,
      qualityPreset: qualityPreset ?? this.qualityPreset,
      textureQuality: textureQuality ?? this.textureQuality,
      geometryQuality: geometryQuality ?? this.geometryQuality,
      scaleUnit: scaleUnit ?? this.scaleUnit,
      destination: destination ?? this.destination,
      destinationPath: clearDestinationPath
          ? null
          : (destinationPath ?? this.destinationPath),
      includeImages: includeImages ?? this.includeImages,
      includeThumbnails: includeThumbnails ?? this.includeThumbnails,
      includeMetadata: includeMetadata ?? this.includeMetadata,
      compressPackage: compressPackage ?? this.compressPackage,
      includeNormals: includeNormals ?? this.includeNormals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetFormat': targetFormat.value,
      'qualityPreset': qualityPreset.value,
      'textureQuality': textureQuality.value,
      'geometryQuality': geometryQuality.value,
      'scaleUnit': scaleUnit.value,
      'destination': destination.value,
      'destinationPath': destinationPath,
      'includeImages': includeImages,
      'includeThumbnails': includeThumbnails,
      'includeMetadata': includeMetadata,
      'compressPackage': compressPackage,
      'includeNormals': includeNormals,
    };
  }

  factory ProjectExportConfig.fromJson(Map<String, dynamic> json) {
    return ProjectExportConfig(
      targetFormat: ExportTargetFormatX.fromValue(
        json['targetFormat'] as String?,
      ),
      qualityPreset: ExportQualityPresetX.fromValue(
        json['qualityPreset'] as String?,
      ),
      textureQuality: TextureQualityX.fromValue(
        json['textureQuality'] as String?,
      ),
      geometryQuality: GeometryQualityX.fromValue(
        json['geometryQuality'] as String?,
      ),
      scaleUnit: ExportScaleUnitX.fromValue(json['scaleUnit'] as String?),
      destination: ExportDestinationX.fromValue(json['destination'] as String?),
      destinationPath: _readOptionalText(json['destinationPath']),
      includeImages: json['includeImages'] as bool? ?? true,
      includeThumbnails: json['includeThumbnails'] as bool? ?? true,
      includeMetadata: json['includeMetadata'] as bool? ?? true,
      compressPackage: json['compressPackage'] as bool? ?? true,
      includeNormals: json['includeNormals'] as bool? ?? true,
    );
  }

  static String? _readOptionalText(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
