import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/api_service.dart';
import 'admin_login_page.dart';
import 'attendance_page.dart';
import 'dart:typed_data';

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

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    // Setup animations
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
      ResolutionPreset.high,
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
    _initCamera();
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

  void _startDetection() {
    _controller.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        final bytes = image.planes.fold<Uint8List>(
          Uint8List(0),
              (previous, plane) => Uint8List.fromList(previous + plane.bytes),
        );

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
            if (faces.isNotEmpty) {
              statusMessage = "Wajah terdeteksi, sedang memverifikasi...";
            } else {
              statusMessage = "Posisikan wajah Anda dalam frame";
            }
          });

          final result = await _apiService.verifyFace(faces.isNotEmpty);
          if (mounted && result["success"]) {
            final now = DateTime.now();
            final formattedTime =
                "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

            final status = getAttendanceStatus(now);

            setState(() {
              attendanceStatus = "Berhasil";
              statusMessage = "Absensi berhasil: ${result["name"]} ($formattedTime)";
            });

            // Trigger success animation
            _successController.forward().then((_) {
              Future.delayed(Duration(milliseconds: 500), () {
                _successController.reverse();
              });
            });

            // Update attendance list
            final existingIndex = attendanceList.indexWhere(
                    (item) => item["name"] == result["name"]);

            if (existingIndex != -1) {
              if (attendanceList[existingIndex]["time"] == "-") {
                attendanceList[existingIndex]["time"] = formattedTime;
                attendanceList[existingIndex]["status"] = status;
              }
            }
          }
        }

        debugPrint("👤 Detected faces: ${faces.length}");
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
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
        children: [
          // Camera Preview with proper sizing
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 120, bottom: 180),
              width: MediaQuery.of(context).size.width - 32,
              height: (MediaQuery.of(context).size.width - 32) * 4/3, // Standard 4:3 ratio
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 32,
                      height: (MediaQuery.of(context).size.width - 32) * 4/3,
                      child: CameraPreview(_controller),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Face detection overlay with proper scaling
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 120, bottom: 180),
              width: MediaQuery.of(context).size.width - 32,
              height: (MediaQuery.of(context).size.width - 32) * 4/3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CustomPaint(
                  painter: ModernFacePainter(
                    faces: _faces,
                    imageSize: Size(
                      _controller.value.previewSize!.height,
                      _controller.value.previewSize!.width,
                    ),
                    animation: _pulseAnimation,
                  ),
                ),
              ),
            ),
          ),

          // Top status card - lebih ke bawah
          Positioned(
            top: 140,
            left: 24,
            right: 24,
            child: AnimatedBuilder(
              animation: _successController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_successAnimation.value * 0.1),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: attendanceStatus == "Berhasil"
                            ? [Colors.green.shade400, Colors.green.shade600]
                            : [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (attendanceStatus == "Berhasil"
                              ? Colors.green
                              : Colors.blue)
                              .withOpacity(0.3),
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
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Face count indicator - posisi lebih ke bawah dan tidak mepet
          Positioned(
            top: 210,
            left: 24,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _faces.isNotEmpty ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.face,
                    color: _faces.isNotEmpty ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Wajah: ${_faces.length}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom instruction card - posisi lebih ke atas
          Positioned(
            bottom: 120,
            left: 24,
            right: 24,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Instruksi Scan",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              "Posisikan wajah dalam frame dan tunggu",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  ModernFacePainter({
    required this.faces,
    required this.imageSize,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    // Proper scaling calculation
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // Use the same scale for both dimensions to maintain aspect ratio
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate offset to center the scaled content
    final double offsetX = (size.width - (imageSize.width * scale)) / 2;
    final double offsetY = (size.height - (imageSize.height * scale)) / 2;

    // Animated paint for face detection
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * animation.value
      ..color = Colors.greenAccent.withOpacity(0.8);

    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 * animation.value
      ..color = Colors.green.withOpacity(0.3);

    for (Face face in faces) {
      // Apply proper scaling and offset
      final rect = Rect.fromLTRB(
        (face.boundingBox.left * scale) + offsetX,
        (face.boundingBox.top * scale) + offsetY,
        (face.boundingBox.right * scale) + offsetX,
        (face.boundingBox.bottom * scale) + offsetY,
      );

      // Draw shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(12)),
        shadowPaint,
      );

      // Draw main frame
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(12)),
        paint,
      );

      // Draw corner indicators
      final cornerSize = 20.0 * animation.value;
      final cornerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = Colors.green;

      // Top-left corner
      canvas.drawPath(
        Path()
          ..moveTo(rect.left, rect.top + cornerSize)
          ..lineTo(rect.left, rect.top + 12)
          ..quadraticBezierTo(rect.left, rect.top, rect.left + 12, rect.top)
          ..lineTo(rect.left + cornerSize, rect.top),
        cornerPaint,
      );

      // Top-right corner
      canvas.drawPath(
        Path()
          ..moveTo(rect.right - cornerSize, rect.top)
          ..lineTo(rect.right - 12, rect.top)
          ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + 12)
          ..lineTo(rect.right, rect.top + cornerSize),
        cornerPaint,
      );

      // Bottom-left corner
      canvas.drawPath(
        Path()
          ..moveTo(rect.left, rect.bottom - cornerSize)
          ..lineTo(rect.left, rect.bottom - 12)
          ..quadraticBezierTo(rect.left, rect.bottom, rect.left + 12, rect.bottom)
          ..lineTo(rect.left + cornerSize, rect.bottom),
        cornerPaint,
      );

      // Bottom-right corner
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
      oldDelegate.faces != faces || oldDelegate.animation.value != animation.value;
}