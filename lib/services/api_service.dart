import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async'; // Tambahkan ini
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';


class ApiService {
  static const String baseUrl = "http://192.168.1.28:8000";
  static const String attendanceEndpoint = "/api/face-verify"; // sesuai FaceController

  final String? bearerToken;
  ApiService({this.bearerToken});

  Future<Map<String, dynamic>> verifyFace(File imageFile) async {
    final url = Uri.parse("$baseUrl$attendanceEndpoint");

    final req = http.MultipartRequest('POST', url)
      ..fields['client_ts'] = DateTime.now().toIso8601String()
      ..files.add(await http.MultipartFile.fromPath(
        'image',                // WAJIB sama: $request->file('image')
        imageFile.path,
        contentType: MediaType('image','jpeg'),
      ));

    if (bearerToken != null && bearerToken!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $bearerToken';
    }
    req.headers['Idempotency-Key'] = _randomIdemKey();

    try {
      final streamed = await req.send().timeout(const Duration(seconds: 12));
      final resp = await http.Response.fromStream(streamed);
      final code = resp.statusCode;
      final body = resp.body;

      if (kDebugMode) print("🔎 Laravel resp ($code): $body");

      Map<String, dynamic>? jsonBody;
      try { jsonBody = json.decode(body); } catch (_) {}

      // Laravel kamu mengembalikan:
      // - success: { "status":"success", "data": {...}, "fastapi_response": {...} }
      // - gagal:   { "status":"failed", "reason": "...", "fastapi_raw": "..." } (400)
      // - error:   { "status":"error", "message": "..." } (500)
      if (jsonBody != null) {
        final status = (jsonBody['status'] ?? '').toString();

        if (status == 'success') {
          final name = (jsonBody['fastapi_response']?['user'] ??
              jsonBody['data']?['name'] ??
              'Unknown').toString();
          return {"success": true, "name": name, "raw": jsonBody};
        }

        final msg = (jsonBody['reason'] ??
            jsonBody['message'] ??
            'Verifikasi gagal (kode: $code)').toString();
        return {"success": false, "message": msg, "code": code, "raw": jsonBody};
      }

      // Fallback kalau bukan JSON
      if (code == 200) return {"success": true, "message": "OK", "raw": body};
      return {"success": false, "message": "Server error: $code", "raw": body};

    } on SocketException {
      return {"success": false, "message": "Tidak bisa terhubung ke server."};
    } on HttpException {
      return {"success": false, "message": "Kesalahan HTTP saat mengirim data."};
    } on TimeoutException {
      return {"success": false, "message": "Timeout: server lambat/tidak merespons."};
    } catch (e) {
      return {"success": false, "message": "Gagal mengirim data: $e"};
    }
  }

  String _randomIdemKey() {
    final r = math.Random();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
