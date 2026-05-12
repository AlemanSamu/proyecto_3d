import 'package:camera/camera.dart';

abstract class CameraCaptureService {
  Future<String?> capturePhotoPath();
}

/// Capture service backed by `package:camera`.
///
/// By default this convenience API captures one photo and disposes the
/// controller. It can also be reused by guided flows through
/// [createBackCameraController] + [takePictureWithController].
class DeviceCameraCaptureService implements CameraCaptureService {
  DeviceCameraCaptureService({
    this.resolutionPreset = ResolutionPreset.max,
    this.imageFormatGroup = ImageFormatGroup.jpeg,
  });

  final ResolutionPreset resolutionPreset;
  final ImageFormatGroup imageFormatGroup;

  Future<CameraController?> createBackCameraController() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return null;

    final selected = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      selected,
      resolutionPreset,
      enableAudio: false,
      imageFormatGroup: imageFormatGroup,
    );
    await controller.initialize();
    try {
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {
      // Best effort: some devices restrict these controls.
    }
    return controller;
  }

  Future<String?> takePictureWithController(CameraController controller) async {
    final shot = await controller.takePicture();
    return shot.path;
  }

  @override
  Future<String?> capturePhotoPath() async {
    CameraController? controller;
    try {
      controller = await createBackCameraController();
      if (controller == null) return null;
      return await takePictureWithController(controller);
    } catch (_) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }
}

/// Legacy name kept for compatibility with previous code.
class ImagePickerCameraCaptureService extends DeviceCameraCaptureService {
  ImagePickerCameraCaptureService({
    super.resolutionPreset = ResolutionPreset.max,
  });
}
