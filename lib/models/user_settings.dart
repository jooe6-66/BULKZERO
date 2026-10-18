import 'package:isar/isar.dart';

part 'user_settings.g.dart';

@collection
class UserSettings {
  Id id = 0; // Fixed ID for single-row local settings
  double targetCalories = 2500;
  double targetProtein = 140;
}
