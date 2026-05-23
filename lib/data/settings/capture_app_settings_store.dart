import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/settings/capture_app_settings.dart';

class CaptureAppSettingsStore {
  static const _profileKey = 'capture.profile';
  static const _resolutionKey = 'capture.resolution';
  static const _maxPhotosKey = 'capture.maxPhotos';

  Future<CaptureAppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CaptureAppSettings(
      captureProfileKey: prefs.getString(_profileKey) ?? 'estable',
      captureResolutionKey: prefs.getString(_resolutionKey) ?? 'max',
      maxPhotos: (prefs.getInt(_maxPhotosKey) ?? 45).clamp(20, 120),
    );
  }

  Future<void> save(CaptureAppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, settings.captureProfileKey);
    await prefs.setString(_resolutionKey, settings.captureResolutionKey);
    await prefs.setInt(_maxPhotosKey, settings.maxPhotos.clamp(20, 120));
  }
}
