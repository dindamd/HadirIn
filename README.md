# HadirIn App (Face Recognition Attendance System) PT RMDOO TEKNOLOGI INDONESIA

Proyek ini merupakan aplikasi absensi berbasis **pengenalan wajah (Face Recognition)** yang dikembangkan untuk memudahkan proses pencatatan kehadiran karyawan secara otomatis.
Sistem ini dilengkapi dengan **verifikasi kedipan (liveness detection)** untuk memastikan pengguna yang hadir adalah orang sebenarnya, serta halaman **Admin Login** dan **Dashboard Admin** untuk memantau data kehadiran karyawan PT RMDOO TEKNOLOGI INDONESIA.

📌 Aplikasi ini dikembangkan sebagai bagian dari pembelajaran pengembangan sistem berbasis biometrik dan manajemen data absensi digital.

---

## 📄 Deskripsi

Aplikasi ini memiliki beberapa halaman utama yang saling terintegrasi:

* **Halaman Face Recognition** – Karyawan melakukan absensi dengan memindai wajah dan berkedip dua kali untuk verifikasi.
* **Halaman Login Admin** – Admin masuk menggunakan username dan password untuk mengakses sistem.
* **Dashboard Admin** – Menampilkan rekap data kehadiran, status kehadiran karyawan, serta fitur pengelolaan data absensi.

Data yang dikumpulkan meliputi:

* Data wajah dan hasil verifikasi,
* Waktu absensi dan status kehadiran,
* Alasan ketidakhadiran (izin, sakit, dll),
* Identitas pengguna yang terhubung dengan sistem.

---

## 🧩 Komponen Database

Struktur database didesain berdasarkan **Entity Relationship Diagram (ERD)** yang menghubungkan beberapa tabel utama:

| **Tabel**           | **Fungsi Utama**                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Pegawai**         | Menyimpan data karyawan seperti NIK, NIP, tanggal lahir, alamat, telepon, tanggal mulai bekerja, serta relasi dengan user, shift, dan departemen. |
| **Users**           | Menyimpan akun pengguna sistem termasuk admin dan karyawan, serta relasi dengan peran dan data karyawan.                                          |
| **Roles**           | Menentukan peran dan hak akses pengguna (misalnya Admin, HRD, atau Karyawan).                                                                     |
| **Attendance**      | Menyimpan data hasil absensi berbasis wajah, termasuk tanggal absensi, waktu check-in/check-out, dan status kehadiran.                            |
| **Status_Presensi** | Menyimpan jenis status kehadiran seperti Tepat Waktu, Terlambat, dan Tidak Hadir.                                                                 |
| **Reason_Presensi** | Menyimpan alasan ketidakhadiran seperti Izin, Sakit, atau Cuti.                                                                                   |
| **Photo**           | Menyimpan data foto hasil verifikasi wajah yang digunakan untuk proses absensi.                                                                   |
| **Shift**           | Menyimpan jadwal kerja karyawan, termasuk nama shift, waktu mulai, dan waktu selesai.                                                             |
| **Departemen**      | Menyimpan data departemen tempat karyawan bekerja beserta deskripsinya.                                                                           |

---

## 🧰 Teknologi Digunakan

* **HTML5** – Struktur tampilan halaman aplikasi.
* **CSS3** – Desain antarmuka aplikasi.
* **JavaScript** – Interaktivitas dan logika front-end.
* **PHP / Laravel** – Pengelolaan data dan backend logic.
* **MySQL** – Database utama sistem.
* **OpenCV / Face Recognition Library** – Untuk mendeteksi wajah dan verifikasi kedipan.

---

## 🚀 Cara Menjalankan

1. Clone repository ini:

   ```bash
   git clone https://github.com/username/face-recognition-attendance.git
   ```
2. Masuk ke direktori proyek:

   ```bash
   cd face-recognition-attendance
   ```
3. Jalankan server lokal:

   ```bash
   php artisan serve
   ```
4. Buka di browser:

   ```
   http://localhost:8000
   ```

---

## 🧑‍💼 Tentang Pengembang

👩‍💻 **Nama:** Adinda Mariasti Dewi
🎓 **Prodi:** Teknologi Informasi
📍 **Deskripsi:**
Pengembang aplikasi *Face Recognition Attendance System* ini yang bertujuan untuk mempermudah sistem absensi berbasis teknologi biometrik, serta sebagai implementasi pembelajaran dalam pengembangan sistem berbasis database dan kecerdasan buatan.

---

## 🪪 Lisensi

Proyek ini dibuat untuk keperluan pembelajaran dan riset akademik.
Segala bentuk distribusi atau penggunaan ulang harap mencantumkan sumber dan izin dari pengembang.

---
