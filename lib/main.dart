import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  List<CameraDescription> cameras = const [];
  Object? initError;
  try {
    cameras = await availableCameras();
  } catch (error) {
    initError = error;
  }

  runApp(CameraApp(cameras: cameras, initError: initError));
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key, required this.cameras, required this.initError});

  final List<CameraDescription> cameras;
  final Object? initError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cross-Platform Camera',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: CameraScreen(cameras: cameras, initError: initError),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.cameras, required this.initError});

  final List<CameraDescription> cameras;
  final Object? initError;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  int _selectedIndex = 0;
  Uint8List? _lastCapture;
  String? _error;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(_selectedIndex);
    }
  }

  void _bootstrap() {
    if (widget.initError != null) {
      setState(() {
        _error = 'Camera initialization failed: ${widget.initError}';
      });
      return;
    }

    if (widget.cameras.isEmpty) {
      setState(() {
        _error = 'No cameras found on this device.';
      });
      return;
    }

    _initializeCamera(_selectedIndex);
  }

  Future<void> _initializeCamera(int index) async {
    if (index < 0 || index >= widget.cameras.length) {
      return;
    }

    setState(() {
      _error = null;
    });

    final description = widget.cameras[index];
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
    } catch (error) {
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to initialize camera: $error';
      });
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    final previous = _controller;
    setState(() {
      _controller = controller;
      _selectedIndex = index;
    });
    await previous?.dispose();
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) {
      return;
    }

    final nextIndex = (_selectedIndex + 1) % widget.cameras.length;
    await _initializeCamera(nextIndex);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (_isBusy || controller.value.isTakingPicture) {
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _lastCapture = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Capture failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final bool isReady =
        controller != null && controller.value.isInitialized;
    final bool canCapture = isReady && !_isBusy;

    Widget preview;
    if (_error != null) {
      preview = Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    } else if (controller != null && controller.value.isInitialized) {
      preview = Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      );
    } else {
      preview = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cross-Platform Camera'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: preview,
            ),
          ),
          if (_lastCapture != null)
            Container(
              color: Colors.black,
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.memory(
                _lastCapture!,
                fit: BoxFit.contain,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.cameras.isEmpty
                      ? 'No camera'
                      : 'Camera ${_selectedIndex + 1} of ${widget.cameras.length}',
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.cameras.length > 1 ? _switchCamera : null,
                      tooltip: 'Switch camera',
                      icon: const Icon(Icons.flip_camera_android),
                    ),
                    IconButton(
                      onPressed: canCapture ? _takePicture : null,
                      tooltip: 'Capture',
                      icon: _isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
