import 'package:json_annotation/json_annotation.dart';

part 'catch.g.dart';

@JsonSerializable()
class Catch {
  final int? id;
  final String fishType;
  final double quantity;
  final double pricePerKg;
  final String location;
  final DateTime catchDate;
  final String status;
  final String? description;
  final String? quality;
  final int? fishermanId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Catch({
    this.id,
    required this.fishType,
    required this.quantity,
    required this.pricePerKg,
    required this.location,
    required this.catchDate,
    this.status = 'Available',
    this.description,
    this.quality,
    this.fishermanId,
    this.createdAt,
    this.updatedAt,
  });

  factory Catch.fromJson(Map<String, dynamic> json) => _$CatchFromJson(json);
  Map<String, dynamic> toJson() => _$CatchToJson(this);

  double get totalValue => quantity * pricePerKg;
}