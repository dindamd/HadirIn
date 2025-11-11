// lib/pages/admin_page.dart
import 'package:flutter/material.dart';
import 'admin_login_page.dart';
import '../services/api_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final attendanceApi = AttendanceApi();

  bool _loading = true;
  bool _updating = false; // lock kecil saat update
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _counts = {"on_time": 0, "late": 0, "absent": 0};

  /// --- NOTE ---
  /// Sementara kita simpan jam kerja di sisi UI hanya untuk "preview" auto-status.
  /// Sumber kebenaran tetap di backend (Laravel). Kalau nanti backend yang auto-compute,
  /// hapus saja konstanta ini & kirim time/phase tanpa status.
  static const String _kWorkStart = '10:00'; // jam mulai
  static const String _kWorkEnd   = '16:00'; // jam selesai
  static const int    _kGraceMin  = 0;       // toleransi menit

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await attendanceApi.fetchTodayAttendance();
      if (!mounted) return;
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _items = List<Map<String, dynamic>>.from(data['items'] ?? []);
          _counts = Map<String, dynamic>.from(
              data['counts'] ?? {"on_time": 0, "late": 0, "absent": 0});
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
              Text('Gagal ambil data: ${res['message'] ?? 'unknown'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ambil data: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Time picker 24 jam → return "HH:MM"
  Future<String?> _pickTime({String? initial}) async {
    final now = TimeOfDay.now();
    TimeOfDay init;
    try {
      if (initial != null && initial.contains(':')) {
        final parts = initial.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        init = TimeOfDay(hour: h, minute: m);
      } else {
        init = now;
      }
    } catch (_) {
      init = now;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return null;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Hitung status otomatis berdasarkan phase + jam edit, pakai aturan sederhana:
  /// - IN  : <= (workStart + grace)  → On Time, else Late
  /// - OUT : >= (workEnd   - grace)  → On Time, else Early
  String _evalAutoStatus({required String phase, required String hhmm}) {
    String addMin(String hhmm, int minutes) {
      final sp = hhmm.split(':');
      int h = int.parse(sp[0]);
      int m = int.parse(sp[1]) + minutes;
      h += m ~/ 60;
      m = m % 60;
      h %= 24;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    bool le(String a, String b) => a.compareTo(b) <= 0; // a <= b
    bool ge(String a, String b) => a.compareTo(b) >= 0; // a >= b

    final startCut = addMin(_kWorkStart, _kGraceMin);
    final endCut   = addMin(_kWorkEnd, -_kGraceMin);

    if (phase == 'IN') {
      return le(hhmm, startCut) ? 'On Time' : 'Late';
    } else {
      return ge(hhmm, endCut) ? 'On Time' : 'Early';
    }
  }

  Future<void> _updateItem({
    required String name,
    required String status,
    String? reason,
    String? time,
    String? phase, // dukung IN / OUT
  }) async {
    if (_updating) return;
    setState(() => _updating = true);
    final res = await attendanceApi.updateToday(
      name: name,
      status: status,
      reason: reason,
      time: time,
      phase: phase,
    );
    if (!mounted) return;
    setState(() => _updating = false);

    if (res['success'] == true) {
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update gagal: ${res['message'] ?? 'unknown'}')),
      );
    }
  }

  /// Bottom sheet edit waktu + phase + (auto status preview)
  void _openEditSheet(Map<String, dynamic> item) async {
    final name = (item["name"] ?? "-").toString();
    // status awal dari item (tetap bisa di-override)
    String status = (item["status"] ?? "On Time").toString();
    // waktu awal (kalau "-" → null)
    String? time = (item["time"] == '-' ? null : item["time"]?.toString());
    // default phase IN (admin bisa ganti)
    String phase = 'IN';

    // status otomatis (preview) mengikuti perubahan time/phase
    String? autoStatus =
    (time != null) ? _evalAutoStatus(phase: phase, hhmm: time) : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setS) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  const Text('Edit Waktu',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                  const SizedBox(height: 16),

                  // Status (masih disediakan untuk override manual)
                  Row(
                    children: [
                      const Text('Status',
                          style: TextStyle(fontFamily: 'Poppins')),
                      const Spacer(),
                      DropdownButton<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(
                              value: "On Time", child: Text("On Time")),
                          DropdownMenuItem(
                              value: "Late", child: Text("Late")),
                          DropdownMenuItem(
                              value: "Absent", child: Text("Absent")),
                          DropdownMenuItem(
                              value: "Early", child: Text("Early")),
                        ],
                        onChanged: (v) => setS(() => status = v!),
                      ),
                    ],
                  ),

                  // Phase
                  Row(
                    children: [
                      const Text('Phase',
                          style: TextStyle(fontFamily: 'Poppins')),
                      const Spacer(),
                      DropdownButton<String>(
                        value: phase,
                        items: const [
                          DropdownMenuItem(value: "IN", child: Text("IN")),
                          DropdownMenuItem(value: "OUT", child: Text("OUT")),
                        ],
                        onChanged: (v) {
                          setS(() {
                            phase = v!;
                            if (time != null) {
                              autoStatus =
                                  _evalAutoStatus(phase: phase, hhmm: time!);
                              // Sinkronkan dropdown status → auto
                              status = autoStatus!;
                            }
                          });
                        },
                      ),
                    ],
                  ),

                  // Time picker
                  Row(
                    children: [
                      const Text('Jam',
                          style: TextStyle(fontFamily: 'Poppins')),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await _pickTime(initial: time);
                          if (picked != null) {
                            setS(() {
                              time = picked;
                              autoStatus =
                                  _evalAutoStatus(phase: phase, hhmm: time!);
                              // Sinkronkan dropdown status → auto
                              status = autoStatus!;
                            });
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(time ?? 'Pilih jam'),
                      ),
                    ],
                  ),

                  // Preview auto status (kalau ada time)
                  if (time != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Auto status:',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.black54)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            autoStatus ?? '-',
                            style: const TextStyle(
                                fontFamily: 'Poppins', color: Colors.white),
                          ),
                          backgroundColor: _getStatusColor(
                              (autoStatus ?? status).toString())
                              .withOpacity(0.85),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // Jika Absent, time/phase diabaikan
                            final sendStatus = status;
                            await _updateItem(
                              name: name,
                              status: sendStatus,
                              time: sendStatus == 'Absent'
                                  ? null
                                  : (time ?? item['time']?.toString()),
                              phase: sendStatus == 'Absent' ? null : phase,
                              reason: sendStatus == 'Absent'
                                  ? ((item['reason']?.toString().isEmpty ??
                                  true)
                                  ? 'Tanpa Keterangan'
                                  : item['reason']?.toString())
                                  : null,
                            );
                            if (mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Konfirmasi Logout",
            style:
            TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          ),
          content: const Text(
            "Apakah Anda yakin ingin keluar dari dashboard admin?",
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Batal",
                  style: TextStyle(
                      color: Colors.grey.shade600, fontFamily: 'Poppins')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const AdminLoginPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Logout",
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Dashboard Admin",
          style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        actions: [
          IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: Colors.white)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade600, Colors.blue.shade400],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Selamat Datang, Admin",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins')),
                SizedBox(height: 8),
                Text("Kelola data kehadiran karyawan",
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'Poppins')),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildStatCard(
                    "Tepat Waktu",
                    "${_counts['on_time']}",
                    Colors.green,
                    Icons.check_circle)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(
                    "Terlambat",
                    "${_counts['late']}",
                    Colors.orange,
                    Icons.schedule)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(
                    "Tidak Hadir",
                    "${_counts['absent']}",
                    Colors.red,
                    Icons.cancel)),
              ],
            ),
          ),

          // List header
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.people_outline,
                    color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Daftar Kehadiran",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: Colors.black87),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text("${_items.length} orang",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontFamily: 'Poppins')),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _items.length,
                itemBuilder: (context, index) =>
                    _buildItem(_items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final name = (item["name"] ?? "-").toString();
    final time = (item["time"] ?? "-").toString();
    final status = (item["status"] ?? "Absent").toString();
    final reason = (item["reason"] ?? "").toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade600,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins'),
                  ),
                ),
                const SizedBox(width: 12),

                // info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              fontFamily: 'Poppins')),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text("Waktu: $time",
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontFamily: 'Poppins')),
                          const SizedBox(width: 8),
                          // tombol edit kecil
                          InkWell(
                            onTap: () => _openEditSheet(item),
                            child: Icon(Icons.edit,
                                size: 14, color: Colors.blue.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // dropdown status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<String>(
                    value: status,
                    underline: const SizedBox(),
                    style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(status),
                        fontFamily: 'Poppins'),
                    items: const [
                      DropdownMenuItem(
                          value: "On Time", child: Text("On Time")),
                      DropdownMenuItem(value: "Late", child: Text("Late")),
                      DropdownMenuItem(
                          value: "Absent", child: Text("Absent")),
                      DropdownMenuItem(value: "Early", child: Text("Early")),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      _updateItem(
                        name: name,
                        status: val,
                        reason: reason.isEmpty ? null : reason,
                        time: time == "-" ? null : time,
                        // dropdown ini tidak mengubah phase/time
                      );
                    },
                  ),
                ),
              ],
            ),

            // alasan jika Absent
            if (status == "Absent")
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    const Text("Alasan:",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontFamily: 'Poppins')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: reason.isEmpty ? null : reason,
                        hint: const Text("Pilih alasan",
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontFamily: 'Poppins')),
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontFamily: 'Poppins'),
                        items: const [
                          DropdownMenuItem(value: "Sakit", child: Text("Sakit")),
                          DropdownMenuItem(value: "Izin", child: Text("Izin")),
                          DropdownMenuItem(
                              value: "Tanpa Keterangan",
                              child: Text("Tanpa Keterangan")),
                        ],
                        onChanged: (val) {
                          _updateItem(
                              name: name, status: "Absent", reason: val ?? "");
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(count,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 4),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontFamily: 'Poppins')),
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
      case "Absent":
        return Colors.red;
      case "Early":
        return Colors.purple; // biar kebaca saat OUT lebih awal
      default:
        return Colors.grey;
    }
  }
}
