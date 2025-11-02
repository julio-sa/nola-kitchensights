class StoreComparisonResponse {
  final List<StoreComparisonItem> stores;

  const StoreComparisonResponse({required this.stores});

  factory StoreComparisonResponse.fromJson(dynamic json) {
    if (json is List) {
      return StoreComparisonResponse(
        stores: json
            .map<StoreComparisonItem>(
                (e) => StoreComparisonItem.fromJson(e))
            .toList(),
      );
    }

    if (json is Map<String, dynamic>) {
      final list = (json['stores'] ?? json['data'] ?? []) as List;
      return StoreComparisonResponse(
        stores: list
            .map<StoreComparisonItem>(
                (e) => StoreComparisonItem.fromJson(e))
            .toList(),
      );
    }

    return const StoreComparisonResponse(stores: []);
  }
}

class StoreComparisonItem {
  final int storeId;
  final String storeName;
  final double totalSales;
  final int totalOrders;
  final double averageTicket;
  final double salesChangePct;
  final String? topChannel;
  final double? topChannelSharePct;

  const StoreComparisonItem({
    required this.storeId,
    required this.storeName,
    required this.totalSales,
    required this.totalOrders,
    required this.averageTicket,
    required this.salesChangePct,
    this.topChannel,
    this.topChannelSharePct,
  });

  factory StoreComparisonItem.fromJson(Map<String, dynamic> json) {
    return StoreComparisonItem(
      storeId: (json['store_id'] ?? json['storeId'] ?? 0) as int,
      storeName: (json['store_name'] ?? json['storeName'] ?? '') as String,
      totalSales:
          _toDouble(json['total_sales'] ?? json['totalSales'] ?? 0),
      totalOrders:
          ((json['total_orders'] ?? json['totalOrders'] ?? 0) as num).toInt(),
      averageTicket:
          _toDouble(json['average_ticket'] ?? json['averageTicket'] ?? 0),
      salesChangePct:
          _toDouble(json['sales_change_pct'] ?? json['salesChangePct'] ?? 0),
      topChannel: (json['top_channel'] ?? json['topChannel']) as String?,
      topChannelSharePct: _toNullableDouble(
          json['top_channel_share_pct'] ?? json['topChannelSharePct']),
    );
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static double? _toNullableDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
