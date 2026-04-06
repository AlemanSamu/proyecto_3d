import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/backend_api_exception.dart';
import '../../data/services/local_backend_api_service.dart';
import '../../domain/settings/local_server_config.dart';

enum ServerConnectionHealth { unknown, checking, reachable, unreachable }

class LocalServerSettingsState {
  const LocalServerSettingsState({
    this.config = const LocalServerConfig(
      host: '192.168.1.100',
      port: 8000,
    ),
    this.health = ServerConnectionHealth.unknown,
    this.lastMessage,
    this.lastCheckedAt,
  });

  final LocalServerConfig config;
  final ServerConnectionHealth health;
  final String? lastMessage;
  final DateTime? lastCheckedAt;

  bool get isChecking => health == ServerConnectionHealth.checking;
  bool? get isReachable => switch (health) {
    ServerConnectionHealth.reachable => true,
    ServerConnectionHealth.unreachable => false,
    _ => null,
  };

  LocalServerSettingsState copyWith({
    LocalServerConfig? config,
    ServerConnectionHealth? health,
    String? lastMessage,
    bool clearLastMessage = false,
    DateTime? lastCheckedAt,
  }) {
    return LocalServerSettingsState(
      config: config ?? this.config,
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
  }) : _pingBackend = pingBackend,
       super(const LocalServerSettingsState());

  final Future<String> Function(LocalServerConfig config) _pingBackend;

  void updateConfig(LocalServerConfig config) {
    state = state.copyWith(config: config);
  }

  void setEnabled(bool enabled) {
    state = state.copyWith(config: state.config.copyWith(enabled: enabled));
  }

  void setAutoSync(bool autoSync) {
    state = state.copyWith(config: state.config.copyWith(autoSync: autoSync));
  }

  void updateEndpoint({
    required String host,
    required int port,
    required bool useHttps,
  }) {
    state = state.copyWith(
      config: state.config.copyWith(host: host, port: port, useHttps: useHttps),
    );
  }

  void updateApiKey(String? apiKey) {
    final normalized = apiKey?.trim() ?? '';
    state = state.copyWith(
      config: normalized.isEmpty
          ? state.config.copyWith(clearApiKey: true)
          : state.config.copyWith(apiKey: normalized),
    );
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
}

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
      return LocalServerSettingsNotifier(
        pingBackend: (config) {
          final service = LocalBackendApiService(
            config: config,
            paths: ref.read(localBackendApiPathsProvider),
          );
          return service.ping().whenComplete(service.dispose);
        },
      );
    });
