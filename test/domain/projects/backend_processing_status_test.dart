import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/domain/projects/backend_processing_status.dart';

void main() {
  test('parses snake_case backend payloads', () {
    final status = BackendProcessingStatus.fromJson({
      'status': 'completed',
      'progress': 100,
      'message': 'Listo',
      'model_download_url': '/projects/demo/model',
      'output_format': 'glb',
    });

    expect(status.rawStatus, 'completed');
    expect(status.state, BackendJobState.completed);
    expect(status.progress, 1);
    expect(status.message, 'Listo');
    expect(status.modelUrl, '/projects/demo/model');
    expect(status.modelFormat, 'glb');
    expect(status.isCompleted, isTrue);
  });

  test('prefers error_message when backend sends it', () {
    final status = BackendProcessingStatus.fromJson({
      'status': 'failed',
      'error_message': 'No hay imagenes',
    });

    expect(status.state, BackendJobState.failed);
    expect(status.message, 'No hay imagenes');
    expect(status.isFailed, isTrue);
  });
}