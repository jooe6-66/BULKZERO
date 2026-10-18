import 'package:isar/isar.dart';

part 'user_settings.g.dart';

@collection
class UserSettings {
  Id id = 0; // Fixed ID for single-row local settings
  String name = '';
  double weight = 60.0; // kg
  double height = 170.0; // cm
  int age = 22;
  double targetCalories = 2500;
  double targetProtein = 140;
  bool isProfileCompleted = false;

  double get bmi {
    if (height <= 0) return 0;
    final hMeter = height / 100;
    return weight / (hMeter * hMeter);
  }

  String get bmiCategory {
    final val = bmi;
    if (val <= 0) return '-';
    if (val < 18.5) return 'Underweight (Kurang)';
    if (val < 25.0) return 'Normal (Ideal)';
    if (val < 30.0) return 'Overweight (Lebih)';
    return 'Obesitas';
  }
}
