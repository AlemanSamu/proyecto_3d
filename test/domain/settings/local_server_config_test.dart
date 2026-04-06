import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/domain/settings/local_server_config.dart';

void main() {
  test('default local server config points to the local backend', () {
    const config = LocalServerConfig();

    expect(config.host, '192.168.1.100');
    expect(config.port, 8000);
    expect(config.enabled, isTrue);
    expect(config.endpoint, 'http://192.168.1.100:8000');
  });

  test('fromJson defaults enabled to true when the field is missing', () {
    final config = LocalServerConfig.fromJson({
      'host': '10.0.0.2',
      'port': 9000,
    });

    expect(config.host, '10.0.0.2');
    expect(config.port, 9000);
    expect(config.enabled, isTrue);
  });
}