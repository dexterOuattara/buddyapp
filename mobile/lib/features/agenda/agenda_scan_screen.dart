import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../providers.dart';
import 'agenda_review_screen.dart';

/// Camera + photo capture for the agenda OCR flow.
///
/// Captures a still image, resizes to a max 1200 px on the long edge
/// (saves data + keeps Gemma under its request limit), then POSTs to
/// `/api/agenda/parse`. On success navigates to [AgendaReviewScreen].
class AgendaScanScreen extends ConsumerStatefulWidget {
  const AgendaScanScreen({super.key});

  @override
  ConsumerState<AgendaScanScreen> createState() => _AgendaScanScreenState();
}

class _AgendaScanScreenState extends ConsumerState<AgendaScanScreen> {
  CameraController? _camera;
  bool _initializing = true;
  String? _initError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _initError = 'No camera available on this device.';
          _initializing = false;
        });
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _camera = controller;
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _initError = e.toString();
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _captureAndParse() async {
    if (_busy || _camera == null) return;
    setState(() => _busy = true);
    try {
      final picture = await _camera!.takePicture();
      final bytes = await File(picture.path).readAsBytes();

      // Resize to max 1200 px on the long edge. ~100 KB final — fine for
      // any mobile data budget.
      final original = img.decodeImage(bytes);
      if (original == null) {
        throw StateError('Could not decode image');
      }
      final resized = _resize(original, maxSide: 1200);
      final jpegBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 82));

      final api = ref.read(apiClientProvider);
      final drafts = await api.parseAgendaImage(jpegBytes);
      if (!mounted) return;
      if (drafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("We couldn't read any agenda items. Try again or enter manually.")),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AgendaReviewScreen(drafts: drafts)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Returns the image if the long edge already fits, otherwise resizes.
  img.Image _resize(img.Image original, {required int maxSide}) {
    final w = original.width;
    final h = original.height;
    if (w <= maxSide && h <= maxSide) return original;
    final ratio = w >= h ? maxSide / w : maxSide / h;
    return img.copyResize(
      original,
      width: (w * ratio).round(),
      height: (h * ratio).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan agenda')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_initError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _initError!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final controller = _camera!;
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        Positioned(
          left: 0, right: 0, bottom: 32,
          child: Center(
            child: FloatingActionButton.large(
              onPressed: _busy ? null : _captureAndParse,
              backgroundColor: Colors.red,
              child: _busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.camera_alt, size: 32),
            ),
          ),
        ),
      ],
    );
  }
}
