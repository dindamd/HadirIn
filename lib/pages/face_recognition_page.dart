// lib/pages/face_recognition_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/api_service.dart';
import 'admin_login_page.dart';
import 'attendance_page.dart';

class FaceRecognitionPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FaceRecognitionPage({super.key, required this.cameras});

  @override
  State<FaceRecognitionPage> createState() => _FaceRecognitionPageState();
}

class _FaceRecognitionPageState extends State<FaceRecognitionPage>
    with TickerProviderStateMixin {
  late CameraController _controller;
  late final FaceDetector _faceDetector;
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successAnimation;

  final ApiService _apiService = ApiService();

  bool _isDetecting = false;
  int _selectedCameraIndex = 0;
  List<Face> _faces = [];
  String attendanceStatus = "Belum";
  String statusMessage = "Posisikan wajah Anda dalam frame";

  // Blink detection variables
  bool _isLivenessCheckActive = false;
  int _blinkCount = 0;
  int _requiredBlinks = 2;
  double _eyeOpenThreshold = 0.4;
  List<double> _eyeOpennesHistory = [];
  int _maxHistorySize = 10;
  bool _canProceedWithVerification = false;

  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true, // Untuk blink detection
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _successAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _successController, curve: Curves.elasticOut));

    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameras[_selectedCameraIndex],
      ResolutionPreset.max,
      enableAudio: false,
    );
    await _controller.initialize();
    if (!mounted) return;
    setState(() {});
    _startDetection();
  }

  void _flipCamera() async {
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    await _controller.dispose();
    _resetBlinkDetection();
    _initCamera();
  }

  void _resetBlinkDetection() {
    setState(() {
      _isLivenessCheckActive = false;
      _blinkCount = 0;
      _eyeOpennesHistory.clear();
      _canProceedWithVerification = false;
      statusMessage = "Posisikan wajah Anda dalam frame";
    });
  }

  bool _detectBlink(Face face) {
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    if (leftEye == null || rightEye == null) return false;

    final avgEyeOpenness = (leftEye + rightEye) / 2;
    _eyeOpennesHistory.add(avgEyeOpenness);
    if (_eyeOpennesHistory.length > _maxHistorySize) {
      _eyeOpennesHistory.removeAt(0);
    }

    if (_eyeOpennesHistory.length >= 3) {
      final recent = _eyeOpennesHistory.sublist(_eyeOpennesHistory.length - 3);
      if (recent[0] > _eyeOpenThreshold &&
          recent[1] < _eyeOpenThreshold &&
          recent[2] > _eyeOpenThreshold) {
        return true;
      }
    }
    return false;
  }

  String getAttendanceStatus(DateTime now) {
    final hour = now.hour;
    final minute = now.minute;
    if (hour >= 8 && (hour < 10 || (hour == 10 && minute == 0))) {
      return "On Time";
    } else {
      return "Late";
    }
  }

  void _startLivenessCheck() {
    setState(() {
      _isLivenessCheckActive = true;
      statusMessage = "Silakan berkedip $_requiredBlinks kali untuk verifikasi";
    });
  }

  void _startDetection() {
    _controller.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        final bytes = image.planes.fold<Uint8List>(
          Uint8List(0),
              (previous, plane) => Uint8List.fromList(previous + plane.bytes),
        );

        final imageSize = Size(image.width.toDouble(), image.height.toDouble());

        final rotation = InputImageRotationValue.fromRawValue(
            widget.cameras[_selectedCameraIndex].sensorOrientation) ??
            InputImageRotation.rotation0deg;

        const format = InputImageFormat.nv21;
        final plane = image.planes.first;

        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: imageSize,
            rotation: rotation,
            format: format,
            bytesPerRow: plane.bytesPerRow,
          ),
        );

        final faces = await _faceDetector.processImage(inputImage);

        if (mounted) {
          setState(() {
            _faces = faces;
          });

          if (faces.isNotEmpty) {
            final face = faces.first;

            if (!_isLivenessCheckActive && !_canProceedWithVerification) {
              _startLivenessCheck();
            } else if (_isLivenessCheckActive && !_canProceedWithVerification) {
              if (_detectBlink(face)) {
                _blinkCount++;
                if (_blinkCount >= _requiredBlinks) {
                  _canProceedWithVerification = true;
                  _isLivenessCheckActive = false;
                  statusMessage = "Verifikasi liveness berhasil! Memverifikasi wajah...";
                } else {
                  statusMessage = "Berkedip lagi (${_requiredBlinks - _blinkCount} kali lagi)";
                }
              }
            } else if (_canProceedWithVerification) {
              // Ambil foto dan kirim ke backend
              final XFile picture = await _controller.takePicture();
              final File imageFile = File(picture.path);

              final result = await _apiService.verifyFace(imageFile);

              if (result["success"]) {
                final now = DateTime.now();
                final formattedTime =
                    "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                final status = getAttendanceStatus(now);

                setState(() {
                  attendanceStatus = "Berhasil";
                  statusMessage = "Absensi berhasil: ${result["name"]} ($formattedTime)";
                });

                _successController.forward().then((_) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _successController.reverse();
                  });
                });

                Future.delayed(const Duration(seconds: 3), () {
                  _resetBlinkDetection();
                });
              } else {
                setState(() {
                  attendanceStatus = "Gagal";
                  statusMessage = "Verifikasi gagal: ${result["message"]}";
                });

                Future.delayed(const Duration(seconds: 3), () {
                  _resetBlinkDetection();
                });
              }
            }
          } else {
            if (!_canProceedWithVerification) {
              _resetBlinkDetection();
            }
          }
        }
      } catch (e) {
        debugPrint("❌ Error face detection: $e");
      }

      _isDetecting = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Face Recognition"),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: _flipCamera,
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminLoginPage()));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CameraPreview(_controller),
            ),
          ),
          // Face overlay, blink, status
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                statusMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
