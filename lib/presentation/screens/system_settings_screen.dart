import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/settings/local_server_config.dart';
import '../../domain/settings/capture_app_settings.dart';
import '../providers/capture_settings_providers.dart';
import '../providers/settings_providers.dart';
import '../screens/capture/capture_profile.dart';
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
  int _selectedSection = 0;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(localServerSettingsProvider);
    final serverNotifier = ref.read(localServerSettingsProvider.notifier);
    final captureSettings = ref.watch(captureAppSettingsProvider);
    final captureNotifier = ref.read(captureAppSettingsProvider.notifier);

    if (!_initialized) {
      _syncControllers(serverState.config);
      _initialized = true;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Text(
          'Configuracion',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ajustes simples para backend y captura.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<int>(value: 0, label: Text('Basico')),
            ButtonSegment<int>(value: 1, label: Text('Avanzado')),
          ],
          selected: {_selectedSection},
          onSelectionChanged: (value) {
            if (value.isEmpty) return;
            setState(() => _selectedSection = value.first);
          },
        ),
        const SizedBox(height: 12),
        if (_selectedSection == 0)
          _buildBasic(serverState: serverState, notifier: serverNotifier)
        else
          _buildAdvanced(settings: captureSettings, notifier: captureNotifier),
      ],
    );
  }

  Widget _buildBasic({
    required LocalServerSettingsState serverState,
    required LocalServerSettingsNotifier notifier,
  }) {
    final status = switch (serverState.health) {
      ServerConnectionHealth.reachable => (
        'Conectado',
        const Color(0xFF57D684),
      ),
      ServerConnectionHealth.unreachable => (
        'Sin conexion',
        const Color(0xFFFF7D7D),
      ),
      ServerConnectionHealth.checking => (
        'Verificando...',
        const Color(0xFFFFB347),
      ),
      ServerConnectionHealth.unknown => (
        'Revisar configuracion',
        const Color(0xFFC3CAD9),
      ),
    };

    return AppSurfaceCard(
      title: 'Backend',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: status.$2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: status.$2.withValues(alpha: 0.32)),
            ),
            child: Text(
              status.$1,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL backend',
              hintText: 'http://192.168.1.120:8000',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiController,
            obscureText: !_showApiKey,
            decoration: InputDecoration(
              labelText: 'API key',
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: serverState.isChecking
                      ? null
                      : () => _saveServerConfig(notifier),
                  child: const Text('Guardar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
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
                  child: Text(
                    serverState.isChecking ? 'Probando...' : 'Probar conexion',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanced({
    required CaptureAppSettings settings,
    required CaptureAppSettingsNotifier notifier,
  }) {
    final profile = CaptureProfileX.fromKey(settings.captureProfileKey);
    final resolution = CaptureResolutionX.fromKey(
      settings.captureResolutionKey,
    );

    return AppSurfaceCard(
      title: 'Captura avanzada',
      child: Column(
        children: [
          DropdownButtonFormField<CaptureProfile>(
            initialValue: profile,
            decoration: const InputDecoration(labelText: 'Perfil de captura'),
            items: [
              for (final option in CaptureProfile.values)
                DropdownMenuItem(value: option, child: Text(option.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              notifier.updateProfile(value.key);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<CaptureResolution>(
            initialValue: resolution,
            decoration: const InputDecoration(labelText: 'Resolucion'),
            items: [
              for (final option in CaptureResolution.values)
                DropdownMenuItem(value: option, child: Text(option.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              notifier.updateResolution(value.name);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: settings.maxPhotos,
            decoration: const InputDecoration(labelText: 'Maximo de fotos'),
            items: const [30, 36, 45, 60, 80, 100]
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text('$value')),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              notifier.updateMaxPhotos(value);
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearTemporaryFiles,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Limpiar temporales'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearTemporaryFiles() async {
    var deleted = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      final entities = tempDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is! File) continue;
        final path = entity.path.toLowerCase();
        if (!path.endsWith('.jpg') && !path.endsWith('.jpeg')) continue;
        await entity.delete();
        deleted++;
      }
    } catch (_) {
      // best effort
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Temporales limpiados: $deleted')));
  }

  void _syncControllers(LocalServerConfig config) {
    _baseUrlController.text = config.endpoint;
    _apiController.text = config.apiKey ?? '';
  }

  bool _saveServerConfig(
    LocalServerSettingsNotifier notifier, {
    bool showFeedback = true,
  }) {
    final normalizedBaseUrl = LocalServerConfig.normalizeBaseUrl(
      _baseUrlController.text,
    );
    if (normalizedBaseUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa una URL valida.')));
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
