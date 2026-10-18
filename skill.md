# Skill: Flutter Offline Bulking Tracker Developer

## Peran & Tanggung Jawab
Mengembangkan aplikasi pelacak bulking berbasis Flutter yang beroperasi 100% offline menggunakan Isar Database, menerapkan estimasi porsi Ukuran Rumah Tangga (URT), dan arsitektur kode yang bersih.

## Standar Teknologi
- Framework: Flutter 3.x (Dart 3.x)
- Database: Isar Database (`isar`, `isar_flutter_libs`, `isar_generator`)
- State Management: Provider / Riverpod / BLoC (Pilih yang minim boilerplate, misal: ValueNotifier atau Riverpod)
- Path Provider: `path_provider`

## Pedoman Arsitektur Data

### 1. Entitas & Relasi Isar
- Gunakan `@collection` pada setiap entitas.
- Pisahkan antara `FoodItem` (katalog master makanan) dan `MealLog` (catatan konsumsi harian).
- Gunakan `IsarLink<FoodItem>` di dalam `MealLog` untuk menjaga integritas data tanpa redundansi penulisan kalori/makro.
- Sediakan kalkulasi getter langsung pada `MealLog` untuk membaca total kalori, protein, karbo, dan lemak berdasarkan `jumlahPorsi`.

### 2. Strategi Seeding Makanan Lokal
- Saat inisialisasi aplikasi via `DbService`, cek `isar.foodItems.count()`.
- Jika bernilai 0, jalankan transaksi tulis (`writeTxn`) untuk memasukkan data awal bahan makanan pokok Indonesia.
- Standar konversi URT baku:
  * Nasi Putih: 1 centong = ~100g (~130 kkal, ~2.7g protein)
  * Dada Ayam: 1 potong sedang = ~100g (~165 kkal, ~31g protein)
  * Telur Ayam: 1 butir = ~55g (~78 kkal, ~6.3g protein)
  * Tempe: 1 potong sedang = ~40g (~80 kkal, ~7.5g protein)

### 3. Aturan Querying
- Selalu batasi pencarian log harian berdasarkan rentang waktu hari yang sama (`tanggalBetween(startOfDay, endOfDay)`).
- Gunakan transaksi penulisan asinkron (`await isar.writeTxn(...)`) dan jangan lupa menyimpan relasi link (`await log.foodItem.save()`).

## Pola Antarmuka (UI/UX)
- Input makanan harus mengutamakan kemudahan satu tangan: sediakan dropdown/counter increment-decrement (0.5, 1, 1.5, 2) untuk porsi.
- Ringkasan harian harus menonjolkan dua metrik utama bulking: **Total Kalori** dan **Total Protein (gram)**.
- Hindari input teks bebas untuk angka gram; selalu gunakan takaran URT sebagai perantara.