import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/user_settings.dart';

class DbService {
  static late final Isar isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [FoodItemSchema, MealLogSchema, UserSettingsSchema],
      directory: dir.path,
      name: 'bulking_db',
    );
    await _seedInitialFoods();
  }

  static Future<UserSettings> getSettings() async {
    final settings = await isar.userSettings.get(0);
    if (settings != null) return settings;

    final defaultSettings = UserSettings();
    await isar.writeTxn(() async {
      await isar.userSettings.put(defaultSettings);
    });
    return defaultSettings;
  }

  static Future<void> saveSettings(double calories, double protein) async {
    final settings = UserSettings()
      ..targetCalories = calories
      ..targetProtein = protein;
    await isar.writeTxn(() async {
      await isar.userSettings.put(settings);
    });
  }

  static Future<void> _seedInitialFoods() async {
    final count = await isar.foodItems.count();
    if (count > 0) return;

    final initialFoods = [
      FoodItem()
        ..name = 'Nasi Putih'
        ..portionUnit = 'centong'
        ..estimatedGrams = 100
        ..calories = 130
        ..protein = 2.7
        ..carbs = 28
        ..fat = 0.3,
      FoodItem()
        ..name = 'Dada Ayam'
        ..portionUnit = 'potong sedang'
        ..estimatedGrams = 100
        ..calories = 165
        ..protein = 31
        ..carbs = 0
        ..fat = 3.6,
      FoodItem()
        ..name = 'Telur Ayam'
        ..portionUnit = 'butir'
        ..estimatedGrams = 55
        ..calories = 78
        ..protein = 6.3
        ..carbs = 0.6
        ..fat = 5,
      FoodItem()
        ..name = 'Tempe'
        ..portionUnit = 'potong sedang'
        ..estimatedGrams = 40
        ..calories = 80
        ..protein = 7.5
        ..carbs = 3
        ..fat = 4,
      FoodItem()
        ..name = 'Tahu'
        ..portionUnit = 'potong sedang'
        ..estimatedGrams = 50
        ..calories = 40
        ..protein = 4
        ..carbs = 1
        ..fat = 2.5,
    ];

    await isar.writeTxn(() async {
      await isar.foodItems.putAll(initialFoods);
    });
    debugPrint('Seeded initial URT food items');
  }

  static Future<List<FoodItem>> searchFoods(String query) async {
    if (query.trim().isEmpty) {
      return isar.foodItems.where().findAll();
    }
    return isar.foodItems
        .filter()
        .nameContains(query.trim(), caseSensitive: false)
        .findAll();
  }

  static Future<List<MealLog>> getLogsForDay(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final logs = await isar.mealLogs
        .filter()
        .dateBetween(startOfDay, endOfDay)
        .findAll();

    for (final log in logs) {
      await log.foodItem.load();
    }
    return logs;
  }

  static Future<void> addMealLog({
    required FoodItem food,
    required String mealSession,
    required double portionMultiplier,
    DateTime? date,
  }) async {
    final log = MealLog()
      ..date = date ?? DateTime.now()
      ..mealSession = mealSession
      ..portionMultiplier = portionMultiplier;
    log.foodItem.value = food;

    await isar.writeTxn(() async {
      await isar.mealLogs.put(log);
      await log.foodItem.save();
    });
  }

  static Future<void> deleteMealLog(Id id) async {
    await isar.writeTxn(() async {
      await isar.mealLogs.delete(id);
    });
  }

  static Future<void> addCustomFood({
    required String name,
    required String portionUnit,
    required double estimatedGrams,
    required double calories,
    required double protein,
    double carbs = 0.0,
    double fat = 0.0,
  }) async {
    final food = FoodItem()
      ..name = name.trim()
      ..portionUnit = portionUnit.trim()
      ..estimatedGrams = estimatedGrams
      ..calories = calories
      ..protein = protein
      ..carbs = carbs
      ..fat = fat
      ..isCustom = true;

    await isar.writeTxn(() async {
      await isar.foodItems.put(food);
    });
  }
}
