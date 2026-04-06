import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/data/services/local_backend_api_service.dart';

void main() {
  test('default local backend paths use the root FastAPI contract', () {
    const paths = LocalBackendApiPaths();

    expect(paths.health, '/health');
    expect(paths.createProject, '/projects');
    expect(paths.uploadImageFor('demo'), '/projects/demo/images');
    expect(paths.startProcessingFor('demo'), '/projects/demo/process');
    expect(paths.statusFor('demo'), '/projects/demo/status');
    expect(paths.modelFor('demo'), '/projects/demo/model');
  });
}