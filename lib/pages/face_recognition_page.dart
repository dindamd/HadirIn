import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'admin_login_page.dart';
import 'dart:typed_data';

class FaceRecognitionPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FaceRecognitionPage({super.key, required this.cameras});

  @override
  State<FaceRecognitionPage> createState() => _FaceRecognitionPageState();
}

class _FaceRecognitionPageState extends State<FaceRecognitionPage> {
  late CameraController _controller;
  late final FaceDetector _faceDetector;
  bool _isDetecting = false;
  int _selectedCameraIndex = 0; // default kamera pertama
  List<Face> _faces = [];
  String attendanceStatus = "Belum"; // status absensi otomatis

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
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller.initialize();
    if (!mounted) return;
    setState(() {});
    _startDetection();
  }

  void _flipCamera() async {
    _selectedCameraIndex =
        (_selectedCameraIndex + 1) % widget.cameras.length;

    await _controller.dispose();
    _initCamera();
  }

  void _startDetection() {
    _controller.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        // Gabungkan semua plane bytes menjadi satu Uint8List
        final bytes = image.planes.fold<Uint8List>(
          Uint8List(0),
              (previous, plane) =>
              Uint8List.fromList(previous + plane.bytes),
        );

        final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

        final rotation = InputImageRotationValue.fromRawValue(
          widget.cameras[_selectedCameraIndex].sensorOrientation,
        ) ?? InputImageRotation.rotation0deg;

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
            // Logika absensi otomatis
            attendanceStatus = _faces.isNotEmpty ? "Berhasil" : "Belum";
          });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Recognition"),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _flipCamera,
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Admin',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginPage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_controller),
          CustomPaint(
            painter: FacePainter(
              faces: _faces,
              imageSize: Size(
                _controller.value.previewSize!.width,
                _controller.value.previewSize!.height,
              ),
            ),
          ),
          // Jumlah wajah
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                "Wajah terdeteksi: ${_faces.length}",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          // Status absensi otomatis
          Positioned(
            top: 60,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                "Status Absensi: $attendanceStatus",
                style: TextStyle(
                  color: _faces.isNotEmpty ? Colors.green : Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  FacePainter({required this.faces, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    for (Face face in faces) {
      final rect = Rect.fromLTRB(
        face.boundingBox.left * scaleX,
        face.boundingBox.top * scaleY,
        face.boundingBox.right * scaleX,
        face.boundingBox.bottom * scaleY,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) =>
      oldDelegate.faces != faces;
}
