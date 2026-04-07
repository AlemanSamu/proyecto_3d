import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/data/settings/local_server_config_store.dart';
import 'package:proyecto_3d/domain/settings/local_server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load prefers stored base URL and API key over defaults', () async {
    SharedPreferences.setMockInitialValues({
      'local_backend_base_url': 'http://nombre-pc:8000',
      'local_backend_api_key': 'secreta',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = LocalServerConfigStore(preferences: preferences);

    final config = store.load(
      defaults: const LocalServerConfig(baseUrl: 'http://127.0.0.1:8000'),
    );

    expect(config.endpoint, 'http://nombre-pc:8000');
    expect(config.apiKey, 'secreta');
  });

  test('save persists normalized URL and removes empty API key', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = LocalServerConfigStore(preferences: preferences);

    await store.save(
      const LocalServerConfig(
        baseUrl: 'http://10.221.168.227:8000',
        apiKey: null,
        autoSync: true,
      ),
    );

    expect(
      preferences.getString('local_backend_base_url'),
      'http://10.221.168.227:8000',
    );
    expect(preferences.getString('local_backend_api_key'), isNull);
    expect(preferences.getBool('local_backend_auto_sync'), isTrue);
  });
}
