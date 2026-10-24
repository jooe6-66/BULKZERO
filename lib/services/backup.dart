import 'dart:convert';

import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/user_settings.dart';
import '../models/weight_log.dart';

const backupVersion = 1;

typedef BackupData = ({
  UserSettings settings,
  List<FoodItem> foods,
  List<({MealLog log, int foodId})> mealLogs,
  List<WeightLog> weightLogs,
});

/// [mealLogs] must have their `foodItem` link loaded.
String encodeBackup({
  required UserSettings settings,
  required List<FoodItem> foods,
  required List<MealLog> mealLogs,
  required List<WeightLog> weightLogs,
}) {
  return jsonEncode({
    'app': 'bulkzero',
    'version': backupVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'settings': {
      'name': settings.name,
      'weight': settings.weight,
      'height': settings.height,
      'age': settings.age,
      'targetCalories': settings.targetCalories,
      'targetProtein': settings.targetProtein,
      'isProfileCompleted': settings.isProfileCompleted,
      'remindersEnabled': settings.remindersEnabled,
      'targetWeight': settings.targetWeight,
      'activityLevel': settings.activityLevel,
    },
    'foods': [
      for (final f in foods)
        {
          'id': f.id,
          'name': f.name,
          'portionUnit': f.portionUnit,
          'estimatedGrams': f.estimatedGrams,
          'calories': f.calories,
          'protein': f.protein,
          'carbs': f.carbs,
          'fat': f.fat,
          'isCustom': f.isCustom,
          'isSnack': f.isSnack,
        },
    ],
    'mealLogs': [
      for (final l in mealLogs)
        if (l.foodItem.value != null)
          {
            'date': l.date.toIso8601String(),
            'mealSession': l.mealSession,
            'portionMultiplier': l.portionMultiplier,
            'foodId': l.foodItem.value!.id,
          },
    ],
    'weightLogs': [
      for (final w in weightLogs) {'date': w.date.toIso8601String(), 'weight': w.weight},
    ],
  });
}

/// Parses and validates a backup file. Throws [FormatException] on any invalid content,
/// so callers can reject the file before touching the database.
BackupData decodeBackup(String source) {
  try {
    final root = jsonDecode(source) as Map<String, dynamic>;
    if (root['app'] != 'bulkzero' || root['version'] != backupVersion) {
      throw const FormatException('Bukan file backup BulkZero yang didukung');
    }
    double d(Object? v) => (v as num).toDouble();

    final s = root['settings'] as Map<String, dynamic>;
    final settings = UserSettings()
      ..name = s['name'] as String
      ..weight = d(s['weight'])
      ..height = d(s['height'])
      ..age = s['age'] as int
      ..targetCalories = d(s['targetCalories'])
      ..targetProtein = d(s['targetProtein'])
      ..isProfileCompleted = s['isProfileCompleted'] as bool
      ..remindersEnabled = s['remindersEnabled'] as bool? ?? false
      ..targetWeight = s['targetWeight'] != null ? d(s['targetWeight']) : 68.0
      ..activityLevel = s['activityLevel'] as int? ?? 1;

    final foods = [
      for (final f in (root['foods'] as List).cast<Map<String, dynamic>>())
        FoodItem()
          ..id = f['id'] as int
          ..name = f['name'] as String
          ..portionUnit = f['portionUnit'] as String
          ..estimatedGrams = d(f['estimatedGrams'])
          ..calories = d(f['calories'])
          ..protein = d(f['protein'])
          ..carbs = d(f['carbs'])
          ..fat = d(f['fat'])
          ..isCustom = f['isCustom'] as bool
          ..isSnack = f['isSnack'] as bool,
    ];
    final foodIds = {for (final f in foods) f.id};

    final mealLogs = [
      for (final l in (root['mealLogs'] as List).cast<Map<String, dynamic>>())
        (
          log: MealLog()
            ..date = DateTime.parse(l['date'] as String)
            ..mealSession = l['mealSession'] as String
            ..portionMultiplier = d(l['portionMultiplier']),
          foodId: l['foodId'] as int,
        ),
    ];
    if (mealLogs.any((e) => !foodIds.contains(e.foodId))) {
      throw const FormatException('Log makan merujuk makanan yang tidak ada');
    }

    final weightLogs = [
      for (final w in (root['weightLogs'] as List).cast<Map<String, dynamic>>())
        WeightLog()
          ..date = DateTime.parse(w['date'] as String)
          ..weight = d(w['weight']),
    ];

    return (settings: settings, foods: foods, mealLogs: mealLogs, weightLogs: weightLogs);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('File backup rusak atau tidak valid');
  }
}
