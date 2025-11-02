// lib/data/models/delivery_heatmap_response.dart

class DeliveryHeatmapResponse {
  final List<DeliveryRegion> regions;

  const DeliveryHeatmapResponse({required this.regions});

  factory DeliveryHeatmapResponse.fromJson(dynamic json) {
    if (json is List) {
      return DeliveryHeatmapResponse(
        regions:
            json.map<DeliveryRegion>((e) => DeliveryRegion.fromJson(e)).toList(),
      );
    }

    if (json is Map<String, dynamic>) {
      final list = (json['regions'] ?? json['data'] ?? []) as List;
      return DeliveryHeatmapResponse(
        regions:
            list.map<DeliveryRegion>((e) => DeliveryRegion.fromJson(e)).toList(),
      );
    }

    return const DeliveryHeatmapResponse(regions: []);
  }
}

class DeliveryRegion {
  final String neighborhood;
  final String city;
  final int deliveryCount;
  final double avgDeliveryMinutes;
  final double? p90DeliveryMinutes;
  final double? weekOverWeekChangePct;

  const DeliveryRegion({
    required this.neighborhood,
    required this.city,
    required this.deliveryCount,
    required this.avgDeliveryMinutes,
    this.p90DeliveryMinutes,
    this.weekOverWeekChangePct,
  });

  factory DeliveryRegion.fromJson(Map<String, dynamic> json) {
    // backend manda avg_delivery_seconds → convertemos pra minutos
    final seconds =
        (json['avg_delivery_seconds'] ?? json['avg_delivery_secs']) as num?;
    final minutesFromSeconds =
        seconds != null ? seconds.toDouble() / 60.0 : null;

    final minutesField =
        (json['avg_delivery_minutes'] ?? json['avgDeliveryMinutes']) as num?;

    final avgMinutes =
        (minutesField?.toDouble()) ??
            (minutesFromSeconds ?? 0.0);

    final p90Seconds =
        (json['p90_delivery_seconds'] ?? json['p90_delivery_secs']) as num?;
    final p90MinutesField =
        (json['p90_delivery_minutes'] ?? json['p90DeliveryMinutes']) as num?;
    final p90Minutes =
        (p90MinutesField?.toDouble()) ??
            (p90Seconds != null ? p90Seconds.toDouble() / 60.0 : null);

    return DeliveryRegion(
      neighborhood: (json['neighborhood'] ?? json['bairro'] ?? '') as String,
      city: (json['city'] ?? json['cidade'] ?? '') as String,
      deliveryCount:
          ((json['delivery_count'] ?? json['deliveryCount'] ?? 0) as num)
              .toInt(),
      avgDeliveryMinutes: avgMinutes,
      p90DeliveryMinutes: p90Minutes,
      weekOverWeekChangePct: _toNullableDouble(
          json['wow_change_pct'] ?? json['weekOverWeekChangePct']),
    );
  }

  static double? _toNullableDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
