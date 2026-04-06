import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../domain/projects/backend_processing_status.dart';
import '../../domain/projects/project_export_config.dart';
import '../../domain/projects/project_processing.dart';
import '../../domain/settings/local_server_config.dart';
import 'backend_api_exception.dart';

class LocalBackendApiPaths {
  const LocalBackendApiPaths({
    this.health = '/health',
    this.createProject = '/projects',
    this.uploadImageTemplate = '/projects/{projectId}/images',
    this.startProcessingTemplate = '/projects/{projectId}/process',
    this.statusTemplate = '/projects/{projectId}/status',
    this.modelTemplate = '/projects/{projectId}/model',
  });

  final String health;
  final String createProject;
  final String uploadImageTemplate;
  final String startProcessingTemplate;
  final String statusTemplate;
  final String modelTemplate;

  String uploadImageFor(String projectId) =>
      _withProjectId(uploadImageTemplate, projectId);

  String startProcessingFor(String projectId) =>
      _withProjectId(startProcessingTemplate, projectId);

  String statusFor(String projectId) => _withProjectId(statusTemplate, projectId);

  String modelFor(String projectId) => _withProjectId(modelTemplate, projectId);

  static String _withProjectId(String template, String projectId) {
    return template.replaceAll('{projectId}', Uri.encodeComponent(projectId));
  }
}

class LocalBackendApiService {
  LocalBackendApiService({
    required LocalServerConfig config,
    http.Client? client,
    Future<Directory> Function()? documentsDirectoryProvider,
    this.paths = const LocalBackendApiPaths(),
    this.timeout = const Duration(seconds: 25),
  }) : _config = config,
       _client = client ?? http.Client(),
       _documentsDirectoryProvider = documentsDirectoryProvider;

  final LocalServerConfig _config;
  final http.Client _client;
  final Future<Directory> Function()? _documentsDirectoryProvider;
  final LocalBackendApiPaths paths;
  final Duration timeout;

  void dispose() {
    _client.close();
  }

  Future<String> ping() async {
    _ensureServerConfigured();
    final response = await _sendGet(paths.health);
    _ensureSuccess(response, expectedStatus: const {200, 204});
    return 'Conectado a ${_config.endpoint}';
  }

  Future<String> createProject({
    required String localProjectId,
    required String name,
    required String description,
    required ProjectExportConfig exportConfig,
    required ProjectProcessingConfig processingConfig,
  }) async {
    _ensureServerConfigured();
    final response = await _sendJson(
      method: 'POST',
      path: paths.createProject,
      body: {
        'localProjectId': localProjectId,
        'name': name,
        'description': description,
        'format': exportConfig.targetFormat.value,
        'export': exportConfig.toJson(),
        'processing': processingConfig.toJson(),
      },
      expectedStatus: const {200, 201},
    );

    final json = _decodeJsonObject(response.bodyBytes, operation: 'crear proyecto');
    final data = _readMap(json, const ['data', 'project']);
    final projectId =
        _readString(data, const ['id', 'projectId', 'project_id']) ??
        _readString(json, const ['id', 'projectId', 'project_id']);

    if (projectId == null) {
      throw const BackendApiException(
        message: 'El backend no devolvio el id del proyecto.',
      );
    }

    return projectId;
  }

  Future<void> uploadImages({
    required String remoteProjectId,
    required List<String> imagePaths,
    void Function(int sent, int total)? onProgress,
  }) async {
    _ensureServerConfigured();
    if (imagePaths.isEmpty) {
      throw const BackendApiException(
        message: 'No hay imagenes para subir al backend.',
      );
    }

    for (int index = 0; index < imagePaths.length; index++) {
      await uploadImage(
        remoteProjectId: remoteProjectId,
        imagePath: imagePaths[index],
      );
      onProgress?.call(index + 1, imagePaths.length);
    }
  }

  Future<void> uploadImage({
    required String remoteProjectId,
    required String imagePath,
  }) async {
    _ensureServerConfigured();
    final file = File(imagePath);
    if (!await file.exists()) {
      throw BackendApiException(
        message: 'No se encontro la imagen para subir.',
        details: imagePath,
      );
    }

    final uri = _buildUri(paths.uploadImageFor(remoteProjectId));
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers(includeJson: false));
    request.fields['projectId'] = remoteProjectId;
    request.fields['project_id'] = remoteProjectId;
    request.files.add(
      await http.MultipartFile.fromPath(
        'files',
        imagePath,
        filename: file.uri.pathSegments.isEmpty
            ? 'capture.jpg'
            : file.uri.pathSegments.last,
      ),
    );

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(timeout);
    } on TimeoutException {
      throw const BackendApiException(
        message: 'Tiempo de espera agotado al subir imagen.',
      );
    } on SocketException {
      throw const BackendApiException(
        message: 'Sin conexion al backend al subir imagen.',
      );
    } on HandshakeException {
      throw const BackendApiException(
        message: 'Error TLS/SSL al subir imagen.',
      );
    }

    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response, expectedStatus: const {200, 201, 202, 204});
  }

  Future<void> startProcessing({
    required String remoteProjectId,
    required ProjectExportConfig exportConfig,
    required ProjectProcessingConfig processingConfig,
  }) async {
    _ensureServerConfigured();
    await _sendJson(
      method: 'POST',
      path: paths.startProcessingFor(remoteProjectId),
      body: {
        'output_format': exportConfig.targetFormat.value,
        'processing': processingConfig.toJson(),
      },
      expectedStatus: const {200, 201, 202, 204},
    );
  }

  Future<BackendProcessingStatus> fetchStatus({
    required String remoteProjectId,
  }) async {
    _ensureServerConfigured();
    final response = await _sendGet(paths.statusFor(remoteProjectId));
    _ensureSuccess(response, expectedStatus: const {200});

    final decoded = _decodeJson(response.bodyBytes, operation: 'consultar estado');
    if (decoded is Map<String, dynamic>) {
      return BackendProcessingStatus.fromJson(decoded);
    }
    if (decoded is Map) {
      return BackendProcessingStatus.fromJson(Map<String, dynamic>.from(decoded));
    }
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      final first = decoded.first;
      if (first is Map<String, dynamic>) {
        return BackendProcessingStatus.fromJson(first);
      }
      return BackendProcessingStatus.fromJson(Map<String, dynamic>.from(first));
    }

    throw const BackendApiException(
      message: 'Respuesta de estado invalida del backend.',
    );
  }

  Future<String> downloadModelToProject({
    required String remoteProjectId,
    required String localProjectId,
    String? preferredFormat,
    String? preferredModelUrl,
  }) async {
    _ensureServerConfigured();

    if (preferredModelUrl != null && preferredModelUrl.trim().isNotEmpty) {
      return _downloadFromUrl(
        rawUrl: preferredModelUrl.trim(),
        localProjectId: localProjectId,
        fallbackFormat: preferredFormat,
      );
    }

    final response = await _sendGet(
      paths.modelFor(remoteProjectId),
      acceptBinary: true,
    );
    _ensureSuccess(response, expectedStatus: const {200});

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (_looksLikeJson(contentType)) {
      final json = _decodeJsonObject(
        response.bodyBytes,
        operation: 'obtener modelo',
      );
      final modelData = _readMap(json, const ['model', 'result', 'data']);
      final downloadUrl =
          _readString(modelData, const ['url', 'downloadUrl', 'download_url']) ??
          _readString(json, const ['url', 'downloadUrl', 'download_url']);
      final format =
          _readString(modelData, const ['format', 'extension']) ??
          _readString(json, const ['format', 'extension']) ??
          preferredFormat;

      final base64Data =
          _readString(modelData, const ['base64', 'data']) ??
          _readString(json, const ['base64', 'data']);
      if (base64Data != null) {
        try {
          final bytes = base64Decode(base64Data);
          return _saveModelBytes(
            bytes: bytes,
            localProjectId: localProjectId,
            extension: _normalizedExtension(format) ?? 'glb',
          );
        } on FormatException {
          throw const BackendApiException(
            message: 'El backend devolvio un modelo base64 invalido.',
          );
        }
      }

      if (downloadUrl == null || downloadUrl.trim().isEmpty) {
        throw const BackendApiException(
          message: 'El backend no devolvio URL ni contenido del modelo.',
        );
      }

      return _downloadFromUrl(
        rawUrl: downloadUrl,
        localProjectId: localProjectId,
        fallbackFormat: format ?? preferredFormat,
      );
    }

    final filename = _readFileNameFromDisposition(
      response.headers['content-disposition'],
    );
    final extension =
        _extensionFromPath(filename) ??
        _extensionFromContentType(contentType) ??
        _normalizedExtension(preferredFormat) ??
        'glb';

    return _saveModelBytes(
      bytes: response.bodyBytes,
      localProjectId: localProjectId,
      extension: extension,
    );
  }

  Future<String> _downloadFromUrl({
    required String rawUrl,
    required String localProjectId,
    String? fallbackFormat,
  }) async {
    final uri = _buildUri(rawUrl);
    final response = await _sendGetAbsolute(uri, acceptBinary: true);
    _ensureSuccess(response, expectedStatus: const {200});

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final fileName = _readFileNameFromDisposition(
      response.headers['content-disposition'],
    );
    final extension =
        _extensionFromPath(uri.path) ??
        _extensionFromPath(fileName) ??
        _extensionFromContentType(contentType) ??
        _normalizedExtension(fallbackFormat) ??
        'glb';

    return _saveModelBytes(
      bytes: response.bodyBytes,
      localProjectId: localProjectId,
      extension: extension,
    );
  }

  Future<String> _saveModelBytes({
    required List<int> bytes,
    required String localProjectId,
    required String extension,
  }) async {
    final docs = _documentsDirectoryProvider != null
        ? await _documentsDirectoryProvider!()
        : await getApplicationDocumentsDirectory();
    final modelsDir = Directory(
      '${docs.path}${Platform.pathSeparator}generated_models'
      '${Platform.pathSeparator}$localProjectId',
    );
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final normalizedExt = _normalizedExtension(extension) ?? 'glb';
    final file = File(
      '${modelsDir.path}${Platform.pathSeparator}'
      'model_remote_${DateTime.now().millisecondsSinceEpoch}.$normalizedExt',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<http.Response> _sendJson({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    Set<int> expectedStatus = const {200},
  }) async {
    final uri = _buildUri(path);
    final encodedBody = jsonEncode(body);
    http.Response response;

    try {
      switch (method.toUpperCase()) {
        case 'POST':
          response = await _client
              .post(uri, headers: _headers(), body: encodedBody)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: _headers(), body: encodedBody)
              .timeout(timeout);
          break;
        default:
          throw BackendApiException(
            message: 'Metodo HTTP no soportado para JSON.',
            details: method,
          );
      }
    } on TimeoutException {
      throw const BackendApiException(
        message: 'Tiempo de espera agotado con el backend.',
      );
    } on SocketException {
      throw const BackendApiException(
        message: 'No se pudo conectar con el backend local.',
      );
    } on HandshakeException {
      throw const BackendApiException(
        message: 'Error TLS/SSL con el backend local.',
      );
    }

    _ensureSuccess(response, expectedStatus: expectedStatus);
    return response;
  }

  Future<http.Response> _sendGet(String path, {bool acceptBinary = false}) {
    return _sendGetAbsolute(_buildUri(path), acceptBinary: acceptBinary);
  }

  Future<http.Response> _sendGetAbsolute(
    Uri uri, {
    bool acceptBinary = false,
  }) async {
    try {
      return await _client
          .get(uri, headers: _headers(acceptBinary: acceptBinary))
          .timeout(timeout);
    } on TimeoutException {
      throw const BackendApiException(
        message: 'Tiempo de espera agotado con el backend.',
      );
    } on SocketException {
      throw const BackendApiException(
        message: 'No se pudo conectar con el backend local.',
      );
    } on HandshakeException {
      throw const BackendApiException(
        message: 'Error TLS/SSL con el backend local.',
      );
    }
  }

  void _ensureServerConfigured() {
    if (!_config.enabled) {
      throw const BackendApiException(
        message:
            'La integracion con backend local esta deshabilitada en Ajustes.',
      );
    }
    if (_config.host.trim().isEmpty || _config.port <= 0 || _config.port > 65535) {
      throw const BackendApiException(
        message: 'La configuracion del backend local es invalida.',
      );
    }
  }

  Uri _buildUri(String pathOrUrl) {
    final normalized = pathOrUrl.trim();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Uri.parse(normalized);
    }

    final base = Uri.parse(_config.endpoint);
    if (normalized.startsWith('/')) return base.resolve(normalized);
    return base.resolve('/$normalized');
  }

  Map<String, String> _headers({
    bool includeJson = true,
    bool acceptBinary = false,
  }) {
    final headers = <String, String>{
      if (includeJson) 'Content-Type': 'application/json',
      'Accept': acceptBinary ? '*/*' : 'application/json',
    };

    final apiKey = _config.apiKey?.trim();
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['x-api-key'] = apiKey;
      headers['Authorization'] = 'Bearer $apiKey';
    }

    return headers;
  }

  void _ensureSuccess(http.Response response, {Set<int> expectedStatus = const {200}}) {
    if (expectedStatus.contains(response.statusCode)) return;
    throw BackendApiException(
      message: 'Respuesta inesperada del backend.',
      statusCode: response.statusCode,
      details: _extractErrorMessage(response),
    );
  }

  Object? _decodeJson(List<int> body, {required String operation}) {
    if (body.isEmpty) {
      throw BackendApiException(
        message: 'El backend devolvio una respuesta vacia al $operation.',
      );
    }

    try {
      return jsonDecode(utf8.decode(body));
    } on FormatException {
      throw BackendApiException(
        message: 'El backend devolvio un JSON invalido al $operation.',
      );
    }
  }

  Map<String, dynamic> _decodeJsonObject(
    List<int> body, {
    required String operation,
  }) {
    final decoded = _decodeJson(body, operation: operation);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw BackendApiException(
      message: 'El backend devolvio un payload invalido al $operation.',
    );
  }

  bool _looksLikeJson(String contentType) {
    return contentType.contains('application/json') ||
        contentType.contains('text/json') ||
        contentType.contains('+json');
  }

  String _extractErrorMessage(http.Response response) {
    final body = response.bodyBytes;
    if (body.isEmpty) return 'Sin detalles de error.';

    try {
      final decoded = jsonDecode(utf8.decode(body));
      if (decoded is Map<String, dynamic>) {
        final message = _readString(
          decoded,
          const ['message', 'error', 'detail', 'description'],
        );
        if (message != null) return message;
      }
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final message = _readString(
          map,
          const ['message', 'error', 'detail', 'description'],
        );
        if (message != null) return message;
      }
    } catch (_) {
      // Fallback to plain text body below.
    }

    final text = utf8.decode(body, allowMalformed: true).trim();
    if (text.isEmpty) return 'Sin detalles de error.';
    return text.length <= 240 ? text : '${text.substring(0, 240)}...';
  }

  static Map<String, dynamic>? _readMap(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String? _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return null;
  }

  static String? _normalizedExtension(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase().replaceAll('.', '');
    if (normalized.isEmpty) return null;
    return switch (normalized) {
      'gltf' => 'glb',
      'glb' || 'obj' || 'fbx' || 'usdz' => normalized,
      _ => normalized,
    };
  }

  static String? _extensionFromPath(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final normalized = path.trim();
    final dot = normalized.lastIndexOf('.');
    if (dot < 0 || dot == normalized.length - 1) return null;
    return _normalizedExtension(normalized.substring(dot + 1));
  }

  static String? _extensionFromContentType(String contentType) {
    if (contentType.contains('model/gltf-binary')) return 'glb';
    if (contentType.contains('model/obj') || contentType.contains('text/plain')) {
      return 'obj';
    }
    if (contentType.contains('application/octet-stream')) return null;
    return null;
  }

  static String? _readFileNameFromDisposition(String? disposition) {
    if (disposition == null || disposition.isEmpty) return null;
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    if (match == null) return null;
    final name = match.group(1)?.trim();
    return name == null || name.isEmpty ? null : name;
  }
}
