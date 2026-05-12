import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/domain/projects/backend_processing_status.dart';
import 'package:proyecto_3d/domain/projects/project_processing.dart';

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

  test('uses current_stage to infer detailed pipeline stage', () {
    final status = BackendProcessingStatus.fromJson({
      'status': 'processing',
      'current_stage': 'export',
      'message': 'Exportando modelo final',
    });

    expect(status.state, BackendJobState.running);
    expect(status.stage, ProcessingStage.packaging);
    expect(status.message, 'Exportando modelo final');
  });
}
