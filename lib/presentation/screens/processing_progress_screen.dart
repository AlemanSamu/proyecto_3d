import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projects/project_model.dart';
import '../../domain/projects/project_processing.dart';
import '../../domain/projects/project_workflow.dart';
import '../providers/project_providers.dart';
import '../utils/presentation_formatters.dart';
import '../widgets/app_info_chip.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_section_badge.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/state_feedback_card.dart';
import '../widgets/status_badge.dart';
import 'model_viewer_screen.dart';

class ProcessingProgressScreen extends ConsumerStatefulWidget {
  const ProcessingProgressScreen({
    super.key,
    required this.projectId,
    this.autoPoll = true,
  });

  final String projectId;
  final bool autoPoll;

  @override
  ConsumerState<ProcessingProgressScreen> createState() =>
      _ProcessingProgressScreenState();
}

class _ProcessingProgressScreenState
    extends ConsumerState<ProcessingProgressScreen> {
  Timer? _pollTimer;
  bool _refreshing = false;
  bool _autoPoll = true;
  bool _initialLoading = true;
  String? _errorMessage;
  DateTime? _lastCheckedAt;

  @override
  void initState() {
    super.initState();
    _autoPoll = widget.autoPoll;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshStatus(manual: false);
      if (_autoPoll) _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progreso')),
        body: const Center(child: Text('No se encontro el proyecto.')),
      );
    }

    final progress = project.processingState.progress.clamp(0, 1).toDouble();
    final progressPct = (progress * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Progreso de procesamiento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          AppPageHeader(
            title: project.name,
            subtitle:
                'Seguimiento en tiempo real del backend local para reconstruccion 3D.',
            badge: AppSectionBadge(
              label: project.status.label,
              color: StatusBadge.colorFor(project.status),
              icon: Icons.sync_rounded,
            ),
            trailing: FilledButton.icon(
              onPressed: _refreshing ? null : () => _refreshStatus(manual: true),
              icon: _refreshing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(_refreshing ? 'Consultando...' : 'Actualizar'),
            ),
          ),
          const SizedBox(height: 12),
          if (_initialLoading)
            const StateFeedbackCard(
              title: 'Cargando estado',
              message: 'Consultando el backend local...',
              icon: Icons.hourglass_top_rounded,
            ),
          if (!_initialLoading && _errorMessage != null) ...[
            StateFeedbackCard(
              title: 'Error de red',
              message: _errorMessage!,
              icon: Icons.wifi_off_rounded,
              tint: const Color(0xFFFF7D7D),
              actionLabel: 'Reintentar',
              onAction: () => _refreshStatus(manual: true),
            ),
            const SizedBox(height: 12),
          ],
          AppSurfaceCard(
            title: 'Pipeline remoto',
            subtitle: project.processingState.stage.label,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppInfoChip(
                      label: 'Progreso $progressPct%',
                      color: const Color(0xFF76A7FF),
                      icon: Icons.stacked_line_chart_rounded,
                    ),
                    AppInfoChip(
                      label: project.remoteStatus ?? 'Sin estado remoto',
                      color: const Color(0xFF8F7BFF),
                      icon: Icons.cloud_queue_rounded,
                    ),
                    if ((project.remoteProjectId ?? '').isNotEmpty)
                      AppInfoChip(
                        label: 'ID remoto ${project.remoteProjectId}',
                        color: const Color(0xFF4FD3C1),
                        icon: Icons.tag_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  project.processingState.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress == 0 ? null : progress,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _buildLastCheckText(project),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-actualizacion'),
                  subtitle: const Text('Consulta estado cada 3 segundos'),
                  value: _autoPoll,
                  onChanged: (enabled) => _toggleAutoPoll(enabled),
                ),
              ],
            ),
          ),
          if ((project.remoteErrorMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            StateFeedbackCard(
              title: 'Error remoto',
              message: project.remoteErrorMessage!,
              icon: Icons.error_outline_rounded,
              tint: const Color(0xFFFF6E6E),
            ),
          ],
          if (project.hasGeneratedModel) ...[
            const SizedBox(height: 12),
            AppSurfaceCard(
              title: 'Modelo listo',
              subtitle: project.modelPath ?? 'Modelo descargado del backend.',
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ModelViewerScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.view_in_ar_rounded),
                  label: const Text('Abrir visor 3D'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refreshStatus({required bool manual}) async {
    final project = ref.read(projectByIdProvider(widget.projectId));
    if (project == null || _refreshing) return;

    setState(() {
      _refreshing = true;
      if (manual) _errorMessage = null;
    });

    final result = await ref
        .read(projectBackendControllerProvider)
        .refreshStatus(project);

    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _initialLoading = false;
      _lastCheckedAt = DateTime.now();
      _errorMessage = result.success ? null : result.message;
      if (result.isCompleted || result.isFailed) {
        _autoPoll = false;
        _pollTimer?.cancel();
      }
    });
  }

  void _toggleAutoPoll(bool enabled) {
    setState(() => _autoPoll = enabled);
    if (enabled) {
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final project = ref.read(projectByIdProvider(widget.projectId));
      if (project == null) return;
      if (project.hasGeneratedModel || project.status == ProjectStatus.error) {
        _toggleAutoPoll(false);
        return;
      }
      _refreshStatus(manual: false);
    });
  }

  String _buildLastCheckText(ProjectModel project) {
    final when = _lastCheckedAt ?? project.processingState.updatedAt;
    if (when.millisecondsSinceEpoch <= 0) {
      return 'Sin consultas recientes.';
    }
    return 'Ultima consulta: ${formatDateTime(when)}';
  }
}
