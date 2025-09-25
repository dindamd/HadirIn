// lib/services/face_service.dart

class ApiService {
  Future<Map<String, dynamic>> verifyFace(bool faceDetected) async {
    await Future.delayed(const Duration(seconds: 1));

    if (faceDetected) {
      final now = DateTime.now();

      return {
        "success": true,
        "name": "Adinda Mariasti",
        "time": now.toString(), // langsung pakai DateTime.now()
      };
    } else {
      return {
        "success": false,
        "message": "Tidak ada wajah terdeteksi",
      };
    }
  }
}
