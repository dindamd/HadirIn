# absensiapp

## HadirIn

🧠 Face Recognition Attendance System

Aplikasi absensi mobile berbasis pengenalan wajah (Face Recognition) yang dikembangkan untuk mencatat kehadiran karyawan secara otomatis dan efisien.
Selain itu, sistem dilengkapi dengan halaman login admin serta dashboard admin untuk memantau dan mengelola data kehadiran karyawan secara real-time.

### Fitur Utama
👤 Face Recognition Page

Melakukan absensi dengan pemindaian wajah (scan wajah).

Dilengkapi dengan verifikasi kedipan (liveness detection) untuk memastikan wajah asli, bukan foto.

Sistem akan menampilkan notifikasi seperti:

“Silakan berkedip 2 kali untuk verifikasi”

“Verifikasi berhasil”

“Absensi berhasil”

Data yang tersimpan meliputi:

Wajah pengguna (encoded vector),

Waktu absensi,

Status kehadiran (Hadir, Terlambat, Tidak Hadir),

Hasil verifikasi (Live/Not Live).

🔐 Admin Login Page

Halaman login khusus untuk administrator.

Admin harus memasukkan username dan password yang terdaftar untuk mengakses sistem.

Mendukung autentikasi berbasis peran (role-based access control).

Data yang disimpan dalam tabel mencakup:

Username, password, nama admin, role, email, status akun, dan waktu login terakhir.

🖥️ Admin Dashboard Page

Menampilkan rekap kehadiran karyawan secara real-time, termasuk jumlah:

Tepat waktu

Terlambat

Tidak hadir

Admin dapat melihat daftar nama karyawan beserta status dan alasan ketidakhadirannya.

Dilengkapi dengan fitur:

Edit data kehadiran,

Input alasan absen,

Logout aman (dengan konfirmasi pop-up).

Data pada dashboard diambil secara otomatis dari tabel Attendance dan Pegawai.

🧩 Struktur Database Utama

Sistem ini terdiri dari beberapa tabel utama yang saling berelasi:

Tabel	Deskripsi Singkat
Pegawai	Menyimpan data karyawan seperti NIK, nama, departemen, dan shift kerja.
Users	Menyimpan akun pengguna sistem (admin dan karyawan).
Roles	Menentukan hak akses pengguna (Admin, HRD, Karyawan).
Attendance	Mencatat hasil absensi berbasis face recognition.
Status_Presensi	Menyimpan status kehadiran (Hadir, Terlambat, Tidak Hadir).
Reason_Presensi	Menyimpan alasan ketidakhadiran (Izin, Sakit, Cuti, dll).
Photo	Menyimpan data foto wajah yang digunakan untuk verifikasi.
Shift	Menyimpan jadwal kerja dan waktu mulai/selesai shift.
Departemen	Menyimpan data struktur departemen perusahaan.
🏗️ Teknologi yang Digunakan

Frontend: Flutter / React Native (mobile)

Backend: Laravel / Node.js (tergantung implementasi)

Database: MySQL / PostgreSQL

Face Recognition Engine: OpenCV / FaceNet / TensorFlow

Authentication: JWT atau session-based login

⚙️ Cara Menjalankan Proyek

Clone repository ini

git clone https://github.com/username/face-recognition-attendance.git


Masuk ke direktori proyek

cd face-recognition-attendance


Install dependencies

npm install  # atau composer install untuk Laravel


Konfigurasi file .env

Atur koneksi database

Tambahkan API Key jika menggunakan layanan cloud face recognition

Jalankan server lokal

npm run dev  # atau php artisan serve


Buka aplikasi di browser / emulator

http://localhost:8000

👥 Peran Pengguna
Role	Deskripsi
Admin	Mengelola data karyawan, memantau kehadiran, dan memperbarui catatan absensi.
Karyawan	Melakukan absensi dengan pemindaian wajah dan melihat status kehadiran pribadi.
🧾 Lisensi

Proyek ini dikembangkan untuk keperluan riset dan implementasi internal.
Dilarang memperbanyak atau mendistribusikan tanpa izin pengembang.
