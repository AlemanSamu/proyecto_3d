import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/projects/project_model.dart';
import '../../domain/projects/project_workflow.dart';
import '../providers/project_providers.dart';
import '../widgets/app_metric_card.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_section_badge.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/project_overview_card.dart';
import 'capture/capture_screen.dart';
import 'capture_review_workspace_screen.dart';
import 'export_workbench_screen.dart';

class ProjectsHubScreen extends ConsumerStatefulWidget {
  const ProjectsHubScreen({super.key, required this.onOpenProject});

  final Future<void> Function(String projectId) onOpenProject;

  @override
  ConsumerState<ProjectsHubScreen> createState() => _ProjectsHubScreenState();
}

class _ProjectsHubScreenState extends ConsumerState<ProjectsHubScreen> {
  String _query = '';
  ProjectStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final filtered = _filteredProjects(projects);
    final capturing = projects
        .where((project) => project.status == ProjectStatus.capturing)
        .length;
    final reviewReady = projects
        .where((project) => project.status == ProjectStatus.reviewReady)
        .length;
    final modelsReady = projects
        .where((project) => project.hasGeneratedModel)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
      children: [
        AppPageHeader(
          title: 'Proyectos',
          subtitle:
              'Busca, filtra y continua cualquier proyecto sin abrir paneles redundantes.',
          trailing: FilledButton.icon(
            onPressed: () => _createProject(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo'),
          ),
          badge: const AppSectionBadge(
            label: 'Operacion local',
            color: Color(0xFF76A7FF),
            icon: Icons.dns_outlined,
          ),
        ),
        const SizedBox(height: 18),
        AppSurfaceCard(
          title: 'Busqueda y estado',
          subtitle: 'Encuentra rapido lo que sigue en el pipeline.',
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre o etapa',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null),
                    ),
                    for (final status in ProjectStatus.values) ...[
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: status.label,
                        selected: _statusFilter == status,
                        onTap: () => setState(() => _statusFilter = status),
                      ),
                    ],
                  ],
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
                      label: 'Total',
                      value: '${projects.length}',
                      accent: const Color(0xFF9AA5BD),
                    ),
                  ),
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'Captura',
                      value: '$capturing',
                      accent: const Color(0xFF76A7FF),
                    ),
                  ),
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'Revision',
                      value: '$reviewReady',
                      accent: const Color(0xFF7A8CFF),
                    ),
                  ),
                  SizedBox(
                    width: 148,
                    child: AppMetricCard(
                      label: 'Modelos',
                      value: '$modelsReady',
                      accent: const Color(0xFF4FD3C1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const AppSurfaceCard(
            title: 'Sin coincidencias',
            subtitle: 'No hay proyectos que coincidan con el filtro actual.',
          )
        else
          for (final project in filtered) ...[
            ProjectOverviewCard(
              project: project,
              onTap: () => widget.onOpenProject(project.id),
              trailing: PopupMenuButton<_ProjectAction>(
                tooltip: 'Acciones',
                color: const Color(0xFF111B27),
                onSelected: (action) => _handleAction(action, project),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _ProjectAction.capture,
                    child: Text('Continuar captura'),
                  ),
                  PopupMenuItem(
                    value: _ProjectAction.review,
                    child: Text('Revisar capturas'),
                  ),
                  PopupMenuItem(
                    value: _ProjectAction.configure,
                    child: Text('Configurar salida'),
                  ),
                  PopupMenuItem(
                    value: _ProjectAction.delete,
                    child: Text('Eliminar proyecto'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  List<ProjectModel> _filteredProjects(List<ProjectModel> projects) {
    final query = _query.trim().toLowerCase();
    final filtered = [
      for (final project in projects)
        if ((query.isEmpty ||
                project.name.toLowerCase().contains(query) ||
                project.status.label.toLowerCase().contains(query)) &&
            (_statusFilter == null || _statusFilter == project.status))
          project,
    ];
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }

  Future<void> _createProject(BuildContext context) async {
    final payload = await showProjectFormDialog(
      context,
      title: 'Nuevo proyecto',
      confirmLabel: 'Crear',
    );

    if (payload == null) return;

    ref
        .read(projectsProvider.notifier)
        .createProject(name: payload.name, description: payload.description);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proyecto creado correctamente.')),
    );
  }

  Future<void> _handleAction(
    _ProjectAction action,
    ProjectModel project,
  ) async {
    switch (action) {
      case _ProjectAction.capture:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaptureScreen(initialProjectId: project.id),
          ),
        );
        return;
      case _ProjectAction.review:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaptureReviewWorkspaceScreen(projectId: project.id),
          ),
        );
        return;
      case _ProjectAction.configure:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExportWorkbenchScreen(projectId: project.id),
          ),
        );
        return;
      case _ProjectAction.delete:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar proyecto'),
            content: Text(
              'Se eliminara "${project.name}" junto con sus capturas y artefactos locales. Esta accion no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        if (confirm != true || !mounted) return;
        ref.read(projectsProvider.notifier).deleteProject(project.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Proyecto eliminado.')));
        return;
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
    );
  }
}

enum _ProjectAction { capture, review, configure, delete }
