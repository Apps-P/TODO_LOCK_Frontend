import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'todo_model.g.dart';


var uuid = Uuid();

@HiveType(typeId: 0)
class Todo extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String user_id;

  @HiveField(2)
  late DateTime date;

  @HiveField(3)
  late int no;

  @HiveField(4)
  late String content;

  @HiveField(5)
  late bool lock;

  @HiveField(6)
  late DateTime? checkTime;

  @HiveField(7)
  late Duration duration;

  @HiveField(8)
  late bool done;

  Todo({
    required this.content,
    required this.lock,
    required this.duration,
    this.done = false,
  }) : id = uuid.v4(), // UUID 자동 생성
       checkTime = null;
}
