import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'face_recognition_page.dart';

class CameraPage extends StatelessWidget {
  final List<CameraDescription> cameras;
  const CameraPage({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mulai Scan"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigasi ke halaman FaceRecognitionPage dengan semua kamera
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FaceRecognitionPage(cameras: cameras),
              ),
            );
          },
          child: const Text("Mulai Face Recognition"),
        ),
      ),
    );
  }
}
