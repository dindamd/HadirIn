class AttendanceItem {
  AttendanceItem({
    this.employeeId,
    required this.name,
    required this.time,
    required this.status,
    required this.reason,
    required this.checkInTime,
    required this.checkOutTime,
  });

  final int? employeeId;
  final String name;
  final String time;
  final String status;
  final String reason;
  final String checkInTime;
  final String checkOutTime;

  factory AttendanceItem.fromJson(Map<String, dynamic> json) {
    final employeeIdRaw = json['employee_id'];
    final employeeId = employeeIdRaw is int
        ? employeeIdRaw
        : int.tryParse(employeeIdRaw?.toString() ?? '');

    return AttendanceItem(
      employeeId: employeeId,
      name: (json['name'] ?? '').toString(),
      time: (json['time'] ?? '-').toString(),
      status: (json['status'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      checkInTime: (json['check_in_time'] ?? '').toString(),
      checkOutTime: (json['check_out_time'] ?? '').toString(),
    );
  }

  AttendanceItem copyWith({
    int? employeeId,
    String? name,
    String? time,
    String? status,
    String? reason,
    String? checkInTime,
    String? checkOutTime,
  }) {
    return AttendanceItem(
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      time: time ?? this.time,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
    );
  }

  String get checkInLabel {
    if (checkInTime.trim().isNotEmpty) {
      return _formatTime(checkInTime);
    }
    return _formatTime(time);
  }

  String get checkOutLabel => _formatTime(checkOutTime);

  static String _formatTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return '-';
    }
    if (trimmed.length >= 5) {
      return trimmed.substring(0, 5);
    }
    return trimmed;
  }
}

class AttendanceSummary {
  AttendanceSummary({
    required this.items,
    required this.onTime,
    required this.late,
    required this.absent,
    required this.leave,
    required this.sick,
  });

  final List<AttendanceItem> items;
  final int onTime;
  final int late;
  final int absent;
  final int leave;
  final int sick;

  int get total => items.length;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    final counts = (json['counts'] as Map?) ?? {};
    final itemsJson = (json['items'] as List?) ?? [];

    return AttendanceSummary(
      items: itemsJson
          .whereType<Map>()
          .map((e) => AttendanceItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      onTime: int.tryParse(counts['on_time']?.toString() ?? '0') ?? 0,
      late: int.tryParse(counts['late']?.toString() ?? '0') ?? 0,
      absent: int.tryParse(counts['absent']?.toString() ?? '0') ?? 0,
      leave: int.tryParse(counts['leave']?.toString() ?? '0') ?? 0,
      sick: int.tryParse(counts['sick']?.toString() ?? '0') ?? 0,
    );
  }
}
