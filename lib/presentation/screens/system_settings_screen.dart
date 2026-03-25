import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _apiController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(localServerSettingsProvider);
    final notifier = ref.read(localServerSettingsProvider.notifier);

    if (!_initialized) {
      final config = serverState.config;
      _hostController.text = config.host;
      _portController.text = '${config.port}';
      _apiController.text = config.apiKey ?? '';
      _initialized = true;
    }

    final statusText = switch (serverState.health) {
      ServerConnectionHealth.reachable =>
        serverState.lastMessage ?? 'Conectado',
      ServerConnectionHealth.unreachable =>
        serverState.lastMessage ?? 'Sin conexion',
      ServerConnectionHealth.checking => 'Validando conectividad local',
      ServerConnectionHealth.unknown => 'Aun no se ha validado la conexion',
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
              'Configuracion local limpia y lista para la futura integracion con servidor.',
          badge: AppSectionBadge(
            label: 'Infraestructura local',
            color: Color(0xFF76A7FF),
            icon: Icons.settings_ethernet_outlined,
          ),
        ),
        const SizedBox(height: 18),
        AppSurfaceCard(
          title: 'Estado local',
          subtitle: 'Lectura rapida del servidor y del modo de sincronizacion.',
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
                      label: 'Canal',
                      value: serverState.config.useHttps ? 'HTTPS' : 'HTTP',
                      accent: const Color(0xFF7A8CFF),
                    ),
                  ),
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'Sync',
                      value: serverState.config.autoSync ? 'Auto' : 'Manual',
                      accent: const Color(0xFF76A7FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.34),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionBadge(
                      label: switch (serverState.health) {
                        ServerConnectionHealth.reachable =>
                          'Servidor operativo',
                        ServerConnectionHealth.unreachable => 'Sin conexion',
                        ServerConnectionHealth.checking => 'Validando',
                        ServerConnectionHealth.unknown => 'Pendiente',
                      },
                      color: statusColor,
                      compact: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      serverState.config.endpoint,
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
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          title: 'Servidor local',
          subtitle:
              'Mantiene la configuracion lista para paquetes, procesos y sincronizacion local.',
          child: Column(
            children: [
              _SettingsToggleRow(
                title: 'Habilitar servidor local',
                subtitle: 'Activa la futura integracion con backend local.',
                value: serverState.config.enabled,
                onChanged: notifier.setEnabled,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(labelText: 'Host'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Puerto'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apiController,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  hintText: 'token_local_123',
                ),
              ),
              const SizedBox(height: 12),
              _SettingsToggleRow(
                title: 'Usar HTTPS',
                subtitle: 'Cambia el protocolo del endpoint local.',
                value: serverState.config.useHttps,
                onChanged: (value) => notifier.updateEndpoint(
                  host: _hostController.text.trim(),
                  port: int.tryParse(_portController.text.trim()) ?? 8080,
                  useHttps: value,
                ),
              ),
              const SizedBox(height: 10),
              _SettingsToggleRow(
                title: 'Auto-sync',
                subtitle: 'Prepara la app para sincronizacion automatica.',
                value: serverState.config.autoSync,
                onChanged: notifier.setAutoSync,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: serverState.isChecking
                          ? null
                          : () => _saveServerConfig(notifier),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: serverState.isChecking
                          ? null
                          : () async {
                              _saveServerConfig(notifier);
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
                            ? 'Probando...'
                            : 'Probar conexion',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveServerConfig(LocalServerSettingsNotifier notifier) {
    notifier.updateEndpoint(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 8080,
      useHttps: ref.read(localServerSettingsProvider).config.useHttps,
    );
    notifier.updateApiKey(_apiController.text);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Configuracion guardada.')));
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
