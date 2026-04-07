import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_providers.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_surface_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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

    final statusText = switch (serverState.isReachable) {
      true => serverState.lastMessage ?? 'Conectado',
      false => serverState.lastMessage ?? 'Sin conexion',
      null => 'Aun no se ha validado la conexion',
    };
    final statusColor = switch (serverState.isReachable) {
      true => const Color(0xFF57D684),
      false => const Color(0xFFFF7D7D),
      null => const Color(0xFFC2C9D8),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
      children: [
        const AppPageHeader(
          title: 'Ajustes',
          subtitle:
              'Configuracion general del entorno local. La gestion de proyectos vive ahora en la pestana Proyectos.',
          badge: _SettingsBadge(),
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          title: 'Servidor local',
          subtitle: 'Preparacion para envio de paquetes y procesos al backend local',
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Habilitar integracion de servidor local'),
                value: serverState.config.enabled,
                onChanged: notifier.setEnabled,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(labelText: 'Host o URL'),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Usar HTTPS'),
                      value: serverState.config.useHttps,
                      onChanged: (value) => notifier.updateEndpoint(
                        host: _hostController.text.trim(),
                        port: int.tryParse(_portController.text.trim()) ?? 8080,
                        useHttps: value,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-sync'),
                      value: serverState.config.autoSync,
                      onChanged: notifier.setAutoSync,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
                        serverState.isChecking ? 'Probando...' : 'Probar conexion',
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
    final normalizedConfig = ref.read(localServerSettingsProvider).config;
    _hostController.text = normalizedConfig.host;
    _portController.text = '${normalizedConfig.port}';
    notifier.updateApiKey(_apiController.text);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Configuracion guardada.')));
  }
}

class _SettingsBadge extends StatelessWidget {
  const _SettingsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4D92FF).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF4D92FF).withValues(alpha: 0.34)),
      ),
      child: Text(
        'Entorno local',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
