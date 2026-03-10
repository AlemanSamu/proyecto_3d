class PhotoQualityReport {
  final bool isOk;
  final double brightness;
  final double sharpness;
  final String hint;

  const PhotoQualityReport({
    required this.isOk,
    required this.brightness,
    required this.sharpness,
    required this.hint,
  });
}
