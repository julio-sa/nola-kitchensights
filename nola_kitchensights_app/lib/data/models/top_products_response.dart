class TopProductsResponse {
  final int storeId;
  final String channel;
  final int dayOfWeek;
  final int hourStart;
  final int hourEnd;
  final List<TopProductItem> products;

  TopProductsResponse({
    required this.storeId,
    required this.channel,
    required this.dayOfWeek,
    required this.hourStart,
    required this.hourEnd,
    required this.products,
  });

  factory TopProductsResponse.fromJson(Map<String, dynamic> json) {
    return TopProductsResponse(
      storeId: json['store_id'],
      channel: json['channel'],
      dayOfWeek: json['day_of_week'],
      hourStart: json['hour_start'],
      hourEnd: json['hour_end'],
      products: (json['products'] as List)
          .map((e) => TopProductItem.fromJson(e))
          .toList(),
    );
  }
}

class TopProductItem {
  final String productName;
  final int totalQuantitySold;
  final double totalRevenue;
  final double percentageOfTotal;
  final double? weekOverWeekChangePct;

  TopProductItem({
    required this.productName,
    required this.totalQuantitySold,
    required this.totalRevenue,
    required this.percentageOfTotal,
    this.weekOverWeekChangePct,
  });

  factory TopProductItem.fromJson(Map<String, dynamic> json) {
    return TopProductItem(
      productName: json['product_name'],
      totalQuantitySold: json['total_quantity_sold'],
      totalRevenue: json['total_revenue'].toDouble(),
      percentageOfTotal: json['percentage_of_total'].toDouble(),
      weekOverWeekChangePct: json['week_over_week_change_pct']?.toDouble(),
    );
  }
}