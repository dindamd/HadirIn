import 'dart:async';

class ApiService {
  // Simulasi endpoint verifikasi wajah
  Future<Map<String, dynamic>> verifyFace(bool hasFace) async {
    // delay untuk simulasi response server
    await Future.delayed(const Duration(seconds: 2));

    if (hasFace) {
      return {
        "success": true,
        "name": "Adinda Mariasti",
        "time": "08:00",
      };
    } else {
      return {
        "success": false,
        "message": "Wajah tidak terdeteksi",
      };
    }
  }
}
