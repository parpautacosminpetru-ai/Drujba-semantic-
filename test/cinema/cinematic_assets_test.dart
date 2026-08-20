import 'dart:ui' as ui;

import 'package:drujba_semantic_core/cinema/cinematic_scene.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every cinematic scene is a bundled WebP asset', () async {
    final catalog = CinematicSceneCatalog.defaults();

    for (final scene in catalog.scenes) {
      final data = await rootBundle.load(scene.assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      expect(bytes.length, greaterThan(12), reason: scene.assetPath);
      expect(
        String.fromCharCodes(bytes.take(4)),
        'RIFF',
        reason: scene.assetPath,
      );
      expect(
        String.fromCharCodes(bytes.skip(8).take(4)),
        'WEBP',
        reason: scene.assetPath,
      );

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1280, reason: scene.assetPath);
      expect(frame.image.height, 720, reason: scene.assetPath);
      frame.image.dispose();
      codec.dispose();
    }
  });
}
