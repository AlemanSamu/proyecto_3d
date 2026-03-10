import 'package:gallery_saver_plus/gallery_saver.dart';

abstract class GallerySaveService {
  Future<bool> saveImage(String imagePath);
}

class DeviceGallerySaveService implements GallerySaveService {
  @override
  Future<bool> saveImage(String imagePath) async {
    return await GallerySaver.saveImage(imagePath, albumName: 'Captura3D') ==
        true;
  }
}
