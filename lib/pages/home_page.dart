import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'face_recognition_page.dart'; // ✅ Import langsung ke face recognition

class HomePage extends StatelessWidget {
  final List<CameraDescription> cameras;
  const HomePage({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo perusahaan
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Image.asset(
                  "assets/img/logo_rmdoo.png",  // ✅ Tambahkan /img/
                  height: 50,
                ),
              ),
            ),

            // Ilustrasi + tulisan
            Column(
              children: [
                Image.asset(
                  "assets/img/IT.png",  // ✅ Tambahkan /img/
                  height: 250,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Welcome!",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 32,
                    fontWeight: FontWeight.w600, // SemiBold
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Silakan lakukan absensi \ndengan scan wajah Anda",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 16,
                    fontWeight: FontWeight.w400, // Regular
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            // Tombol hitam - langsung ke Face Recognition
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // ✅ Navigasi langsung ke FaceRecognitionPage
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FaceRecognitionPage(cameras: cameras),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Mulai Absen",
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}