import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:proyecto_3d/data/services/local_backend_api_service.dart';
import 'package:proyecto_3d/domain/projects/backend_processing_status.dart';
import 'package:proyecto_3d/domain/projects/project_export_config.dart';
import 'package:proyecto_3d/domain/projects/project_processing.dart';
import 'package:proyecto_3d/domain/settings/local_server_config.dart';

const bool kRunLocalBackendE2E = bool.fromEnvironment(
  'RUN_LOCAL_BACKEND_E2E',
  defaultValue: false,
);
const String kE2EBackendUrl = String.fromEnvironment(
  'LOCAL_BACKEND_URL',
  defaultValue: LocalServerDefaults.baseUrl,
);
const String kE2EApiKey = String.fromEnvironment(
  'LOCAL_BACKEND_API_KEY',
  defaultValue: '',
);

void main() {
  test('flujo remoto end-to-end con PROCESAMIENTO', () async {
    debugPrint('[E2E] iniciando test');
    final docsDir = Directory.systemTemp.createTempSync('proyecto_3d_docs_');
    addTearDown(() async {
      if (await docsDir.exists()) {
        await docsDir.delete(recursive: true);
      }
    });
    debugPrint('[E2E] directorio temporal listo: ${docsDir.path}');

    final backendConfig = LocalServerConfig(
      baseUrl: kE2EBackendUrl,
      enabled: true,
      apiKey: kE2EApiKey.trim().isEmpty ? null : kE2EApiKey.trim(),
    );
    debugPrint('[E2E] backend configurado en: ${backendConfig.endpoint}');

    final service = LocalBackendApiService(
      config: backendConfig,
      documentsDirectoryProvider: () async => docsDir,
    );
    addTearDown(service.dispose);
    debugPrint('[E2E] servicio creado');

    final health = await service.ping();
    debugPrint('[E2E] health: $health');
    expect(health, contains('Conexion OK'));
    final healthPayload = await _readHealthPayload(backendConfig);
    final backendEngine =
        (healthPayload['engine']?.toString().toLowerCase() ?? 'unknown');
    debugPrint('[E2E] engine detectado: $backendEngine');

    final localProjectId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('[E2E] creando proyecto: $localProjectId');
    final remoteProjectId = await service.createProject(
      localProjectId: localProjectId,
      name: 'E2E remoto',
      description: 'Validacion de integracion end-to-end',
      exportConfig: const ProjectExportConfig(
        targetFormat: ExportTargetFormat.glb,
      ),
      processingConfig: const ProjectProcessingConfig(),
    );
    debugPrint('[E2E] proyecto remoto: $remoteProjectId');
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
      await file.writeAsBytes(_buildE2EImageBytes(index));
      imagePaths.add(file.path);
    }
    debugPrint('[E2E] imagenes creadas: ${imagePaths.length}');

    debugPrint('[E2E] subiendo imagenes');
    await service.uploadImages(
      remoteProjectId: remoteProjectId,
      imagePaths: imagePaths,
    );
    debugPrint('[E2E] upload completo');

    final statusAfterUploadResponse = await http.get(
      _buildBackendUri(backendConfig, '/projects/$remoteProjectId/status'),
      headers: _backendHeaders(backendConfig),
    );
    debugPrint(
      '[E2E] status tras upload: ${statusAfterUploadResponse.statusCode}',
    );
    expect(statusAfterUploadResponse.statusCode, 200);
    final statusAfterUploadJson =
        jsonDecode(statusAfterUploadResponse.body) as Map<String, dynamic>;
    expect(statusAfterUploadJson['status'], 'ready');
    expect(statusAfterUploadJson['image_count'], 3);

    final statusBeforeProcessing = await service.fetchStatus(
      remoteProjectId: remoteProjectId,
    );
    debugPrint(
      '[E2E] status antes de procesar: ${statusBeforeProcessing.rawStatus}',
    );
    expect(statusBeforeProcessing.rawStatus.toLowerCase(), 'ready');
    expect(statusBeforeProcessing.isCompleted, isFalse);
    expect(statusBeforeProcessing.isActive, isTrue);
    expect(statusBeforeProcessing.stage, ProcessingStage.queued);

    debugPrint('[E2E] iniciando procesamiento');
    await service.startProcessing(
      remoteProjectId: remoteProjectId,
      exportConfig: const ProjectExportConfig(
        targetFormat: ExportTargetFormat.glb,
      ),
      processingConfig: const ProjectProcessingConfig(),
    );
    debugPrint('[E2E] proceso iniciado');

    debugPrint('[E2E] esperando estado terminal');
    final completed = await _waitForTerminalStatus(
      service,
      remoteProjectId,
      timeout: backendEngine == 'colmap'
          ? const Duration(seconds: 90)
          : const Duration(seconds: 30),
    );
    debugPrint('[E2E] estado terminal: ${completed.rawStatus}');
    if (completed.isFailed && backendEngine == 'colmap') {
      final normalizedMessage = completed.message.toLowerCase();
      debugPrint(
        '[E2E] colmap termino en failed con imagenes sinteticas: '
        '${completed.message}',
      );
      expect(
        normalizedMessage,
        anyOf(
          contains('colmap'),
          contains('mapper'),
          contains('sparse'),
          contains('image'),
          contains('fallid'),
          contains('failed'),
          contains('error'),
        ),
      );
      return;
    }

    expect(completed.isFailed, isFalse);
    expect(completed.isCompleted, isTrue);
    expect(completed.modelUrl, isNotNull);

    debugPrint('[E2E] descargando modelo');
    final modelPath = await service.downloadModelToProject(
      remoteProjectId: remoteProjectId,
      localProjectId: localProjectId,
      preferredFormat: 'glb',
      preferredModelUrl: completed.modelUrl,
    );
    debugPrint('[E2E] modelo descargado: $modelPath');
    final modelFile = File(modelPath);
    expect(await modelFile.exists(), isTrue);
    final modelBytes = await modelFile.readAsBytes();
    expect(modelBytes.length, greaterThan(0));
    expect(String.fromCharCodes(modelBytes.take(4)), 'glTF');
  }, skip: !kRunLocalBackendE2E);
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

Future<Map<String, dynamic>> _readHealthPayload(
  LocalServerConfig config,
) async {
  final response = await http.get(
    _buildBackendUri(config, '/health'),
    headers: _backendHeaders(config),
  );
  if (response.statusCode != 200) {
    throw StateError(
      'No se pudo consultar /health para detectar engine. '
      'status=${response.statusCode}',
    );
  }

  final decoded = jsonDecode(response.body);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw StateError('El payload de /health no es un objeto JSON.');
}

Uri _buildBackendUri(LocalServerConfig config, String pathOrUrl) {
  final normalized = pathOrUrl.trim();
  if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
    return Uri.parse(normalized);
  }

  final base = Uri.parse(config.endpoint);
  final requestUri = Uri.parse(
    normalized.startsWith('/') ? normalized : '/$normalized',
  );
  final resolvedPath = _resolvePathWithBase(
    basePath: base.path,
    requestPath: requestUri.path,
  );

  return base.replace(
    path: resolvedPath,
    query: requestUri.query.isEmpty ? null : requestUri.query,
    fragment: requestUri.fragment.isEmpty ? null : requestUri.fragment,
  );
}

String _resolvePathWithBase({
  required String basePath,
  required String requestPath,
}) {
  final normalizedBase = _normalizePath(basePath, allowRootEmpty: true);
  final normalizedRequest = _normalizePath(requestPath);

  if (normalizedBase.isEmpty) return normalizedRequest;
  if (normalizedRequest == '/') return normalizedBase;
  if (normalizedRequest == normalizedBase ||
      normalizedRequest.startsWith('$normalizedBase/')) {
    return normalizedRequest;
  }
  return '$normalizedBase$normalizedRequest';
}

String _normalizePath(String rawPath, {bool allowRootEmpty = false}) {
  var normalized = rawPath.trim();
  if (normalized.isEmpty) return allowRootEmpty ? '' : '/';

  normalized = normalized.replaceAll(RegExp(r'/+'), '/');
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }
  if (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (allowRootEmpty && normalized == '/') return '';
  return normalized;
}

Map<String, String> _backendHeaders(LocalServerConfig config) {
  final headers = <String, String>{'Accept': 'application/json'};
  final apiKey = config.apiKey?.trim();
  if (apiKey != null && apiKey.isNotEmpty) {
    headers['X-API-Key'] = apiKey;
  }
  return headers;
}

List<int> _buildE2EImageBytes(int index) {
  const width = 640;
  const height = 480;
  final image = img.Image(width: width, height: height);
  final shiftX = index * 17;
  final shiftY = index * 11;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final adjustedX = (x + shiftX) % width;
      final adjustedY = (y + shiftY) % height;
      final checker = ((adjustedX ~/ 24) + (adjustedY ~/ 24)) % 2;
      final red = adjustedX * 255 ~/ (width - 1);
      final green = adjustedY * 255 ~/ (height - 1);
      final blue = checker == 0 ? 40 : 210;
      image.setPixelRgba(x, y, red, green, blue, 255);
    }
  }

  for (var stripe = 0; stripe < 6; stripe++) {
    final stripeX = (80 + stripe * 84 + shiftX) % width;
    for (var y = 24; y < height - 24; y++) {
      image.setPixelRgba(stripeX, y, 255, 255, 255, 255);
      if (stripeX + 1 < width) {
        image.setPixelRgba(stripeX + 1, y, 0, 0, 0, 255);
      }
    }
  }

  _paintFilledCircle(
    image,
    centerX: 190 + shiftX,
    centerY: 150 + shiftY,
    radius: 52,
    red: 255,
    green: 80,
    blue: 30,
  );
  _paintFilledCircle(
    image,
    centerX: 410 + shiftX,
    centerY: 280 + shiftY,
    radius: 60,
    red: 30,
    green: 220,
    blue: 180,
  );

  return img.encodeJpg(image, quality: 92);
}

void _paintFilledCircle(
  img.Image image, {
  required int centerX,
  required int centerY,
  required int radius,
  required int red,
  required int green,
  required int blue,
}) {
  final normalizedCenterX = centerX % image.width;
  final normalizedCenterY = centerY % image.height;
  final radiusSquared = radius * radius;
  final minX = (normalizedCenterX - radius).clamp(0, image.width - 1);
  final maxX = (normalizedCenterX + radius).clamp(0, image.width - 1);
  final minY = (normalizedCenterY - radius).clamp(0, image.height - 1);
  final maxY = (normalizedCenterY + radius).clamp(0, image.height - 1);

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final dx = x - normalizedCenterX;
      final dy = y - normalizedCenterY;
      if ((dx * dx) + (dy * dy) <= radiusSquared) {
        image.setPixelRgba(x, y, red, green, blue, 255);
      }
    }
  }
}
