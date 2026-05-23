import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings/capture_app_settings_store.dart';
import '../../domain/settings/capture_app_settings.dart';

class CaptureAppSettingsNotifier extends StateNotifier<CaptureAppSettings> {
  CaptureAppSettingsNotifier(this._store) : super(const CaptureAppSettings()) {
    unawaited(_load());
  }

  final CaptureAppSettingsStore _store;

  Future<void> _load() async {
    final loaded = await _store.load();
    state = loaded;
  }

  void updateProfile(String profileKey) {
    _update(state.copyWith(captureProfileKey: profileKey));
  }

  void updateResolution(String resolutionKey) {
    _update(state.copyWith(captureResolutionKey: resolutionKey));
  }

  void updateMaxPhotos(int maxPhotos) {
    _update(state.copyWith(maxPhotos: maxPhotos.clamp(20, 120)));
  }

  Future<void> _update(CaptureAppSettings next) async {
    state = next;
    await _store.save(next);
  }
}

final captureAppSettingsStoreProvider = Provider<CaptureAppSettingsStore>((
  ref,
) {
  return CaptureAppSettingsStore();
});

final captureAppSettingsProvider =
    StateNotifierProvider<CaptureAppSettingsNotifier, CaptureAppSettings>((
      ref,
    ) {
      return CaptureAppSettingsNotifier(
        ref.watch(captureAppSettingsStoreProvider),
      );
    });
