class DeliveryHeatmapResponse {
  final int storeId;
  final List<DeliveryRegionInsight> regions;

  DeliveryHeatmapResponse({
    required this.storeId,
    required this.regions,
  });

  factory DeliveryHeatmapResponse.fromJson(Map<String, dynamic> json) {
    return DeliveryHeatmapResponse(
      storeId: json['store_id'],
      regions: (json['regions'] as List)
          .map((e) => DeliveryRegionInsight.fromJson(e))
          .toList(),
    );
  }
}

class DeliveryRegionInsight {
  final String neighborhood;
  final String city;
  final int deliveryCount;
  final double avgDeliveryMinutes;
  final double p90DeliveryMinutes;
  final double? weekOverWeekChangePct;

  DeliveryRegionInsight({
    required this.neighborhood,
    required this.city,
    required this.deliveryCount,
    required this.avgDeliveryMinutes,
    required this.p90DeliveryMinutes,
    this.weekOverWeekChangePct,
  });

  factory DeliveryRegionInsight.fromJson(Map<String, dynamic> json) {
    return DeliveryRegionInsight(
      neighborhood: json['neighborhood'],
      city: json['city'],
      deliveryCount: json['delivery_count'],
      avgDeliveryMinutes: json['avg_delivery_minutes'].toDouble(),
      p90DeliveryMinutes: json['p90_delivery_minutes'].toDouble(),
      weekOverWeekChangePct: json['week_over_week_change_pct']?.toDouble(),
    );
  }
}