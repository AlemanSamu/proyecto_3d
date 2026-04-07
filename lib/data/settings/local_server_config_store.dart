import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/settings/local_server_config.dart';

class LocalServerConfigStore {
  LocalServerConfigStore({SharedPreferences? preferences})
    : _preferences = preferences;

  final SharedPreferences? _preferences;

  static const _baseUrlKey = 'local_backend_base_url';
  static const _apiKeyKey = 'local_backend_api_key';
  static const _enabledKey = 'local_backend_enabled';
  static const _autoSyncKey = 'local_backend_auto_sync';

  LocalServerConfig load({
    LocalServerConfig defaults = const LocalServerConfig(),
  }) {
    final preferences = _preferences;
    if (preferences == null) {
      _log('Using in-memory defaults', defaults);
      return defaults;
    }

    final storedApiKey = _readText(preferences.getString(_apiKeyKey));
    final config = defaults.copyWith(
      baseUrl: preferences.getString(_baseUrlKey) ?? defaults.baseUrl,
      enabled: preferences.getBool(_enabledKey) ?? defaults.enabled,
      autoSync: preferences.getBool(_autoSyncKey) ?? defaults.autoSync,
      apiKey: storedApiKey,
      clearApiKey: storedApiKey == null,
    );
    _log('Loaded persisted config', config);
    return config;
  }

  Future<void> save(LocalServerConfig config) async {
    final preferences = _preferences;
    if (preferences == null) {
      _log('Skipped persistence without SharedPreferences', config);
      return;
    }

    await preferences.setString(_baseUrlKey, config.endpoint);
    await preferences.setBool(_enabledKey, config.enabled);
    await preferences.setBool(_autoSyncKey, config.autoSync);

    final apiKey = _readText(config.apiKey);
    if (apiKey == null) {
      await preferences.remove(_apiKeyKey);
    } else {
      await preferences.setString(_apiKeyKey, apiKey);
    }

    _log('Saved config', config);
  }

  static String? _readText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  static void _log(String action, LocalServerConfig config) {
    if (!kDebugMode) return;
    debugPrint(
      '[LocalServerConfigStore] '
      '$action baseUrl=${config.endpoint} apiKeySet=${config.apiKey?.isNotEmpty == true}',
    );
  }
}
