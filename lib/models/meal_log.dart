import 'package:isar/isar.dart';
import 'food_item.dart';

part 'meal_log.g.dart';

@collection
class MealLog {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime date;

  late String mealSession; // "Makan 1", "Makan 2", "Makan 3", "Camilan"

  late double portionMultiplier; // 0.5, 1.0, 1.5, 2.0, etc.

  final foodItem = IsarLink<FoodItem>();

  double get totalCalories => (foodItem.value?.calories ?? 0.0) * portionMultiplier;
  double get totalProtein => (foodItem.value?.protein ?? 0.0) * portionMultiplier;
  double get totalCarbs => (foodItem.value?.carbs ?? 0.0) * portionMultiplier;
  double get totalFat => (foodItem.value?.fat ?? 0.0) * portionMultiplier;
}
