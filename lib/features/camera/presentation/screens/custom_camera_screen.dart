import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../bloc/camera_bloc.dart';
import '../bloc/camera_event.dart';
import '../bloc/camera_state.dart';

class CustomCameraScreen extends StatefulWidget {
  final String? deliveryId;

  const CustomCameraScreen({super.key, this.deliveryId});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  bool _isPermissionDenied = false;
  String? _errorMessage;
  bool _isInitializing = false;
  bool _wentToSettings = false;
  FlashMode _currentFlashMode = FlashMode.auto;

  double _currentLatitude = 28.6139;
  double _currentLongitude = 77.2090;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchLocationForStamp();
    _initializeCamera();
  }

  Future<void> _fetchLocationForStamp() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
      if (mounted) {
        setState(() {
          _currentLatitude = position.latitude;
          _currentLongitude = position.longitude;
        });
      }
    } catch (_) {}
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing) return;
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _isPermissionDenied = false;
        _errorMessage = null;
      });
    }

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'No camera sensor detected on this device.';
          });
        }
        return;
      }

      final backCamera = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await controller.initialize();
      await controller.setFlashMode(_currentFlashMode);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isInitializing = false;
          _isPermissionDenied = false;
          _errorMessage = null;
        });
      }
    } on CameraException {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isInitializing = false;
          _isPermissionDenied = true;
          _errorMessage = 'Camera permission is required to capture proof-of-delivery photos.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isInitializing = false;
          _isPermissionDenied = true;
          _errorMessage = 'Camera access is required. Please grant permission in App Settings.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final camera = _cameraController;
    if (lifecycleState == AppLifecycleState.inactive || lifecycleState == AppLifecycleState.paused) {
      // Do not dispose if we are in the middle of initializing / awaiting the OS permission dialog
      if (camera != null && camera.value.isInitialized && !_isInitializing) {
        _disposeCameraController();
      }
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (_wentToSettings || (!_isCameraInitialized && !_isPermissionDenied)) {
        _wentToSettings = false;
        _initializeCamera();
      }
    }
  }

  void _disposeCameraController() {
    _isCameraInitialized = false;
    _cameraController?.dispose();
    _cameraController = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCameraController();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final camera = _cameraController;
    if (camera == null || !camera.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile rawFile = await camera.takePicture();

      if (!mounted) return;

      context.read<CameraBloc>().add(
            CapturePhotoEvent(
              rawTempPath: rawFile.path,
              latitude: _currentLatitude,
              longitude: _currentLongitude,
              deliveryId: widget.deliveryId,
            ),
          );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture photo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    final nextMode = _currentFlashMode == FlashMode.auto
        ? FlashMode.always
        : _currentFlashMode == FlashMode.always
            ? FlashMode.off
            : FlashMode.auto;

    await _cameraController!.setFlashMode(nextMode);
    setState(() => _currentFlashMode = nextMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Capture Proof of Delivery'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _currentFlashMode == FlashMode.auto
                  ? Icons.flash_auto
                  : _currentFlashMode == FlashMode.always
                      ? Icons.flash_on
                      : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) {
          if (state is CameraPhotoCaptured) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Proof of delivery saved! (${(state.photo.fileSizeBytes / 1024).toStringAsFixed(1)} KB)'),
                backgroundColor: Colors.green[700],
                duration: const Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pop(state.photo);
          } else if (state is CameraError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (_isPermissionDenied || _errorMessage != null) {
            return _buildPermissionDeniedView();
          }

          if (!_isCameraInitialized || _cameraController == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Initializing camera sensor...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }

          final isProcessing = state is CameraProcessingPhoto || _isCapturing;

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_cameraController!),
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Align parcel label inside frame',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 110,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.gps_fixed, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'LAT: ${_currentLatitude.toStringAsFixed(4)}, LNG: ${_currentLongitude.toStringAsFixed(4)}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: isProcessing
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 8),
                            Text(
                              'Baking EXIF & compressing in Isolate...',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: _takePhoto,
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: Center(
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Camera Access Required',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Camera permission was denied. Please grant camera access to capture proof of delivery.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              onPressed: () {
                _wentToSettings = true;
                Geolocator.openAppSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}
