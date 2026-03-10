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
  int calls = 0;

  @override
  Future<PhotoQualityReport> analyze(String sourcePath) async {
    calls++;
    return report;
  }
}

class FakeStorage implements ProjectCaptureStorage {
  FakeStorage(this.copiedPath);
  String? copiedPath;
  final List<String> deletedPaths = <String>[];

  @override
  Future<String?> copyToProject({
    required String projectId,
    required String sourcePath,
  }) async => copiedPath;

  @override
  Future<void> deleteIfExists(String path) async {
    deletedPaths.add(path);
  }

  @override
  Future<void> deleteProjectData(String projectId) async {}
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
  required FakeStorage storage,
  required bool gallerySaved,
  required ProjectsNotifier notifier,
  FakeQualityAnalyzer? analyzer,
}) {
  final qualityAnalyzer = analyzer ?? FakeQualityAnalyzer(report);
  return CaptureFlowController(
    permissionService: FakePermissionService(permission),
    cameraService: FakeCameraService(cameraPath),
    qualityAnalyzer: qualityAnalyzer,
    storage: storage,
    gallerySaver: FakeGalleryService(gallerySaved),
    projectsNotifier: notifier,
  );
}

void main() {
  test('marca guardado en app cuando falla guardar en galeria', () async {
    final notifier = ProjectsNotifier(InMemoryProjectRepository());
    final project = notifier.createProject();
    final storage = FakeStorage('/tmp/output.jpg');
    final controller = _buildController(
      permission: CameraPermissionState.granted,
      cameraPath: '/tmp/input.jpg',
      report: const PhotoQualityReport(
        isOk: true,
        brightness: 90,
        sharpness: 20,
        hint: 'ok',
      ),
      storage: storage,
      gallerySaved: false,
      notifier: notifier,
    );

    final result = await controller.captureForProject(
      projectId: project.id,
      autoQuality: true,
      confirmLowQualitySave: (_) async => true,
    );

    expect(result.message, 'Imagen guardada en proyecto, pero no en galeria.');
    expect(result.saved, isTrue);
    expect(notifier.state.first.imagePaths, ['/tmp/output.jpg']);
  });

  test('processCapturedFile evita analisis si autoQuality es false', () async {
    final notifier = ProjectsNotifier(InMemoryProjectRepository());
    final project = notifier.createProject();
    final analyzer = FakeQualityAnalyzer(
      const PhotoQualityReport(
        isOk: false,
        brightness: 10,
        sharpness: 2,
        hint: 'baja',
      ),
    );
    final storage = FakeStorage('/tmp/output.jpg');
    final controller = _buildController(
      permission: CameraPermissionState.granted,
      cameraPath: '/tmp/input.jpg',
      report: analyzer.report,
      storage: storage,
      gallerySaved: true,
      notifier: notifier,
      analyzer: analyzer,
    );

    final result = await controller.processCapturedFile(
      projectId: project.id,
      sourcePath: '/tmp/input.jpg',
      autoQuality: false,
      confirmLowQualitySave: (_) async => false,
    );

    expect(analyzer.calls, 0);
    expect(result.saved, isTrue);
    expect(notifier.state.first.imagePaths, ['/tmp/output.jpg']);
  });

  test('removeImage limpia storage y estado del proyecto', () async {
    final notifier = ProjectsNotifier(InMemoryProjectRepository());
    final project = notifier.createProject();
    notifier.addImagePath(project.id, '/tmp/output.jpg');

    final storage = FakeStorage('/tmp/output.jpg');
    final controller = _buildController(
      permission: CameraPermissionState.granted,
      cameraPath: '/tmp/input.jpg',
      report: const PhotoQualityReport(
        isOk: true,
        brightness: 90,
        sharpness: 20,
        hint: 'ok',
      ),
      storage: storage,
      gallerySaved: true,
      notifier: notifier,
    );

    await controller.removeImage(
      projectId: project.id,
      imagePath: '/tmp/output.jpg',
    );

    expect(storage.deletedPaths, ['/tmp/output.jpg']);
    expect(notifier.state.first.imagePaths, isEmpty);
  });
}
