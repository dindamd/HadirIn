import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_page.dart';

class HomePage extends StatelessWidget {
  final List<CameraDescription> cameras;
  const HomePage({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Absensi App")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CameraPage(cameras: cameras),
              ),
            );
          },
          child: const Text("Mulai Absen"),
        ),
      ),
    );
  }
}
