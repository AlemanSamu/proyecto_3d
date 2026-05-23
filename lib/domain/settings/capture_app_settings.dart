class CaptureAppSettings {
  const CaptureAppSettings({
    this.captureProfileKey = 'estable',
    this.captureResolutionKey = 'max',
    this.maxPhotos = 45,
  });

  final String captureProfileKey;
  final String captureResolutionKey;
  final int maxPhotos;

  CaptureAppSettings copyWith({
    String? captureProfileKey,
    String? captureResolutionKey,
    int? maxPhotos,
  }) {
    return CaptureAppSettings(
      captureProfileKey: captureProfileKey ?? this.captureProfileKey,
      captureResolutionKey: captureResolutionKey ?? this.captureResolutionKey,
      maxPhotos: maxPhotos ?? this.maxPhotos,
    );
  }
}
