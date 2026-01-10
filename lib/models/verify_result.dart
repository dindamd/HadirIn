class VerifyResult {
  VerifyResult({
    required this.success,
    required this.message,
    this.name,
    this.phase,
    this.status,
    this.time,
    this.distance,
    this.gap,
  });

  final bool success;
  final String message;
  final String? name;
  final String? phase;
  final String? status;
  final String? time;
  final double? distance;
  final double? gap;

  factory VerifyResult.fromApi(Map<String, dynamic> json, {int? statusCode}) {
    final data = (json['data'] as Map?) ?? {};
    final name = (data['name'] ?? json['user'] ?? '').toString();

    final time = (data['check_out_time'] ??
            data['check_in_time'] ??
            data['time'] ??
            json['time'] ??
            '')
        .toString();

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      return double.tryParse(val.toString());
    }

    final message = json['message']?.toString();
    final reason = json['reason']?.toString();
    final msg = (message != null && message.isNotEmpty)
        ? message
        : (reason != null && reason.isNotEmpty)
            ? reason
            : (json['success'] == true
                ? 'Verifikasi berhasil'
                : 'Verifikasi gagal');

    return VerifyResult(
      success: json['success'] == true && (statusCode == null || statusCode < 400),
      message: msg,
      name: name.isEmpty ? null : name,
      phase: (json['phase'] ?? '').toString().isEmpty ? null : json['phase'].toString(),
      status: (json['status'] ?? '').toString().isEmpty ? null : json['status'].toString(),
      time: time.isEmpty ? null : time,
      distance: parseDouble(json['distance'] ?? data['distance']),
      gap: parseDouble(json['gap'] ?? data['gap']),
    );
  }

  factory VerifyResult.error(String message) =>
      VerifyResult(success: false, message: message);
}
