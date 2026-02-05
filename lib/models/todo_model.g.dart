// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TodoAdapter extends TypeAdapter<Todo> {
  @override
  final int typeId = 0;

  @override
  Todo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Todo(
      content: fields[4] as String,
      lock: fields[5] as bool,
      duration: fields[7] as Duration,
      done: fields[8] as bool,
    )
      ..id = fields[0] as String
      ..user_id = fields[1] as String
      ..date = fields[2] as DateTime
      ..no = fields[3] as int
      ..checkTime = fields[6] as DateTime?;
  }

  @override
  void write(BinaryWriter writer, Todo obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.user_id)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.no)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.lock)
      ..writeByte(6)
      ..write(obj.checkTime)
      ..writeByte(7)
      ..write(obj.duration)
      ..writeByte(8)
      ..write(obj.done);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
