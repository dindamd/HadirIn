import 'package:flutter/material.dart';
import 'admin_login_page.dart';
import 'attendance_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
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

  int get _onTimeCount => attendanceList.where((item) => item["status"] == "On Time").length;
  int get _lateCount => attendanceList.where((item) => item["status"] == "Late").length;
  int get _absentCount => attendanceList.where((item) => item["status"] == "Absent").length;

  @override
  Widget build(BuildContext context) {
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
                  "Kelola data kehadiran karyawan",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),

          // Statistics Cards
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Tepat Waktu",
                    _onTimeCount.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Terlambat",
                    _lateCount.toString(),
                    Colors.orange,
                    Icons.schedule,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Tidak Hadir",
                    _absentCount.toString(),
                    Colors.red,
                    Icons.cancel,
                  ),
                ),
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
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${attendanceList.length} orang",
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

          // Employee List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: attendanceList.length,
              itemBuilder: (context, index) {
                final item = attendanceList[index];
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
                        Row(
                          children: [
                            // Avatar with status
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blue.shade600,
                                  child: Text(
                                    item["name"]![0].toUpperCase(),
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
                                      color: _getStatusColor(item["status"]!),
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

                            // Employee info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item["name"]!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Waktu: ${item["time"]}",
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
                            ),

                            // Status dropdown
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(item["status"]!).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButton<String>(
                                value: item["status"],
                                underline: SizedBox(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColor(item["status"]!),
                                  fontFamily: 'Poppins',
                                ),
                                items: const [
                                  DropdownMenuItem(value: "On Time", child: Text("On Time")),
                                  DropdownMenuItem(value: "Late", child: Text("Late")),
                                  DropdownMenuItem(value: "Absent", child: Text("Absent")),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    item["status"] = value ?? "Absent";

                                    if (value == "Absent") {
                                      item["time"] = "-";
                                    } else {
                                      if (item["time"] == "-") {
                                        item["time"] = "08:00";
                                      }
                                    }

                                    if (value != "Absent") item["reason"] = "";
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        // Absent reason
                        if (item["status"] == "Absent")
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
                                    value: item["reason"]!.isEmpty ? null : item["reason"],
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
                                    onChanged: (value) {
                                      setState(() {
                                        item["reason"] = value ?? "";
                                      });
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
              },
            ),
          ),
        ],
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
            color: Colors.black.withOpacity(0.05),
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
      case "Absent":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}