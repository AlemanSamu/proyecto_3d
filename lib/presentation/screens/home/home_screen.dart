import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/project_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/project_form_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onNavigateToTab});

  final void Function(int index) onNavigateToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(localServerSettingsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Text(
          'Inicio',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 38,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Captura limpia para reconstruccion 3D.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        _BackendStatusCard(health: server.health),
        const SizedBox(height: 16),
        SizedBox(
          height: 58,
          child: ElevatedButton.icon(
            onPressed: () => _createProject(context, ref, onNavigateToTab),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Nuevo escaneo'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => onNavigateToTab(2),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Historial'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => onNavigateToTab(4),
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Configuracion'),
          ),
        ),
      ],
    );
  }
}

class _BackendStatusCard extends StatelessWidget {
  const _BackendStatusCard({required this.health});

  final ServerConnectionHealth health;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (health) {
      ServerConnectionHealth.reachable => (
        'Conectado',
        const Color(0xFF59D98E),
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
        const Color(0xFFC4CCDA),
      ),
    };

    return AppSurfaceCard(
      title: 'Backend',
      subtitle: 'Estado de conexion',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, color: color, size: 12),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _createProject(
  BuildContext context,
  WidgetRef ref,
  void Function(int index) onNavigateToTab,
) async {
  final payload = await showProjectFormDialog(
    context,
    title: 'Nuevo escaneo',
    confirmLabel: 'Crear y capturar',
  );

  if (payload == null) return;

  ref
      .read(projectsProvider.notifier)
      .createProject(name: payload.name, description: payload.description);

  if (!context.mounted) return;
  onNavigateToTab(1);
}
