import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Converts a Flutter camera frame into the byte layout required by ML Kit.
///
/// The implementation is intentionally local: no bytes leave the device. It
/// accepts both the single-plane NV21 stream produced by `camera_android` and
/// three-plane YUV streams returned by some Android camera implementations.
final class CameraInputImageAdapter {
  CameraInputImageAdapter({
    required this.camera,
    required this.controller,
  });

  final CameraDescription camera;
  final CameraController controller;

  static const Map<DeviceOrientation, int> _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Uint8List? _nv21Buffer;

  InputImage? convert(CameraImage image) {
    final rotation = _rotation();
    if (rotation == null || image.planes.isEmpty) {
      return null;
    }

    late final Uint8List bytes;
    late final InputImageFormat format;
    late final int bytesPerRow;

    if (image.planes.length == 1) {
      final sourceFormat =
          InputImageFormatValue.fromRawValue(image.format.raw);
      if (sourceFormat == null) {
        return null;
      }
      bytes = image.planes.first.bytes;
      format = sourceFormat == InputImageFormat.bgra8888
          ? InputImageFormat.bgra8888
          : InputImageFormat.nv21;
      bytesPerRow = image.planes.first.bytesPerRow;
    } else if (Platform.isAndroid && image.planes.length == 3) {
      bytes = _convertYuv420ToNv21(image);
      format = InputImageFormat.nv21;
      bytesPerRow = image.width;
    } else {
      return null;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  InputImageRotation? _rotation() {
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    final deviceDegrees =
        _orientationDegrees[controller.value.deviceOrientation];
    if (deviceDegrees == null) {
      return null;
    }

    final rotationDegrees = camera.lensDirection == CameraLensDirection.front
        ? (sensorOrientation + deviceDegrees) % 360
        : (sensorOrientation - deviceDegrees + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotationDegrees);
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final requiredSize = ySize + (ySize ~/ 2);
    final target = _nv21Buffer?.length == requiredSize
        ? _nv21Buffer!
        : (_nv21Buffer = Uint8List(requiredSize));

    final yPlane = image.planes[0];
    var destination = 0;
    for (var row = 0; row < height; row++) {
      final sourceStart = row * yPlane.bytesPerRow;
      target.setRange(
        destination,
        destination + width,
        yPlane.bytes,
        sourceStart,
      );
      destination += width;
    }

    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    var uvDestination = ySize;

    for (var row = 0; row < height ~/ 2; row++) {
      final uRowStart = row * uPlane.bytesPerRow;
      final vRowStart = row * vPlane.bytesPerRow;
      for (var column = 0; column < width ~/ 2; column++) {
        target[uvDestination++] =
            vPlane.bytes[vRowStart + (column * vPixelStride)];
        target[uvDestination++] =
            uPlane.bytes[uRowStart + (column * uPixelStride)];
      }
    }

    return target;
  }
}
