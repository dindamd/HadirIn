class AttendanceItem {
  AttendanceItem({
    required this.name,
    required this.time,
    required this.status,
    required this.reason,
  });

  final String name;
  final String time;
  final String status;
  final String reason;

  factory AttendanceItem.fromJson(Map<String, dynamic> json) {
    return AttendanceItem(
      name: (json['name'] ?? '').toString(),
      time: (json['time'] ?? '-').toString(),
      status: (json['status'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }

  AttendanceItem copyWith({
    String? name,
    String? time,
    String? status,
    String? reason,
  }) {
    return AttendanceItem(
      name: name ?? this.name,
      time: time ?? this.time,
      status: status ?? this.status,
      reason: reason ?? this.reason,
    );
  }
}

class AttendanceSummary {
  AttendanceSummary({
    required this.items,
    required this.onTime,
    required this.late,
    required this.absent,
  });

  final List<AttendanceItem> items;
  final int onTime;
  final int late;
  final int absent;

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
    );
  }
}
