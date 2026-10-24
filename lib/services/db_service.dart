import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/user_settings.dart';
import '../models/weight_log.dart';
import '../data/dkpi_foods.dart';
import 'backup.dart';

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
    required double targetWeight,
    required double height,
    required int age,
    required int activityLevel,
    required double targetCalories,
    required double targetProtein,
  }) async {
    final current = await getSettings();
    final settings = UserSettings()
      ..name = name.trim()
      ..weight = weight
      ..targetWeight = targetWeight
      ..height = height
      ..age = age
      ..activityLevel = activityLevel
      ..targetCalories = targetCalories
      ..targetProtein = targetProtein
      ..isProfileCompleted = true
      ..remindersEnabled = current.remindersEnabled;
    await isar.writeTxn(() async {
      await isar.userSettings.put(settings);
    });
  }

  static Future<void> setRemindersEnabled(bool enabled) async {
    final current = await getSettings();
    current.remindersEnabled = enabled;
    await isar.writeTxn(() async {
      await isar.userSettings.put(current);
    });
  }

  static Future<String> exportBackupJson() async {
    final settings = await getSettings();
    final foods = await isar.foodItems.where().findAll();
    final mealLogs = await isar.mealLogs.where().findAll();
    for (final l in mealLogs) {
      await l.foodItem.load();
    }
    final weightLogs = await isar.weightLogs.where().findAll();
    return encodeBackup(
      settings: settings,
      foods: foods,
      mealLogs: mealLogs,
      weightLogs: weightLogs,
    );
  }

  static Future<void> importBackupJson(String jsonSource) async {
    final data = decodeBackup(jsonSource);
    await isar.writeTxn(() async {
      await isar.mealLogs.clear();
      await isar.weightLogs.clear();
      await isar.foodItems.clear();
      await isar.userSettings.put(data.settings);
      await isar.foodItems.putAll(data.foods);
      final foodById = {for (final f in data.foods) f.id: f};
      for (final item in data.mealLogs) {
        item.log.foodItem.value = foodById[item.foodId];
        await isar.mealLogs.put(item.log);
        await item.log.foodItem.save();
      }
      await isar.weightLogs.putAll(data.weightLogs);
    });
    await _seedInitialFoods();
  }

  static Future<void> _seedInitialFoods() async {
    final existing = {
      for (final f in await isar.foodItems.filter().isCustomEqualTo(false).findAll())
        f.name.toLowerCase().trim(): f,
    };

    // New DKPI items, plus existing ones whose category changed in a later version.
    final toPut = <FoodItem>[];
    for (final seed in dkpiFoods()) {
      final current = existing[seed.name.toLowerCase().trim()];
      if (current == null) {
        toPut.add(seed);
      } else if (current.isSnack != seed.isSnack) {
        toPut.add(current..isSnack = seed.isSnack);
      }
    }

    if (toPut.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.foodItems.putAll(toPut);
      });
      debugPrint('Seeded/updated ${toPut.length} DKPI food items.');
    }
  }

  /// Empty query + [isSnack] set: only that category. Typed query: search all foods.
  static Future<List<FoodItem>> searchFoods(String query, {bool? isSnack}) async {
    final q = query.trim();
    if (q.isNotEmpty) {
      return isar.foodItems.filter().nameContains(q, caseSensitive: false).findAll();
    }
    if (isSnack == null) return isar.foodItems.where().findAll();
    // Rows saved before `isSnack` existed store null, so "not snack" must be `not(== true)`.
    return isSnack
        ? isar.foodItems.filter().isSnackEqualTo(true).findAll()
        : isar.foodItems.filter().not().isSnackEqualTo(true).findAll();
  }

  /// Distinct foods most recently logged in [session], newest first.
  static Future<List<FoodItem>> getRecentFoods(String session, {int limit = 5}) async {
    final logs = await isar.mealLogs
        .filter()
        .mealSessionEqualTo(session)
        .sortByDateDesc()
        .limit(30)
        .findAll();
    final seen = <int>{};
    final foods = <FoodItem>[];
    for (final log in logs) {
      await log.foodItem.load();
      final food = log.foodItem.value;
      if (food != null && seen.add(food.id)) foods.add(food);
      if (foods.length == limit) break;
    }
    return foods;
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

  /// Daily calorie totals for the 7 days ending on [endDate] (oldest first).
  static Future<List<({DateTime date, double calories})>> getWeeklyCalories(DateTime endDate) async {
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final startDay = endDay.subtract(const Duration(days: 6));
    final upper = endDay.add(const Duration(days: 1));

    final logs = await isar.mealLogs
        .filter()
        .dateBetween(startDay, upper, includeUpper: false)
        .findAll();
    for (final log in logs) {
      await log.foodItem.load();
    }

    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = startDay.add(Duration(days: i));
          final cals = logs
              .where((l) => l.date.year == d.year && l.date.month == d.month && l.date.day == d.day)
              .fold(0.0, (acc, item) => acc + item.totalCalories);
          return (date: d, calories: cals);
        }(),
    ];
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
    Id? id,
    required String name,
    required String portionUnit,
    required double estimatedGrams,
    required double calories,
    required double protein,
    double carbs = 0.0,
    double fat = 0.0,
    bool isSnack = false,
  }) async {
    final food = FoodItem()
      ..name = name.trim()
      ..portionUnit = portionUnit.trim()
      ..estimatedGrams = estimatedGrams
      ..calories = calories
      ..protein = protein
      ..carbs = carbs
      ..fat = fat
      ..isSnack = isSnack
      ..isCustom = true;
    if (id != null) food.id = id;

    await isar.writeTxn(() async {
      await isar.foodItems.put(food);
    });
  }

  static Future<void> deleteCustomFood(Id id) async {
    final logs = await isar.mealLogs
        .filter()
        .foodItem((q) => q.idEqualTo(id))
        .findAll();
    final logIds = logs.map((l) => l.id).toList();
    await isar.writeTxn(() async {
      if (logIds.isNotEmpty) {
        await isar.mealLogs.deleteAll(logIds);
      }
      await isar.foodItems.delete(id);
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
    final latest = await isar.weightLogs.where().sortByDateDesc().findFirst();
    if (latest != null) {
      final current = await getSettings();
      current.weight = latest.weight;
      await isar.writeTxn(() async {
        await isar.userSettings.put(current);
      });
    }
  }
}
