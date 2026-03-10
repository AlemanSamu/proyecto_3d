import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_3d/features/capture/capture_controller.dart';
import 'package:proyecto_3d/features/capture/pose_library.dart';
import 'package:proyecto_3d/features/capture/quality_analyzer.dart';

const _samplePose = PoseStep(
  id: 'mid_0',
  title: 'Pose media',
  level: PoseLevel.mid,
  angleDeg: 0,
  instruction: 'Instruccion',
);

class FakeCapturePermissions implements CapturePermissions {
  FakeCapturePermissions(this.allowed);
  final bool allowed;
  int calls = 0;

  @override
  Future<bool> ensureCapturePermissions() async {
    calls++;
    return allowed;
  }
}

class FakeCaptureCamera implements CaptureCamera {
  FakeCaptureCamera({this.path});
  final String? path;
  int calls = 0;

  @override
  Future<String?> takePhotoPath() async {
    calls++;
    return path;
  }
}

class FakeCaptureQualityAnalyzer implements CaptureQualityAnalyzer {
  FakeCaptureQualityAnalyzer(this.report);
  final QualityReport report;
  int calls = 0;

  @override
  Future<QualityReport> analyze(String filePath) async {
    calls++;
    return report;
  }
}

class FakeCaptureFileStorage implements CaptureFileStorage {
  FakeCaptureFileStorage({this.pathToStore});
  final String? pathToStore;
  int storeCalls = 0;
  String? deletedPath;

  @override
  Future<void> deleteIfExists(String? path) async {
    deletedPath = path;
  }

  @override
  Future<String?> storeCapture({
    required String projectId,
    required String sourcePath,
    required String poseId,
  }) async {
    storeCalls++;
    return pathToStore;
  }
}

class FakeCaptureGallerySaver implements CaptureGallerySaver {
  FakeCaptureGallerySaver(this.willSave);
  final bool willSave;
  int calls = 0;
  String? lastPath;

  @override
  Future<bool> save(String path) async {
    calls++;
    lastPath = path;
    return willSave;
  }
}

class FakeCaptureProjectStore implements CaptureProjectStore {
  int setCalls = 0;
  int removeCalls = 0;
  String? setProjectId;
  String? setPoseId;
  String? setPath;
  String? removedProjectId;
  String? removedPoseId;

  @override
  void removePosePhoto(String projectId, String poseId) {
    removeCalls++;
    removedProjectId = projectId;
    removedPoseId = poseId;
  }

  @override
  void setPosePhoto(String projectId, String poseId, String path) {
    setCalls++;
    setProjectId = projectId;
    setPoseId = poseId;
    setPath = path;
  }
}

CaptureController _buildController({
  required FakeCapturePermissions permissions,
  required FakeCaptureCamera camera,
  required FakeCaptureQualityAnalyzer analyzer,
  required FakeCaptureFileStorage files,
  required FakeCaptureGallerySaver gallery,
  required FakeCaptureProjectStore projects,
}) {
  return CaptureController(
    projectId: 'project-1',
    permissions: permissions,
    camera: camera,
    qualityAnalyzer: analyzer,
    fileStorage: files,
    gallerySaver: gallery,
    projectStore: projects,
  );
}

void main() {
  test('retorna mensaje cuando faltan permisos', () async {
    final permissions = FakeCapturePermissions(false);
    final camera = FakeCaptureCamera(path: '/tmp/camera.jpg');
    final analyzer = FakeCaptureQualityAnalyzer(
      const QualityReport(
        isOk: true,
        brightness: 80,
        sharpness: 20,
        hint: 'ok',
      ),
    );
    final files = FakeCaptureFileStorage(pathToStore: '/tmp/saved.jpg');
    final gallery = FakeCaptureGallerySaver(true);
    final projects = FakeCaptureProjectStore();
    final controller = _buildController(
      permissions: permissions,
      camera: camera,
      analyzer: analyzer,
      files: files,
      gallery: gallery,
      projects: projects,
    );

    final result = await controller.takeForPose(
      pose: _samplePose,
      confirmLowQuality: (_) async => true,
    );

    expect(result.message, 'Necesito permisos de camara y fotos.');
    expect(camera.calls, 0);
    expect(projects.setCalls, 0);
  });

  test('cancela cuando calidad baja no es aceptada', () async {
    final permissions = FakeCapturePermissions(true);
    final camera = FakeCaptureCamera(path: '/tmp/camera.jpg');
    final analyzer = FakeCaptureQualityAnalyzer(
      const QualityReport(
        isOk: false,
        brightness: 20,
        sharpness: 5,
        hint: 'baja',
      ),
    );
    final files = FakeCaptureFileStorage(pathToStore: '/tmp/saved.jpg');
    final gallery = FakeCaptureGallerySaver(true);
    final projects = FakeCaptureProjectStore();
    final controller = _buildController(
      permissions: permissions,
      camera: camera,
      analyzer: analyzer,
      files: files,
      gallery: gallery,
      projects: projects,
    );

    final result = await controller.takeForPose(
      pose: _samplePose,
      confirmLowQuality: (_) async => false,
    );

    expect(result.message, isNull);
    expect(files.storeCalls, 0);
    expect(projects.setCalls, 0);
  });

  test('guarda proyecto y galeria cuando todo sale bien', () async {
    final permissions = FakeCapturePermissions(true);
    final camera = FakeCaptureCamera(path: '/tmp/camera.jpg');
    final analyzer = FakeCaptureQualityAnalyzer(
      const QualityReport(
        isOk: true,
        brightness: 90,
        sharpness: 30,
        hint: 'ok',
      ),
    );
    final files = FakeCaptureFileStorage(pathToStore: '/tmp/saved.jpg');
    final gallery = FakeCaptureGallerySaver(true);
    final projects = FakeCaptureProjectStore();
    final controller = _buildController(
      permissions: permissions,
      camera: camera,
      analyzer: analyzer,
      files: files,
      gallery: gallery,
      projects: projects,
    );

    final result = await controller.takeForPose(
      pose: _samplePose,
      confirmLowQuality: (_) async => true,
    );

    expect(result.message, 'Foto guardada.');
    expect(projects.setCalls, 1);
    expect(projects.setProjectId, 'project-1');
    expect(projects.setPoseId, 'mid_0');
    expect(projects.setPath, '/tmp/saved.jpg');
    expect(gallery.calls, 1);
  });

  test('reporta guardado solo en app cuando falla galeria', () async {
    final permissions = FakeCapturePermissions(true);
    final camera = FakeCaptureCamera(path: '/tmp/camera.jpg');
    final analyzer = FakeCaptureQualityAnalyzer(
      const QualityReport(
        isOk: true,
        brightness: 90,
        sharpness: 30,
        hint: 'ok',
      ),
    );
    final files = FakeCaptureFileStorage(pathToStore: '/tmp/saved.jpg');
    final gallery = FakeCaptureGallerySaver(false);
    final projects = FakeCaptureProjectStore();
    final controller = _buildController(
      permissions: permissions,
      camera: camera,
      analyzer: analyzer,
      files: files,
      gallery: gallery,
      projects: projects,
    );

    final result = await controller.takeForPose(
      pose: _samplePose,
      confirmLowQuality: (_) async => true,
    );

    expect(result.message, 'Foto guardada en app, pero no en galeria.');
    expect(projects.setCalls, 1);
  });

  test('eliminacion de pose limpia archivo y store', () async {
    final permissions = FakeCapturePermissions(true);
    final camera = FakeCaptureCamera(path: '/tmp/camera.jpg');
    final analyzer = FakeCaptureQualityAnalyzer(
      const QualityReport(
        isOk: true,
        brightness: 90,
        sharpness: 30,
        hint: 'ok',
      ),
    );
    final files = FakeCaptureFileStorage(pathToStore: '/tmp/saved.jpg');
    final gallery = FakeCaptureGallerySaver(true);
    final projects = FakeCaptureProjectStore();
    final controller = _buildController(
      permissions: permissions,
      camera: camera,
      analyzer: analyzer,
      files: files,
      gallery: gallery,
      projects: projects,
    );

    await controller.removePosePhoto(
      poseId: 'mid_0',
      filePath: '/tmp/saved.jpg',
    );

    expect(files.deletedPath, '/tmp/saved.jpg');
    expect(projects.removeCalls, 1);
    expect(projects.removedProjectId, 'project-1');
    expect(projects.removedPoseId, 'mid_0');
  });
}
