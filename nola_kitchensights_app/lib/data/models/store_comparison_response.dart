class StoreComparisonStore {
  final int storeId;
  final String storeName;
  final double totalSales;
  final int totalOrders;
  final double averageTicket;
  final double salesChangePct;
  final String? topChannel;
  final double? topChannelSharePct;

  StoreComparisonStore({
    required this.storeId,
    required this.storeName,
    required this.totalSales,
    required this.totalOrders,
    required this.averageTicket,
    required this.salesChangePct,
    this.topChannel,
    this.topChannelSharePct,
  });

  factory StoreComparisonStore.fromJson(Map<String, dynamic> json) {
    return StoreComparisonStore(
      storeId: json['store_id'] as int,
      storeName: json['store_name'] as String,
      totalSales: (json['total_sales'] as num).toDouble(),
      totalOrders: json['total_orders'] as int,
      averageTicket: (json['average_ticket'] as num).toDouble(),
      salesChangePct: (json['sales_change_pct'] as num).toDouble(),
      topChannel: json['top_channel'] as String?,
      topChannelSharePct: (json['top_channel_share_pct'] as num?)?.toDouble(),
    );
  }
}

class StoreComparisonResponse {
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<StoreComparisonStore> stores;

  StoreComparisonResponse({
    required this.periodStart,
    required this.periodEnd,
    required this.stores,
  });

  factory StoreComparisonResponse.fromJson(Map<String, dynamic> json) {
    return StoreComparisonResponse(
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      stores: (json['stores'] as List)
          .map((e) => StoreComparisonStore.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
