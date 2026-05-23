import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class BackendImageUploadPlan {
  const BackendImageUploadPlan({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.targetWidth,
    required this.targetHeight,
    required this.shouldResize,
  });

  final int sourceWidth;
  final int sourceHeight;
  final int targetWidth;
  final int targetHeight;
  final bool shouldResize;
}

class PreparedBackendImage {
  const PreparedBackendImage({
    required this.path,
    required this.filename,
    required this.isTemporary,
  });

  final String path;
  final String filename;
  final bool isTemporary;
}

BackendImageUploadPlan planBackendImageUploadSize({
  required int width,
  required int height,
  int maxLongSide = 2560,
}) {
  final longSide = max(width, height);
  if (width <= 0 || height <= 0 || longSide <= maxLongSide) {
    return BackendImageUploadPlan(
      sourceWidth: width,
      sourceHeight: height,
      targetWidth: width,
      targetHeight: height,
      shouldResize: false,
    );
  }

  final scale = maxLongSide / longSide;
  return BackendImageUploadPlan(
    sourceWidth: width,
    sourceHeight: height,
    targetWidth: max(1, (width * scale).round()),
    targetHeight: max(1, (height * scale).round()),
    shouldResize: true,
  );
}

Future<PreparedBackendImage> prepareBackendImageForUpload(
  String sourcePath, {
  Future<Directory> Function()? temporaryDirectoryProvider,
}) async {
  final sourceFile = File(sourcePath);
  final originalName = sourceFile.uri.pathSegments.isEmpty
      ? 'capture.jpg'
      : sourceFile.uri.pathSegments.last;
  final tempDir = temporaryDirectoryProvider != null
      ? await temporaryDirectoryProvider()
      : await getTemporaryDirectory();

  try {
    final preparedPath = await Isolate.run(
      () => _prepareBackendImageSync(
        sourcePath: sourcePath,
        tempDirPath: tempDir.path,
        originalName: originalName,
      ),
    );
    if (preparedPath == null) {
      return PreparedBackendImage(
        path: sourcePath,
        filename: originalName,
        isTemporary: false,
      );
    }
    return PreparedBackendImage(
      path: preparedPath,
      filename: '${_basenameWithoutExtension(originalName)}_upload.jpg',
      isTemporary: true,
    );
  } catch (_) {
    return PreparedBackendImage(
      path: sourcePath,
      filename: originalName,
      isTemporary: false,
    );
  }
}

String? _prepareBackendImageSync({
  required String sourcePath,
  required String tempDirPath,
  required String originalName,
}) {
  final bytes = File(sourcePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final plan = planBackendImageUploadSize(
    width: decoded.width,
    height: decoded.height,
  );
  final output = plan.shouldResize
      ? img.copyResize(
          decoded,
          width: plan.targetWidth,
          height: plan.targetHeight,
          interpolation: img.Interpolation.cubic,
        )
      : decoded;

  final encoded = img.encodeJpg(output, quality: 92);
  if (!plan.shouldResize && encoded.length >= bytes.length) {
    return null;
  }

  final uploadDir = Directory(
    '$tempDirPath${Platform.pathSeparator}local3d_backend_uploads',
  );
  if (!uploadDir.existsSync()) {
    uploadDir.createSync(recursive: true);
  }
  final safeBase = _basenameWithoutExtension(
    originalName,
  ).replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  final file = File(
    '${uploadDir.path}${Platform.pathSeparator}'
    '${safeBase}_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  file.writeAsBytesSync(encoded, flush: true);
  return file.path;
}

String _basenameWithoutExtension(String path) {
  final slash = max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
  final name = slash < 0 ? path : path.substring(slash + 1);
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name.isEmpty ? 'capture' : name;
  return name.substring(0, dot);
}
