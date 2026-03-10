import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

class CameraPermissionService {
  Future<CameraPermissionState> getStatus() async {
    final status = await Permission.camera.status;
    return _map(status);
  }

  Future<CameraPermissionState> request() async {
    final status = await Permission.camera.request();
    return _map(status);
  }

  Future<bool> openSettings() {
    return openAppSettings();
  }

  CameraPermissionState _map(PermissionStatus status) {
    if (status.isGranted) return CameraPermissionState.granted;
    if (status.isLimited) return CameraPermissionState.limited;
    if (status.isPermanentlyDenied) {
      return CameraPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) return CameraPermissionState.restricted;
    return CameraPermissionState.denied;
  }
}
