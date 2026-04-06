import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/projects/project_export_config.dart';
import '../../../domain/projects/project_model.dart';
import '../../../domain/projects/project_processing.dart';
import '../../../domain/projects/project_workflow.dart';
import '../../providers/project_providers.dart';
import '../../widgets/app_info_chip.dart';
import '../../widgets/app_metric_card.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_section_badge.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/project_overview_card.dart';
import '../../widgets/status_badge.dart';
import '../model_viewer_screen.dart';
import '../project_workspace_screen.dart';

class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final generatedModels = [
      for (final project in projects)
        if (project.hasGeneratedModel &&
            (_query.isEmpty ||
                project.name.toLowerCase().contains(_query.toLowerCase())))
          project,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final awaitingModels = [
      for (final project in projects)
        if (!project.hasGeneratedModel &&
            project.status == ProjectStatus.readyToProcess)
          project,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final exported = generatedModels
        .where((project) => project.status == ProjectStatus.exported)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
      children: [
        const AppPageHeader(
          title: 'Modelos',
          subtitle:
              'Artefactos listos, cola de generacion y acceso futuro al visor.',
          badge: AppSectionBadge(
            label: 'Listo para visor',
            color: Color(0xFF4FD3C1),
            icon: Icons.view_in_ar_outlined,
          ),
        ),
        const SizedBox(height: 18),
        AppSurfaceCard(
          title: 'Estado del modulo',
          subtitle: 'Todo el inventario importante del area de modelos.',
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  hintText: 'Buscar modelo por nombre de proyecto',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'Disponibles',
                      value: '${generatedModels.length}',
                      accent: const Color(0xFF4FD3C1),
                    ),
                  ),
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'Exportados',
                      value: '$exported',
                      accent: const Color(0xFF57D684),
                    ),
                  ),
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'En cola',
                      value: '${awaitingModels.length}',
                      accent: const Color(0xFFFFB347),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (generatedModels.isEmpty)
          const AppSurfaceCard(
            subtitle:
                'Todavia no hay modelos generados. Completa captura, revision y procesamiento en un proyecto.',
          )
        else ...[
          Text(
            'Modelos disponibles',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final project in generatedModels) ...[
            _ModelCard(project: project),
            const SizedBox(height: 10),
          ],
        ],
        if (awaitingModels.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Listos para generar',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final project in awaitingModels.take(3)) ...[
            ProjectOverviewCard(
              project: project,
              compact: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ProjectWorkspaceScreen(projectId: project.id),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      title: project.name,
      subtitle: project.modelPath == null
          ? 'Modelo pendiente de sincronizacion local'
          : project.modelPath!,
      trailing: StatusBadge(status: project.status, compact: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppInfoChip(
                label: project.exportConfig.targetFormat.label,
                color: const Color(0xFF7A8CFF),
                icon: Icons.inventory_2_outlined,
              ),
              AppInfoChip(
                label: project.processingConfig.profile.label,
                color: const Color(0xFF76A7FF),
                icon: Icons.tune_rounded,
              ),
              AppInfoChip(
                label: project.lastExportPackagePath == null
                    ? 'Sin paquete'
                    : 'Paquete listo',
                color: project.lastExportPackagePath == null
                    ? const Color(0xFF9AA5BD)
                    : const Color(0xFF57D684),
                icon: Icons.archive_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ProjectWorkspaceScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Abrir proyecto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ModelViewerScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.view_in_ar_rounded),
                  label: const Text('Abrir visor'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
