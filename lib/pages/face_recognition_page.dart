// lib/pages/face_recognition_page.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:http_parser/http_parser.dart'; // tidak perlu di file ini
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

  bool _isProcessingFrame = false;
  int _selectedCameraIndex = 0;
  List<Face> _faces = [];
  String attendanceStatus = "Belum";
  String statusMessage = "Posisikan wajah Anda dalam frame";

  // Blink detection
  bool _isLivenessCheckActive = false;
  int _blinkCount = 0;
  final int _requiredBlinks = 2;
  final double _eyeOpenThreshold = 0.4;
  final List<double> _eyeOpennesHistory = [];
  final int _maxHistorySize = 10;
  bool _canProceedWithVerification = false;

  // Guards & stabilizer pasca-liveness
  bool _verifying = false;                 // cegah multiple verify
  bool _awaitingStableOpen = false;        // fase setelah kedip terpenuhi
  int _consecutiveOpenFrames = 0;          // butuh open berturut-turut
  final int _stableOpenTarget = 6;         // jumlah frame open stabil
  Rect? _prevBox;                          // cek stabilitas gerak

  // Throttle pemrosesan frame
  DateTime _lastProc = DateTime.fromMillisecondsSinceEpoch(0);
  final int _minFrameGapMs = 120; // ~8 fps

  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,               // ringan; blink tetap jalan
        enableClassification: true,          // perlu untuk blink
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.2,
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
      ResolutionPreset.high,                 // cukup tajam tanpa berat
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // YUV untuk stream agar lancar
    );
    await _controller.initialize();
    if (!mounted) return;
    setState(() {});
    _startDetection();
  }

  void _startDetection() {
    if (!_controller.value.isStreamingImages) {
      _controller.startImageStream(_onCameraImage);
    }
  }

  void _stopDetection() async {
    if (_controller.value.isStreamingImages) {
      try { await _controller.stopImageStream(); } catch (_) {}
    }
  }

  void _flipCamera() async {
    _stopDetection(); // pastikan stop dulu agar tidak double stream
    await _controller.dispose();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    _resetBlinkDetection();
    _initCamera();
  }

  void _resetBlinkDetection() {
    setState(() {
      _isLivenessCheckActive = false;
      _blinkCount = 0;
      _eyeOpennesHistory.clear();
      _canProceedWithVerification = false;
      _awaitingStableOpen = false;
      _consecutiveOpenFrames = 0;
      _prevBox = null;
      _faces = [];
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

  // IoU untuk cek stabilitas posisi wajah antar frame
  double _iou(Rect a, Rect b) {
    final interLeft = math.max(a.left, b.left);
    final interTop = math.max(a.top, b.top);
    final interRight = math.min(a.right, b.right);
    final interBottom = math.min(a.bottom, b.bottom);
    final interW = math.max(0, interRight - interLeft);
    final interH = math.max(0, interBottom - interTop);
    final inter = interW * interH;
    final union = a.width * a.height + b.width * b.height - inter;
    if (union <= 0) return 0;
    return inter / union;
  }

  Future<void> _onCameraImage(CameraImage image) async {
    // throttle & guard
    final now = DateTime.now();
    if (_isProcessingFrame || _verifying ||
        now.difference(_lastProc).inMilliseconds < _minFrameGapMs) {
      return;
    }
    _lastProc = now;
    _isProcessingFrame = true;

    try {
      // gabungkan bytes dari semua plane
      final bytes = image.planes.fold<Uint8List>(
        Uint8List(0),
            (prev, plane) => Uint8List.fromList(prev + plane.bytes),
      );

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = InputImageRotationValue.fromRawValue(
          widget.cameras[_selectedCameraIndex].sensorOrientation) ??
          InputImageRotation.rotation0deg;

      // Kompatibel dengan google_mlkit_commons 0.11.0 (tanpa planeData)
      final inputImageFormat = Platform.isAndroid
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888; // iOS

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.first.bytesPerRow, // cukup first plane
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _faces = [];
        });
        _eyeOpennesHistory.clear();
        if (!_canProceedWithVerification) {
          _resetBlinkDetection();
        }
        _isProcessingFrame = false;
        return;
      }

      // pilih wajah terbesar
      faces.sort((a, b) => b.boundingBox.height.compareTo(a.boundingBox.height));
      final face = faces.first;

      setState(() {
        _faces = [face];
      });

      // Mulai liveness jika belum
      if (!_isLivenessCheckActive && !_canProceedWithVerification) {
        _startLivenessCheck();
      }
      // Hitung kedip
      else if (_isLivenessCheckActive && !_canProceedWithVerification) {
        if (_detectBlink(face)) {
          _blinkCount++;
          if (_blinkCount >= _requiredBlinks) {
            _canProceedWithVerification = true;
            _isLivenessCheckActive = false;
            _awaitingStableOpen = false;
            _consecutiveOpenFrames = 0;
            _prevBox = null;
            setState(() {
              statusMessage = "Verifikasi liveness berhasil! Tahan pandangan...";
            });
          } else {
            setState(() {
              statusMessage = "Berkedip lagi (${_requiredBlinks - _blinkCount} kali lagi)";
            });
          }
        }
      }
      // Pasca-liveness: tunggu mata terbuka stabil beberapa frame
      else if (_canProceedWithVerification && !_verifying) {
        final l = face.leftEyeOpenProbability ?? 1.0;
        final r = face.rightEyeOpenProbability ?? 1.0;
        final bothOpen = (l > 0.5 && r > 0.5);
        final box = face.boundingBox;

        if (!_awaitingStableOpen) {
          _awaitingStableOpen = true;
          _consecutiveOpenFrames = 0;
          _prevBox = null;
          setState(() {
            statusMessage = "Tahan pandangan ke kamera...";
          });
        }

        if (bothOpen) {
          if (_prevBox == null) {
            _consecutiveOpenFrames += 1;
          } else {
            final iou = _iou(_prevBox!, box);
            if (iou >= 0.6) {
              _consecutiveOpenFrames += 1;
            } else {
              _consecutiveOpenFrames = 0; // gerak terlalu banyak
            }
          }
        } else {
          _consecutiveOpenFrames = 0; // mata tertutup lagi
        }
        _prevBox = box;

        if (_consecutiveOpenFrames >= _stableOpenTarget) {
          // Saatnya foto → stop stream → delay → takePicture → kirim
          _verifying = true;
          _awaitingStableOpen = false;
          _canProceedWithVerification = false;

          setState(() {
            statusMessage = "Mengambil foto...";
          });

          try {
            _stopDetection(); // hentikan stream dulu
            await Future.delayed(const Duration(milliseconds: 300)); // autoexposure settle
            final XFile shot = await _controller.takePicture();
            final File imageFile = File(shot.path);

            setState(() {
              statusMessage = "Mengirim & memverifikasi...";
            });

            final result = await _apiService.verifyFace(imageFile);
            if (!mounted) return;

            if (result["success"] == true) {
              final now = DateTime.now();
              final hh = now.hour.toString().padLeft(2, '0');
              final mm = now.minute.toString().padLeft(2, '0');
              final status = getAttendanceStatus(now);

              setState(() {
                attendanceStatus = "Berhasil";
                statusMessage = "Absensi berhasil: ${result["name"]} ($hh:$mm) • $status";
              });

              await _successController.forward();
              await Future.delayed(const Duration(milliseconds: 800));
              await _successController.reverse();

              // SIKLUS SELESAI → reset & siap percobaan berikutnya
              _resetBlinkDetection();
              _verifying = false;
              if (mounted && !_controller.value.isStreamingImages) {
                try { _startDetection(); } catch (_) {}
              }
            } else {
              setState(() {
                attendanceStatus = "Gagal";
                statusMessage = "Verifikasi gagal: ${result["message"] ?? 'Tidak dikenali'}";
              });

              await Future.delayed(const Duration(seconds: 2));
              _resetBlinkDetection();
              _verifying = false;
              if (mounted && !_controller.value.isStreamingImages) {
                try { _startDetection(); } catch (_) {}
              }
            }
          } catch (e) {
            debugPrint("❌ Error capture/verify: $e");
            if (mounted) {
              setState(() {
                attendanceStatus = "Gagal";
                statusMessage = "Terjadi kesalahan saat mengambil/mengirim foto.";
              });
            }
            await Future.delayed(const Duration(seconds: 2));
            _resetBlinkDetection();
            _verifying = false;
            if (mounted && !_controller.value.isStreamingImages) {
              try { _startDetection(); } catch (_) {}
            }
          }
          // TIDAK ADA finally yang mereset state
        }
      }
    } catch (e) {
      debugPrint("❌ Error face detection: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  @override
  void dispose() {
    _stopDetection();
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
                MaterialPageRoute(builder: (_) => const AdminLoginPage()),
              );
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
          // Face overlay, blink, status (UI TIDAK DIUBAH)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
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
