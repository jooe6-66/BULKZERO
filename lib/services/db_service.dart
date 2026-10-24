import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/user_settings.dart';
import '../models/weight_log.dart';
import '../data/dkpi_foods.dart';

class DbService {
  static late final Isar isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [FoodItemSchema, MealLogSchema, UserSettingsSchema, WeightLogSchema],
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

    final itemsToSeed = dkpiFoods()
        .where((f) => !existingNames.contains(f.name.toLowerCase().trim()))
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
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final logs = await isar.mealLogs
        .filter()
        .dateBetween(startOfDay, endOfDay, includeUpper: false)
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

  static Future<void> updateMealLogPortion(Id id, double newMultiplier) async {
    final log = await isar.mealLogs.get(id);
    if (log == null) return;
    log.portionMultiplier = newMultiplier;
    await isar.writeTxn(() async {
      await isar.mealLogs.put(log);
    });
  }

  static Future<int> copySessionFromYesterday(String session, DateTime targetDate) async {
    final yesterday = targetDate.subtract(const Duration(days: 1));
    final yesterdayLogs = await getLogsForDay(yesterday);
    final sessionLogs = yesterdayLogs.where((l) => l.mealSession == session).toList();
    if (sessionLogs.isEmpty) return 0;

    for (final oldLog in sessionLogs) {
      if (oldLog.foodItem.value != null) {
        await addMealLog(
          food: oldLog.foodItem.value!,
          mealSession: session,
          portionMultiplier: oldLog.portionMultiplier,
          date: targetDate,
        );
      }
    }
    return sessionLogs.length;
  }

  static Future<void> addWeightLog(double weight, DateTime date) async {
    final log = WeightLog()
      ..date = date
      ..weight = weight;

    await isar.writeTxn(() async {
      await isar.weightLogs.put(log);
    });

    final current = await getSettings();
    current.weight = weight;
    await isar.writeTxn(() async {
      await isar.userSettings.put(current);
    });
  }

  static Future<List<WeightLog>> getWeightLogs() async {
    return isar.weightLogs.where().sortByDateDesc().findAll();
  }

  static Future<void> deleteWeightLog(Id id) async {
    await isar.writeTxn(() async {
      await isar.weightLogs.delete(id);
    });
  }
}
