import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto_3d/data/services/local_backend_api_service.dart';
import 'package:proyecto_3d/domain/settings/local_server_config.dart';

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

  test('resolves project endpoints under base URL path prefixes', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        '{"status":"processing","message":"ok"}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = LocalBackendApiService(
      config: const LocalServerConfig(baseUrl: 'http://127.0.0.1:8000/api/v1'),
      client: client,
    );
    addTearDown(service.dispose);

    await service.fetchStatus(remoteProjectId: 'demo');

    expect(
      requestedUri?.toString(),
      'http://127.0.0.1:8000/api/v1/projects/demo/status',
    );
  });

  test(
    'does not duplicate API prefix when download URL is already prefixed',
    () async {
      final requestedUris = <Uri>[];
      final tempDocs = Directory.systemTemp.createTempSync(
        'local_backend_api_service_test_',
      );
      addTearDown(() async {
        if (tempDocs.existsSync()) {
          await tempDocs.delete(recursive: true);
        }
      });

      final client = MockClient((request) async {
        requestedUris.add(request.url);
        return http.Response.bytes(
          const [0x67, 0x6C, 0x54, 0x46],
          200,
          headers: {
            'content-type': 'model/gltf-binary',
            'content-disposition': 'attachment; filename="demo.glb"',
          },
        );
      });
      final service = LocalBackendApiService(
        config: const LocalServerConfig(
          baseUrl: 'http://127.0.0.1:8000/api/v1',
        ),
        client: client,
        documentsDirectoryProvider: () async => tempDocs,
      );
      addTearDown(service.dispose);

      final modelPath = await service.downloadModelToProject(
        remoteProjectId: 'demo',
        localProjectId: 'local-demo',
        preferredModelUrl: '/api/v1/projects/demo/model',
      );

      expect(
        requestedUris.single.toString(),
        'http://127.0.0.1:8000/api/v1/projects/demo/model',
      );
      expect(File(modelPath).existsSync(), isTrue);
    },
  );

  test('probeConnection keeps API prefix when backend suggests host', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://127.0.0.1:8000/api/v1/health');
      return http.Response(
        '{"status":"ok","network":{"preferred_base_url":"http://backend-pc:8000","advertised_urls":["http://backend-pc:8000"]}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = LocalBackendApiService(
      config: const LocalServerConfig(baseUrl: 'http://127.0.0.1:8000/api/v1'),
      client: client,
    );
    addTearDown(service.dispose);

    final probe = await service.probeConnection();

    expect(probe.message, contains('URL recomendada'));
    expect(probe.resolvedConfig?.endpoint, 'http://backend-pc:8000/api/v1');
  });

  test(
    'ping retries Android emulator fallback when loopback is unreachable',
    () async {
      final requested = <Uri>[];
      final client = MockClient((request) async {
        requested.add(request.url);
        if (request.url.host == '127.0.0.1') {
          throw const SocketException('connection refused');
        }
        if (request.url.host == '10.0.2.2') {
          return http.Response(
            '{"status":"ok","network":{"advertised_urls":["http://10.0.2.2:8000"]}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        throw StateError('Host no esperado en test: ${request.url.host}');
      });

      final service = LocalBackendApiService(
        config: const LocalServerConfig(baseUrl: 'http://127.0.0.1:8000'),
        client: client,
      );
      addTearDown(service.dispose);

      final message = await service.ping();

      expect(message, contains('Conexion OK'));
      expect(
        requested.any((uri) => uri.host == '10.0.2.2' && uri.path == '/health'),
        isTrue,
      );
    },
  );
}
