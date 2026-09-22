// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Catch _$CatchFromJson(Map<String, dynamic> json) => Catch(
  id: (json['id'] as num?)?.toInt(),
  fishType: json['fishType'] as String,
  quantity: (json['quantity'] as num).toDouble(),
  pricePerKg: (json['pricePerKg'] as num).toDouble(),
  location: json['location'] as String,
  catchDate: DateTime.parse(json['catchDate'] as String),
  status: json['status'] as String? ?? 'Available',
  description: json['description'] as String?,
  quality: json['quality'] as String?,
  fishermanId: (json['fishermanId'] as num?)?.toInt(),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$CatchToJson(Catch instance) => <String, dynamic>{
  'id': instance.id,
  'fishType': instance.fishType,
  'quantity': instance.quantity,
  'pricePerKg': instance.pricePerKg,
  'location': instance.location,
  'catchDate': instance.catchDate.toIso8601String(),
  'status': instance.status,
  'description': instance.description,
  'quality': instance.quality,
  'fishermanId': instance.fishermanId,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
