import 'package:flutter_test/flutter_test.dart';
import 'package:bulking_tracker/models/food_item.dart';
import 'package:bulking_tracker/models/meal_log.dart';
import 'package:bulking_tracker/models/user_settings.dart';
import 'package:bulking_tracker/models/weight_log.dart';
import 'package:bulking_tracker/services/backup.dart';
import 'package:bulking_tracker/data/dkpi_foods.dart';
import 'package:bulking_tracker/main.dart' show sessionForHour;

void main() {
  test('URT portion multiplier calculation check', () {
    final chicken = FoodItem()
      ..name = 'Dada Ayam'
      ..portionUnit = 'potong sedang'
      ..estimatedGrams = 100
      ..calories = 165
      ..protein = 31;

    final log = MealLog()
      ..date = DateTime.now()
      ..mealSession = 'Makan 1'
      ..portionMultiplier = 1.5;
    log.foodItem.value = chicken;

    expect(log.totalCalories, 247.5);
    expect(log.totalProtein, 46.5);
    expect(chicken.estimatedGrams * log.portionMultiplier, 150.0);
  });

  test('Default session follows time of day', () {
    expect(sessionForHour(7), 'Makan 1');
    expect(sessionForHour(12), 'Makan 2');
    expect(sessionForHour(16), 'Camilan');
    expect(sessionForHour(20), 'Makan 3');
  });

  test('DKPI foods are split into meals and snacks', () {
    final foods = dkpiFoods();
    bool snack(String name) => foods.firstWhere((f) => f.name == name).isSnack;
    expect(snack('Nasi Putih'), isFalse);
    expect(snack('Pisang Ambon'), isTrue);
    expect(snack('Susu Whey Protein'), isTrue);
  });

  test('Backup encode and decode round-trip', () {
    final settings = UserSettings()
      ..name = 'Budi'
      ..weight = 65
      ..targetWeight = 72
      ..height = 172
      ..age = 24
      ..activityLevel = 2
      ..targetCalories = 2800
      ..targetProtein = 150
      ..isProfileCompleted = true
      ..remindersEnabled = true;

    final food = FoodItem()
      ..id = 7
      ..name = 'Telur Rebus'
      ..portionUnit = 'butir'
      ..estimatedGrams = 50
      ..calories = 77
      ..protein = 6.3
      ..isSnack = false
      ..isCustom = false;

    final meal = MealLog()
      ..date = DateTime(2026, 10, 25, 8, 0)
      ..mealSession = 'Makan 1'
      ..portionMultiplier = 2.0;
    meal.foodItem.value = food;

    final weight = WeightLog()
      ..date = DateTime(2026, 10, 25)
      ..weight = 65.4;

    final jsonStr = encodeBackup(
      settings: settings,
      foods: [food],
      mealLogs: [meal],
      weightLogs: [weight],
    );

    final decoded = decodeBackup(jsonStr);
    expect(decoded.settings.name, 'Budi');
    expect(decoded.settings.targetWeight, 72);
    expect(decoded.settings.activityLevel, 2);
    expect(decoded.settings.remindersEnabled, isTrue);
    expect(decoded.foods.single.name, 'Telur Rebus');
    expect(decoded.mealLogs.single.foodId, 7);
    expect(decoded.mealLogs.single.log.portionMultiplier, 2.0);
    expect(decoded.weightLogs.single.weight, 65.4);
  });
}
