class RevenueTopChannel {
  final String channel;
  final double totalSales;
  final double sharePct;

  RevenueTopChannel({
    required this.channel,
    required this.totalSales,
    required this.sharePct,
  });

  factory RevenueTopChannel.fromJson(Map<String, dynamic> json) {
    return RevenueTopChannel(
      channel: json['channel'] as String,
      totalSales: (json['total_sales'] as num).toDouble(),
      sharePct: (json['share_pct'] as num).toDouble(),
    );
  }
}

class RevenueDailyPoint {
  final DateTime date;
  final double totalSales;
  final int totalOrders;

  RevenueDailyPoint({
    required this.date,
    required this.totalSales,
    required this.totalOrders,
  });

  factory RevenueDailyPoint.fromJson(Map<String, dynamic> json) {
    return RevenueDailyPoint(
      date: DateTime.parse(json['sale_date'] as String),
      totalSales: (json['total_sales'] as num).toDouble(),
      totalOrders: json['total_orders'] as int,
    );
  }
}

class RevenueOverviewResponse {
  final int storeId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalSales;
  final int totalOrders;
  final double averageTicket;
  final double salesChangePct;
  final double ordersChangePct;
  final List<RevenueTopChannel> topChannels;
  final List<RevenueDailyPoint> dailyBreakdown;

  RevenueOverviewResponse({
    required this.storeId,
    required this.startDate,
    required this.endDate,
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
      storeId: json['store_id'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalSales: (json['total_sales'] as num).toDouble(),
      totalOrders: json['total_orders'] as int,
      averageTicket: (json['average_ticket'] as num).toDouble(),
      salesChangePct: (json['sales_change_pct'] as num).toDouble(),
      ordersChangePct: (json['orders_change_pct'] as num).toDouble(),
      topChannels: (json['top_channels'] as List)
          .map((e) => RevenueTopChannel.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyBreakdown: (json['daily_breakdown'] as List)
          .map((e) => RevenueDailyPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
