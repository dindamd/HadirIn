import 'package:intl/intl.dart';

class RetentionNotice {
  const RetentionNotice({
    required this.show,
    this.message,
    this.cutoffDate,
    this.oldestDate,
    this.nextPurgeAt,
    this.recordsPending = 0,
  });

  final bool show;
  final String? message;
  final String? cutoffDate;
  final String? oldestDate;
  final String? nextPurgeAt;
  final int recordsPending;

  factory RetentionNotice.fromJson(Map<String, dynamic> json) {
    return RetentionNotice(
      show: json['show'] == true || json['show'] == 1,
      message: json['message']?.toString(),
      cutoffDate: json['cutoff_date']?.toString(),
      oldestDate: json['oldest_date']?.toString(),
      nextPurgeAt: json['next_purge_at']?.toString(),
      recordsPending: int.tryParse(json['records_pending']?.toString() ?? '0') ?? 0,
    );
  }
}

class AttendanceHistory {
  AttendanceHistory({
    required this.days,
    required this.start,
    required this.end,
    this.retention,
  });

  final List<AttendanceSummary> days;
  final String start;
  final String end;
  final RetentionNotice? retention;

  AttendanceSummary? get firstDay => days.isNotEmpty ? days.first : null;

  factory AttendanceHistory.fromJson(Map<String, dynamic> json) {
    final daysJson = (json['days'] as List?) ?? [];

    return AttendanceHistory(
      days: daysJson
          .whereType<Map>()
          .map((e) => AttendanceSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      start: (json['range']?['start'] ?? '').toString(),
      end: (json['range']?['end'] ?? '').toString(),
      retention: json['retention_notice'] is Map
          ? RetentionNotice.fromJson(Map<String, dynamic>.from(json['retention_notice'] as Map))
          : null,
    );
  }
}

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
    required this.date,
  });

  final List<AttendanceItem> items;
  final int onTime;
  final int late;
  final int absent;
  final int leave;
  final int sick;
  final String date;

  int get total => items.length;

  DateTime? get parsedDate {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  bool get isToday {
    final d = parsedDate;
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d == today;
  }

  String get friendlyLabel {
    final d = parsedDate;
    if (d == null) return date;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (d == today) return 'Hari ini';
    if (d == yesterday) return 'Kemarin';

    return DateFormat('EEE, dd MMM', 'id_ID').format(d);
  }

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
      date: (json['date'] ?? '').toString(),
    );
  }
}
