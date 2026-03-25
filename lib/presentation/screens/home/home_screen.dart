import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/projects/project_model.dart';
import '../../../domain/projects/project_workflow.dart';
import '../../providers/project_providers.dart';
import '../../widgets/app_info_chip.dart';
import '../../widgets/app_metric_card.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_section_badge.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/project_form_dialog.dart';
import '../../widgets/project_overview_card.dart';
import '../../widgets/status_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onNavigateToTab,
    required this.onOpenProject,
  });

  final void Function(int index) onNavigateToTab;
  final Future<void> Function(String projectId) onOpenProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final sorted = [...projects]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final latest = sorted.isEmpty ? null : sorted.first;
    final capturing = sorted
        .where((project) => project.status == ProjectStatus.capturing)
        .length;
    final reviewReady = sorted
        .where((project) => project.status == ProjectStatus.reviewReady)
        .length;
    final modelsReady = sorted
        .where((project) => project.hasGeneratedModel)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
      children: [
        AppPageHeader(
          title: 'Inicio',
          subtitle:
              'Continua el flujo sin ruido: crea, captura, revisa y abre modelos desde un punto claro.',
          trailing: FilledButton.icon(
            onPressed: () => _createProject(context, ref, onNavigateToTab),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo proyecto'),
          ),
          badge: const AppSectionBadge(
            label: 'Flujo guiado activo',
            color: Color(0xFF76A7FF),
            icon: Icons.auto_awesome_rounded,
          ),
        ),
        const SizedBox(height: 18),
        _OverviewCard(
          totalProjects: sorted.length,
          capturing: capturing,
          reviewReady: reviewReady,
          modelsReady: modelsReady,
          onNavigateToTab: onNavigateToTab,
        ),
        const SizedBox(height: 12),
        if (latest != null)
          _PriorityProjectCard(
            project: latest,
            onOpenProject: onOpenProject,
            onNavigateToTab: onNavigateToTab,
          )
        else
          AppSurfaceCard(
            title: 'Sin proyectos activos',
            subtitle: 'Crea el primer proyecto para abrir una sesion guiada.',
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _createProject(context, ref, onNavigateToTab),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear primer proyecto'),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recientes',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => onNavigateToTab(2),
              child: const Text('Ver proyectos'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (sorted.isEmpty)
          const AppSurfaceCard(
            subtitle: 'Todavia no hay proyectos registrados en esta sesion.',
          )
        else
          for (final project in sorted.take(3)) ...[
            ProjectOverviewCard(
              project: project,
              compact: true,
              onTap: () => onOpenProject(project.id),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.totalProjects,
    required this.capturing,
    required this.reviewReady,
    required this.modelsReady,
    required this.onNavigateToTab,
  });

  final int totalProjects;
  final int capturing;
  final int reviewReady;
  final int modelsReady;
  final void Function(int index) onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      title: 'Vista rapida',
      subtitle: 'Lo importante del flujo y accesos para seguir trabajando.',
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
                  label: 'Proyectos',
                  value: '$totalProjects',
                  accent: const Color(0xFF9AA5BD),
                ),
              ),
              SizedBox(
                width: 148,
                child: AppMetricCard(
                  label: 'En captura',
                  value: '$capturing',
                  accent: const Color(0xFF76A7FF),
                ),
              ),
              SizedBox(
                width: 148,
                child: AppMetricCard(
                  label: 'En revision',
                  value: '$reviewReady',
                  accent: const Color(0xFF7A8CFF),
                ),
              ),
              SizedBox(
                width: 148,
                child: AppMetricCard(
                  label: 'Modelos listos',
                  value: '$modelsReady',
                  accent: const Color(0xFF4FD3C1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 190,
                child: ElevatedButton.icon(
                  onPressed: () => onNavigateToTab(1),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Abrir captura'),
                ),
              ),
              SizedBox(
                width: 190,
                child: OutlinedButton.icon(
                  onPressed: () => onNavigateToTab(2),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Revisar proyectos'),
                ),
              ),
              SizedBox(
                width: 190,
                child: OutlinedButton.icon(
                  onPressed: () => onNavigateToTab(3),
                  icon: const Icon(Icons.view_in_ar_outlined),
                  label: const Text('Ver modelos'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityProjectCard extends StatelessWidget {
  const _PriorityProjectCard({
    required this.project,
    required this.onOpenProject,
    required this.onNavigateToTab,
  });

  final ProjectModel project;
  final Future<void> Function(String projectId) onOpenProject;
  final void Function(int index) onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final reviewSummary = project.reviewSummary;

    return AppSurfaceCard(
      title: 'Proyecto priorizado',
      subtitle: project.primaryActionDescription,
      trailing: StatusBadge(status: project.status, compact: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              project.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppInfoChip(
                icon: Icons.check_circle_outline_rounded,
                label: '${reviewSummary.accepted} aceptadas',
                color: const Color(0xFF57D684),
              ),
              AppInfoChip(
                icon: Icons.flag_outlined,
                label: '${reviewSummary.flagged} retake',
                color: const Color(0xFFFFB347),
              ),
              AppInfoChip(
                icon: Icons.grid_view_rounded,
                label: '${reviewSummary.missing} faltantes',
                color: const Color(0xFF76A7FF),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openPrimaryAction(project),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(project.primaryActionLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onOpenProject(project.id),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir detalle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPrimaryAction(ProjectModel project) {
    switch (project.primaryActionIntent) {
      case ProjectPrimaryActionIntent.capture:
        onNavigateToTab(1);
        return Future<void>.value();
      case ProjectPrimaryActionIntent.review:
      case ProjectPrimaryActionIntent.process:
      case ProjectPrimaryActionIntent.troubleshoot:
        return onOpenProject(project.id);
      case ProjectPrimaryActionIntent.models:
      case ProjectPrimaryActionIntent.export:
        onNavigateToTab(3);
        return Future<void>.value();
    }
  }
}

Future<void> _createProject(
  BuildContext context,
  WidgetRef ref,
  void Function(int index) onNavigateToTab,
) async {
  final payload = await showProjectFormDialog(
    context,
    title: 'Crear proyecto',
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
  onNavigateToTab(1);
}
