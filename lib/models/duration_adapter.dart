// lib/models/duration_adapter.dart


import 'package:hive/hive.dart';

/// duration type을 hive에 저장할 수 있게 변환
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 100; 

  @override
  Duration read(BinaryReader reader) {
    final milliseconds = reader.readInt();
    return Duration(milliseconds: milliseconds);
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMilliseconds);
  }
}