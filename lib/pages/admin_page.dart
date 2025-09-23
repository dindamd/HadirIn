import 'package:flutter/material.dart';
import 'admin_login_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Dummy data absensi
  List<Map<String, String>> attendanceList = [
    {"name": "Adinda Mariasti", "time": "08:00", "status": "On Time", "reason": ""},
    {"name": "Rizky Aulia", "time": "08:05", "status": "Late", "reason": ""},
    {"name": "Siti Nurhaliza", "time": "-", "status": "Absent", "reason": "Sakit"},
  ];

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Admin"),
        automaticallyImplyLeading: false, // tombol back di AppBar dihapus
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Daftar Absensi Hari Ini",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: attendanceList.length,
                itemBuilder: (context, index) {
                  final item = attendanceList[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            child: Text(item["name"]![0]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item["name"]!,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text("Waktu: ${item["time"]}"),
                                if (item["status"] == "Absent")
                                  DropdownButton<String>(
                                    value: item["reason"]!.isEmpty ? null : item["reason"],
                                    hint: const Text("Pilih alasan absent"),
                                    isExpanded: true,
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: DropdownButton<String>(
                              value: item["status"],
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: "On Time", child: Text("On Time")),
                                DropdownMenuItem(value: "Late", child: Text("Late")),
                                DropdownMenuItem(value: "Absent", child: Text("Absent")),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  item["status"] = value ?? "Absent";

                                  if (value == "Absent") {
                                    item["time"] = "-"; // otomatis jam -
                                  } else {
                                    // jika sebelumnya Absent, set jam default
                                    if (item["time"] == "-") {
                                      item["time"] = "08:00"; // bisa diubah sesuai kebutuhan
                                    }
                                  }

                                  if (value != "Absent") item["reason"] = "";
                                });
                              },
                              underline: const SizedBox(),
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
      ),
    );
  }
}
