import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/camera_permission_service.dart';
import '../../../data/capture/camera_capture_service.dart';
import '../../../data/capture/gallery_save_service.dart';
import '../../../data/capture/photo_quality_analyzer.dart';
import '../../../data/capture/project_capture_storage.dart';
import '../../../domain/projects/project_model.dart';
import '../../controllers/capture_flow_controller.dart';
import '../../providers/capture_settings_providers.dart';
import '../../providers/project_providers.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/project_form_dialog.dart';
import 'capture_profile.dart';
import 'capture_summary_screen.dart';
import 'guided_camera_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, this.initialProjectId});

  final String? initialProjectId;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _permissionService = CameraPermissionService();
  late final CaptureFlowController _captureController;
  final _galleryPicker = ImagePicker();

  String? _activeProjectId;
  bool _capturing = false;
  bool _importing = false;

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
    final captureSettings = ref.watch(captureAppSettingsProvider);
    final activeProject = _resolveActiveProject(projects);

    final captureProfile = CaptureProfileX.fromKey(
      captureSettings.captureProfileKey,
    );
    final captureResolution = CaptureResolutionX.fromKey(
      captureSettings.captureResolutionKey,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Text(
          'Captura guiada',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Menos ruido, mejores fotos para reconstruccion.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        AppSurfaceCard(
          title: 'Proyecto',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (projects.isEmpty)
                Text(
                  'No hay proyectos. Crea uno para iniciar.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: activeProject?.id,
                  decoration: const InputDecoration(
                    labelText: 'Proyecto activo',
                  ),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _createProject,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuevo proyecto'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          title: 'Guia por anillos',
          subtitle: 'Bajo 10-15 | Medio 12-18 | Alto 10-15',
          child: Column(
            children: [
              _RingProgressRow(
                label: 'Bajo',
                count: _levelCount(activeProject, 'low'),
                minTarget: 10,
                maxTarget: 15,
              ),
              const SizedBox(height: 10),
              _RingProgressRow(
                label: 'Medio',
                count: _levelCount(activeProject, 'mid'),
                minTarget: 12,
                maxTarget: 18,
              ),
              const SizedBox(height: 10),
              _RingProgressRow(
                label: 'Alto',
                count: _levelCount(activeProject, 'top'),
                minTarget: 10,
                maxTarget: 15,
              ),
              const SizedBox(height: 12),
              _line('Perfil', captureProfile.label),
              _line('Resolucion', captureResolution.label),
              _line('Maximo de fotos', '${captureSettings.maxPhotos}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 58,
          child: ElevatedButton.icon(
            onPressed: _capturing ? null : () => _capture(activeProject),
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
            label: Text(
              _capturing ? 'Abriendo camara...' : 'Abrir captura guiada',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _importing
                ? null
                : () => _pickImagesFromGallery(activeProject),
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined),
            label: Text(
              _importing ? 'Importando...' : 'Importar desde galeria',
            ),
          ),
        ),
        if (activeProject != null && activeProject.photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CaptureSummaryScreen(projectId: activeProject.id),
                  ),
                );
              },
              icon: const Icon(Icons.summarize_outlined),
              label: const Text('Resumen y envio'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _line(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  int _levelCount(ProjectModel? project, String level) {
    if (project == null) return 0;
    return project.photos.where((photo) => photo.level == level).length;
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
      title: 'Nuevo escaneo',
      confirmLabel: 'Crear',
    );

    if (payload == null) return;

    final project = ref
        .read(projectsProvider.notifier)
        .createProject(name: payload.name, description: payload.description);

    if (!mounted) return;
    setState(() => _activeProjectId = project.id);
  }

  Future<void> _capture(ProjectModel? project) async {
    if (_capturing || project == null) return;

    final captureSettings = ref.read(captureAppSettingsProvider);
    final maxPhotos = captureSettings.maxPhotos;
    final captureProfile = CaptureProfileX.fromKey(
      captureSettings.captureProfileKey,
    );
    final captureResolution = CaptureResolutionX.fromKey(
      captureSettings.captureResolutionKey,
    );

    setState(() => _capturing = true);

    try {
      final permission = await _permissionService.request();
      final granted =
          permission == CameraPermissionState.granted ||
          permission == CameraPermissionState.limited;

      if (!granted) {
        if (!mounted) return;
        if (permission == CameraPermissionState.permanentlyDenied) {
          _showSnack('Permiso de camara bloqueado. Abre Ajustes.');
          await _permissionService.openSettings();
        } else {
          _showSnack('Permiso de camara denegado.');
        }
        return;
      }

      if (!mounted) return;
      final session = await Navigator.of(context)
          .push<GuidedCameraSessionResult>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => GuidedCameraScreen(
                projectName: project.name,
                captureIndex: project.photos.length,
                targetMinPhotos: 20,
                targetMaxPhotos: maxPhotos,
                levelKey: 'low',
                levelLabel: 'Bajo',
                angleDeg: 0,
                requireLiveQualityGate: true,
                captureProfile: captureProfile,
                captureResolution: captureResolution,
                existingLevelCounts: _buildLevelCounts(project),
              ),
            ),
          );

      if (!mounted || session == null || session.shots.isEmpty) return;

      int savedCount = 0;
      final durations = <int>[];
      int stableCaptures = 0;
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
          captureProfile: shot.profile.key,
          captureIndex: savedCount + 1 + project.photos.length,
          stable: shot.stable,
          localWarnings: shot.warnings,
          captureStartTime: shot.captureStartTime,
          captureEndTime: shot.captureEndTime,
          captureDurationMs: shot.captureDurationMs,
          cameraResolutionPreset: shot.cameraResolutionPreset,
          qualityGateEnabled: shot.qualityGateEnabled,
          realtimeAnalysisEnabled: shot.realtimeAnalysisEnabled,
        );
        if (result.saved) {
          savedCount++;
          durations.add(shot.captureDurationMs);
          if (shot.stable) stableCaptures++;
        }
      }

      if (durations.isNotEmpty) {
        await _captureController.writeSessionSummary(
          projectId: project.id,
          profileUsed: captureProfile.key,
          captureDurationsMs: durations,
          stableCaptures: stableCaptures,
        );
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CaptureSummaryScreen(projectId: project.id),
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pickImagesFromGallery(ProjectModel? project) async {
    if (_importing || project == null) return;

    final picked = await _galleryPicker.pickMultiImage(
      imageQuality: 94,
      requestFullMetadata: false,
    );
    if (!mounted || picked.isEmpty) return;

    setState(() => _importing = true);
    try {
      int savedCount = 0;
      for (final image in picked) {
        final result = await _captureController.processCapturedFile(
          projectId: project.id,
          sourcePath: image.path,
          autoQuality: false,
          confirmLowQualitySave: (_) async => true,
        );
        if (result.saved) savedCount++;
      }

      if (!mounted) return;
      _showSnack('Importadas $savedCount de ${picked.length} imagenes.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('No se pudieron importar imagenes.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Map<String, int> _buildLevelCounts(ProjectModel project) {
    final counts = <String, int>{'low': 0, 'mid': 0, 'top': 0};
    for (final photo in project.photos) {
      final level = photo.level;
      if (level == null || !counts.containsKey(level)) continue;
      counts[level] = (counts[level] ?? 0) + 1;
    }
    return counts;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RingProgressRow extends StatelessWidget {
  const _RingProgressRow({
    required this.label,
    required this.count,
    required this.minTarget,
    required this.maxTarget,
  });

  final String label;
  final int count;
  final int minTarget;
  final int maxTarget;

  @override
  Widget build(BuildContext context) {
    final progress = (count / maxTarget).clamp(0.0, 1.0);
    final status = count < minTarget
        ? 'Faltan ${minTarget - count}'
        : count > maxTarget
        ? 'Completo'
        : 'Bien';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label: $count fotos',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(status, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress, minHeight: 7),
        ),
      ],
    );
  }
}
