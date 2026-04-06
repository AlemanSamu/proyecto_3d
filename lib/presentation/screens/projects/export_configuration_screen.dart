import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/projects/project_export_config.dart';
import '../../../domain/projects/project_model.dart';
import '../../../domain/projects/project_processing.dart';
import '../../../domain/projects/project_workflow.dart';
import '../../providers/project_providers.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/export_configuration_panel.dart';
import '../../widgets/status_badge.dart';
import '../processing_progress_screen.dart';

class ExportConfigurationScreen extends ConsumerStatefulWidget {
  const ExportConfigurationScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ExportConfigurationScreen> createState() =>
      _ExportConfigurationScreenState();
}

class _ExportConfigurationScreenState
    extends ConsumerState<ExportConfigurationScreen> {
  late ProjectExportConfig _exportDraft;
  late ProjectProcessingConfig _processingDraft;
  bool _initialized = false;
  bool _processing = false;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exportacion')),
        body: const Center(child: Text('No se encontro el proyecto.')),
      );
    }

    if (!_initialized) {
      _exportDraft = project.exportConfig;
      _processingDraft = project.processingConfig;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion de salida')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppPageHeader(
            title: project.name,
            subtitle:
                'Define exportacion, procesa el proyecto y prepara el paquete final.',
            badge: StatusBadge(status: project.status, compact: true),
          ),
          const SizedBox(height: 12),
          AppSurfaceCard(
            title: 'Estado operativo',
            subtitle:
                '${project.coverage.acceptedPhotos} aceptadas - ${project.coverage.flaggedForRetake} retake',
            child: Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Formato',
                    value: _exportDraft.targetFormat.label,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Perfil',
                    value: _processingDraft.profile.label,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Modelo',
                    value: project.hasGeneratedModel ? 'Listo' : 'Pendiente',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ExportConfigurationPanel(
            config: _exportDraft,
            onChanged: (config) => setState(() => _exportDraft = config),
          ),
          const SizedBox(height: 12),
          _ProcessingPanel(
            config: _processingDraft,
            onChanged: (config) => setState(() => _processingDraft = config),
          ),
          const SizedBox(height: 12),
          _FinalSummary(
            project: project,
            exportConfig: _exportDraft,
            processingConfig: _processingDraft,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveDraft(project),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing || _exporting
                      ? null
                      : () => _processProject(project),
                  icon: _processing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.precision_manufacturing_rounded),
                  label: Text(_processing ? 'Procesando...' : 'Generar modelo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _processing ||
                      _exporting ||
                      !project.hasGeneratedModel
                  ? null
                  : () => _exportProject(project),
              icon: _exporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.archive_outlined),
              label: Text(_exporting ? 'Exportando...' : 'Generar paquete final'),
            ),
          ),
          if ((project.modelPath ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            AppSurfaceCard(
              title: 'Modelo local',
              subtitle: project.modelPath!,
            ),
          ],
          if ((project.lastExportPackagePath ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            AppSurfaceCard(
              title: 'Ultimo paquete exportado',
              subtitle: project.lastExportPackagePath!,
            ),
          ],
        ],
      ),
    );
  }

  void _saveDraft(ProjectModel project) {
    final notifier = ref.read(projectsProvider.notifier);
    notifier.updateExportConfig(project.id, _exportDraft);
    notifier.updateProcessingConfig(project.id, _processingDraft);
    if (project.status == ProjectStatus.reviewReady ||
        project.status == ProjectStatus.capturing ||
        project.status == ProjectStatus.draft) {
      notifier.updateStatus(project.id, ProjectStatus.readyToProcess);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Configuracion guardada.')));
  }

  Future<void> _processProject(ProjectModel project) async {
    if (project.coverage.acceptedPhotos == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes validar capturas antes de procesar.'),
        ),
      );
      return;
    }

    _saveDraft(project);
    setState(() => _processing = true);
    final effectiveProject = project.copyWith(
      exportConfig: _exportDraft,
      processingConfig: _processingDraft,
      status: ProjectStatus.readyToProcess,
    );

    final result = await ref
        .read(projectBackendControllerProvider)
        .submitForProcessing(effectiveProject);

    if (!mounted) return;
    setState(() => _processing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'El procesamiento ha finalizado.')),
    );

    if (result.success) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProcessingProgressScreen(projectId: project.id),
        ),
      );
    }
  }
  Future<void> _exportProject(ProjectModel project) async {
    _saveDraft(project);
    setState(() => _exporting = true);

    final effectiveProject = project.copyWith(
      exportConfig: _exportDraft,
      processingConfig: _processingDraft,
      status: project.status,
    );

    final result = await ref
        .read(projectExportControllerProvider)
        .exportProject(effectiveProject);

    if (!mounted) return;
    setState(() => _exporting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'No se pudo exportar.')),
    );
  }
}

class _ProcessingPanel extends StatelessWidget {
  const _ProcessingPanel({
    required this.config,
    required this.onChanged,
  });

  final ProjectProcessingConfig config;
  final ValueChanged<ProjectProcessingConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      title: 'Procesamiento',
      subtitle: 'Controla el perfil de reconstruccion previo a la exportacion',
      child: Column(
        children: [
          DropdownButtonFormField<ProcessingProfile>(
            initialValue: config.profile,
            decoration: const InputDecoration(labelText: 'Perfil'),
            items: [
              for (final profile in ProcessingProfile.values)
                DropdownMenuItem(value: profile, child: Text(profile.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              onChanged(config.copyWith(profile: value));
            },
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Eliminar fondo'),
            value: config.removeBackground,
            onChanged: (value) => onChanged(config.copyWith(removeBackground: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Eliminar artefactos flotantes'),
            value: config.removeFloatingArtifacts,
            onChanged: (value) =>
                onChanged(config.copyWith(removeFloatingArtifacts: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Generar texturas PBR'),
            value: config.generatePbrTextures,
            onChanged: (value) => onChanged(config.copyWith(generatePbrTextures: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Optimizar para movil'),
            value: config.optimizeForMobile,
            onChanged: (value) => onChanged(config.copyWith(optimizeForMobile: value)),
          ),
        ],
      ),
    );
  }
}

class _FinalSummary extends StatelessWidget {
  const _FinalSummary({
    required this.project,
    required this.exportConfig,
    required this.processingConfig,
  });

  final ProjectModel project;
  final ProjectExportConfig exportConfig;
  final ProjectProcessingConfig processingConfig;

  @override
  Widget build(BuildContext context) {
    final destination = exportConfig.destination == ExportDestination.localServer
        ? (exportConfig.destinationPath ?? 'Servidor local sin endpoint')
        : 'Dispositivo local';

    return AppSurfaceCard(
      title: 'Resumen final',
      subtitle: 'Validacion previa antes de generar artefactos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(label: 'Formato', value: exportConfig.targetFormat.label),
          _Line(label: 'Calidad', value: exportConfig.qualityPreset.label),
          _Line(label: 'Texturas', value: exportConfig.textureQuality.label),
          _Line(label: 'Geometria', value: exportConfig.geometryQuality.label),
          _Line(label: 'Escala', value: exportConfig.scaleUnit.label),
          _Line(label: 'Destino', value: destination),
          _Line(label: 'Perfil', value: processingConfig.profile.label),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              project.missingRecommendedPhotos == 0
                  ? 'Cobertura minima cumplida para procesamiento.'
                  : 'Faltan ${project.missingRecommendedPhotos} capturas recomendadas para una cobertura completa.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
