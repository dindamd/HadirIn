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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final res = await attendanceApi.fetchTodayAttendance();
    if (!mounted) return;
    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      setState(() {
        _items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        _counts = Map<String, dynamic>.from(data['counts'] ?? {"on_time": 0, "late": 0, "absent": 0});
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ambil data: ${res['message'] ?? 'unknown'}')),
      );
    }
  }

  Future<void> _updateItem({
    required String name,
    required String status,
    String? reason,
    String? time,
  }) async {
    if (_updating) return;
    setState(() => _updating = true);
    final res = await attendanceApi.updateToday(
      name: name,
      status: status,
      reason: reason,
      time: time,
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

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Konfirmasi Logout",
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          ),
          content: const Text(
            "Apakah Anda yakin ingin keluar dari dashboard admin?",
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Batal", style: TextStyle(color: Colors.grey.shade600, fontFamily: 'Poppins')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminLoginPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Logout", style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
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
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded, color: Colors.white)),
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
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                SizedBox(height: 8),
                Text("Kelola data kehadiran karyawan",
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Poppins')),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildStatCard("Tepat Waktu", "${_counts['on_time']}", Colors.green, Icons.check_circle)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Terlambat", "${_counts['late']}", Colors.orange, Icons.schedule)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Tidak Hadir", "${_counts['absent']}", Colors.red, Icons.cancel)),
              ],
            ),
          ),

          // List header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Daftar Kehadiran",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: Colors.black87),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text("${_items.length} orang",
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontFamily: 'Poppins')),
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
                itemBuilder: (context, index) => _buildItem(_items[index]),
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
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  ),
                ),
                const SizedBox(width: 12),

                // info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Poppins')),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text("Waktu: $time",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontFamily: 'Poppins')),
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
                    style: TextStyle(fontSize: 12, color: _getStatusColor(status), fontFamily: 'Poppins'),
                    items: const [
                      DropdownMenuItem(value: "On Time", child: Text("On Time")),
                      DropdownMenuItem(value: "Late", child: Text("Late")),
                      DropdownMenuItem(value: "Absent", child: Text("Absent")),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      _updateItem(
                        name: name,
                        status: val,
                        reason: reason.isEmpty ? null : reason,
                        time: time == "-" ? null : time,
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
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    const Text("Alasan:",
                        style: TextStyle(fontSize: 12, color: Colors.red, fontFamily: 'Poppins')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: reason.isEmpty ? null : reason,
                        hint: const Text("Pilih alasan",
                            style: TextStyle(fontSize: 11, color: Colors.red, fontFamily: 'Poppins')),
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(fontSize: 11, color: Colors.red, fontFamily: 'Poppins'),
                        items: const [
                          DropdownMenuItem(value: "Sakit", child: Text("Sakit")),
                          DropdownMenuItem(value: "Izin", child: Text("Izin")),
                          DropdownMenuItem(value: "Tanpa Keterangan", child: Text("Tanpa Keterangan")),
                        ],
                        onChanged: (val) {
                          _updateItem(name: name, status: "Absent", reason: val ?? "");
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

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'Poppins')),
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
      default:
        return Colors.grey;
    }
  }
}
