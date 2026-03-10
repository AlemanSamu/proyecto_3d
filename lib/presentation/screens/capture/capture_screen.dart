import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/camera_permission_service.dart';
import '../../../data/capture/camera_capture_service.dart';
import '../../../data/capture/gallery_save_service.dart';
import '../../../data/capture/photo_quality_analyzer.dart';
import '../../../data/capture/project_capture_storage.dart';
import '../../../domain/projects/project_model.dart';
import '../../controllers/capture_flow_controller.dart';
import '../../providers/project_providers.dart';
import 'capture_guide_plan.dart';
import 'guided_camera_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  static const _targetMinPhotos = 24;
  static const _targetMaxPhotos = 48;
  static final List<CaptureGuideStep> _guidePlan =
      CaptureGuidePlan.alternating24;

  final _permissionService = CameraPermissionService();
  late final CaptureFlowController _captureController;

  bool _enforceLiveQuality = true;
  bool _capturing = false;
  String? _activeProjectId;

  @override
  void initState() {
    super.initState();
    _captureController = CaptureFlowController(
      permissionService: _permissionService,
      cameraService: DeviceCameraCaptureService(),
      qualityAnalyzer: IsolatePhotoQualityAnalyzer(),
      storage: LocalProjectCaptureStorage(),
      gallerySaver: DeviceGallerySaveService(),
      projectsNotifier: ref.read(projectsProvider.notifier),
    );
  }

  Future<void> _showCreateProjectDialog() async {
    final input = TextEditingController();
    final projectName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo proyecto'),
        content: TextField(
          controller: input,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Nombre del proyecto',
            hintText: 'Ej: Silla sala',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(input.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(input.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (!mounted || projectName == null || projectName.trim().isEmpty) return;

    final project = ref
        .read(projectsProvider.notifier)
        .createProject(name: projectName.trim());
    setState(() => _activeProjectId = project.id);
    _toast('Proyecto creado: ${project.name}');
  }

  Future<void> _capture(ProjectModel project) async {
    if (_capturing) return;
    setState(() => _capturing = true);

    try {
      final permission = await _permissionService.request();
      final granted =
          permission == CameraPermissionState.granted ||
          permission == CameraPermissionState.limited;

      if (!granted) {
        if (!mounted) return;
        if (permission == CameraPermissionState.permanentlyDenied) {
          _toast('Permiso de camara bloqueado. Abre Ajustes.');
          await _permissionService.openSettings();
        } else {
          _toast('Permiso de camara denegado.');
        }
        return;
      }

      final captureCount = project.imagePaths.length;
      final nextStep = captureCount < _guidePlan.length
          ? _guidePlan[captureCount]
          : _guidePlan.last;

      if (!mounted) return;
      final session = await Navigator.of(context)
          .push<GuidedCameraSessionResult>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => GuidedCameraScreen(
                projectName: project.name,
                captureIndex: captureCount,
                targetMinPhotos: _targetMinPhotos,
                targetMaxPhotos: _targetMaxPhotos,
                levelKey: nextStep.level.key,
                levelLabel: nextStep.level.label,
                angleDeg: nextStep.angleDeg,
                requireLiveQualityGate: _enforceLiveQuality,
              ),
            ),
          );

      if (!mounted || session == null || session.shots.isEmpty) return;

      int savedCount = 0;
      String? lastMessage;

      for (final shot in session.shots) {
        final result = await _captureController.processCapturedFile(
          projectId: project.id,
          sourcePath: shot.sourcePath,
          autoQuality: false,
          confirmLowQualitySave: (_) async => true,
        );
        if (result.message != null) {
          lastMessage = result.message;
        }
        if (result.saved) {
          savedCount++;
        }
      }

      if (!mounted) return;
      if (savedCount > 0) {
        _toast('Sesion guardada: $savedCount / ${session.shots.length} fotos.');
      } else if (lastMessage != null) {
        _toast(lastMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  Future<void> _removeImage(ProjectModel project, String imagePath) async {
    await _captureController.removeImage(
      projectId: project.id,
      imagePath: imagePath,
    );
    if (mounted) _toast('Imagen eliminada del proyecto.');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final activeProject = _resolveActiveProject(projects);
    final captureCount = activeProject?.imagePaths.length ?? 0;
    final nextStep = captureCount < _guidePlan.length
        ? _guidePlan[captureCount]
        : null;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CaptureHeader(onBack: () => Navigator.maybePop(context)),
                  const SizedBox(height: 20),
                  _buildQuickGuideCard(context, captureCount, nextStep),
                  const SizedBox(height: 16),
                  _buildProjectCard(context, projects, activeProject),
                  const SizedBox(height: 20),
                  _buildMainButton(context, activeProject),
                  const SizedBox(height: 24),
                  _buildCaptureSection(context, activeProject),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickGuideCard(
    BuildContext context,
    int captureCount,
    CaptureGuideStep? nextStep,
  ) {
    final progress = (captureCount / _targetMinPhotos).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    final statusMessage = switch (captureCount) {
      < _targetMinPhotos =>
        'Faltan ${_targetMinPhotos - captureCount} fotos para cobertura minima.',
      <= _targetMaxPhotos =>
        'Cobertura minima completa. Puedes mejorar hasta $_targetMaxPhotos.',
      _ => 'Cobertura avanzada alcanzada.',
    };

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBubble(icon: Icons.lightbulb_outline_rounded),
              const SizedBox(width: 12),
              Text('Guia rapida', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          const _GuideLine('Rodea el objeto para cubrir 360 grados.'),
          const SizedBox(height: 6),
          const _GuideLine('Manten distancia y luz constantes.'),
          const SizedBox(height: 6),
          const _GuideLine('Alterna altura media, alta y baja.'),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress, minHeight: 6),
          const SizedBox(height: 8),
          Text(statusMessage, style: theme.textTheme.bodySmall),
          if (nextStep != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.track_changes_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Siguiente toma: ${nextStep.level.label} - ${nextStep.angleDeg} deg',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Asistencia en vivo', style: theme.textTheme.bodyMedium),
              Switch.adaptive(
                value: _enforceLiveQuality,
                onChanged: (value) =>
                    setState(() => _enforceLiveQuality = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    List<ProjectModel> projects,
    ProjectModel? activeProject,
  ) {
    final theme = Theme.of(context);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBubble(icon: Icons.folder_open_rounded),
              const SizedBox(width: 12),
              Text('Proyecto activo', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('No hay proyectos. Crea uno para comenzar.'),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: activeProject?.id,
              decoration: const InputDecoration(
                labelText: 'Seleccionar proyecto',
              ),
              dropdownColor: theme.colorScheme.surface,
              items: [
                for (final project in projects)
                  DropdownMenuItem(
                    value: project.id,
                    child: Text(project.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _activeProjectId = value);
              },
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _showCreateProjectDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo proyecto'),
          ),
          if (activeProject != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${activeProject.imagePaths.length} capturas | estado: ${activeProject.status.label}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainButton(BuildContext context, ProjectModel? activeProject) {
    final enabled = !_capturing && activeProject != null;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ElevatedButton.icon(
          onPressed: enabled ? () => _capture(activeProject) : null,
          icon: _capturing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(Icons.camera_alt_rounded),
          label: Text(_capturing ? 'Abriendo camara...' : 'Tomar foto'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 62),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            shadowColor: theme.colorScheme.primary.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureSection(
    BuildContext context,
    ProjectModel? activeProject,
  ) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBubble(icon: Icons.photo_library_outlined),
              const SizedBox(width: 12),
              Text('Capturas', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (activeProject != null)
                Text(
                  '${activeProject.imagePaths.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCaptureGrid(context, activeProject),
        ],
      ),
    );
  }

  Widget _buildCaptureGrid(BuildContext context, ProjectModel? activeProject) {
    if (activeProject == null) {
      return const Padding(
        padding: EdgeInsets.all(6),
        child: Text('Selecciona o crea un proyecto para iniciar capturas.'),
      );
    }

    if (activeProject.imagePaths.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(6),
        child: Text('Aun no hay imagenes en este proyecto.'),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activeProject.imagePaths.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final path = activeProject.imagePaths[index];
        return _CaptureTile(
          path: path,
          onDelete: () => _removeImage(activeProject, path),
        );
      },
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
}

class _CaptureHeader extends StatelessWidget {
  const _CaptureHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Row(
      children: [
        IconButton(
          onPressed: canPop ? onBack : null,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Modulo de captura',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({required this.path, required this.onDelete});

  final String path;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 256,
              cacheHeight: 256,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Eliminar imagen',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
