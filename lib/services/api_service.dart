import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://192.168.1.36:8000/api"; // sesuaikan host & port backend
  final ImagePicker _picker = ImagePicker();

  /// Ambil foto dari kamera
  Future<File?> pickImageFromCamera() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100, // jaga kualitas maksimal
      preferredCameraDevice: CameraDevice.front, // kalau mau pakai kamera depan
    );

    if (pickedFile != null) {
      print("📸 File picked: ${pickedFile.path}");
      return File(pickedFile.path);
    }
    return null;
  }

  /// Kirim foto ke Laravel untuk verifikasi wajah
  Future<Map<String, dynamic>> verifyFace(File imageFile) async {
    final url = Uri.parse("$baseUrl/face-verify"); // endpoint Laravel

    var request = http.MultipartRequest('POST', url);
    request.files.add(
      await http.MultipartFile.fromPath(
        'image', // pastikan key sama dengan Laravel/ FastAPI
        imageFile.path,
      ),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print("✅ Response: ${response.body}");
        return json.decode(response.body);
      } else {
        print("❌ Server error: ${response.statusCode}");
        return {
          "success": false,
          "message": "Server error: ${response.statusCode}",
          "body": response.body,
        };
      }
    } catch (e) {
      print("❌ Request failed: $e");
      return {
        "success": false,
        "message": "Request failed: $e",
      };
    }
  }
}
