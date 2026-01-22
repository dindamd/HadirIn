import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/attendance.dart';
import '../models/verify_result.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? body;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiConfig.baseUrl}$normalized');
  }

  Uri _faceUri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiConfig.faceUrl}$normalized');
  }

  // ================= FACE SERVICE =================

  Future<VerifyResult> verifyFace(XFile image, {String? type}) async {
    final faceResult = await _verifyWithFaceService(image, type: type);
    if (!faceResult.success) {
      return faceResult;
    }

    final name = faceResult.name;
    if (name == null || name.isEmpty) {
      return VerifyResult.error('Wajah dikenali tetapi nama tidak terbaca dari server.');
    }

    final attendanceResult = await _storeAttendanceResult(
      name: name,
      type: type,
      distance: faceResult.distance,
      gap: faceResult.gap,
    );

    if (!attendanceResult.success) {
      return VerifyResult(
        success: false,
        message: 'Berhasil mengenali $name tetapi gagal menyimpan absensi: ${attendanceResult.message}',
        name: name,
        phase: attendanceResult.phase,
        status: attendanceResult.status,
        time: attendanceResult.time,
        distance: faceResult.distance,
        gap: faceResult.gap,
      );
    }

    return VerifyResult(
      success: true,
      message: attendanceResult.message,
      name: attendanceResult.name ?? name,
      phase: attendanceResult.phase,
      status: attendanceResult.status,
      time: attendanceResult.time,
      distance: attendanceResult.distance ?? faceResult.distance,
      gap: attendanceResult.gap ?? faceResult.gap,
    );
  }

  // ================= LARAVEL API =================

  Future<AttendanceHistory> fetchAttendanceHistory({int days = 7}) async {
    try {
      final uri = _uri('/api/admin/attendance/history?days=$days');
      final res = await _client.get(uri).timeout(const Duration(seconds: 20));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException('Gagal memuat data absensi (HTTP ${res.statusCode})');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ApiException(body['message']?.toString() ?? 'Respon gagal');
      }

      return AttendanceHistory.fromJson(body);
    } on TimeoutException {
      throw ApiException('Koneksi timeout saat memuat absensi harian.');
    }
  }

  Future<AttendanceSummary> fetchTodayAttendance() async {
    final history = await fetchAttendanceHistory(days: 1);
    if (history.days.isEmpty) {
      throw ApiException('Tidak ada data absensi untuk hari ini.');
    }
    return history.days.first;
  }

  Future<void> loginAdmin({
    required String identifier,
    required String password,
  }) async {
    final payload = {
      'email': identifier,
      'password': password,
    };

    try {
      final res = await _client
          .post(
        _uri('/api/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> body = {};
      if (res.body.isNotEmpty) {
        try {
          body = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {}
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = body['message']?.toString() ??
            'Login admin gagal (HTTP ${res.statusCode})';
        throw ApiException(message, statusCode: res.statusCode, body: body);
      }

      if (body['success'] != true) {
        throw ApiException(body['message']?.toString() ?? 'Login admin gagal');
      }
    } on TimeoutException {
      throw ApiException('Koneksi timeout saat login admin.');
    }
  }

  Future<void> updateAttendance({
    required String name,
    required String status,
    int? employeeId,
    String phase = 'IN',
    String reason = '',
    String? time,
    bool auto = false,
  }) async {
    final payload = {
      'name': name,
      'status': status,
      'phase': phase,
      'reason': reason,
      'auto': auto,
      if (employeeId != null) 'employee_id': employeeId,
      if (time != null && time.isNotEmpty) 'time': time,
    };

    try {
      final res = await _client
          .post(
        _uri('/api/admin/attendance/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException('Gagal memperbarui absensi (HTTP ${res.statusCode})');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ApiException(body['message']?.toString() ?? 'Update gagal');
      }
    } on TimeoutException {
      throw ApiException('Koneksi timeout saat update absensi.');
    }
  }

  Future<VerifyResult> _verifyWithFaceService(
    XFile image, {
    String? type,
  }) async {
    final request = http.MultipartRequest('POST', _faceUri('/api/verify-face'));

    request.files.add(
      await http.MultipartFile.fromPath('image', image.path),
    );

    if (type != null && type.isNotEmpty) {
      request.fields['type'] = type;
    }

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 50));
    } on TimeoutException catch (_) {
      return VerifyResult.error('Koneksi timeout ke server absensi.');
    } catch (e) {
      return VerifyResult.error('Gagal terhubung ke server: $e');
    }

    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}
    }

    return VerifyResult.fromApi(data, statusCode: response.statusCode);
  }

  Future<VerifyResult> _storeAttendanceResult({
    required String name,
    String? type,
    double? distance,
    double? gap,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      if (type != null && type.isNotEmpty) 'type': type.toUpperCase(),
      if (distance != null) 'distance': distance,
      if (gap != null) 'gap': gap,
    };

    try {
      final res = await _client
          .post(
        _uri('/api/attendance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> body = {};
      if (res.body.isNotEmpty) {
        try {
          body = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {}
      }

      return VerifyResult.fromApi(body, statusCode: res.statusCode);
    } on TimeoutException {
      return VerifyResult.error('Koneksi timeout saat menyimpan absensi ke server.');
    } catch (e) {
      return VerifyResult.error('Gagal menyimpan absensi ke server: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
