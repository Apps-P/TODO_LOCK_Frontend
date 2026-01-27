import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'job_model.g.dart';

var uuid = Uuid();

@HiveType(typeId: 0)
class Job extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late DateTime createdAt;

  @HiveField(2)
  late String content;

  @HiveField(3)
  late bool lock;

  @HiveField(4)
  late DateTime? checkTime;

  @HiveField(5)
  late Duration duration;

  @HiveField(6)
  late bool done;

  Job({
    required this.content,
    required this.lock,
    required this.duration,
    this.done = false,
  }) : id = uuid.v4(), // UUID 자동 생성
       createdAt = DateTime.now(), // 현재 시각 자동 설정
       checkTime = null;
}
