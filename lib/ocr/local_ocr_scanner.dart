import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'camera_input_image_adapter.dart';

typedef RecognizedFrameCallback = void Function(String text);

/// Owns the device camera and the bundled, on-device ML Kit recognizer.
///
/// This class deliberately has no HTTP client, remote endpoint, or cloud
/// fallback. Recognition either succeeds on the device or reports a local
/// error to the user.
final class LocalOcrScanner extends ChangeNotifier {
  LocalOcrScanner({required this.onRecognizedFrame});

  final RecognizedFrameCallback onRecognizedFrame;
  TextRecognizer? _recognizer;

  CameraController? _cameraController;
  CameraInputImageAdapter? _adapter;
  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);
  bool _processingFrame = false;
  bool _starting = false;
  bool _disposed = false;
  int _consecutiveRejectedFrames = 0;
  String _status = 'OCR local pregătit';
  String? _error;
  String _lastRecognizedText = '';

  CameraController? get cameraController => _cameraController;
  bool get isStarting => _starting;
  bool get isScanning =>
      _cameraController?.value.isStreamingImages ?? false;
  String get status => _status;
  String? get error => _error;
  String get lastRecognizedText => _lastRecognizedText;

  Future<void> start() async {
    if (_starting || isScanning || _disposed) {
      return;
    }

    _starting = true;
    _error = null;
    _consecutiveRejectedFrames = 0;
    _lastRecognizedText = '';
    _status = 'Pornesc camera locală...';
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    _notify();

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'Dispozitivul nu raportează nicio cameră disponibilă.',
        );
      }

      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      _adapter = CameraInputImageAdapter(
        camera: selected,
        controller: controller,
      );
      await controller.startImageStream(_processFrame);
      _status = 'Scanez liniar - OCR 100% local';
    } on CameraException catch (exception) {
      await _releaseCamera();
      _error = _cameraErrorMessage(exception);
      _status = 'Scanarea nu a pornit';
    } catch (exception) {
      await _releaseCamera();
      _error = 'Camera sau OCR-ul local nu a putut porni: $exception';
      _status = 'Scanarea nu a pornit';
    } finally {
      _starting = false;
      _notify();
    }
  }

  Future<void> stop() async {
    if (_disposed && _cameraController == null) {
      return;
    }
    await _releaseCamera();
    _status = 'Scanare oprită - procesarea rămâne locală';
    _notify();
  }

  Future<void> _releaseCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    _adapter = null;
    if (controller == null) {
      return;
    }
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  Future<void> _processFrame(CameraImage frame) async {
    final now = DateTime.now();
    if (_processingFrame ||
        now.difference(_lastAnalysis) < const Duration(milliseconds: 650)) {
      return;
    }

    _processingFrame = true;
    _lastAnalysis = now;
    try {
      final image = _adapter?.convert(frame);
      if (image == null) {
        _consecutiveRejectedFrames += 1;
        _status = 'Camera activă - verific formatul cadrului OCR';
        if (_consecutiveRejectedFrames >= 8) {
          _error = 'Camera livrează un format de imagine incompatibil cu OCR. '
              'Oprește și repornește scanarea sau încearcă introducerea manuală.';
        }
        _notify();
        return;
      }

      _consecutiveRejectedFrames = 0;
      final recognized = await _recognizer!.processImage(image);
      final text = recognized.text.trim();
      if (text.isNotEmpty && !_disposed && isScanning) {
        _error = null;
        _lastRecognizedText = text;
        _status = 'OCR local: ${text.split(RegExp(r'\s+')).length} cuvinte detectate';
        onRecognizedFrame(text);
        _notify();
      } else if (!_disposed && isScanning) {
        _status = 'Camera activă - apropie și focalizează textul';
        _notify();
      }
    } catch (exception) {
      if (!_disposed) {
        _error = 'Un cadru nu a putut fi citit local: $exception';
        _notify();
      }
    } finally {
      _processingFrame = false;
    }
  }

  String _cameraErrorMessage(CameraException exception) {
    switch (exception.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Permisiunea pentru cameră este necesară pentru OCR. Activeaz-o '
            'din setările Android și încearcă din nou.';
      default:
        return exception.description ??
            'Camera nu este disponibilă (${exception.code}).';
    }
  }

  void clearError() {
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_releaseCamera());
    final recognizer = _recognizer;
    _recognizer = null;
    if (recognizer != null) {
      unawaited(recognizer.close());
    }
    super.dispose();
  }
}
