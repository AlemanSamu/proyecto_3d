class NormalizedLocalServerEndpoint {
  const NormalizedLocalServerEndpoint({
    required this.host,
    required this.port,
    required this.useHttps,
  });

  final String host;
  final int port;
  final bool useHttps;
}

class LocalServerDefaults {
  static const String baseUrl = String.fromEnvironment(
    'LOCAL_BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}

class LocalServerConfig {
  const LocalServerConfig({
    this.baseUrl = LocalServerDefaults.baseUrl,
    this.autoSync = false,
    this.enabled = true,
    this.apiKey,
  });

  final String baseUrl;
  final bool autoSync;
  final bool enabled;
  final String? apiKey;

  Uri? get endpointUri => tryParseBaseUrl(baseUrl);

  String get endpoint => endpointUri?.toString() ?? '';

  String get host => endpointUri?.host ?? '';

  int get port {
    final uri = endpointUri;
    if (uri == null) return 0;
    if (uri.hasPort) return uri.port;
    return uri.scheme.toLowerCase() == 'https' ? 443 : 80;
  }

  bool get useHttps => endpointUri?.scheme.toLowerCase() == 'https';

  bool get hasValidEndpoint => endpointUri != null;

  static String normalizeBaseUrl(
    String rawBaseUrl, {
    String fallbackScheme = 'http',
    int? fallbackPort,
  }) {
    final trimmed = rawBaseUrl.trim();
    if (trimmed.isEmpty) return '';

    final normalizedScheme = fallbackScheme.toLowerCase() == 'https'
        ? 'https'
        : 'http';
    final candidate = trimmed.contains('://')
        ? trimmed
        : '$normalizedScheme://$trimmed';
    final parsed = Uri.tryParse(candidate);
    if (parsed == null || !parsed.hasScheme || parsed.host.trim().isEmpty) {
      return '';
    }

    final scheme = parsed.scheme.toLowerCase() == 'https' ? 'https' : 'http';
    final port = parsed.hasPort ? parsed.port : fallbackPort;
    return Uri(scheme: scheme, host: parsed.host.trim(), port: port).toString();
  }

  static Uri? tryParseBaseUrl(String rawBaseUrl) {
    final normalized = normalizeBaseUrl(rawBaseUrl);
    if (normalized.isEmpty) return null;
    return Uri.tryParse(normalized);
  }

  static NormalizedLocalServerEndpoint normalizeEndpointInput({
    required String rawHost,
    required int fallbackPort,
    required bool fallbackUseHttps,
  }) {
    final normalizedBaseUrl = normalizeBaseUrl(
      rawHost,
      fallbackScheme: fallbackUseHttps ? 'https' : 'http',
      fallbackPort: fallbackPort,
    );
    final parsed = Uri.tryParse(normalizedBaseUrl);
    if (parsed == null || parsed.host.trim().isEmpty) {
      return NormalizedLocalServerEndpoint(
        host: '',
        port: fallbackPort,
        useHttps: fallbackUseHttps,
      );
    }

    return NormalizedLocalServerEndpoint(
      host: parsed.host.trim(),
      port: parsed.hasPort ? parsed.port : fallbackPort,
      useHttps: parsed.scheme.toLowerCase() == 'https',
    );
  }

  LocalServerConfig copyWith({
    String? baseUrl,
    bool? autoSync,
    bool? enabled,
    String? apiKey,
    bool clearApiKey = false,
  }) {
    return LocalServerConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      autoSync: autoSync ?? this.autoSync,
      enabled: enabled ?? this.enabled,
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': endpoint,
      'autoSync': autoSync,
      'enabled': enabled,
      'apiKey': apiKey,
    };
  }

  factory LocalServerConfig.fromJson(Map<String, dynamic> json) {
    final baseUrl = _readText(json['baseUrl']);
    final legacyHost = _readText(json['host']);
    final parsedPort = _readInt(json['port']);
    final useHttps = json['useHttps'] as bool? ?? false;
    final resolvedBaseUrl = normalizeBaseUrl(
      baseUrl ?? legacyHost ?? LocalServerDefaults.baseUrl,
      fallbackScheme: useHttps ? 'https' : 'http',
      fallbackPort: parsedPort ?? 8000,
    );

    return LocalServerConfig(
      baseUrl: resolvedBaseUrl.isEmpty
          ? LocalServerDefaults.baseUrl
          : resolvedBaseUrl,
      autoSync: json['autoSync'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
      apiKey: _readText(json['apiKey']),
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _readText(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
