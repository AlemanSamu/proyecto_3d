import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/core/services/camera_permission_service.dart';
import 'package:proyecto_3d/data/capture/camera_capture_service.dart';
import 'package:proyecto_3d/data/capture/gallery_save_service.dart';
import 'package:proyecto_3d/data/capture/photo_quality_analyzer.dart';
import 'package:proyecto_3d/data/capture/project_capture_storage.dart';
import 'package:proyecto_3d/data/projects/project_repository.dart';
import 'package:proyecto_3d/domain/capture/photo_quality_report.dart';
import 'package:proyecto_3d/domain/projects/project_model.dart';
import 'package:proyecto_3d/presentation/controllers/capture_flow_controller.dart';
import 'package:proyecto_3d/presentation/providers/project_providers.dart';

class InMemoryProjectRepository implements ProjectRepository {
  List<ProjectModel> _projects = const [];

  @override
  Future<List<ProjectModel>> readProjects() async {
    return List<ProjectModel>.from(_projects);
  }

  @override
  Future<void> writeProjects(List<ProjectModel> projects) async {
    _projects = List<ProjectModel>.from(projects);
  }
}

class FakePermissionService extends CameraPermissionService {
  FakePermissionService(this.nextState);
  CameraPermissionState nextState;

  @override
  Future<CameraPermissionState> request() async => nextState;
}

class FakeCameraService implements CameraCaptureService {
  FakeCameraService(this.path);
  String? path;

  @override
  Future<String?> capturePhotoPath() async => path;
}

class FakeQualityAnalyzer implements PhotoQualityAnalyzer {
  FakeQualityAnalyzer(this.report);
  PhotoQualityReport report;

  @override
  Future<PhotoQualityReport> analyze(String sourcePath) async => report;
}

class FakeStorage implements ProjectCaptureStorage {
  FakeStorage(this.copiedPath);
  String? copiedPath;

  @override
  Future<String?> copyToProject({
    required String projectId,
    required String sourcePath,
  }) async => copiedPath;

  @override
  Future<void> deleteIfExists(String path) async {}
}

class FakeGalleryService implements GallerySaveService {
  FakeGalleryService(this.saved);
  bool saved;

  @override
  Future<bool> saveImage(String imagePath) async => saved;
}

CaptureFlowController _buildController({
  required CameraPermissionState permission,
  required String? cameraPath,
  required PhotoQualityReport report,
  required String? storedPath,
  required bool gallerySaved,
  required ProjectsNotifier notifier,
}) {
  return CaptureFlowController(
    permissionService: FakePermissionService(permission),
    cameraService: FakeCameraService(cameraPath),
    qualityAnalyzer: FakeQualityAnalyzer(report),
    storage: FakeStorage(storedPath),
    gallerySaver: FakeGalleryService(gallerySaved),
    projectsNotifier: notifier,
  );
}

void main() {
  test('retorna mensaje cuando permiso esta bloqueado', () async {
    final notifier = ProjectsNotifier(InMemoryProjectRepository());
    final project = notifier.createProject();
    final controller = _buildController(
      permission: CameraPermissionState.permanentlyDenied,
      cameraPath: '/tmp/input.jpg',
      report: const PhotoQualityReport(
        isOk: true,
        brightness: 100,
        sharpness: 20,
        hint: 'ok',
      ),
      storedPath: '/tmp/output.jpg',
      gallerySaved: true,
      notifier: notifier,
    );

    final result = await controller.captureForProject(
      projectId: project.id,
      autoQuality: true,
      confirmLowQualitySave: (_) async => true,
    );

    expect(result.shouldOpenSettings, isTrue);
    expect(result.message, contains('bloqueado'));
  });

  test('descarta captura cuando calidad es baja y usuario no acepta', () async {
    final notifier = ProjectsNotifier(InMemoryProjectRepository());
    final project = notifier.createProject();
    final controller = _buildController(
      permission: CameraPermissionState.granted,
      cameraPath: '/tmp/input.jpg',
      report: const PhotoQualityReport(
        isOk: false,
        brightness: 12,
        sharpness: 4,
        hint: 'baja',
      ),
      storedPath: '/tmp/output.jpg',
      gallerySaved: true,
      notifier: notifier,
    );

    final result = await controller.captureForProject(
      projectId: project.id,
      autoQuality: true,
      confirmLowQualitySave: (_) async => false,
    );

    expect(result.message, 'Captura descartada.');
    expect(notifier.state.first.imagePaths, isEmpty);
  });

  test('guarda captura en proyecto cuando flujo es exitoso', () async {
    final notifier = ProjectsNotifier(InMemoryProjectRepository());
    final project = notifier.createProject();
    final controller = _buildController(
      permission: CameraPermissionState.granted,
      cameraPath: '/tmp/input.jpg',
      report: const PhotoQualityReport(
        isOk: true,
        brightness: 85,
        sharpness: 22,
        hint: 'ok',
      ),
      storedPath: '/tmp/output.jpg',
      gallerySaved: true,
      notifier: notifier,
    );

    final result = await controller.captureForProject(
      projectId: project.id,
      autoQuality: true,
      confirmLowQualitySave: (_) async => true,
    );

    expect(result.message, 'Imagen capturada y guardada.');
    expect(notifier.state.first.imagePaths, ['/tmp/output.jpg']);
  });
}
