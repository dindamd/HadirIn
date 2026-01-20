import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/api_service.dart';
import 'admin_login_page.dart';

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
  bool _isVerifying = false;
  bool _pendingVerification = false;
  DateTime? _lastFrameProcessedAt;
  final Duration _frameInterval = const Duration(milliseconds: 140);
  int _selectedCameraIndex = 0;
  List<Face> _faces = [];
  String attendanceStatus = "Belum";
  String statusMessage = "Posisikan wajah Anda dalam frame";
  DateTime? _lastFaceSeenAt;

  // Blink detection variables
  bool _isLivenessCheckActive = false;
  int _blinkCount = 0;
  final int _requiredBlinks = 2;
  final double _eyeOpenThreshold = 0.38;
  final double _eyeClosedThreshold = 0.32;
  final int _baselineTargetSamples = 3;
  final int _minClosedFrames = 1;
  final Duration _blinkDebounce = Duration(milliseconds: 220);
  bool _eyesCurrentlyOpen = true;
  DateTime? _lastBlinkAt;
  double? _eyeBaseline;
  int _baselineSamples = 0;
  int _closedFrames = 0;
  final List<double> _eyeOpennesHistory = [];
  final int _maxHistorySize = 4;
  bool _canProceedWithVerification = false;
  DateTime? _lastVerificationAt;

  @override
  void initState() {
    super.initState();
    _selectedCameraIndex = widget.cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    if (_selectedCameraIndex < 0) {
      _selectedCameraIndex = 0;
    }
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: true, // Enable untuk blink detection
        performanceMode: FaceDetectorMode.fast, // Lebih responsif di device asli
        enableTracking: true,
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

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _successAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() {});
      await _startDetection();
    } catch (e) {
      debugPrint('Error init camera: $e');
    }
  }

  void _flipCamera() async {
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    await _stopDetectionStream();
    await _controller.dispose();
    _resetBlinkDetection();
    _initCamera();
  }

  void _resetBlinkDetection() {
    _pendingVerification = false;
    setState(() {
      _isLivenessCheckActive = false;
      _blinkCount = 0;
      _eyesCurrentlyOpen = true;
      _lastBlinkAt = null;
      _eyeBaseline = null;
      _baselineSamples = 0;
      _closedFrames = 0;
      _eyeOpennesHistory.clear();
      _canProceedWithVerification = false;
      statusMessage = "Posisikan wajah Anda dalam frame";
    });
  }

  bool _detectBlink(Face face) {
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    final availableEyes = <double>[];
    if (leftEye != null) availableEyes.add(leftEye);
    if (rightEye != null) availableEyes.add(rightEye);
    if (availableEyes.isEmpty) return false;

    final avgEyeOpenness =
        availableEyes.reduce((a, b) => a + b) / availableEyes.length;

    _eyeOpennesHistory.add(avgEyeOpenness);
    if (_eyeOpennesHistory.length > _maxHistorySize) {
      _eyeOpennesHistory.removeAt(0);
    }

    final smoothed = _eyeOpennesHistory.reduce((a, b) => a + b) /
        _eyeOpennesHistory.length;

    if (_isLivenessCheckActive && _eyeBaseline == null) {
      if (smoothed >= _eyeOpenThreshold) {
        _baselineSamples += 1;
        _eyeBaseline = (_eyeBaseline ?? 0) + smoothed;
        if (_baselineSamples >= _baselineTargetSamples) {
          _eyeBaseline = _eyeBaseline! / _baselineSamples;
        }
      }
    }

    final double openThreshold = _eyeBaseline != null
        ? (_eyeBaseline! * 0.75).clamp(0.28, 0.85).toDouble()
        : _eyeOpenThreshold;
    final double closedThreshold = _eyeBaseline != null
        ? (_eyeBaseline! * 0.6).clamp(0.22, 0.7).toDouble()
        : _eyeClosedThreshold;

    if (smoothed < closedThreshold) {
      _closedFrames += 1;
      _eyesCurrentlyOpen = false;
      return false;
    }

    if (smoothed > openThreshold) {
      if (!_eyesCurrentlyOpen && _closedFrames >= _minClosedFrames) {
        _eyesCurrentlyOpen = true;
        _closedFrames = 0;
        final now = DateTime.now();
        if (_lastBlinkAt == null ||
            now.difference(_lastBlinkAt!) > _blinkDebounce) {
          _lastBlinkAt = now;
          return true;
        }
      } else {
        _closedFrames = 0;
        _eyesCurrentlyOpen = true;
      }
    }

    return false;
  }

  void _startLivenessCheck() {
    setState(() {
      _isLivenessCheckActive = true;
      statusMessage = "Silakan berkedip $_requiredBlinks kali untuk verifikasi";
    });
  }

  Future<void> _startDetection() async {
    if (!_controller.value.isInitialized || _controller.value.isStreamingImages) {
      return;
    }

    try {
      await _controller.startImageStream((CameraImage image) async {
        if (_isDetecting || _isVerifying) return;
        final now = DateTime.now();
        if (_lastFrameProcessedAt != null &&
            now.difference(_lastFrameProcessedAt!) < _frameInterval) {
          return;
        }
        _lastFrameProcessedAt = now;
        _isDetecting = true;

        try {
          final WriteBuffer allBytes = WriteBuffer();
          for (final plane in image.planes) {
            allBytes.putUint8List(plane.bytes);
          }
          final bytes = allBytes.done().buffer.asUint8List();

          final Size imageSize =
              Size(image.width.toDouble(), image.height.toDouble());

          final rotation = InputImageRotationValue.fromRawValue(
                widget.cameras[_selectedCameraIndex].sensorOrientation,
              ) ??
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
              _lastFaceSeenAt = DateTime.now();
              final face = faces.first;

              if (!_isLivenessCheckActive && !_canProceedWithVerification) {
                _startLivenessCheck();
              } else if (_isLivenessCheckActive && !_canProceedWithVerification) {
                if (_detectBlink(face)) {
                  _blinkCount++;
                  setState(() {
                    if (_blinkCount >= _requiredBlinks) {
                      _canProceedWithVerification = true;
                      _isLivenessCheckActive = false;
                      statusMessage = "Verifikasi liveness berhasil! Memverifikasi wajah...";
                    } else {
                      statusMessage =
                          "Berkedip lagi (${_requiredBlinks - _blinkCount} kali lagi)";
                    }
                  });
                }
              } else if (_canProceedWithVerification &&
                  !_pendingVerification &&
                  !_isVerifying) {
                _pendingVerification = true;
                _isDetecting = false;
                await _captureAndVerify();
                return;
              }
            } else {
              if (!_canProceedWithVerification && !_isVerifying) {
                final now = DateTime.now();
                final lastSeen = _lastFaceSeenAt;
                final shouldReset = lastSeen == null ||
                    now.difference(lastSeen) > const Duration(milliseconds: 900);
                if (shouldReset) {
                  setState(() {
                    statusMessage = "Posisikan wajah Anda dalam frame";
                  });
                  _resetBlinkDetection();
                }
              }
            }
          }
        } catch (e) {
          debugPrint("Error face detection: $e");
        }

        _isDetecting = false;
      });
    } catch (e) {
      debugPrint('Gagal memulai stream kamera: $e');
    }
  }

  Future<void> _stopDetectionStream() async {
    if (_controller.value.isStreamingImages) {
      try {
        await _controller.stopImageStream();
      } catch (e) {
        debugPrint('Gagal menghentikan stream: $e');
      }
    }
    _isDetecting = false;
  }

  Future<void> _captureAndVerify() async {
    if (!_controller.value.isInitialized) return;

    setState(() {
      _isVerifying = true;
      attendanceStatus = "Memproses";
      statusMessage = "Mengambil gambar untuk verifikasi...";
    });

    await _stopDetectionStream();

    try {
      final picture = await _controller.takePicture();
      if (!mounted) return;

      setState(() {
        statusMessage = "Mengirim ke server absensi...";
      });

      final result = await _apiService.verifyFace(picture);
      if (!mounted) return;

      if (result.success) {
        setState(() {
          attendanceStatus = "Berhasil";
          final name = result.name ?? 'Karyawan';
          final time = result.time != null && result.time!.isNotEmpty
              ? ' (${result.time})'
              : '';
          statusMessage = "Absensi $name$time";
        });

        _successController.forward().then((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _successController.reverse();
          });
        });
      } else {
        setState(() {
          attendanceStatus = "Gagal";
          statusMessage = result.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          attendanceStatus = "Gagal";
          statusMessage = "Gagal verifikasi: $e";
        });
      }
    } finally {
      if (mounted) {
        _pendingVerification = false;
        _isVerifying = false;
        _lastVerificationAt = DateTime.now();
        await Future.delayed(const Duration(seconds: 3));
        attendanceStatus = "Belum";
        _resetBlinkDetection();
        await Future.delayed(const Duration(milliseconds: 300));
        await _startDetection();
      }
    }
  }

  @override
  void dispose() {
    _stopDetectionStream();
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  strokeWidth: 4,
                ),
              ),
              SizedBox(height: 24),
              Text(
                "Mempersiapkan kamera...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final previewSize = _controller.value.previewSize;
    final painterSize = previewSize == null
        ? const Size(1, 1)
        : (previewSize.width > previewSize.height
            ? Size(previewSize.height, previewSize.width)
            : Size(previewSize.width, previewSize.height));

    final cameraLayer = previewSize == null
        ? Container(color: Colors.black)
        : FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.width,
              height: previewSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_controller),
                  CustomPaint(
                    painter: ModernFacePainter(
                      faces: _faces,
                      imageSize: painterSize,
                      animation: _pulseAnimation,
                      isLivenessActive: _isLivenessCheckActive,
                    ),
                  ),
                ],
              ),
            ),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Face Recognition",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.cameraswitch_outlined, color: Colors.white),
              onPressed: _flipCamera,
              tooltip: 'Flip Camera',
            ),
          ),
          Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
              tooltip: 'Admin',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: cameraLayer),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.05),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: _successController,
                    builder: (context, child) {
                      Color startColor;
                      Color endColor;
                      if (attendanceStatus == "Berhasil") {
                        startColor = Colors.green.shade400;
                        endColor = Colors.green.shade600;
                      } else if (attendanceStatus == "Gagal") {
                        startColor = Colors.red.shade400;
                        endColor = Colors.red.shade600;
                      } else if (_isLivenessCheckActive) {
                        startColor = Colors.orange.shade400;
                        endColor = Colors.orange.shade600;
                      } else {
                        startColor = Colors.blue.shade400;
                        endColor = Colors.blue.shade600;
                      }

                      final shadowColor = attendanceStatus == "Berhasil"
                          ? Colors.green
                          : attendanceStatus == "Gagal"
                              ? Colors.red
                              : _isLivenessCheckActive
                                  ? Colors.orange
                                  : Colors.blue;

                      return Transform.scale(
                        scale: 1.0 + (_successAnimation.value * 0.1),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [startColor, endColor],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  statusMessage,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                              if (_isVerifying)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      if (_isLivenessCheckActive)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.remove_red_eye,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Kedipan: $_blinkCount/$_requiredBlinks",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isLivenessCheckActive) SizedBox(width: 10),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _faces.isNotEmpty
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.face_retouching_natural,
                              color: _faces.isNotEmpty
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Wajah: ${_faces.length}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _isLivenessCheckActive
                                ? Icons.remove_red_eye
                                : Icons.camera_alt_outlined,
                            color: Colors.blue.shade600,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isLivenessCheckActive
                                    ? "Instruksi Kedip"
                                    : "Instruksi Scan",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Poppins',
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                _isLivenessCheckActive
                                    ? "Berkedip $_requiredBlinks kali untuk verifikasi anti-foto"
                                    : _isVerifying
                                        ? "Sedang memverifikasi wajah ke server..."
                                        : "Posisikan wajah dalam frame dan tunggu",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        if (_isVerifying)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ModernFacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Animation<double> animation;
  final bool isLivenessActive;

  ModernFacePainter({
    required this.faces,
    required this.imageSize,
    required this.animation,
    required this.isLivenessActive,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    final double scale = scaleX < scaleY ? scaleX : scaleY;
    final double offsetX = (size.width - (imageSize.width * scale)) / 2;
    final double offsetY = (size.height - (imageSize.height * scale)) / 2;

    final Color frameColor = isLivenessActive
        ? Colors.orange
        : Colors.greenAccent;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * animation.value
      ..color = frameColor.withValues(alpha: 0.8);

    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 * animation.value
      ..color = frameColor.withValues(alpha: 0.3);

    for (Face face in faces) {
      final rect = Rect.fromLTRB(
        (face.boundingBox.left * scale) + offsetX,
        (face.boundingBox.top * scale) + offsetY,
        (face.boundingBox.right * scale) + offsetX,
        (face.boundingBox.bottom * scale) + offsetY,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(12)),
        shadowPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(12)),
        paint,
      );

      final cornerSize = 20.0 * animation.value;
      final cornerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = frameColor;

      canvas.drawPath(
        Path()
          ..moveTo(rect.left, rect.top + cornerSize)
          ..lineTo(rect.left, rect.top + 12)
          ..quadraticBezierTo(rect.left, rect.top, rect.left + 12, rect.top)
          ..lineTo(rect.left + cornerSize, rect.top),
        cornerPaint,
      );

      canvas.drawPath(
        Path()
          ..moveTo(rect.right - cornerSize, rect.top)
          ..lineTo(rect.right - 12, rect.top)
          ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + 12)
          ..lineTo(rect.right, rect.top + cornerSize),
        cornerPaint,
      );

      canvas.drawPath(
        Path()
          ..moveTo(rect.left, rect.bottom - cornerSize)
          ..lineTo(rect.left, rect.bottom - 12)
          ..quadraticBezierTo(rect.left, rect.bottom, rect.left + 12, rect.bottom)
          ..lineTo(rect.left + cornerSize, rect.bottom),
        cornerPaint,
      );

      canvas.drawPath(
        Path()
          ..moveTo(rect.right - cornerSize, rect.bottom)
          ..lineTo(rect.right - 12, rect.bottom)
          ..quadraticBezierTo(rect.right, rect.bottom, rect.right, rect.bottom - 12)
          ..lineTo(rect.right, rect.bottom - cornerSize),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ModernFacePainter oldDelegate) =>
      oldDelegate.faces != faces ||
      oldDelegate.animation.value != animation.value ||
      oldDelegate.isLivenessActive != isLivenessActive;
}
