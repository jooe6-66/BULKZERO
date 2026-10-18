import 'package:isar/isar.dart';

part 'weight_log.g.dart';

@collection
class WeightLog {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime date;

  late double weight; // kg
}
