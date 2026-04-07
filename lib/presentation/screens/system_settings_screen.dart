import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/settings/local_server_config.dart';
import '../providers/settings_providers.dart';
import '../widgets/app_metric_card.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_section_badge.dart';
import '../widgets/app_surface_card.dart';

class SystemSettingsScreen extends ConsumerStatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  ConsumerState<SystemSettingsScreen> createState() =>
      _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends ConsumerState<SystemSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _apiController = TextEditingController();
  bool _initialized = false;
  bool _showApiKey = false;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(localServerSettingsProvider);
    final notifier = ref.read(localServerSettingsProvider.notifier);

    if (!_initialized) {
      _syncControllers(serverState.config);
      _initialized = true;
    }

    final statusText = switch (serverState.health) {
      ServerConnectionHealth.reachable =>
        serverState.lastMessage ?? 'Conexion validada correctamente.',
      ServerConnectionHealth.unreachable =>
        serverState.lastMessage ?? 'No se pudo conectar al backend.',
      ServerConnectionHealth.checking =>
        'Consultando /health del backend local...',
      ServerConnectionHealth.unknown => 'Aun no se ha probado la conexion.',
    };
    final statusColor = switch (serverState.health) {
      ServerConnectionHealth.reachable => const Color(0xFF57D684),
      ServerConnectionHealth.unreachable => const Color(0xFFFF7D7D),
      ServerConnectionHealth.checking => const Color(0xFFFFB347),
      ServerConnectionHealth.unknown => const Color(0xFFC2C9D8),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
      children: [
        const AppPageHeader(
          title: 'Ajustes',
          subtitle:
              'Configura el backend local con una URL estable, una API key y una validacion rapida de conectividad.',
          badge: AppSectionBadge(
            label: 'Backend local',
            color: Color(0xFF76A7FF),
            icon: Icons.settings_ethernet_outlined,
          ),
        ),
        const SizedBox(height: 18),
        AppSurfaceCard(
          title: 'Estado local',
          subtitle: 'Resumen de la configuracion activa para la app Flutter.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'Servidor',
                      value: serverState.config.enabled ? 'Activo' : 'Inactivo',
                      accent: serverState.config.enabled
                          ? const Color(0xFF4FD3C1)
                          : const Color(0xFFBBC3D5),
                    ),
                  ),
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'Origen',
                      value: serverState.isUsingDefaultBaseUrl
                          ? 'Default'
                          : 'Personalizado',
                      accent: const Color(0xFF7A8CFF),
                    ),
                  ),
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'API key',
                      value: (serverState.config.apiKey ?? '').isEmpty
                          ? 'Vacia'
                          : 'Configurada',
                      accent: const Color(0xFF76A7FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StatusPanel(
                statusColor: statusColor,
                statusText: statusText,
                currentUrl: serverState.config.endpoint,
                defaultUrl: serverState.defaultConfig.endpoint,
                health: serverState.health,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          title: 'Conexion al backend',
          subtitle:
              'Admite IP, hostname o URLs privadas mas estables para el servidor local.',
          child: Column(
            children: [
              _SettingsToggleRow(
                title: 'Habilitar servidor local',
                subtitle: 'Activa la integracion con el backend FastAPI.',
                value: serverState.config.enabled,
                onChanged: notifier.setEnabled,
              ),
              const SizedBox(height: 12),
              _SettingsToggleRow(
                title: 'Auto-sync',
                subtitle: 'Conserva la opcion para futuros flujos automaticos.',
                value: serverState.config.autoSync,
                onChanged: notifier.setAutoSync,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL base del backend',
                  hintText: 'http://nombre-pc:8000',
                  helperText:
                      'Ejemplos: http://10.221.168.227:8000 o http://nombre-pc:8000',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apiController,
                obscureText: !_showApiKey,
                decoration: InputDecoration(
                  labelText: 'API key',
                  hintText: 'token_local_123',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showApiKey = !_showApiKey),
                    icon: Icon(
                      _showApiKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Valor por defecto actual: ${serverState.defaultConfig.endpoint}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: serverState.isChecking
                          ? null
                          : () => _restoreDefaultBaseUrl(notifier),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Restaurar default'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: serverState.isChecking
                          ? null
                          : () => _saveServerConfig(notifier),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: serverState.isChecking
                      ? null
                      : () async {
                          if (!_saveServerConfig(
                            notifier,
                            showFeedback: false,
                          )) {
                            return;
                          }
                          await notifier.testConnection();
                        },
                  icon: serverState.isChecking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.network_check_rounded),
                  label: Text(
                    serverState.isChecking
                        ? 'Probando conexion...'
                        : 'Probar conexion',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _syncControllers(LocalServerConfig config) {
    _baseUrlController.text = config.endpoint;
    _apiController.text = config.apiKey ?? '';
  }

  void _restoreDefaultBaseUrl(LocalServerSettingsNotifier notifier) {
    notifier.restoreDefaultBaseUrl();
    final restored = ref.read(localServerSettingsProvider).config;
    _baseUrlController.text = restored.endpoint;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL restaurada al valor por defecto.')),
    );
  }

  bool _saveServerConfig(
    LocalServerSettingsNotifier notifier, {
    bool showFeedback = true,
  }) {
    final normalizedBaseUrl = LocalServerConfig.normalizeBaseUrl(
      _baseUrlController.text,
    );
    if (normalizedBaseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una URL base valida para el backend.'),
        ),
      );
      return false;
    }

    notifier.updateBaseUrl(normalizedBaseUrl);
    notifier.updateApiKey(_apiController.text);
    final normalizedConfig = ref.read(localServerSettingsProvider).config;
    _syncControllers(normalizedConfig);

    if (showFeedback) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuracion guardada.')));
    }
    return true;
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.statusColor,
    required this.statusText,
    required this.currentUrl,
    required this.defaultUrl,
    required this.health,
  });

  final Color statusColor;
  final String statusText;
  final String currentUrl;
  final String defaultUrl;
  final ServerConnectionHealth health;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionBadge(
            label: switch (health) {
              ServerConnectionHealth.reachable => 'Servidor operativo',
              ServerConnectionHealth.unreachable => 'Sin conexion',
              ServerConnectionHealth.checking => 'Validando',
              ServerConnectionHealth.unknown => 'Pendiente',
            },
            color: statusColor,
            compact: true,
          ),
          const SizedBox(height: 10),
          Text(
            currentUrl.isEmpty ? 'URL no configurada' : currentUrl,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Default: $defaultUrl',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
