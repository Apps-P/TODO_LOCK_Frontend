import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'job_model.dart';

@HiveType(typeId: 1) // Job이 0번이므로 1번 부여
class DailyPlan extends HiveObject {
  @HiveField(0)
  late String dateKey; // '2026-01-27' 형식 (조회 및 식별용)

  @HiveField(1)
  late List<Job> jobs; // 해당 날짜의 작업 리스트

  @HiveField(2)
  bool isTargetAchieved; // 하루 목표 달성 여부 (선택 사항)

  DailyPlan({
    required this.dateKey,
    required this.jobs,
    this.isTargetAchieved = false,
  });
}