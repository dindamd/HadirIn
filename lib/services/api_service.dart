// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// ====== CONFIG CEPAT (ubah IP di sini saja) ======
/// NOTE: FastAPI via Cloudflare, Laravel via LAN IPv4
const String kFastApiBase = "https://outdoor-silicon-loaded-veteran.trycloudflare.com";
const String kLaravelBase = "http://192.168.1.3:8000";
Uri _u(String base, String p) => Uri.parse("$base${p.startsWith('/') ? p : '/$p'}");

Map<String, dynamic> _err(Object e) => {
  'success': false,
  'message': e is SocketException
      ? 'Tidak bisa terhubung ke server'
      : e.toString(),
};

/// ====== FASTAPI: verifikasi wajah (upload foto) ======
class FastApiService {
  Future<Map<String, dynamic>> verifyFace(File imageFile) async {
    try {
      final req = http.MultipartRequest('POST', _u(kFastApiBase, '/verify-face'))
        ..files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ));

      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(streamed);

      Map<String, dynamic>? jsonBody;
      try { jsonBody = json.decode(res.body); } catch (_) {}

      if (res.statusCode == 200 && (jsonBody?['success'] == true)) {
        return {'success': true, 'data': jsonBody};
      }
      return {
        'success': false,
        'message': jsonBody?['message'] ?? 'FastAPI gagal (${res.statusCode})',
        'raw': res.body,
        'code': res.statusCode,
      };
    } catch (e) {
      return _err(e);
    }
  }
}

/// ====== LARAVEL: simpan & tarik data attendance ======
class AttendanceApi {
  /// Simpan hasil absensi (jalur baru): Flutter -> Laravel JSON kecil
  Future<Map<String, dynamic>> saveAttendance({
    required String name,
    required String type, // 'IN' | 'OUT'
    double? distance,
    double? gap,
  }) async {
    try {
      final body = {
        'name': name,
        'type': type,
        if (distance != null) 'distance': distance,
        if (gap != null) 'gap': gap,
        'client_ts': DateTime.now().toIso8601String(),
      };

      final res = await http
          .post(
        _u(kLaravelBase, '/api/attendance'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      )
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic>? jsonBody;
      try { jsonBody = json.decode(res.body); } catch (_) {}

      if (res.statusCode >= 200 && res.statusCode < 300 && jsonBody?['success'] == true) {
        return {'success': true, 'data': jsonBody};
      }
      return {
        'success': false,
        'message': jsonBody?['message'] ?? 'Gagal simpan absensi (${res.statusCode})',
        'raw': res.body,
        'code': res.statusCode,
      };
    } catch (e) {
      return _err(e);
    }
  }

  /// Ambil daftar kehadiran HARI INI untuk dashboard admin
  /// GET /api/admin/attendance/today
  Future<Map<String, dynamic>> fetchTodayAttendance() async {
    try {
      final res = await http
          .get(_u(kLaravelBase, '/api/admin/attendance/today'))
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic>? jsonBody;
      try { jsonBody = json.decode(res.body); } catch (_) {}

      if (res.statusCode >= 200 && res.statusCode < 300 && jsonBody?['success'] == true) {
        return {'success': true, 'data': jsonBody};
      }
      return {
        'success': false,
        'message': jsonBody?['message'] ?? 'Gagal ambil data (${res.statusCode})',
        'raw': res.body,
        'code': res.statusCode,
      };
    } catch (e) {
      return _err(e);
    }
  }

  /// UPDATE status hari ini (admin)
  /// POST /api/admin/attendance/update
  /// Body: { name, status: 'On Time'|'Late'|'Absent', reason?, time?('HH:MM'), phase?('IN'|'OUT') }
  Future<Map<String, dynamic>> updateToday({
    required String name,
    required String status,
    String? reason,
    String? time,
    String? phase, // IN | OUT
    bool auto = false, // NEW: minta server auto-derive status
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'status': status,
      if (reason != null) 'reason': reason,
      if (time != null) 'time': time,
      if (phase != null) 'phase': phase,
      'auto': auto, // NEW
    };

    final res = await http
        .post(
      _u(kLaravelBase, '/api/admin/attendance/update'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    )
        .timeout(const Duration(seconds: 10));

    Map<String, dynamic>? jsonBody;
    try { jsonBody = json.decode(res.body); } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300 && (jsonBody?['success'] == true)) {
      return {'success': true};
    }
    return {
      'success': false,
      'message': jsonBody?['message'] ?? 'Gagal update (${res.statusCode})',
      'raw': res.body,
      'code': res.statusCode,
    };
  }
}
