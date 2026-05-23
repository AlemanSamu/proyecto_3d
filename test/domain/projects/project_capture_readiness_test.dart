import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/domain/capture/capture_photo.dart';
import 'package:proyecto_3d/domain/projects/project_capture_readiness.dart';
import 'package:proyecto_3d/domain/projects/project_model.dart';

void main() {
  test('summarizes coverage by angle level and warnings', () {
    final project = ProjectModel(
      id: 'demo',
      name: 'Objeto',
      createdAt: DateTime(2026),
      photos: [
        _photo(id: '1', level: 'low', warnings: const ['borrosa']),
        _photo(id: '2', level: 'mid'),
        _photo(id: '3', level: 'high', brightness: 70, sharpness: 18),
      ],
    );

    final summary = ProjectCaptureReadiness.fromProject(project);

    expect(summary.acceptedPhotos, 3);
    expect(summary.lowAngleCount, 1);
    expect(summary.midAngleCount, 1);
    expect(summary.highAngleCount, 1);
    expect(summary.warningCounts['borrosa'], 1);
    expect(summary.suggestions, contains('Minimo recomendado: 20 fotos.'));
  });
}

CapturePhoto _photo({
  required String id,
  required String level,
  double brightness = 60,
  double sharpness = 14,
  List<String> warnings = const [],
}) {
  return CapturePhoto(
    id: id,
    originalPath: '/tmp/$id.jpg',
    thumbnailPath: '/tmp/${id}_thumb.jpg',
    level: level,
    brightness: brightness,
    sharpness: sharpness,
    width: 1920,
    height: 1080,
    warnings: warnings,
    accepted: true,
    flaggedForRetake: false,
    createdAt: DateTime(2026),
  );
}
