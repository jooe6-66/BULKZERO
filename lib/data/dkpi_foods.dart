import '../models/food_item.dart';

FoodItem _food({
  required String name,
  required String portionUnit,
  required double estimatedGrams,
  required double calories,
  required double protein,
  double carbs = 0,
  double fat = 0,
}) =>
    FoodItem()
      ..name = name
      ..portionUnit = portionUnit
      ..estimatedGrams = estimatedGrams
      ..calories = calories
      ..protein = protein
      ..carbs = carbs
      ..fat = fat;

/// 100 Data Makanan Populer Indonesia berdasarkan standar DKPI (Daftar Komposisi Pangan Indonesia) Kemenkes RI
List<FoodItem> dkpiFoods() => [
  // --- MAKANAN POKOK & KARBOHIDRAT ---
  _food(name: 'Nasi Putih', portionUnit: 'centong', estimatedGrams: 100, calories: 130, protein: 2.7, carbs: 28.0, fat: 0.3),
  _food(name: 'Nasi Merah', portionUnit: 'centong', estimatedGrams: 100, calories: 110, protein: 2.8, carbs: 23.5, fat: 0.8),
  _food(name: 'Nasi Uduk', portionUnit: 'centong', estimatedGrams: 100, calories: 160, protein: 3.1, carbs: 26.0, fat: 5.0),
  _food(name: 'Nasi Goreng Telur', portionUnit: 'piring sedang', estimatedGrams: 200, calories: 330, protein: 9.5, carbs: 45.0, fat: 12.0),
  _food(name: 'Lontong', portionUnit: 'buah sedang', estimatedGrams: 150, calories: 195, protein: 3.5, carbs: 42.0, fat: 0.5),
  _food(name: 'Ketupat', portionUnit: 'buah', estimatedGrams: 160, calories: 205, protein: 3.8, carbs: 44.0, fat: 0.6),
  _food(name: 'Bubur Ayam (tanpa kerupuk)', portionUnit: 'mangkuk', estimatedGrams: 250, calories: 215, protein: 8.5, carbs: 32.0, fat: 5.5),
  _food(name: 'Kentang Rebus', portionUnit: 'buah sedang', estimatedGrams: 150, calories: 130, protein: 3.0, carbs: 30.0, fat: 0.2),
  _food(name: 'Kentang Goreng', portionUnit: 'porsi kecil', estimatedGrams: 100, calories: 290, protein: 3.5, carbs: 38.0, fat: 14.0),
  _food(name: 'Ubi Jalar Rebus', portionUnit: 'buah sedang', estimatedGrams: 150, calories: 150, protein: 2.5, carbs: 36.0, fat: 0.3),
  _food(name: 'Singkong Rebus', portionUnit: 'potong sedang', estimatedGrams: 100, calories: 145, protein: 1.2, carbs: 34.0, fat: 0.4),
  _food(name: 'Jagung Manis Rebus', portionUnit: 'tongkol sedang', estimatedGrams: 120, calories: 120, protein: 4.0, carbs: 25.0, fat: 1.5),
  _food(name: 'Roti Tawar Putih', portionUnit: 'lembar', estimatedGrams: 35, calories: 95, protein: 3.0, carbs: 18.0, fat: 1.2),
  _food(name: 'Roti Tawar Gandum', portionUnit: 'lembar', estimatedGrams: 40, calories: 100, protein: 4.2, carbs: 17.5, fat: 1.5),
  _food(name: 'Oatmeal Matang', portionUnit: 'mangkuk kecil', estimatedGrams: 150, calories: 140, protein: 5.0, carbs: 25.0, fat: 2.5),
  _food(name: 'Mie Instan Goreng', portionUnit: 'bungkus', estimatedGrams: 85, calories: 380, protein: 8.0, carbs: 54.0, fat: 15.0),
  _food(name: 'Mie Instan Kuah', portionUnit: 'bungkus', estimatedGrams: 75, calories: 330, protein: 7.0, carbs: 48.0, fat: 13.0),
  _food(name: 'Bihun Goreng', portionUnit: 'piring sedang', estimatedGrams: 150, calories: 260, protein: 5.5, carbs: 42.0, fat: 8.0),
  _food(name: 'Kwetiau Goreng', portionUnit: 'piring sedang', estimatedGrams: 180, calories: 310, protein: 7.0, carbs: 46.0, fat: 11.0),

  // --- LAUK AYAM & UNGGAS ---
  _food(name: 'Dada Ayam Rebus/Kukus', portionUnit: 'potong sedang', estimatedGrams: 100, calories: 150, protein: 31.0, carbs: 0.0, fat: 3.0),
  _food(name: 'Dada Ayam Panggang', portionUnit: 'potong sedang', estimatedGrams: 100, calories: 165, protein: 31.0, carbs: 0.0, fat: 3.6),
  _food(name: 'Paha Ayam Atas Bakar', portionUnit: 'potong', estimatedGrams: 90, calories: 175, protein: 22.0, carbs: 1.0, fat: 9.0),
  _food(name: 'Paha Bawah (Pentung) Goreng', portionUnit: 'buah', estimatedGrams: 80, calories: 190, protein: 18.0, carbs: 2.0, fat: 12.0),
  _food(name: 'Sayap Ayam Goreng', portionUnit: 'buah', estimatedGrams: 60, calories: 160, protein: 13.0, carbs: 1.0, fat: 11.5),
  _food(name: 'Ayam Goreng Lengkuas', portionUnit: 'potong sedang', estimatedGrams: 100, calories: 245, protein: 26.0, carbs: 2.5, fat: 14.5),
  _food(name: 'Ayam Pop (khas Minang)', portionUnit: 'potong sedang', estimatedGrams: 100, calories: 180, protein: 25.0, carbs: 1.0, fat: 8.5),
  _food(name: 'Ayam Suwir Balado', portionUnit: 'porsi (4 sdm)', estimatedGrams: 80, calories: 160, protein: 20.0, carbs: 3.0, fat: 7.5),
  _food(name: 'Hati Ayam Rebus', portionUnit: 'buah', estimatedGrams: 50, calories: 75, protein: 12.0, carbs: 1.0, fat: 2.5),
  _food(name: 'Ampela Ayam Rebus', portionUnit: 'buah', estimatedGrams: 45, calories: 60, protein: 11.5, carbs: 0.5, fat: 1.2),
  _food(name: 'Bebek Goreng', portionUnit: 'potong sedang', estimatedGrams: 120, calories: 340, protein: 24.0, carbs: 1.0, fat: 26.0),

  // --- DAGING SAPI, KAMBING & OLAHAN ---
  _food(name: 'Daging Sapi Has Dalam Rebus', portionUnit: 'potong sedang', estimatedGrams: 100, calories: 200, protein: 28.0, carbs: 0.0, fat: 9.0),
  _food(name: 'Rendang Daging Sapi', portionUnit: 'potong sedang', estimatedGrams: 80, calories: 220, protein: 19.5, carbs: 4.0, fat: 14.0),
  _food(name: 'Empal Daging Sapi', portionUnit: 'potong', estimatedGrams: 60, calories: 175, protein: 16.0, carbs: 5.0, fat: 10.0),
  _food(name: 'Daging Cincang Sapi Tumis', portionUnit: 'porsi (4 sdm)', estimatedGrams: 80, calories: 190, protein: 18.0, carbs: 2.0, fat: 12.0),
  _food(name: 'Bakso Sapi Kuah', portionUnit: 'butir besar', estimatedGrams: 40, calories: 70, protein: 6.0, carbs: 5.0, fat: 3.0),
  _food(name: 'Sate Kambing (daging saja)', portionUnit: '5 tusuk', estimatedGrams: 100, calories: 215, protein: 25.0, carbs: 2.0, fat: 12.0),
  _food(name: 'Gulai Daging Sapi', portionUnit: 'mangkuk kecil', estimatedGrams: 120, calories: 250, protein: 18.0, carbs: 4.5, fat: 18.0),
  _food(name: 'Kornet Sapi Tumis', portionUnit: '3 sendok makan', estimatedGrams: 60, calories: 140, protein: 9.0, carbs: 3.0, fat: 10.0),
  _food(name: 'Sosis Sapi Panggang', portionUnit: 'batang', estimatedGrams: 50, calories: 135, protein: 7.0, carbs: 3.0, fat: 11.0),

  // --- IKAN & SEAFOOD ---
  _food(name: 'Ikan Lele Goreng', portionUnit: 'ekor sedang', estimatedGrams: 100, calories: 205, protein: 18.0, carbs: 2.0, fat: 13.5),
  _food(name: 'Ikan Nila Bakar', portionUnit: 'ekor sedang', estimatedGrams: 120, calories: 155, protein: 24.0, carbs: 1.5, fat: 5.5),
  _food(name: 'Ikan Nila Goreng', portionUnit: 'ekor sedang', estimatedGrams: 110, calories: 210, protein: 22.0, carbs: 2.0, fat: 12.5),
  _food(name: 'Ikan Tongkol Balado', portionUnit: 'potong', estimatedGrams: 80, calories: 140, protein: 20.0, carbs: 2.5, fat: 5.5),
  _food(name: 'Ikan Kembung Goreng', portionUnit: 'ekor', estimatedGrams: 90, calories: 185, protein: 19.5, carbs: 1.0, fat: 11.0),
  _food(name: 'Ikan Kembung Kukus', portionUnit: 'ekor', estimatedGrams: 90, calories: 125, protein: 19.0, carbs: 0.0, fat: 4.5),
  _food(name: 'Ikan Mas Goreng', portionUnit: 'ekor sedang', estimatedGrams: 110, calories: 215, protein: 20.0, carbs: 1.5, fat: 13.5),
  _food(name: 'Ikan Bandeng Presto Goreng', portionUnit: 'potong sedang', estimatedGrams: 90, calories: 195, protein: 18.0, carbs: 2.0, fat: 12.5),
  _food(name: 'Ikan Teri Goreng', portionUnit: '2 sendok makan', estimatedGrams: 30, calories: 110, protein: 10.5, carbs: 1.0, fat: 7.0),
  _food(name: 'Ikan Gurame Bakar', portionUnit: 'potong', estimatedGrams: 120, calories: 160, protein: 23.0, carbs: 2.0, fat: 6.0),
  _food(name: 'Ikan Bawal Bakar', portionUnit: 'potong', estimatedGrams: 110, calories: 150, protein: 21.0, carbs: 1.5, fat: 6.5),
  _food(name: 'Ikan Salmon Panggang', portionUnit: 'potong sedang', estimatedGrams: 100, calories: 205, protein: 22.0, carbs: 0.0, fat: 12.5),
  _food(name: 'Cumi-cumi Tumis Pedas', portionUnit: 'porsi (4 sdm)', estimatedGrams: 90, calories: 125, protein: 16.0, carbs: 3.5, fat: 5.0),
  _food(name: 'Udang Rebus', portionUnit: '5-6 ekor sedang', estimatedGrams: 80, calories: 85, protein: 18.0, carbs: 0.5, fat: 1.0),
  _food(name: 'Udang Goreng Tepung', portionUnit: '4 ekor sedang', estimatedGrams: 80, calories: 180, protein: 14.0, carbs: 12.0, fat: 8.5),
  _food(name: 'Sarden Saus Tomat Kaleng', portionUnit: 'potong ikan + saus', estimatedGrams: 80, calories: 140, protein: 14.5, carbs: 4.0, fat: 7.0),

  // --- TELUR & SUSU ---
  _food(name: 'Telur Ayam Rebus', portionUnit: 'butir', estimatedGrams: 55, calories: 78, protein: 6.3, carbs: 0.6, fat: 5.3),
  _food(name: 'Telur Ayam Ceplok (Minyak)', portionUnit: 'butir', estimatedGrams: 60, calories: 110, protein: 6.5, carbs: 0.6, fat: 9.0),
  _food(name: 'Telur Ayam Dadar', portionUnit: 'butir', estimatedGrams: 65, calories: 125, protein: 7.0, carbs: 1.0, fat: 10.5),
  _food(name: 'Putih Telur Rebus', portionUnit: 'butir', estimatedGrams: 35, calories: 17, protein: 3.8, carbs: 0.2, fat: 0.1),
  _food(name: 'Telur Asin Rebus', portionUnit: 'butir', estimatedGrams: 60, calories: 105, protein: 8.0, carbs: 1.0, fat: 7.5),
  _food(name: 'Telur Puyuh Rebus', portionUnit: 'butir', estimatedGrams: 10, calories: 16, protein: 1.3, carbs: 0.1, fat: 1.1),
  _food(name: 'Susu Sapi Murni / UHT Full Cream', portionUnit: 'gelas (200ml)', estimatedGrams: 200, calories: 130, protein: 6.5, carbs: 10.0, fat: 7.0),
  _food(name: 'Susu UHT Low Fat', portionUnit: 'gelas (200ml)', estimatedGrams: 200, calories: 95, protein: 6.8, carbs: 11.0, fat: 2.5),
  _food(name: 'Susu Kedelai Murni', portionUnit: 'gelas (200ml)', estimatedGrams: 200, calories: 90, protein: 6.0, carbs: 8.0, fat: 4.0),
  _food(name: 'Keju Cheddar Olahan', portionUnit: 'lembar / slice', estimatedGrams: 20, calories: 65, protein: 4.0, carbs: 1.0, fat: 5.0),
  _food(name: 'Yoghurt Plain', portionUnit: 'cup kecil', estimatedGrams: 100, calories: 65, protein: 4.5, carbs: 6.0, fat: 3.0),
  _food(name: 'Susu Whey Protein', portionUnit: 'scoop', estimatedGrams: 30, calories: 120, protein: 24.0, carbs: 2.0, fat: 1.5),

  // --- TAHU, TEMPE & KACANG-KACANGAN ---
  _food(name: 'Tempe Goreng Tepung', portionUnit: 'potong sedang', estimatedGrams: 50, calories: 120, protein: 7.0, carbs: 7.0, fat: 7.5),
  _food(name: 'Tempe Goreng Gurih', portionUnit: 'potong sedang', estimatedGrams: 40, calories: 95, protein: 7.5, carbs: 3.5, fat: 5.5),
  _food(name: 'Tempe Bacem', portionUnit: 'potong sedang', estimatedGrams: 50, calories: 110, protein: 7.5, carbs: 11.0, fat: 4.0),
  _food(name: 'Tempe Mendoan', portionUnit: 'lembar', estimatedGrams: 50, calories: 135, protein: 6.5, carbs: 9.0, fat: 8.5),
  _food(name: 'Tempe Kukus / Rebus', portionUnit: 'potong sedang', estimatedGrams: 40, calories: 75, protein: 7.8, carbs: 3.0, fat: 3.2),
  _food(name: 'Tahu Goreng', portionUnit: 'potong segitiga/kotak', estimatedGrams: 50, calories: 65, protein: 4.5, carbs: 1.5, fat: 4.5),
  _food(name: 'Tahu Putih Kukus/Rebus', portionUnit: 'potong', estimatedGrams: 75, calories: 45, protein: 5.5, carbs: 1.0, fat: 2.0),
  _food(name: 'Tahu Bacem', portionUnit: 'potong', estimatedGrams: 60, calories: 85, protein: 5.0, carbs: 9.0, fat: 3.0),
  _food(name: 'Tahu Isi Sayur Goreng', portionUnit: 'buah', estimatedGrams: 60, calories: 130, protein: 4.5, carbs: 12.0, fat: 7.5),
  _food(name: 'Oncom Goreng', portionUnit: 'potong', estimatedGrams: 40, calories: 75, protein: 4.5, carbs: 4.0, fat: 4.5),
  _food(name: 'Edamame Rebus', portionUnit: 'mangkuk kecil (kulit)', estimatedGrams: 100, calories: 120, protein: 11.0, carbs: 9.0, fat: 5.0),
  _food(name: 'Kacang Tanah Sangrai/Goreng', portionUnit: '2 sendok makan', estimatedGrams: 30, calories: 175, protein: 7.5, carbs: 5.0, fat: 14.5),
  _food(name: 'Kacang Hijau Rebus (gula sedikit)', portionUnit: 'mangkuk', estimatedGrams: 150, calories: 160, protein: 8.0, carbs: 30.0, fat: 1.0),
  _food(name: 'Selai Kacang (Peanut Butter)', portionUnit: 'sendok makan', estimatedGrams: 16, calories: 95, protein: 4.0, carbs: 3.0, fat: 8.0),

  // --- SAYUR & MASAKAN RUMAHAN ---
  _food(name: 'Sayur Sop Ayam', portionUnit: 'mangkuk', estimatedGrams: 200, calories: 110, protein: 8.0, carbs: 10.0, fat: 4.0),
  _food(name: 'Sayur Bening Bayam', portionUnit: 'mangkuk', estimatedGrams: 150, calories: 35, protein: 2.5, carbs: 6.0, fat: 0.5),
  _food(name: 'Sayur Asem', portionUnit: 'mangkuk', estimatedGrams: 180, calories: 60, protein: 2.0, carbs: 11.0, fat: 1.0),
  _food(name: 'Tumis Kangkung', portionUnit: 'piring kecil', estimatedGrams: 100, calories: 85, protein: 2.5, carbs: 5.0, fat: 6.0),
  _food(name: 'Capcay Sayur Kuah', portionUnit: 'mangkuk sedang', estimatedGrams: 150, calories: 90, protein: 4.5, carbs: 9.0, fat: 4.0),
  _food(name: 'Sayur Lodeh', portionUnit: 'mangkuk', estimatedGrams: 180, calories: 135, protein: 3.5, carbs: 10.0, fat: 9.5),
  _food(name: 'Tumis Buncis & Wortel', portionUnit: 'piring kecil', estimatedGrams: 100, calories: 75, protein: 2.2, carbs: 6.5, fat: 4.5),
  _food(name: 'Brokoli Kukus', portionUnit: 'mangkuk kecil', estimatedGrams: 100, calories: 35, protein: 3.0, carbs: 6.5, fat: 0.4),
  _food(name: 'Gado-Gado Komplit (dengan telur & bumbu)', portionUnit: 'porsi', estimatedGrams: 250, calories: 350, protein: 14.0, carbs: 35.0, fat: 18.0),
  _food(name: 'Pecel Sayur (dengan bumbu)', portionUnit: 'porsi', estimatedGrams: 180, calories: 230, protein: 8.5, carbs: 25.0, fat: 11.5),
  _food(name: 'Lalapan Timun & Selada', portionUnit: 'piring kecil', estimatedGrams: 100, calories: 15, protein: 0.8, carbs: 3.0, fat: 0.1),

  // --- MASAKAN POPULER / WARUNG ---
  _food(name: 'Soto Ayam Lamongan/Kuning', portionUnit: 'mangkuk', estimatedGrams: 250, calories: 240, protein: 18.0, carbs: 12.0, fat: 14.0),
  _food(name: 'Soto Betawi (Daging Sapi & Santan)', portionUnit: 'mangkuk', estimatedGrams: 250, calories: 380, protein: 21.0, carbs: 8.0, fat: 29.0),
  _food(name: 'Rawon Daging Sapi', portionUnit: 'mangkuk', estimatedGrams: 250, calories: 290, protein: 22.0, carbs: 6.0, fat: 20.0),
  _food(name: 'Sate Ayam Bumbu Kacang', portionUnit: '5 tusuk', estimatedGrams: 100, calories: 230, protein: 21.0, carbs: 10.0, fat: 12.0),
  _food(name: 'Martabak Telur Sapi', portionUnit: '2 potong', estimatedGrams: 100, calories: 270, protein: 11.0, carbs: 16.0, fat: 18.0),

  // --- BUAH-BUAHAN & CEMILAN SEHAT ---
  _food(name: 'Pisang Ambon', portionUnit: 'buah sedang', estimatedGrams: 100, calories: 95, protein: 1.2, carbs: 24.0, fat: 0.3),
  _food(name: 'Pisang Cavendish', portionUnit: 'buah sedang', estimatedGrams: 110, calories: 105, protein: 1.3, carbs: 26.0, fat: 0.3),
  _food(name: 'Alpukat', portionUnit: 'buah sedang', estimatedGrams: 150, calories: 240, protein: 3.0, carbs: 12.0, fat: 22.0),
  _food(name: 'Apel Fuji', portionUnit: 'buah sedang', estimatedGrams: 150, calories: 80, protein: 0.4, carbs: 21.0, fat: 0.2),
  _food(name: 'Pepaya', portionUnit: 'potong sedang', estimatedGrams: 150, calories: 60, protein: 0.9, carbs: 15.0, fat: 0.2),
  _food(name: 'Mangga Harum Manis', portionUnit: 'buah sedang', estimatedGrams: 150, calories: 100, protein: 1.0, carbs: 25.0, fat: 0.5),
  _food(name: 'Semangka', portionUnit: 'potong besar', estimatedGrams: 200, calories: 60, protein: 1.2, carbs: 15.0, fat: 0.3),
  _food(name: 'Kurma Sukari', portionUnit: '3 butir', estimatedGrams: 30, calories: 85, protein: 0.8, carbs: 22.0, fat: 0.1),
];
