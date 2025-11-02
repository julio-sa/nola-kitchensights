// lib/data/params/widget_params.dart

import 'package:flutter/foundation.dart';

@immutable
class RevenueOverviewParams {
  final int storeId;
  final DateTime startDate;
  final DateTime endDate;

  const RevenueOverviewParams({
    required this.storeId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RevenueOverviewParams &&
            other.storeId == storeId &&
            other.startDate == startDate &&
            other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(storeId, startDate, endDate);
}

@immutable
class StoreComparisonParams {
  final int storeA;
  final int storeB;
  final DateTime startDate;
  final DateTime endDate;

  const StoreComparisonParams({
    required this.storeA,
    required this.storeB,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoreComparisonParams &&
            other.storeA == storeA &&
            other.storeB == storeB &&
            other.startDate == startDate &&
            other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(storeA, storeB, startDate, endDate);
}

@immutable
class DeliveryHeatmapParams {
  final int storeId;
  final DateTime? startDate;
  final DateTime? endDate;

  const DeliveryHeatmapParams({
    required this.storeId,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeliveryHeatmapParams &&
            other.storeId == storeId &&
            other.startDate == startDate &&
            other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(storeId, startDate, endDate);
}

@immutable
class TopProductsParams {
  final int storeId;
  final String channel;
  final int dayOfWeek;
  final int hourStart;
  final int hourEnd;

  const TopProductsParams({
    required this.storeId,
    required this.channel,
    required this.dayOfWeek,
    required this.hourStart,
    required this.hourEnd,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TopProductsParams &&
            other.storeId == storeId &&
            other.channel == channel &&
            other.dayOfWeek == dayOfWeek &&
            other.hourStart == hourStart &&
            other.hourEnd == hourEnd;
  }

  @override
  int get hashCode =>
      Object.hash(storeId, channel, dayOfWeek, hourStart, hourEnd);
}
