import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/domain/settings/local_server_config.dart';

void main() {
  test('default local server config points to the local backend base URL', () {
    const config = LocalServerConfig();

    expect(config.baseUrl, 'http://127.0.0.1:8000');
    expect(config.enabled, isTrue);
    expect(config.endpoint, 'http://127.0.0.1:8000');
  });

  test(
    'fromJson keeps backward compatibility with legacy host and port fields',
    () {
      final config = LocalServerConfig.fromJson({
        'host': '10.0.0.2',
        'port': 9000,
      });

      expect(config.endpoint, 'http://10.0.0.2:9000');
      expect(config.enabled, isTrue);
    },
  );

  test('normalizes hostnames without scheme using http by default', () {
    final normalized = LocalServerConfig.normalizeBaseUrl('nombre-pc:8000');

    expect(normalized, 'http://nombre-pc:8000');
  });

  test('strips pasted health paths and preserves protocol and port', () {
    final normalized = LocalServerConfig.normalizeBaseUrl(
      'https://192.168.0.15:9443/health',
    );

    expect(normalized, 'https://192.168.0.15:9443');
  });

  test('normalizeEndpointInput remains compatible with older host-port UI', () {
    final normalized = LocalServerConfig.normalizeEndpointInput(
      rawHost: '192.168.0.15:8010/health',
      fallbackPort: 8000,
      fallbackUseHttps: false,
    );

    expect(normalized.host, '192.168.0.15');
    expect(normalized.port, 8010);
    expect(normalized.useHttps, isFalse);
  });

  test('builds endpoint URIs safely for IPv6 hosts', () {
    const config = LocalServerConfig(baseUrl: 'http://[2001:db8::10]:8000');

    expect(config.endpoint, 'http://[2001:db8::10]:8000');
  });
}
