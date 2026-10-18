import 'package:isar/isar.dart';

part 'food_item.g.dart';

@collection
class FoodItem {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  late String portionUnit; // e.g. "centong", "potong sedang", "butir"
  late double estimatedGrams;
  late double calories;
  late double protein;
  double carbs = 0.0;
  double fat = 0.0;
  bool isCustom = false;
}
