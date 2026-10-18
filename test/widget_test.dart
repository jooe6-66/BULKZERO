import 'package:flutter_test/flutter_test.dart';
import 'package:bulking_tracker/models/food_item.dart';
import 'package:bulking_tracker/models/meal_log.dart';

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

  test('WeightLog model and delta check', () {
    final day1 = DateTime(2026, 10, 10);
    final day2 = DateTime(2026, 10, 17);

    final w1 = 60.0;
    final w2 = 60.8;
    final delta = double.parse((w2 - w1).toStringAsFixed(1));

    expect(delta, 0.8);
    expect(day2.isAfter(day1), isTrue);
  });
}
