// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChannelAdapter extends TypeAdapter<Channel> {
  @override
  final int typeId = 0;

  @override
  Channel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Channel(
      id: fields[0] as String,
      name: fields[1] as String,
      streamUrl: fields[2] as String,
      logoUrl: fields[3] as String,
      groupTitle: fields[4] as String,
      tvgId: fields[5] as String?,
      isHttpStream: fields[6] as bool,
      // MIGRAÇÃO SEGURA: Se o utilizador tiver uma versão antiga do app,
      // o campo 7 será nulo. O operador '?? false' evita o crash!
      isFavorite: (fields[7] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Channel obj) {
    writer
      ..writeByte(8) // Agora escrevemos 8 campos no total (0 a 7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.streamUrl)
      ..writeByte(3)
      ..write(obj.logoUrl)
      ..writeByte(4)
      ..write(obj.groupTitle)
      ..writeByte(5)
      ..write(obj.tvgId)
      ..writeByte(6)
      ..write(obj.isHttpStream)
      ..writeByte(7) // Novo slot mapeado para Favoritos
      ..write(obj.isFavorite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
