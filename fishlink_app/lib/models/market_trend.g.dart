// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market_trend.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MarketTrend _$MarketTrendFromJson(Map<String, dynamic> json) => MarketTrend(
  id: (json['id'] as num).toInt(),
  fishType: json['fishType'] as String,
  currentPrice: (json['currentPrice'] as num).toDouble(),
  previousPrice: (json['previousPrice'] as num).toDouble(),
  priceChange: (json['priceChange'] as num).toDouble(),
  percentageChange: (json['percentageChange'] as num).toDouble(),
  trend: json['trend'] as String,
  date: DateTime.parse(json['date'] as String),
  location: json['location'] as String?,
);

Map<String, dynamic> _$MarketTrendToJson(MarketTrend instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fishType': instance.fishType,
      'currentPrice': instance.currentPrice,
      'previousPrice': instance.previousPrice,
      'priceChange': instance.priceChange,
      'percentageChange': instance.percentageChange,
      'trend': instance.trend,
      'date': instance.date.toIso8601String(),
      'location': instance.location,
    };
