import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:proyecto_3d/data/services/local_backend_api_service.dart';
import 'package:proyecto_3d/domain/projects/backend_processing_status.dart';
import 'package:proyecto_3d/domain/projects/project_export_config.dart';
import 'package:proyecto_3d/domain/projects/project_processing.dart';
import 'package:proyecto_3d/domain/settings/local_server_config.dart';

void main() {
  test('flujo remoto end-to-end con PROCESAMIENTO', () async {
    print('[E2E] iniciando test');
    final docsDir = Directory.systemTemp.createTempSync('proyecto_3d_docs_');
    addTearDown(() async {
      if (await docsDir.exists()) {
        await docsDir.delete(recursive: true);
      }
    });
    print('[E2E] directorio temporal listo: ${docsDir.path}');

    final service = LocalBackendApiService(
      config: const LocalServerConfig(
        host: '127.0.0.1',
        port: 8000,
        enabled: true,
      ),
      documentsDirectoryProvider: () async => docsDir,
    );
    addTearDown(service.dispose);
    print('[E2E] servicio creado');

    final health = await service.ping();
    print('[E2E] health: $health');
    expect(health, contains('127.0.0.1:8000'));

    final localProjectId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    print('[E2E] creando proyecto: $localProjectId');
    final remoteProjectId = await service.createProject(
      localProjectId: localProjectId,
      name: 'E2E remoto',
      description: 'Validacion de integracion end-to-end',
      exportConfig: const ProjectExportConfig(
        targetFormat: ExportTargetFormat.glb,
      ),
      processingConfig: const ProjectProcessingConfig(),
    );
    print('[E2E] proyecto remoto: $remoteProjectId');
    expect(remoteProjectId, isNotEmpty);

    final imageDir = Directory(
      '${docsDir.path}${Platform.pathSeparator}captures',
    );
    await imageDir.create(recursive: true);
    final imagePaths = <String>[];
    for (var index = 0; index < 3; index++) {
      final file = File(
        '${imageDir.path}${Platform.pathSeparator}capture_$index.jpg',
      );
      await file.writeAsBytes(List<int>.generate(128, (i) => (i + index) % 256));
      imagePaths.add(file.path);
    }
    print('[E2E] imagenes creadas: ${imagePaths.length}');

    print('[E2E] subiendo imagenes');
    await service.uploadImages(
      remoteProjectId: remoteProjectId,
      imagePaths: imagePaths,
    );
    print('[E2E] upload completo');

    final statusAfterUploadResponse = await http.get(
      Uri.parse('http://127.0.0.1:8000/projects/$remoteProjectId/status'),
    );
    print('[E2E] status tras upload: ${statusAfterUploadResponse.statusCode}');
    expect(statusAfterUploadResponse.statusCode, 200);
    final statusAfterUploadJson = jsonDecode(
      statusAfterUploadResponse.body,
    ) as Map<String, dynamic>;
    expect(statusAfterUploadJson['status'], 'ready');
    expect(statusAfterUploadJson['image_count'], 3);

    final statusBeforeProcessing = await service.fetchStatus(
      remoteProjectId: remoteProjectId,
    );
    print('[E2E] status antes de procesar: ${statusBeforeProcessing.rawStatus}');
    expect(statusBeforeProcessing.rawStatus.toLowerCase(), 'ready');
    expect(statusBeforeProcessing.isCompleted, isFalse);
    expect(statusBeforeProcessing.isActive, isTrue);
    expect(statusBeforeProcessing.stage, ProcessingStage.queued);

    print('[E2E] iniciando procesamiento');
    await service.startProcessing(
      remoteProjectId: remoteProjectId,
      exportConfig: const ProjectExportConfig(
        targetFormat: ExportTargetFormat.glb,
      ),
      processingConfig: const ProjectProcessingConfig(),
    );
    print('[E2E] proceso iniciado');

    print('[E2E] esperando estado terminal');
    final completed = await _waitForTerminalStatus(
      service,
      remoteProjectId,
      timeout: const Duration(seconds: 30),
    );
    print('[E2E] estado terminal: ${completed.rawStatus}');
    expect(completed.isFailed, isFalse);
    expect(completed.isCompleted, isTrue);
    expect(completed.modelUrl, isNotNull);

    print('[E2E] descargando modelo');
    final modelPath = await service.downloadModelToProject(
      remoteProjectId: remoteProjectId,
      localProjectId: localProjectId,
      preferredFormat: 'glb',
      preferredModelUrl: completed.modelUrl,
    );
    print('[E2E] modelo descargado: $modelPath');
    final modelFile = File(modelPath);
    expect(await modelFile.exists(), isTrue);
    final modelBytes = await modelFile.readAsBytes();
    expect(modelBytes.length, greaterThan(0));
    expect(String.fromCharCodes(modelBytes.take(4)), 'glTF');
  });
}

Future<BackendProcessingStatus> _waitForTerminalStatus(
  LocalBackendApiService service,
  String remoteProjectId, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  BackendProcessingStatus? lastStatus;

  while (DateTime.now().isBefore(deadline)) {
    lastStatus = await service.fetchStatus(remoteProjectId: remoteProjectId);
    if (lastStatus.isTerminal) return lastStatus;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  throw StateError(
    'El backend no alcanzo un estado terminal. Ultimo estado: '
    '${lastStatus?.rawStatus ?? 'desconocido'}',
  );
}
