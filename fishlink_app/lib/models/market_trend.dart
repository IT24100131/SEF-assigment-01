import 'package:json_annotation/json_annotation.dart';

part 'market_trend.g.dart';

@JsonSerializable()
class MarketTrend {
  final int id;
  final String fishType;
  final double currentPrice;
  final double previousPrice;
  final double priceChange;
  final double percentageChange;
  final String trend; // 'up', 'down', 'stable'
  final DateTime date;
  final String? location;

  MarketTrend({
    required this.id,
    required this.fishType,
    required this.currentPrice,
    required this.previousPrice,
    required this.priceChange,
    required this.percentageChange,
    required this.trend,
    required this.date,
    this.location,
  });

  factory MarketTrend.fromJson(Map<String, dynamic> json) => _$MarketTrendFromJson(json);
  Map<String, dynamic> toJson() => _$MarketTrendToJson(this);
}