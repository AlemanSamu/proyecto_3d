class LocalServerConfig {
  const LocalServerConfig({
    this.host = '192.168.1.100',
    this.port = 8000,
    this.useHttps = false,
    this.autoSync = false,
    this.enabled = true,
    this.apiKey,
  });

  final String host;
  final int port;
  final bool useHttps;
  final bool autoSync;
  final bool enabled;
  final String? apiKey;

  String get endpoint {
    final protocol = useHttps ? 'https' : 'http';
    return '$protocol://$host:$port';
  }

  LocalServerConfig copyWith({
    String? host,
    int? port,
    bool? useHttps,
    bool? autoSync,
    bool? enabled,
    String? apiKey,
    bool clearApiKey = false,
  }) {
    return LocalServerConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useHttps: useHttps ?? this.useHttps,
      autoSync: autoSync ?? this.autoSync,
      enabled: enabled ?? this.enabled,
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'useHttps': useHttps,
      'autoSync': autoSync,
      'enabled': enabled,
      'apiKey': apiKey,
    };
  }

  factory LocalServerConfig.fromJson(Map<String, dynamic> json) {
    final parsedPort = json['port'];
    return LocalServerConfig(
      host: json['host'] as String? ?? '192.168.1.100',
      port: parsedPort is int ? parsedPort : 8000,
      useHttps: json['useHttps'] as bool? ?? false,
      autoSync: json['autoSync'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
      apiKey: _readText(json['apiKey']),
    );
  }

  static String? _readText(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
