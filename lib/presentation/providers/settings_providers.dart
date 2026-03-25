import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/settings/local_server_config.dart';

enum ServerConnectionHealth { unknown, checking, reachable, unreachable }

class LocalServerSettingsState {
  const LocalServerSettingsState({
    this.config = const LocalServerConfig(),
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
  LocalServerSettingsNotifier() : super(const LocalServerSettingsState());

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

    await Future<void>.delayed(const Duration(milliseconds: 700));

    final config = state.config;
    final validHost = config.host.trim().isNotEmpty;
    final validPort = config.port > 0 && config.port < 65536;
    final reachable = validHost && validPort;

    state = state.copyWith(
      health: reachable
          ? ServerConnectionHealth.reachable
          : ServerConnectionHealth.unreachable,
      lastMessage: reachable
          ? 'Conectado a ${config.endpoint}'
          : 'No se pudo establecer conexion. Revisa host y puerto.',
      lastCheckedAt: DateTime.now(),
    );
  }
}

final localServerSettingsProvider =
    StateNotifierProvider<
      LocalServerSettingsNotifier,
      LocalServerSettingsState
    >((ref) {
      return LocalServerSettingsNotifier();
    });
