// // lib/pages/face_recognition_page.dart
// import 'dart:io';
// import 'dart:math' as math;
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import '../services/api_service.dart';
// import 'admin_login_page.dart';
// import 'attendance_page.dart';
//
// class FaceRecognitionPage extends StatefulWidget {
//   final List<CameraDescription> cameras;
//   const FaceRecognitionPage({super.key, required this.cameras});
//
//   @override
//   State<FaceRecognitionPage> createState() => _FaceRecognitionPageState();
// }
//
// class _FaceRecognitionPageState extends State<FaceRecognitionPage>
//     with TickerProviderStateMixin {
//   late CameraController _controller;
//   late final FaceDetector _faceDetector;
//   late AnimationController _pulseController;
//   late AnimationController _successController;
//   late Animation<double> _pulseAnimation;
//   late Animation<double> _successAnimation;
//
//   final ApiService _apiService = ApiService();
//
//   bool _isProcessingFrame = false;
//   bool _isSwitchingCamera = false; // guard saat flip kamera
//   int _selectedCameraIndex = 0;
//   List<Face> _faces = [];
//   String attendanceStatus = "Belum";
//   String statusMessage = "Posisikan wajah Anda dalam frame";
//
//   // === Tambahan: tipe absensi (IN/OUT) ===
//   String _attendanceType = 'IN';
//
//   // Blink detection
//   bool _isLivenessCheckActive = false;
//   int _blinkCount = 0;
//   final int _requiredBlinks = 2;
//   double _openThresh = 0.4;   // lowered threshold for "open"
//   double _closedThresh = 0.35; // raised threshold for "closed" (smaller gap)
//   final List<double> _eyeOpennesHistory = [];
//   final int _maxHistorySize = 15; // increased buffer
//   bool _canProceedWithVerification = false;
//   bool _eyesWereClosed = false; // track blink state
//
//   // Debounce blink
//   DateTime _lastBlinkAt = DateTime.fromMillisecondsSinceEpoch(0);
//   final int _minBlinkIntervalMs = 400;
//
//   // Guards & stabilizer pasca-liveness
//   bool _verifying = false;
//   bool _awaitingStableOpen = false;
//   int _consecutiveOpenFrames = 0;
//   final int _stableOpenTarget = 5; // 5 frame stabil
//   Rect? _prevBox;
//
//   // Throttle pemrosesan frame
//   DateTime _lastProc = DateTime.fromMillisecondsSinceEpoch(0);
//   final int _minFrameGapMs = 100; // ~10 fps
//
//   // Session timeout
//   final int _maxSessionSecs = 20; // batas 20 detik
//   late DateTime _sessionDeadline;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _faceDetector = FaceDetector(
//       options: FaceDetectorOptions(
//         enableContours: false,
//         enableClassification: true,
//         performanceMode: FaceDetectorMode.fast,
//         minFaceSize: 0.3,
//       ),
//     );
//
//     _pulseController = AnimationController(
//       duration: const Duration(seconds: 2),
//       vsync: this,
//     )..repeat(reverse: true);
//
//     _successController = AnimationController(
//       duration: const Duration(milliseconds: 600),
//       vsync: this,
//     );
//
//     _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2)
//         .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
//
//     _successAnimation = Tween<double>(begin: 0.0, end: 1.0)
//         .animate(CurvedAnimation(parent: _successController, curve: Curves.elasticOut));
//
//     // Default: pilih kamera depan jika tersedia
//     _selectedCameraIndex = widget.cameras.indexWhere(
//           (c) => c.lensDirection == CameraLensDirection.front,
//     );
//     if (_selectedCameraIndex < 0) _selectedCameraIndex = 0;
//
//     _initCamera();
//
//     // Munculkan pilihan IN/OUT setelah frame pertama
//     WidgetsBinding.instance.addPostFrameCallback((_) => _pickType());
//   }
//
//   Future<void> _pickType() async {
//     final sel = await showModalBottomSheet<String>(
//       context: context,
//       backgroundColor: Colors.grey[900],
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (_) {
//         return SafeArea(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Text("Pilih jenis absensi",
//                     style: TextStyle(color: Colors.white, fontSize: 16)),
//               ),
//               ListTile(
//                 leading: const Icon(Icons.login, color: Colors.white),
//                 title: const Text("Check-In", style: TextStyle(color: Colors.white)),
//                 onTap: () => Navigator.pop(context, 'IN'),
//               ),
//               ListTile(
//                 leading: const Icon(Icons.logout, color: Colors.white),
//                 title: const Text("Check-Out", style: TextStyle(color: Colors.white)),
//                 onTap: () => Navigator.pop(context, 'OUT'),
//               ),
//               const SizedBox(height: 8),
//             ],
//           ),
//         );
//       },
//     );
//
//     setState(() {
//       _attendanceType = (sel == 'OUT') ? 'OUT' : 'IN';
//       statusMessage = _attendanceType == 'IN'
//           ? "Mode: Check-In • Posisi wajah dalam frame"
//           : "Mode: Check-Out • Posisi wajah dalam frame";
//     });
//   }
//
//   Future<void> _initCamera() async {
//     _controller = CameraController(
//       widget.cameras[_selectedCameraIndex],
//       ResolutionPreset.medium,
//       enableAudio: false,
//       imageFormatGroup: ImageFormatGroup.yuv420, // stream lancar
//     );
//     await _controller.initialize();
//     if (!mounted) return;
//     setState(() {});
//     _startDetection();
//   }
//
//   void _startDetection() {
//     _startSessionTimer();
//     if (!_controller.value.isStreamingImages) {
//       _controller.startImageStream(_onCameraImage);
//     }
//   }
//
//   void _stopDetection() async {
//     if (_controller.value.isStreamingImages) {
//       try {
//         await _controller.stopImageStream();
//       } catch (_) {}
//     }
//   }
//
//   // Flip camera: aman dari disposed buildPreview
//   Future<void> _flipCamera() async {
//     if (_isSwitchingCamera) return;
//     setState(() => _isSwitchingCamera = true);
//
//     try {
//       _stopDetection();
//       try {
//         await _controller.dispose();
//       } catch (_) {}
//
//       _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
//
//       _resetBlinkDetection();
//       await _initCamera();
//     } finally {
//       if (mounted) setState(() => _isSwitchingCamera = false);
//     }
//   }
//
//   void _startSessionTimer() {
//     _sessionDeadline = DateTime.now().add(Duration(seconds: _maxSessionSecs));
//   }
//
//   bool _sessionExpired() => DateTime.now().isAfter(_sessionDeadline);
//
//   void _resetBlinkDetection({String? message}) {
//     setState(() {
//       _isLivenessCheckActive = false;
//       _blinkCount = 0;
//       _eyeOpennesHistory.clear();
//       _canProceedWithVerification = false;
//       _awaitingStableOpen = false;
//       _consecutiveOpenFrames = 0;
//       _prevBox = null;
//       _faces = [];
//       statusMessage = message ?? "Posisikan wajah Anda dalam frame";
//     });
//     _startSessionTimer();
//   }
//
//   bool _detectBlink(Face face) {
//     final l = face.leftEyeOpenProbability;
//     final r = face.rightEyeOpenProbability;
//     if (l == null || r == null) return false;
//
//     final avg = (l + r) / 2;
//     _eyeOpennesHistory.add(avg);
//     if (_eyeOpennesHistory.length > _maxHistorySize) {
//       _eyeOpennesHistory.removeAt(0);
//     }
//
//     if (_eyeOpennesHistory.length >= 3) {
//       final recent = _eyeOpennesHistory.sublist(_eyeOpennesHistory.length - 3);
//       final isBlink = (recent[0] > _openThresh) &&
//           (recent[1] < _closedThresh) &&
//           (recent[2] > _openThresh);
//
//       if (isBlink) {
//         final now = DateTime.now();
//         if (now.difference(_lastBlinkAt).inMilliseconds >= _minBlinkIntervalMs) {
//           _lastBlinkAt = now;
//           return true;
//         }
//       }
//     }
//     return false;
//   }
//
//   String getAttendanceStatus(DateTime now) {
//     final hour = now.hour;
//     final minute = now.minute;
//     if (hour >= 8 && (hour < 10 || (hour == 10 && minute == 0))) {
//       return "On Time";
//     } else {
//       return "Late";
//     }
//   }
//
//   void _startLivenessCheck() {
//     setState(() {
//       _isLivenessCheckActive = true;
//       statusMessage = "Silakan berkedip $_requiredBlinks kali (≤ ${_maxSessionSecs}s)";
//     });
//     _startSessionTimer();
//   }
//
//   double _iou(Rect a, Rect b) {
//     final interLeft = math.max(a.left, b.left);
//     final interTop = math.max(a.top, b.top);
//     final interRight = math.min(a.right, b.right);
//     final interBottom = math.min(a.bottom, b.bottom);
//     final interW = math.max(0, interRight - interLeft);
//     final interH = math.max(0, interBottom - interTop);
//     final inter = interW * interH;
//     final union = a.width * a.height + b.width * b.height - inter;
//     if (union <= 0) return 0;
//     return inter / union;
//   }
//
//   String _remainingSecText() {
//     final left = _sessionDeadline.difference(DateTime.now()).inSeconds;
//     final clamped = left < 0 ? 0 : left;
//     return "sisa ${clamped}s";
//   }
//
//   Future<void> _onCameraImage(CameraImage image) async {
//     // timeout sesi
//     if (_sessionExpired() && !_verifying) {
//       _stopDetection();
//       setState(() {
//         statusMessage = "Waktu habis (>${_maxSessionSecs}s). Coba lagi.";
//       });
//       await Future.delayed(const Duration(milliseconds: 800));
//       _resetBlinkDetection();
//       _startDetection();
//       return;
//     }
//
//     // throttle & guard
//     final now = DateTime.now();
//     if (_isProcessingFrame ||
//         _verifying ||
//         now.difference(_lastProc).inMilliseconds < _minFrameGapMs) {
//       return;
//     }
//     _lastProc = now;
//     _isProcessingFrame = true;
//
//     try {
//       // gabungkan bytes (YUV)
//       final bytes = image.planes.fold<Uint8List>(
//         Uint8List(0),
//             (prev, plane) => Uint8List.fromList(prev + plane.bytes),
//       );
//
//       final imageSize = Size(image.width.toDouble(), image.height.toDouble());
//       final rotation = InputImageRotationValue.fromRawValue(
//           widget.cameras[_selectedCameraIndex].sensorOrientation) ??
//           InputImageRotation.rotation0deg;
//
//       // Kompatibel dengan google_mlkit_commons 0.11.x (tanpa planeData)
//       final inputImageFormat = Platform.isAndroid
//           ? InputImageFormat.nv21
//           : InputImageFormat.bgra8888;
//
//       final inputImage = InputImage.fromBytes(
//         bytes: bytes,
//         metadata: InputImageMetadata(
//           size: imageSize,
//           rotation: rotation,
//           format: inputImageFormat,
//           bytesPerRow: image.planes.first.bytesPerRow,
//         ),
//       );
//
//       final faces = await _faceDetector.processImage(inputImage);
//       if (!mounted) return;
//
//       if (faces.isEmpty) {
//         setState(() {
//           _faces = [];
//           statusMessage = "Wajah belum terdeteksi • ${_remainingSecText()}";
//         });
//         _eyeOpennesHistory.clear();
//         _isProcessingFrame = false;
//         return;
//       }
//
//       // pilih wajah terbesar
//       faces.sort((a, b) => b.boundingBox.height.compareTo(a.boundingBox.height));
//       final face = faces.first;
//
//       setState(() {
//         _faces = [face];
//       });
//
//       // Mulai liveness jika belum
//       if (!_isLivenessCheckActive && !_canProceedWithVerification) {
//         _startLivenessCheck();
//       }
//       // Hitung kedip
//       else if (_isLivenessCheckActive && !_canProceedWithVerification) {
//         if (_detectBlink(face)) {
//           _blinkCount++;
//           if (_blinkCount >= _requiredBlinks) {
//             _canProceedWithVerification = true;
//             _isLivenessCheckActive = false;
//             _awaitingStableOpen = false;
//             _consecutiveOpenFrames = 0;
//             _prevBox = null;
//             setState(() {
//               statusMessage = "Liveness OK • Tahan pandangan… ${_remainingSecText()}";
//             });
//           } else {
//             setState(() {
//               statusMessage =
//               "Berkedip lagi (${_requiredBlinks - _blinkCount}) • ${_remainingSecText()}";
//             });
//           }
//         } else {
//           setState(() {
//             statusMessage = "Berkedip $_requiredBlinks× • ${_remainingSecText()}";
//           });
//         }
//       }
//       // Pasca-liveness: tunggu mata terbuka stabil beberapa frame
//       else if (_canProceedWithVerification && !_verifying) {
//         final l = face.leftEyeOpenProbability ?? 1.0;
//         final r = face.rightEyeOpenProbability ?? 1.0;
//         final bothOpen = (l > _openThresh && r > _openThresh);
//         final box = face.boundingBox;
//
//         if (!_awaitingStableOpen) {
//           _awaitingStableOpen = true;
//           _consecutiveOpenFrames = 0;
//           _prevBox = null;
//           setState(() {
//             statusMessage = "Tahan pandangan… ${_remainingSecText()}";
//           });
//         }
//
//         if (bothOpen) {
//           if (_prevBox == null) {
//             _consecutiveOpenFrames += 1;
//           } else {
//             final iou = _iou(_prevBox!, box);
//             if (iou >= 0.6) {
//               _consecutiveOpenFrames += 1;
//             } else {
//               _consecutiveOpenFrames = 0;
//             }
//           }
//         } else {
//           _consecutiveOpenFrames = 0;
//         }
//         _prevBox = box;
//
//         if (_consecutiveOpenFrames >= _stableOpenTarget) {
//           // Saatnya foto → stop stream → delay → takePicture → kirim
//           _verifying = true;
//           _awaitingStableOpen = false;
//           _canProceedWithVerification = false;
//
//           setState(() {
//             statusMessage = "Mengambil foto…";
//           });
//
//           try {
//             _stopDetection();
//             await Future.delayed(const Duration(milliseconds: 280)); // exposure settle
//             final XFile shot = await _controller.takePicture();
//             final File imageFile = File(shot.path);
//
//             setState(() {
//               statusMessage = "Memverifikasi…";
//             });
//
//             // >>> kirim type IN/OUT ke backend
//             final result = await _apiService.verifyFace(imageFile, type: _attendanceType);
//             if (!mounted) return;
//
//             if (result["success"] == true) {
//               final now2 = DateTime.now();
//               final hh = now2.hour.toString().padLeft(2, '0');
//               final mm = now2.minute.toString().padLeft(2, '0');
//               final status = getAttendanceStatus(now2);
//
//               setState(() {
//                 attendanceStatus = "Berhasil";
//                 final phase = (result["phase"] ?? _attendanceType).toString();
//                 final msg = (result["message"] ?? (phase == 'IN'
//                     ? "Check-In berhasil"
//                     : phase == 'OUT'
//                     ? "Check-Out berhasil"
//                     : "Absensi berhasil")) as String;
//                 statusMessage = "$msg: ${result["name"] ?? '-'} ($hh:$mm) • $status";
//               });
//
//               await _successController.forward();
//               await Future.delayed(const Duration(milliseconds: 800));
//               await _successController.reverse();
//
//               _resetBlinkDetection();
//               _verifying = false;
//               if (mounted && !_controller.value.isStreamingImages) {
//                 try {
//                   _startDetection();
//                 } catch (_) {}
//               }
//             } else {
//               setState(() {
//                 attendanceStatus = "Gagal";
//                 statusMessage =
//                 "Verifikasi gagal: ${result["message"] ?? 'Tidak dikenali'}";
//               });
//
//               await Future.delayed(const Duration(seconds: 2));
//               _resetBlinkDetection();
//               _verifying = false;
//               if (mounted && !_controller.value.isStreamingImages) {
//                 try {
//                   _startDetection();
//                 } catch (_) {}
//               }
//             }
//           } catch (e) {
//             debugPrint("❌ Error capture/verify: $e");
//             if (mounted) {
//               setState(() {
//                 attendanceStatus = "Gagal";
//                 statusMessage = "Kesalahan saat mengambil/mengirim foto.";
//               });
//             }
//             await Future.delayed(const Duration(seconds: 2));
//             _resetBlinkDetection();
//             _verifying = false;
//             if (mounted && !_controller.value.isStreamingImages) {
//               try {
//                 _startDetection();
//               } catch (_) {}
//             }
//           }
//         } else {
//           setState(() {
//             statusMessage = "Tahan pandangan… ${_remainingSecText()}";
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint("❌ Error face detection: $e");
//     } finally {
//       _isProcessingFrame = false;
//     }
//   }
//
//   @override
//   void dispose() {
//     _stopDetection();
//     _controller.dispose();
//     _faceDetector.close();
//     _pulseController.dispose();
//     _successController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Tahan render saat switching / belum initialized → hindari disposed error
//     if (_isSwitchingCamera || !_controller.value.isInitialized) {
//       return Scaffold(
//         backgroundColor: Colors.black,
//         body: const Center(
//           child: CircularProgressIndicator(color: Colors.blue),
//         ),
//       );
//     }
//
//     return Scaffold(
//       backgroundColor: Colors.black,
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         title: const Text("Face Recognition"),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.cameraswitch_outlined),
//             onPressed: _flipCamera,
//           ),
//           IconButton(
//             icon: const Icon(Icons.admin_panel_settings_outlined),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const AdminLoginPage()),
//               );
//             },
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           Center(
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(24),
//               child: _controller.value.isInitialized
//                   ? CameraPreview(_controller)
//                   : const SizedBox.shrink(),
//             ),
//           ),
//           // Status overlay (UI tetap)
//           Positioned(
//             top: 20,
//             left: 20,
//             right: 20,
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.5),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 statusMessage,
//                 style: const TextStyle(color: Colors.white),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
