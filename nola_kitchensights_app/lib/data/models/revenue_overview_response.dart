class RevenueOverviewResponse {
  final double totalSales;
  final int totalOrders;
  final double averageTicket;
  final double salesChangePct;
  final double ordersChangePct;
  final List<TopChannel> topChannels;
  final List<DailyBreakdown> dailyBreakdown;

  const RevenueOverviewResponse({
    required this.totalSales,
    required this.totalOrders,
    required this.averageTicket,
    required this.salesChangePct,
    required this.ordersChangePct,
    required this.topChannels,
    required this.dailyBreakdown,
  });

  factory RevenueOverviewResponse.fromJson(Map<String, dynamic> json) {
    return RevenueOverviewResponse(
      totalSales: _toDouble(json['total_sales'] ?? json['totalSales'] ?? 0),
      totalOrders: (json['total_orders'] ?? json['totalOrders'] ?? 0) as int,
      averageTicket:
          _toDouble(json['average_ticket'] ?? json['averageTicket'] ?? 0),
      salesChangePct:
          _toDouble(json['sales_change_pct'] ?? json['salesChangePct'] ?? 0),
      ordersChangePct:
          _toDouble(json['orders_change_pct'] ?? json['ordersChangePct'] ?? 0),
      topChannels: (json['top_channels'] ?? json['topChannels'] ?? [])
          .map<TopChannel>(
              (e) => TopChannel.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyBreakdown: (json['daily_breakdown'] ?? json['dailyBreakdown'] ?? [])
          .map<DailyBreakdown>(
              (e) => DailyBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class TopChannel {
  final String channel;
  final double totalSales;
  final double sharePct;

  const TopChannel({
    required this.channel,
    required this.totalSales,
    required this.sharePct,
  });

  factory TopChannel.fromJson(Map<String, dynamic> json) {
    return TopChannel(
      channel: (json['channel'] ?? json['name'] ?? '') as String,
      totalSales: RevenueOverviewResponse._toDouble(
          json['total_sales'] ?? json['totalSales'] ?? 0),
      sharePct: RevenueOverviewResponse._toDouble(
          json['share_pct'] ?? json['sharePct'] ?? 0),
    );
  }
}

class DailyBreakdown {
  final String saleDate;
  final double totalSales;
  final int totalOrders;

  const DailyBreakdown({
    required this.saleDate,
    required this.totalSales,
    required this.totalOrders,
  });

  factory DailyBreakdown.fromJson(Map<String, dynamic> json) {
    return DailyBreakdown(
      saleDate: (json['sale_date'] ?? json['saleDate'] ?? '') as String,
      totalSales: RevenueOverviewResponse._toDouble(
          json['total_sales'] ?? json['totalSales'] ?? 0),
      totalOrders: (json['total_orders'] ?? json['totalOrders'] ?? 0) as int,
    );
  }
}
