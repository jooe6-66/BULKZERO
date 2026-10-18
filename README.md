# BulkZero - Simple Offline Bulking Tracker

Aplikasi pelacak kalori dan protein harian untuk fase *bulking*, dirancang khusus dengan database makanan lokal Indonesia (DKPI) dan ukuran rumah tangga (URT) standar. Ringan, cepat, dan 100% offline tanpa perlu login atau koneksi internet (Zero Internet, Zero Login, Zero Ads).

---

## ⚡ Fitur Utama

- **105 Database Makanan Lokal (DKPI):** Data gizi resmi pangan Indonesia dengan takaran rumah tangga umum (*centong nasi, potong dada ayam, butir telur, papan tempe*).
- **Target Bulking Otomatis:** Perhitungan BMR (Mifflin-St Jeor), TDEE, estimasi BMI, serta rekomendasi target kalori surplus (+500 kkal) dan protein harian.
- **Salin Menu Kemarin (1-Tap Copy):** Salin riwayat makan hari kemarin ke hari ini dalam 1 klik tanpa input ulang.
- **Ubah Porsi Praktis & Timbang Gram:** Pilih istilah porsi sehari-hari (*Setengah, Pas Standar, Nambah, Jumbo, Porsi Kuli*) atau timbang langsung berat makanan dalam gram (dengan stepper +/- 10g).
- **Log Berat Badan Berkala:** Pantau tren kenaikan berat badan dengan indikator delta selisih (+/- kg).
- **100% Offline & Cepat:** Menggunakan Isar Database lokal. Bebas iklan, bebas pelacakan, dan instan.

---

## 📲 Unduh & Pasang APK

File APK siap pakai dapat diunduh langsung melalui menu **[Releases](https://github.com/jooe6-66/bulk-track/releases)** di repositori ini:

1. Buka halaman **Releases** pada repository GitHub ini.
2. Unduh file `app-release.apk` pada versi terbaru.
3. Buka file APK di HP Android Anda dan izinkan instalasi dari sumber tidak dikenal (*Allow from this source*).

---

## 🛠️ Tech Stack & Pengembangan

- **Framework:** Flutter 3 (Dart)
- **Database:** Isar Database (Local NoSQL)
- **State & Architecture:** Minimalist StatefulWidget + Service Pattern

### Build dari Source:
```bash
# Clone repository
git clone https://github.com/jooe6-66/bulk-track.git
cd bulk-track

# Install dependencies & generate Isar code
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Build APK Release
flutter build apk --release
# File APK tersimpan di: build/app/outputs/flutter-apk/app-release.apk
```
