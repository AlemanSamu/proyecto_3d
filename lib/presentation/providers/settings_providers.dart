import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/backend_api_exception.dart';
import '../../data/services/local_backend_api_service.dart';
import '../../data/settings/local_server_config_store.dart';
import '../../domain/settings/local_server_config.dart';

enum ServerConnectionHealth { unknown, checking, reachable, unreachable }

class LocalServerSettingsState {
  const LocalServerSettingsState({
    this.config = const LocalServerConfig(),
    this.defaultConfig = const LocalServerConfig(),
    this.health = ServerConnectionHealth.unknown,
    this.lastMessage,
    this.lastCheckedAt,
  });

  final LocalServerConfig config;
  final LocalServerConfig defaultConfig;
  final ServerConnectionHealth health;
  final String? lastMessage;
  final DateTime? lastCheckedAt;

  bool get isChecking => health == ServerConnectionHealth.checking;
  bool get isUsingDefaultBaseUrl => config.endpoint == defaultConfig.endpoint;
  bool? get isReachable => switch (health) {
    ServerConnectionHealth.reachable => true,
    ServerConnectionHealth.unreachable => false,
    _ => null,
  };

  LocalServerSettingsState copyWith({
    LocalServerConfig? config,
    LocalServerConfig? defaultConfig,
    ServerConnectionHealth? health,
    String? lastMessage,
    bool clearLastMessage = false,
    DateTime? lastCheckedAt,
  }) {
    return LocalServerSettingsState(
      config: config ?? this.config,
      defaultConfig: defaultConfig ?? this.defaultConfig,
      health: health ?? this.health,
      lastMessage: clearLastMessage ? null : (lastMessage ?? this.lastMessage),
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

class LocalServerSettingsNotifier
    extends StateNotifier<LocalServerSettingsState> {
  LocalServerSettingsNotifier({
    required Future<String> Function(LocalServerConfig config) pingBackend,
    required Future<void> Function(LocalServerConfig config) persistConfig,
    required LocalServerConfig initialConfig,
    required LocalServerConfig defaultConfig,
  }) : _pingBackend = pingBackend,
       _persistConfig = persistConfig,
       super(
         LocalServerSettingsState(
           config: initialConfig,
           defaultConfig: defaultConfig,
         ),
       );

  final Future<String> Function(LocalServerConfig config) _pingBackend;
  final Future<void> Function(LocalServerConfig config) _persistConfig;

  void updateConfig(LocalServerConfig config) {
    _applyConfig(config);
  }

  void setEnabled(bool enabled) {
    _applyConfig(state.config.copyWith(enabled: enabled));
  }

  void setAutoSync(bool autoSync) {
    _applyConfig(state.config.copyWith(autoSync: autoSync));
  }

  void updateBaseUrl(String baseUrl) {
    final normalized = LocalServerConfig.normalizeBaseUrl(baseUrl);
    _applyConfig(state.config.copyWith(baseUrl: normalized));
  }

  void updateEndpoint({
    required String host,
    required int port,
    required bool useHttps,
  }) {
    final normalized = LocalServerConfig.normalizeBaseUrl(
      host,
      fallbackScheme: useHttps ? 'https' : 'http',
      fallbackPort: port,
    );
    _applyConfig(state.config.copyWith(baseUrl: normalized));
  }

  void updateApiKey(String? apiKey) {
    final normalized = apiKey?.trim() ?? '';
    _applyConfig(
      normalized.isEmpty
          ? state.config.copyWith(clearApiKey: true)
          : state.config.copyWith(apiKey: normalized),
    );
  }

  void restoreDefaultBaseUrl() {
    _applyConfig(state.config.copyWith(baseUrl: state.defaultConfig.baseUrl));
  }

  Future<void> testConnection() async {
    state = state.copyWith(
      health: ServerConnectionHealth.checking,
      clearLastMessage: true,
    );

    final config = state.config;
    try {
      final message = await _pingBackend(config);
      state = state.copyWith(
        health: ServerConnectionHealth.reachable,
        lastMessage: message,
        lastCheckedAt: DateTime.now(),
      );
    } on BackendApiException catch (error) {
      state = state.copyWith(
        health: ServerConnectionHealth.unreachable,
        lastMessage: error.message,
        lastCheckedAt: DateTime.now(),
      );
    } catch (_) {
      state = state.copyWith(
        health: ServerConnectionHealth.unreachable,
        lastMessage: 'No se pudo establecer conexion con el backend.',
        lastCheckedAt: DateTime.now(),
      );
    }
  }

  void _applyConfig(LocalServerConfig config) {
    state = state.copyWith(
      config: config,
      health: ServerConnectionHealth.unknown,
      clearLastMessage: true,
    );
    unawaited(_persistConfig(config));
  }
}

final defaultLocalServerConfigProvider = Provider<LocalServerConfig>((ref) {
  return const LocalServerConfig();
});

final localServerConfigStoreProvider = Provider<LocalServerConfigStore>((ref) {
  return LocalServerConfigStore();
});

final initialLocalServerConfigProvider = Provider<LocalServerConfig>((ref) {
  final defaults = ref.watch(defaultLocalServerConfigProvider);
  return ref.watch(localServerConfigStoreProvider).load(defaults: defaults);
});

final localBackendApiPathsProvider = Provider<LocalBackendApiPaths>((ref) {
  return const LocalBackendApiPaths();
});

final localBackendApiServiceProvider = Provider<LocalBackendApiService>((ref) {
  final service = LocalBackendApiService(
    config: ref.watch(localServerSettingsProvider).config,
    paths: ref.watch(localBackendApiPathsProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final localServerSettingsProvider =
    StateNotifierProvider<
      LocalServerSettingsNotifier,
      LocalServerSettingsState
    >((ref) {
      final store = ref.watch(localServerConfigStoreProvider);
      final defaultConfig = ref.watch(defaultLocalServerConfigProvider);
      final initialConfig = ref.watch(initialLocalServerConfigProvider);

      return LocalServerSettingsNotifier(
        initialConfig: initialConfig,
        defaultConfig: defaultConfig,
        persistConfig: store.save,
        pingBackend: (config) {
          final service = LocalBackendApiService(
            config: config,
            paths: ref.read(localBackendApiPathsProvider),
          );
          return service.ping().whenComplete(service.dispose);
        },
      );
    });
