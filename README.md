# BulkZero - Simple Offline Bulking Tracker

Aplikasi pelacak kalori dan protein harian untuk fase *bulking*, dirancang khusus dengan database makanan lokal Indonesia (DKPI) dan ukuran rumah tangga (URT) standar. Ringan, cepat, dan 100% offline tanpa perlu login atau koneksi internet (*Zero Internet, Zero Login, Zero Ads*).

---

## Fitur Utama

- **105 Database Makanan Lokal (DKPI):** Data gizi resmi pangan Indonesia dengan takaran rumah tangga umum (*centong nasi, potong dada ayam, butir telur, papan tempe*).
- **Target Bulking Otomatis:** Perhitungan BMR (Mifflin-St Jeor), TDEE, estimasi BMI, serta rekomendasi target kalori surplus (+500 kkal) dan protein harian.
- **Salin Menu Kemarin (1-Tap Copy):** Salin riwayat makan hari kemarin ke hari ini dalam 1 klik tanpa input ulang.
- **Ubah Porsi Praktis & Timbang Gram:** Pilih istilah porsi sehari-hari (*Setengah, Pas Standar, Nambah, Jumbo, Porsi Kuli*) atau timbang langsung berat makanan dalam gram (dengan stepper +/- 10g).
- **Log Berat Badan Berkala:** Pantau tren kenaikan berat badan dengan indikator delta selisih (+/- kg).
- **100% Offline & Cepat:** Menggunakan Isar Database lokal. Bebas iklan, bebas pelacakan, dan instan.

---

## Unduh & Pasang Aplikasi

### Android (APK)
1. Buka menu **[Releases](https://github.com/jooe6-66/bulk-track/releases)** di repositori ini.
2. Unduh file apk pada rilis versi terbaru.
3. Buka file APK di HP Android Anda dan izinkan instalasi (*Allow from this source*).

### iOS / iPhone (IPA via GitHub Actions)
Karena sistem iOS tertutup, build `.ipa` dilakukan secara otomatis di cloud macOS GitHub:
1. Buka tab **[Actions](https://github.com/jooe6-66/bulk-track/actions)** pada repositori ini.
2. Pilih workflow **"Build iOS IPA"** di menu sebelah kiri.
3. Klik tombol **"Run workflow"** (pilih branch `main` lalu tekan tombol hijau).
4. Setelah build selesai (5–10 menit), klik judul run tersebut lalu unduh file **`BulkZero-iOS-IPA`** di bagian *Artifacts*.
5. **Pasang ke iPhone via Sideloadly (Gratis):**
   - Unduh software gratis [Sideloadly](https://sideloadly.io) di PC/laptop (Windows/Mac).
   - Hubungkan iPhone ke PC/laptop dengan kabel data.
   - Tarik file `BulkZero.ipa` ke Sideloadly, masukkan Apple ID Anda, lalu klik **Start**.
   - Di iPhone: Buka *Pengaturan (Settings) > Umum (General) > Manajemen VPN & Perangkat*, lalu klik **Trust** pada akun Apple ID Anda.

---

## Tech Stack & Pengembangan

- **Framework:** Flutter 3 (Dart)
- **Database:** Isar Database (Local NoSQL)
- **State & Architecture:** Minimalist StatefulWidget + Service Pattern
- **CI/CD:** GitHub Actions (Automated macOS Runner for iOS)

### Build dari Source:
```bash
# Clone repository
git clone https://github.com/jooe6-66/bulk-track.git
cd bulk-track

# Install dependencies & generate Isar code
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Build APK Release (Android)
flutter build apk --release
# File APK tersimpan di: build/app/outputs/flutter-apk/app-release.apk
```
