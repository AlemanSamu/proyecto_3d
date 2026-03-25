import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/camera_permission_service.dart';
import '../../../data/capture/camera_capture_service.dart';
import '../../../data/capture/gallery_save_service.dart';
import '../../../data/capture/photo_quality_analyzer.dart';
import '../../../data/capture/project_capture_storage.dart';
import '../../../domain/projects/project_model.dart';
import '../../../domain/projects/project_workflow.dart';
import '../../controllers/capture_flow_controller.dart';
import '../../providers/project_providers.dart';
import '../../utils/presentation_formatters.dart';
import '../../widgets/app_info_chip.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_section_badge.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/capture_guidance_ring.dart';
import '../../widgets/coverage_summary_panel.dart';
import '../../widgets/project_form_dialog.dart';
import '../../widgets/status_badge.dart';
import '../capture_photo_inspector_screen.dart';
import '../capture_review_workspace_screen.dart';
import '../export_workbench_screen.dart';
import '../project_workspace_screen.dart';
import 'capture_guide_plan.dart';
import 'guided_camera_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, this.initialProjectId});

  final String? initialProjectId;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  static const _targetMinPhotos = 24;
  static const _targetMaxPhotos = 48;

  final _permissionService = CameraPermissionService();
  late final CaptureFlowController _captureController;

  String? _activeProjectId;
  bool _capturing = false;
  bool _requireLiveQuality = true;

  @override
  void initState() {
    super.initState();
    _activeProjectId = widget.initialProjectId;
    _captureController = CaptureFlowController(
      permissionService: _permissionService,
      cameraService: DeviceCameraCaptureService(),
      qualityAnalyzer: IsolatePhotoQualityAnalyzer(),
      storage: LocalProjectCaptureStorage(),
      gallerySaver: DeviceGallerySaveService(),
      projectsNotifier: ref.read(projectsProvider.notifier),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final activeProject = _resolveActiveProject(projects);
    final nextStep = CaptureGuidePlan.stepForCaptureCount(
      activeProject?.photos.length ?? 0,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
      children: [
        AppPageHeader(
          title: 'Captura guiada',
          subtitle:
              'Una sola guia por toma, menos ruido visual y revision mas clara al terminar la sesion.',
          trailing: FilledButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo proyecto'),
          ),
          badge: AppSectionBadge(
            label: _requireLiveQuality ? 'Guia asistida' : 'Captura flexible',
            color: _requireLiveQuality
                ? const Color(0xFF4FD3C1)
                : const Color(0xFFFFB347),
            icon: Icons.camera_outdoor_outlined,
          ),
        ),
        const SizedBox(height: 18),
        _SessionSetupCard(
          projects: projects,
          activeProject: activeProject,
          requireLiveQuality: _requireLiveQuality,
          onProjectChanged: (value) => setState(() => _activeProjectId = value),
          onQualityModeChanged: (value) =>
              setState(() => _requireLiveQuality = value),
        ),
        const SizedBox(height: 12),
        _CameraLaunchCard(
          activeProject: activeProject,
          nextStep: nextStep,
          targetMinPhotos: _targetMinPhotos,
          targetMaxPhotos: _targetMaxPhotos,
          requireLiveQuality: _requireLiveQuality,
          capturing: _capturing,
          onCapture: () => _capture(activeProject),
        ),
        if (activeProject != null) ...[
          const SizedBox(height: 12),
          CoverageSummaryPanel(summary: activeProject.coverage),
          const SizedBox(height: 12),
          _ProjectWorkspaceCard(project: activeProject),
        ],
      ],
    );
  }

  ProjectModel? _resolveActiveProject(List<ProjectModel> projects) {
    if (projects.isEmpty) {
      if (_activeProjectId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _activeProjectId = null);
        });
      }
      return null;
    }

    for (final project in projects) {
      if (project.id == _activeProjectId) return project;
    }

    final fallback = projects.first;
    if (_activeProjectId != fallback.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _activeProjectId = fallback.id);
      });
    }
    return fallback;
  }

  Future<void> _createProject() async {
    final payload = await showProjectFormDialog(
      context,
      title: 'Crear proyecto',
      confirmLabel: 'Crear',
    );

    if (payload == null) return;

    final project = ref
        .read(projectsProvider.notifier)
        .createProject(name: payload.name, description: payload.description);

    if (!mounted) return;
    setState(() => _activeProjectId = project.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Proyecto creado.')));
  }

  Future<void> _capture(ProjectModel? project) async {
    if (_capturing || project == null) return;
    setState(() => _capturing = true);

    try {
      final permission = await _permissionService.request();
      final granted =
          permission == CameraPermissionState.granted ||
          permission == CameraPermissionState.limited;

      if (!granted) {
        if (!mounted) return;
        if (permission == CameraPermissionState.permanentlyDenied) {
          _showSnack(
            'Permiso de camara bloqueado. Abre Ajustes del dispositivo.',
          );
          await _permissionService.openSettings();
        } else {
          _showSnack('Permiso de camara denegado.');
        }
        return;
      }

      final nextStep = CaptureGuidePlan.stepForCaptureCount(
        project.photos.length,
      );
      if (!mounted) return;
      final session = await Navigator.of(context)
          .push<GuidedCameraSessionResult>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => GuidedCameraScreen(
                projectName: project.name,
                captureIndex: project.photos.length,
                targetMinPhotos: _targetMinPhotos,
                targetMaxPhotos: _targetMaxPhotos,
                levelKey: nextStep.level.key,
                levelLabel: nextStep.level.label,
                angleDeg: nextStep.angleDeg,
                requireLiveQualityGate: _requireLiveQuality,
              ),
            ),
          );

      if (!mounted || session == null || session.shots.isEmpty) return;

      int savedCount = 0;
      for (final shot in session.shots) {
        final result = await _captureController.processCapturedFile(
          projectId: project.id,
          sourcePath: shot.sourcePath,
          autoQuality: false,
          confirmLowQualitySave: (_) async => true,
          poseId: shot.poseId,
          angleDeg: shot.angleDeg,
          level: shot.level,
          brightness: shot.brightness,
          sharpness: shot.detail,
          accepted: shot.qualityOk,
          flaggedForRetake: !shot.qualityOk,
        );
        if (result.saved) savedCount++;
      }

      if (!mounted) return;
      _showSnack(
        'Sesion guardada: $savedCount de ${session.shots.length} capturas.',
      );

      final projectNow = ref.read(projectByIdProvider(project.id));
      if (projectNow != null && projectNow.photos.isNotEmpty) {
        await showModalBottomSheet<void>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sesion completada',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Puedes revisar las capturas ahora o volver a la pantalla de captura para seguir cubriendo el objeto.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Seguir capturando'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CaptureReviewWorkspaceScreen(
                                  projectId: project.id,
                                ),
                              ),
                            );
                          },
                          child: const Text('Ir a revision'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SessionSetupCard extends StatelessWidget {
  const _SessionSetupCard({
    required this.projects,
    required this.activeProject,
    required this.requireLiveQuality,
    required this.onProjectChanged,
    required this.onQualityModeChanged,
  });

  final List<ProjectModel> projects;
  final ProjectModel? activeProject;
  final bool requireLiveQuality;
  final ValueChanged<String> onProjectChanged;
  final ValueChanged<bool> onQualityModeChanged;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      title: 'Sesion activa',
      subtitle:
          'Selecciona el proyecto y define si la guia bloqueara tomas debiles.',
      trailing: activeProject == null
          ? null
          : StatusBadge(status: activeProject!.status, compact: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (projects.isEmpty)
            Text(
              'No hay proyectos disponibles. Crea uno para comenzar la captura.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: activeProject?.id,
              decoration: const InputDecoration(labelText: 'Proyecto activo'),
              items: [
                for (final project in projects)
                  DropdownMenuItem(
                    value: project.id,
                    child: Text(project.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                onProjectChanged(value);
              },
            ),
            if (activeProject != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppInfoChip(
                    label: '${activeProject!.photos.length} capturas',
                    color: const Color(0xFF76A7FF),
                    icon: Icons.photo_library_outlined,
                  ),
                  AppInfoChip(
                    label:
                        '${activeProject!.coverage.acceptedPhotos} aceptadas',
                    color: const Color(0xFF57D684),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  AppInfoChip(
                    label: activeProject!.primaryActionLabel,
                    color: const Color(0xFF7A8CFF),
                    icon: Icons.route_outlined,
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 14),
          Container(
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
                      const Text(
                        'Control de calidad en vivo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        requireLiveQuality
                            ? 'La guia bloquea tomas con calidad insuficiente.'
                            : 'La guia permite disparar con mas flexibilidad.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: requireLiveQuality,
                  onChanged: onQualityModeChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraLaunchCard extends StatelessWidget {
  const _CameraLaunchCard({
    required this.activeProject,
    required this.nextStep,
    required this.targetMinPhotos,
    required this.targetMaxPhotos,
    required this.requireLiveQuality,
    required this.capturing,
    required this.onCapture,
  });

  final ProjectModel? activeProject;
  final CaptureGuideStep nextStep;
  final int targetMinPhotos;
  final int targetMaxPhotos;
  final bool requireLiveQuality;
  final bool capturing;
  final VoidCallback onCapture;

  List<int> get _capturedSectors {
    if (activeProject == null) return const [];
    final sectors = <int>{};
    for (final photo in activeProject!.photos) {
      final angle = photo.angleDeg;
      if (angle == null) continue;
      sectors.add((((angle % 360) + 360) % 360) ~/ 30 * 30);
    }
    return sectors.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final captured = activeProject?.photos.length ?? 0;
    final remaining = (targetMinPhotos - captured).clamp(0, targetMinPhotos);
    final progress = targetMinPhotos == 0
        ? 0.0
        : (captured / targetMinPhotos).clamp(0.0, 1.0);
    final canCapture = activeProject != null && !capturing;
    final actionLabel = activeProject == null
        ? 'Selecciona un proyecto'
        : captured == 0
        ? 'Comenzar captura'
        : 'Continuar captura';

    final preview = AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CaptureGuidanceRing(
            capturedSectors: _capturedSectors,
            suggestedAngle: nextStep.angleDeg,
            highlightColor: const Color(0xFF76A7FF),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.48),
                  border: Border.all(color: Colors.white24),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  '${nextStep.level.label} - ${nextStep.angleDeg} deg',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeProject == null
              ? 'Prepara un proyecto antes de abrir la camara.'
              : 'Una toma limpia por sector. El siguiente objetivo ya esta definido.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppInfoChip(
              icon: Icons.layers_outlined,
              label: 'Nivel ${nextStep.level.label}',
              color: const Color(0xFF76A7FF),
            ),
            AppInfoChip(
              icon: Icons.explore_outlined,
              label: 'Sector ${nextStep.angleDeg} deg',
              color: const Color(0xFF7A8CFF),
            ),
            AppInfoChip(
              icon: Icons.grid_view_rounded,
              label: '$captured/$targetMaxPhotos registradas',
              color: const Color(0xFF4FD3C1),
            ),
            AppInfoChip(
              icon: Icons.auto_fix_high_outlined,
              label: requireLiveQuality ? 'Calidad asistida' : 'Modo flexible',
              color: requireLiveQuality
                  ? const Color(0xFF4FD3C1)
                  : const Color(0xFFFFB347),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress, minHeight: 7),
        ),
        const SizedBox(height: 8),
        Text(
          remaining == 0
              ? 'La cobertura minima ya esta cubierta. Puedes seguir refinando la sesion.'
              : 'Faltan $remaining capturas para la cobertura minima recomendada.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canCapture ? onCapture : null,
            icon: capturing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.camera_alt_rounded),
            label: Text(capturing ? 'Abriendo camara...' : actionLabel),
          ),
        ),
      ],
    );

    return AppSurfaceCard(
      title: 'Camara guiada',
      subtitle: 'Overlay minimo, objetivo visible y progreso compacto.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: preview,
                ),
                const SizedBox(height: 18),
                content,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: preview),
              const SizedBox(width: 20),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectWorkspaceCard extends StatelessWidget {
  const _ProjectWorkspaceCard({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final orderedPhotos = [...project.photos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return AppSurfaceCard(
      title: 'Proyecto activo',
      subtitle: 'Acciones rapidas y ultimas tomas sin abrir paneles extra.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 210,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CaptureReviewWorkspaceScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Revision'),
                ),
              ),
              SizedBox(
                width: 210,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExportWorkbenchScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Salida'),
                ),
              ),
              SizedBox(
                width: 210,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ProjectWorkspaceScreen(projectId: project.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Abrir tablero'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Capturas recientes',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (orderedPhotos.isEmpty)
            Text(
              'Aun no hay capturas registradas para este proyecto.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            )
          else
            SizedBox(
              height: 138,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: orderedPhotos.length.clamp(0, 10),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final photo = orderedPhotos[index];
                  return SizedBox(
                    width: 118,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CapturePhotoInspectorScreen(
                              projectId: project.id,
                              photoId: photo.id,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(
                                    photo.thumbnailPath.isNotEmpty
                                        ? photo.thumbnailPath
                                        : photo.originalPath,
                                  ),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFF111727),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatCaptureDescriptor(
                                level: photo.level,
                                angleDeg: photo.angleDeg,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
