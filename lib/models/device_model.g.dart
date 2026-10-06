// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedDeviceAdapter extends TypeAdapter<SavedDevice> {
  @override
  final int typeId = 0;

  @override
  SavedDevice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedDevice(
      id: fields[0] as String,
      name: fields[1] as String,
      firstSeen: fields[2] as DateTime,
      lastSeen: fields[3] as DateTime,
      autoAcceptImages: fields[4] as bool,
      nickname: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedDevice obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.firstSeen)
      ..writeByte(3)
      ..write(obj.lastSeen)
      ..writeByte(4)
      ..write(obj.autoAcceptImages)
      ..writeByte(5)
      ..write(obj.nickname);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedDeviceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BlockedDeviceAdapter extends TypeAdapter<BlockedDevice> {
  @override
  final int typeId = 1;

  @override
  BlockedDevice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlockedDevice(
      id: fields[0] as String,
      name: fields[1] as String,
      blockedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BlockedDevice obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.blockedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedDeviceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
