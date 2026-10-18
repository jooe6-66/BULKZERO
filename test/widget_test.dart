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
}
