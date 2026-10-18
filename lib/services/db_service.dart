import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/user_settings.dart';
import '../data/dkpi_foods.dart';

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
    final current = await getSettings();
    current.targetCalories = calories;
    current.targetProtein = protein;
    await isar.writeTxn(() async {
      await isar.userSettings.put(current);
    });
  }

  static Future<void> saveProfile({
    required String name,
    required double weight,
    required double height,
    required int age,
    required double targetCalories,
    required double targetProtein,
  }) async {
    final settings = UserSettings()
      ..name = name.trim()
      ..weight = weight
      ..height = height
      ..age = age
      ..targetCalories = targetCalories
      ..targetProtein = targetProtein
      ..isProfileCompleted = true;
    await isar.writeTxn(() async {
      await isar.userSettings.put(settings);
    });
  }

  static Future<void> _seedInitialFoods() async {
    final existingFoods = await isar.foodItems.where().findAll();
    final existingNames = existingFoods.map((e) => e.name.toLowerCase().trim()).toSet();

    final itemsToSeed = dkpiFoodDatabase
        .where((df) => !existingNames.contains(df.name.toLowerCase().trim()))
        .map((df) => FoodItem()
          ..name = df.name
          ..portionUnit = df.portionUnit
          ..estimatedGrams = df.estimatedGrams
          ..calories = df.calories
          ..protein = df.protein
          ..carbs = df.carbs
          ..fat = df.fat
          ..isCustom = false)
        .toList();

    if (itemsToSeed.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.foodItems.putAll(itemsToSeed);
      });
      debugPrint('Seeded ${itemsToSeed.length} DKPI food items into local database.');
    }
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
