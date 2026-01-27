// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JobAdapter extends TypeAdapter<Job> {
  @override
  final int typeId = 0;

  @override
  Job read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Job(
      content: fields[2] as String,
      lock: fields[3] as String,
      duration: fields[5] as Duration,
      done: fields[6] as bool,
    )
      ..id = fields[0] as String
      ..createdAt = fields[1] as DateTime
      ..checkTime = fields[4] as DateTime?;
  }

  @override
  void write(BinaryWriter writer, Job obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.lock)
      ..writeByte(4)
      ..write(obj.checkTime)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.done);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
