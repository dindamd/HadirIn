import 'dart:async';

import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../services/api_service.dart';
import 'admin_login_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final ApiService _apiService = ApiService();
  AttendanceHistory? _history;
  bool _loading = true;
  String? _error;
  String? _savingName;
  Timer? _refreshTimer;
  bool _requestInFlight = false;
  int _selectedIndex = 0;

  AttendanceSummary? get _activeSummary {
    if (_history == null || _history!.days.isEmpty) return null;
    final maxIndex = _history!.days.length - 1;
    final index = _selectedIndex.clamp(0, maxIndex).toInt();
    return _history!.days[index];
  }

  bool get _selectedIsToday => _activeSummary?.isToday ?? false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (_savingName != null || _requestInFlight) return;
        _loadAttendance(showLoading: false);
      },
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Konfirmasi Logout",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            "Apakah Anda yakin ingin keluar dari dashboard admin?",
            style: TextStyle(
              fontFamily: 'Poppins',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Batal",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Logout",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadAttendance({bool showLoading = true}) async {
    if (_requestInFlight) return;
    _requestInFlight = true;

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final history = await _apiService.fetchAttendanceHistory(days: 7);
      if (!mounted) return;
      setState(() {
        _history = history;
        _error = null;
        if (_selectedIndex >= history.days.length) {
          _selectedIndex = history.days.isNotEmpty ? history.days.length - 1 : 0;
        }
        if (_history?.days.isNotEmpty ?? false) {
          _selectedIndex = 0;
        }
        if (showLoading) {
          _loading = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (showLoading) {
          _loading = false;
          _error = e.toString();
        } else {
          _error = _error ?? e.toString();
        }
      });
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> _updateAttendance(
    AttendanceItem item, {
    required String status,
    String reason = '',
    String phase = 'IN',
    String? time,
    bool auto = false,
  }) async {
    if (!_selectedIsToday) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hanya absensi hari ini yang bisa diubah dari sini.'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    setState(() {
      _savingName = item.name;
    });

    try {
      await _apiService.updateAttendance(
        name: item.name,
        status: status,
        employeeId: item.employeeId,
        reason: reason,
        phase: phase,
        time: time,
        auto: auto,
      );
      await _loadAttendance(showLoading: false);
      if (!mounted) return;
      setState(() {
        _savingName = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() {
        _savingName = null;
      });
    }
  }

  Future<void> _editTime(AttendanceItem item, String phase) async {
    final baseTime = phase == 'IN' ? item.checkInLabel : item.checkOutLabel;
    final initial = _parseTimeOfDay(baseTime) ?? TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) {
      return;
    }

    final timeValue = _formatTimeOfDay(picked);
    await _updateAttendance(
      item,
      status: item.status.isEmpty ? 'On Time' : item.status,
      reason: item.reason,
      phase: phase,
      time: timeValue,
      auto: true,
    );
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return null;
    }
    final parts = trimmed.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final activeSummary = _activeSummary;
    final onTimeCount = activeSummary?.onTime ?? 0;
    final lateCount = activeSummary?.late ?? 0;
    final absentCount = activeSummary?.absent ?? 0;
    final leaveCount = activeSummary?.leave ?? 0;
    final sickCount = activeSummary?.sick ?? 0;
    final items = activeSummary?.items ?? <AttendanceItem>[];
    final summaryDate = activeSummary?.friendlyLabel ?? '';
    final summaryIsoDate = activeSummary?.date ?? '';
    final selectedIsToday = activeSummary?.isToday ?? false;

    Widget listSection;
    if (_loading) {
      listSection = Expanded(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
        ),
      );
    } else if (_error != null) {
      listSection = Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600, size: 36),
              SizedBox(height: 12),
              Text(
                _error ?? 'Gagal memuat data',
                style: TextStyle(fontFamily: 'Poppins'),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    } else {
      Widget listView;
      if (items.isEmpty) {
        listView = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          children: [
            SizedBox(height: 40),
            Center(
              child: Text(
                'Belum ada data absensi pada rentang ini.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        );
      } else {
        listView = ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSaving = _savingName == item.name;
            final disableActions = isSaving || !selectedIsToday;
            final avatarChar = item.name.isNotEmpty ? item.name[0].toUpperCase() : '?';
            final statusValue = item.status.isNotEmpty ? item.status : 'On Time';
            const editableStatuses = ["On Time", "Late", "Absent"];
            final dropdownValue = editableStatuses.contains(statusValue) ? statusValue : null;
            final statusColor = _getStatusColor(statusValue);

            return Card(
              margin: EdgeInsets.only(bottom: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!selectedIsToday)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Riwayat hari lalu — hanya bisa dibaca',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey.shade700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    Row(
                      children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blue.shade600,
                              child: Text(
                                avatarChar,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              SizedBox(height: 4),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.login,
                                        size: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Masuk: ${item.checkInLabel}",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.logout,
                                        size: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Pulang: ${item.checkOutLabel}",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String>(
                            value: dropdownValue,
                            hint: Text(
                              statusValue,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            underline: SizedBox(),
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontFamily: 'Poppins',
                            ),
                            items: const [
                              DropdownMenuItem(value: "On Time", child: Text("On Time")),
                              DropdownMenuItem(value: "Late", child: Text("Late")),
                              DropdownMenuItem(value: "Absent", child: Text("Absent")),
                            ],
                            onChanged: disableActions
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    _updateAttendance(item, status: value, reason: item.reason);
                                  },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        TextButton.icon(
                          onPressed: disableActions ? null : () => _editTime(item, 'IN'),
                          icon: Icon(Icons.login, size: 16),
                          label: Text("Ubah Masuk"),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blueGrey.shade700,
                            backgroundColor: Colors.blueGrey.shade50,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: disableActions ? null : () => _editTime(item, 'OUT'),
                          icon: Icon(Icons.logout, size: 16),
                          label: Text("Ubah Pulang"),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blueGrey.shade700,
                            backgroundColor: Colors.blueGrey.shade50,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        if (isSaving)
                          Padding(
                            padding: EdgeInsets.only(left: 4, top: 6),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blueGrey.shade600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (item.reason.trim().isNotEmpty && item.status != "Absent")
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(top: 10),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade700),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Alasan: ${item.reason}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (item.status == "Absent")
                      Container(
                        margin: EdgeInsets.only(top: 12),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.red.shade600,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Alasan:",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: item.reason.isEmpty ? null : item.reason,
                                hint: Text(
                                  "Pilih alasan",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade400,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                isExpanded: true,
                                underline: SizedBox(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade700,
                                  fontFamily: 'Poppins',
                                ),
                                items: const [
                                  DropdownMenuItem(value: "Sakit", child: Text("Sakit")),
                                  DropdownMenuItem(value: "Izin", child: Text("Izin")),
                                  DropdownMenuItem(value: "Tanpa Keterangan", child: Text("Tanpa Keterangan")),
                                ],
                                onChanged: disableActions
                                    ? null
                                    : (value) {
                                        _updateAttendance(
                                          item,
                                          status: "Absent",
                                          reason: value ?? '',
                                        );
                                      },
                              ),
                            ),
                            if (isSaving)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }

      listSection = Expanded(
        child: RefreshIndicator(
          onRefresh: () => _loadAttendance(showLoading: false),
          child: listView,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Dashboard Admin",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _logout,
              icon: Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: "Logout",
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade600,
                  Colors.blue.shade400,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Selamat Datang, Admin",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  summaryDate.isNotEmpty
                      ? "Data kehadiran untuk $summaryDate"
                      : "Kelola data kehadiran karyawan",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                ),
            ],
          ),
        ),

          _buildRetentionNotice(),
          _buildDateSelector(),

          // Statistics Cards
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Tepat Waktu",
                    onTimeCount.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Terlambat",
                    lateCount.toString(),
                    Colors.orange,
                    Icons.schedule,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Tidak Hadir",
                    absentCount.toString(),
                    Colors.red,
                    Icons.cancel,
                  ),
                ),
              ],
            ),
          ),

          // Additional status row (leave/sick)
          Container(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Izin",
                    leaveCount.toString(),
                    Colors.blueGrey,
                    Icons.event_busy,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Sakit",
                    sickCount.toString(),
                    Colors.purple,
                    Icons.healing,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),

          // List Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  "Daftar Kehadiran",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: Colors.black87,
                  ),
                ),
                if (summaryIsoDate.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        summaryIsoDate,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                if (!selectedIsToday)
                  Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Riwayat",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${items.length} orang",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),

          listSection,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _apiService.dispose();
    super.dispose();
  }

  Widget _buildRetentionNotice() {
    final notice = _history?.retention;
    if (notice == null || notice.show == false) {
      return SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup data absensi',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            notice.message ?? 'Data lama akan dibersihkan, segera lakukan backup.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.orange.shade800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Cutoff ${notice.cutoffDate ?? '-'} · Jadwal bersih ${notice.nextPurgeAt ?? '-'}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final days = _history?.days ?? [];
    if (days.isEmpty) return SizedBox.shrink();

    final activeIndex = _history!.days.isEmpty ? 0 : _selectedIndex.clamp(0, _history!.days.length - 1).toInt();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(days.length, (index) {
            final day = days[index];
            final isActive = index == activeIndex;
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: ChoiceChip(
                labelPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.friendlyLabel,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      day.date,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                selected: isActive,
                selectedColor: Colors.blue.shade50,
                backgroundColor: Colors.white,
                side: BorderSide(color: isActive ? Colors.blue.shade400 : Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (value) {
                  if (!value) return;
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "On Time":
        return Colors.green;
      case "Late":
        return Colors.orange;
      case "Leave":
        return Colors.blueGrey;
      case "Sick":
        return Colors.purple;
      case "Absent":
        return Colors.red;
      case "Early":
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
