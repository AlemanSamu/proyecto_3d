import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'data/settings/local_server_config_store.dart';
import 'domain/settings/local_server_config.dart';
import 'presentation/providers/settings_providers.dart';
import 'presentation/screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  const defaultConfig = LocalServerConfig();
  final configStore = LocalServerConfigStore(preferences: preferences);
  final initialConfig = configStore.load(defaults: defaultConfig);

  runApp(
    ProviderScope(
      overrides: [
        defaultLocalServerConfigProvider.overrideWithValue(defaultConfig),
        localServerConfigStoreProvider.overrideWithValue(configStore),
        initialLocalServerConfigProvider.overrideWithValue(initialConfig),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Captura Guiada 3D',
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
