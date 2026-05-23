import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/data/services/backend_image_upload_preparer.dart';

void main() {
  test('keeps small images at original size', () {
    final plan = planBackendImageUploadSize(width: 1280, height: 720);

    expect(plan.shouldResize, isFalse);
    expect(plan.targetWidth, 1280);
    expect(plan.targetHeight, 720);
  });

  test('limits large images while preserving aspect ratio', () {
    final plan = planBackendImageUploadSize(width: 4000, height: 3000);

    expect(plan.shouldResize, isTrue);
    expect(plan.targetWidth, 2560);
    expect(plan.targetHeight, 1920);
  });
}
