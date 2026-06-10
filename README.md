# EyeGuard Mobile

> Aplikasi Android berbasis Flutter untuk membantu pengguna menjaga kesehatan mata saat menggunakan smartphone.

---

## Deskripsi Proyek

**EyeGuard Mobile** adalah aplikasi mobile Android yang dirancang untuk membantu pengguna menjaga kesehatan mata saat menggunakan smartphone. Aplikasi ini memanfaatkan sensor cahaya perangkat untuk mendeteksi intensitas pencahayaan lingkungan secara *real-time*, lalu memberikan peringatan jika pengguna terlalu lama menggunakan smartphone di kondisi pencahayaan yang buruk.

Selain monitoring cahaya, aplikasi menyediakan fitur pengaturan batas waktu penggunaan per-aplikasi (App Timer) serta statistik screen time harian dan mingguan agar pengguna dapat mengontrol dan memahami pola penggunaan perangkat mereka.

---

## Fitur Utama

| Fitur | Deskripsi |
|---|---|
| **Monitoring Cahaya** | Deteksi lux real-time, status terang/gelap, notifikasi peringatan, riwayat grafik |
| **App Timer** | Batas waktu per-aplikasi, notifikasi bertingkat, background foreground service |
| **Statistik** | Screen time harian & mingguan, grafik bar chart, aplikasi paling sering digunakan |

---

## Tech Stack

- **Framework**: Flutter (Dart) — SDK `^3.11.5`
- **Backend API**: Node.js + PostgreSQL · `https://eye-guard-api.vercel.app`
- **Autentikasi**: JWT Token + OTP via Email

### Dependensi Utama

| Package | Kegunaan |
|---|---|
| `usage_stats` | Membaca statistik penggunaan aplikasi Android |
| `flutter_foreground_task` | Background Foreground Service untuk timer & sensor |
| `flutter_local_notifications` | Notifikasi peringatan |
| `light` | Membaca sensor lux secara real-time |
| `fl_chart` | Visualisasi grafik bar chart |
| `permission_handler` | Manajemen izin Android |
| `shared_preferences` | Penyimpanan data lokal |
| `http` | Komunikasi ke REST API backend |
| `google_fonts` | Tipografi (font Outfit) |

---

## Instalasi & Menjalankan Proyek

### Prasyarat

Pastikan hal berikut sudah terinstal di komputer Anda:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) versi `^3.11.5`
- [Android Studio](https://developer.android.com/studio) atau VS Code dengan ekstensi Flutter
- Android SDK dengan **minSdkVersion 26+**
- Perangkat Android fisik (direkomendasikan — emulator tidak mendukung sensor lux)

### Langkah Instalasi

```bash
# 1. Clone repositori ini
git clone https://github.com/iqbalmuhammad08f/EyeGuardMobile

# 2. Masuk ke direktori proyek
cd eye_guard_mobile

# 3. Install semua dependensi Flutter
flutter pub get

# 4. Pastikan perangkat Android terhubung, lalu jalankan aplikasi
flutter run
```

### Izin yang Diperlukan

Saat pertama kali dijalankan, aplikasi akan meminta izin berikut melalui halaman onboarding:

- **Usage Access** — Untuk membaca statistik penggunaan aplikasi *(wajib diberikan manual via Pengaturan → Aplikasi → Akses Penggunaan)*
- **Notifikasi** — Untuk peringatan timer dan monitoring cahaya
- **Tampil di atas aplikasi lain** — Untuk fitur blokir layar saat timer habis

---

