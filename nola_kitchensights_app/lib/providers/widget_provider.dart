// lib/providers/widget_provider.dart

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:nola_kitchensights_app/data/params/widget_params.dart';

const String _baseUrl = 'http://localhost:8000/api/v1/widgets';

final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

Uri _buildUri(String endpoint, [Map<String, String>? query]) {
  final uri = Uri.parse('$_baseUrl/$endpoint');
  if (query == null) return uri;
  return uri.replace(queryParameters: query);
}

/// GET que espera MAP
Future<Map<String, dynamic>> _getJson(
  Ref ref,
  String endpoint, [
  Map<String, String>? query,
]) async {
  final client = ref.read(httpClientProvider);
  final resp = await client.get(_buildUri(endpoint, query));
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    final body = jsonDecode(resp.body);
    if (body is Map<String, dynamic>) {
      return body;
    }
    // se vier lista por engano, embrulha
    if (body is List) {
      return {'data': body};
    }
  }
  throw Exception('Erro ${resp.statusCode} ao chamar $endpoint: ${resp.body}');
}

/// GET que espera LIST
Future<List<dynamic>> _getList(
  Ref ref,
  String endpoint, [
  Map<String, String>? query,
]) async {
  final client = ref.read(httpClientProvider);
  final resp = await client.get(_buildUri(endpoint, query));
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    final body = jsonDecode(resp.body);
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      return (body['data'] as List?) ?? <dynamic>[];
    }
  }
  throw Exception('Erro ${resp.statusCode} ao chamar $endpoint: ${resp.body}');
}

/// tenta descobrir uma loja que realmente tem dado de entrega/venda
Future<int?> _getFirstAvailableStoreId(Ref ref) async {
  try {
    final list = await _getList(ref, 'available-stores');
    if (list.isEmpty) return null;
    final first = list.first;
    if (first is Map<String, dynamic>) {
      final id = first['store_id'] ?? first['id'];
      if (id is int) return id;
      if (id is num) return id.toInt();
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// devolve o mês cheio ANTERIOR ao mês atual
Map<String, String> _previousFullMonthRange() {
  final now = DateTime.now();
  final currentMonthStart = DateTime(now.year, now.month, 1);
  final prevMonthEnd = currentMonthStart.subtract(const Duration(days: 1));
  final prevMonthStart = DateTime(prevMonthEnd.year, prevMonthEnd.month, 1);
  return {
    'start_date':
        '${prevMonthStart.year.toString().padLeft(4, '0')}-${prevMonthStart.month.toString().padLeft(2, '0')}-01',
    'end_date':
        '${prevMonthEnd.year.toString().padLeft(4, '0')}-${prevMonthEnd.month.toString().padLeft(2, '0')}-${prevMonthEnd.day.toString().padLeft(2, '0')}',
  };
}

/// helpers de parse seguros
double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime _asDateOrNow(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is String && v.isNotEmpty) {
    return DateTime.parse(v);
  }
  return DateTime.now();
}

/// =========================
/// MODELS
/// =========================

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
      productName: (json['product_name'] ??
              json['productName'] ??
              json['name'] ??
              'Produto') as String,
      totalQuantitySold: _asInt(json['total_quantity_sold'] ??
          json['total_quantity'] ??
          json['totalQuantity'] ??
          0),
      totalRevenue: _asDouble(
          json['total_revenue'] ?? json['totalRevenue'] ?? json['revenue']),
      percentageOfTotal: _asDouble(
          json['percentage_of_total'] ?? json['pct_of_total'] ?? 0.0),
      weekOverWeekChangePct: json['week_over_week_change_pct'] != null
          ? _asDouble(json['week_over_week_change_pct'])
          : (json['wow_change_pct'] != null
              ? _asDouble(json['wow_change_pct'])
              : null),
    );
  }
}

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
    final list = (json['products'] as List<dynamic>? ?? [])
        .map((e) => TopProductItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return TopProductsResponse(
      storeId: _asInt(json['store_id']),
      channel: (json['channel'] ?? 'ALL') as String,
      dayOfWeek: _asInt(json['day_of_week']),
      hourStart: _asInt(json['hour_start']),
      hourEnd: _asInt(json['hour_end'] ?? 23),
      products: list,
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
    final seconds =
        (json['avg_delivery_seconds'] ?? json['avg_delivery_secs']) as num?;
    final minutesFromSeconds =
        seconds != null ? seconds.toDouble() / 60.0 : null;

    final minutesField =
        (json['avg_delivery_minutes'] ?? json['avgDeliveryMinutes']) as num?;

    final avgMinutes =
        (minutesField != null ? minutesField.toDouble() : null) ??
            (minutesFromSeconds ?? 0.0);

    final p90Seconds =
        (json['p90_delivery_seconds'] ?? json['p90_delivery_secs']) as num?;
    final p90MinutesField =
        (json['p90_delivery_minutes'] ?? json['p90DeliveryMinutes']) as num?;
    final p90Minutes =
        (p90MinutesField != null ? p90MinutesField.toDouble() : null) ??
            (p90Seconds != null ? p90Seconds.toDouble() / 60.0 : 0.0);

    return DeliveryRegionInsight(
      neighborhood: (json['neighborhood'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      deliveryCount: _asInt(json['delivery_count']),
      avgDeliveryMinutes: avgMinutes,
      p90DeliveryMinutes: p90Minutes,
      weekOverWeekChangePct: json['week_over_week_change_pct'] != null
          ? _asDouble(json['week_over_week_change_pct'])
          : (json['wow_change_pct'] != null
              ? _asDouble(json['wow_change_pct'])
              : null),
    );
  }
}

class DeliveryHeatmapResponse {
  final int storeId;
  final String? periodStart;
  final String? periodEnd;
  final List<DeliveryRegionInsight> regions;

  DeliveryHeatmapResponse({
    required this.storeId,
    this.periodStart,
    this.periodEnd,
    required this.regions,
  });

  factory DeliveryHeatmapResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['regions'] as List<dynamic>? ?? [])
        .map((e) => DeliveryRegionInsight.fromJson(e as Map<String, dynamic>))
        .toList();
    return DeliveryHeatmapResponse(
      storeId: _asInt(json['store_id']),
      periodStart: json['period_start'] as String?,
      periodEnd: json['period_end'] as String?,
      regions: list,
    );
  }
}

class AtRiskCustomer {
  final String customerName;
  final int? customerId;
  final int totalOrders;
  final String lastOrderDate;
  final int daysSinceLastOrder;

  AtRiskCustomer({
    required this.customerName,
    required this.customerId,
    required this.totalOrders,
    required this.lastOrderDate,
    required this.daysSinceLastOrder,
  });

  factory AtRiskCustomer.fromJson(Map<String, dynamic> json) {
    return AtRiskCustomer(
      customerName: (json['customer_name'] ?? 'Cliente') as String,
      customerId: json['customer_id'] as int?,
      totalOrders: _asInt(json['total_orders']),
      lastOrderDate: (json['last_order_date'] ?? '') as String,
      daysSinceLastOrder: _asInt(json['days_since_last_order']),
    );
  }
}

class AtRiskCustomersResponse {
  final int storeId;
  final List<AtRiskCustomer> customers;

  AtRiskCustomersResponse({
    required this.storeId,
    required this.customers,
  });

  factory AtRiskCustomersResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['customers'] as List<dynamic>? ?? [])
        .map((e) => AtRiskCustomer.fromJson(e as Map<String, dynamic>))
        .toList();
    return AtRiskCustomersResponse(
      storeId: _asInt(json['store_id']),
      customers: list,
    );
  }
}

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
      channel: (json['channel'] ?? json['name'] ?? '') as String,
      totalSales: _asDouble(json['total_sales'] ?? json['totalSales']),
      sharePct: _asDouble(json['share_pct'] ?? json['sharePct']),
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
    // se por algum motivo vier sem sale_date, não vamos quebrar
    final rawDate = json['sale_date'] ?? json['date'];
    final dt = rawDate != null && rawDate is String && rawDate.isNotEmpty
        ? DateTime.parse(rawDate)
        : DateTime.now();
    return RevenueDailyPoint(
      date: dt,
      totalSales: _asDouble(json['total_sales'] ?? json['totalSales']),
      totalOrders: _asInt(json['total_orders'] ?? json['totalOrders']),
    );
  }
}

class RevenueOverviewResponse {
  final int storeId;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalSales;
  final int totalOrders;
  final double averageTicket;
  final double salesChangePct;
  final double ordersChangePct;
  final List<RevenueTopChannel> topChannels;
  final List<RevenueDailyPoint> dailyBreakdown;

  RevenueOverviewResponse({
    required this.storeId,
    this.startDate,
    this.endDate,
    required this.totalSales,
    required this.totalOrders,
    required this.averageTicket,
    required this.salesChangePct,
    required this.ordersChangePct,
    required this.topChannels,
    required this.dailyBreakdown,
  });

  factory RevenueOverviewResponse.fromJson(Map<String, dynamic> json) {
    final channels = (json['top_channels'] as List<dynamic>? ?? [])
        .map((e) => RevenueTopChannel.fromJson(e as Map<String, dynamic>))
        .toList();
    final daily = (json['daily_breakdown'] as List<dynamic>? ?? [])
        .map((e) => RevenueDailyPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return RevenueOverviewResponse(
      storeId: _asInt(json['store_id']),
      startDate: json['start_date'] != null && json['start_date'] != ''
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null && json['end_date'] != ''
          ? DateTime.parse(json['end_date'] as String)
          : null,
      totalSales: _asDouble(json['total_sales'] ?? json['totalSales']),
      totalOrders: _asInt(json['total_orders'] ?? json['totalOrders']),
      averageTicket:
          _asDouble(json['average_ticket'] ?? json['averageTicket']),
      salesChangePct:
          _asDouble(json['sales_change_pct'] ?? json['salesChangePct']),
      ordersChangePct:
          _asDouble(json['orders_change_pct'] ?? json['ordersChangePct']),
      topChannels: channels,
      dailyBreakdown: daily,
    );
  }
}

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
    final id = _asInt(json['store_id'] ?? json['storeId']);
    // 🔥 AQUI é a mudança: tentamos vários nomes antes de cair no "Loja XX"
    final rawName = (json['store_name'] ??
            json['storeName'] ??
            json['name'] ??
            json['location'] ??
            json['store'] ??
            '')
        .toString()
        .trim();

    final finalName =
        rawName.isNotEmpty ? rawName : 'Loja ${id.toString().padLeft(2, '0')}';

    return StoreComparisonStore(
      storeId: id,
      storeName: finalName,
      totalSales: _asDouble(json['total_sales'] ?? json['totalSales']),
      totalOrders: _asInt(json['total_orders'] ?? json['totalOrders']),
      averageTicket:
          _asDouble(json['average_ticket'] ?? json['averageTicket']),
      salesChangePct:
          _asDouble(json['sales_change_pct'] ?? json['salesChangePct']),
      topChannel: (json['top_channel'] ?? json['topChannel']) as String?,
      topChannelSharePct: json['top_channel_share_pct'] != null
          ? _asDouble(json['top_channel_share_pct'])
          : (json['topChannelSharePct'] != null
              ? _asDouble(json['topChannelSharePct'])
              : null),
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
    final list = (json['stores'] as List<dynamic>? ?? [])
        .map((e) => StoreComparisonStore.fromJson(e as Map<String, dynamic>))
        .toList();
    // às vezes o backend não manda period_start/period_end
    final ps = json['period_start'];
    final pe = json['period_end'];
    return StoreComparisonResponse(
      periodStart: ps != null && ps is String && ps.isNotEmpty
          ? DateTime.parse(ps)
          : DateTime.now(),
      periodEnd: pe != null && pe is String && pe.isNotEmpty
          ? DateTime.parse(pe)
          : DateTime.now(),
      stores: list,
    );
  }
}

/// =========================
/// PROVIDERS
/// =========================

final topProductsProvider = FutureProvider.family<TopProductsResponse,
    TopProductsParams>((ref, params) async {
  // 1ª tentativa com a loja pedida
  Map<String, dynamic> json = await _getJson(ref, 'top-products', {
    'store_id': params.storeId.toString(),
    'channel': params.channel,
    'day_of_week': params.dayOfWeek.toString(),
    'hour_start': params.hourStart.toString(),
    'hour_end': params.hourEnd.toString(),
  });
  var resp = TopProductsResponse.fromJson(json);

  // se não veio nada, tenta descobrir uma loja com dados
  if (resp.products.isEmpty) {
    final fallbackStore = await _getFirstAvailableStoreId(ref);
    if (fallbackStore != null && fallbackStore != params.storeId) {
      json = await _getJson(ref, 'top-products', {
        'store_id': fallbackStore.toString(),
        'channel': params.channel,
        'day_of_week': params.dayOfWeek.toString(),
        'hour_start': params.hourStart.toString(),
        'hour_end': params.hourEnd.toString(),
      });
      resp = TopProductsResponse.fromJson(json);
    }
  }
  return resp;
});

final deliveryHeatmapProvider = FutureProvider.family<
    DeliveryHeatmapResponse, DeliveryHeatmapParams>((ref, params) async {
  // 1ª chamada com a loja pedida
  final qp = {
    'store_id': params.storeId.toString(),
  };
  if (params.startDate != null) {
    qp['start_date'] = params.startDate!.toIso8601String().split('T').first;
  }
  if (params.endDate != null) {
    qp['end_date'] = params.endDate!.toIso8601String().split('T').first;
  }
  Map<String, dynamic> json = await _getJson(ref, 'delivery-heatmap', qp);
  var resp = DeliveryHeatmapResponse.fromJson(json);

  if (resp.regions.isEmpty) {
    // tenta com uma loja que tem delivery
    final fallbackStore = await _getFirstAvailableStoreId(ref);
    if (fallbackStore != null && fallbackStore != params.storeId) {
      final qp2 = {
        'store_id': fallbackStore.toString(),
      };
      if (params.startDate != null) {
        qp2['start_date'] =
            params.startDate!.toIso8601String().split('T').first;
      }
      if (params.endDate != null) {
        qp2['end_date'] = params.endDate!.toIso8601String().split('T').first;
      }
      json = await _getJson(ref, 'delivery-heatmap', qp2);
      resp = DeliveryHeatmapResponse.fromJson(json);
    }
  }

  return resp;
});

final atRiskCustomersProvider =
    FutureProvider.family<AtRiskCustomersResponse, int>((ref, storeId) async {
  Map<String, dynamic> json =
      await _getJson(ref, 'at-risk-customers', {'store_id': '$storeId'});
  var resp = AtRiskCustomersResponse.fromJson(json);

  if (resp.customers.isEmpty) {
    final fallbackStore = await _getFirstAvailableStoreId(ref);
    if (fallbackStore != null && fallbackStore != storeId) {
      json = await _getJson(ref, 'at-risk-customers', {
        'store_id': fallbackStore.toString(),
      });
      resp = AtRiskCustomersResponse.fromJson(json);
    }
  }

  return resp;
});

final revenueOverviewProvider = FutureProvider.family<
    RevenueOverviewResponse, RevenueOverviewParams>((ref, params) async {
  // primeira tentativa com o período enviado pela UI
  Map<String, dynamic> json = await _getJson(ref, 'revenue-overview', {
    'store_id': params.storeId.toString(),
    'start_date': params.startDate.toIso8601String().split('T').first,
    'end_date': params.endDate.toIso8601String().split('T').first,
  });
  var resp = RevenueOverviewResponse.fromJson(json);

  final bool gotZero =
      resp.totalSales == 0 && resp.totalOrders == 0 && resp.topChannels.isEmpty;

  if (gotZero) {
    // 1) tenta mesmo período mas com loja que tem dado
    final fallbackStore = await _getFirstAvailableStoreId(ref);
    if (fallbackStore != null && fallbackStore != params.storeId) {
      json = await _getJson(ref, 'revenue-overview', {
        'store_id': fallbackStore.toString(),
        'start_date': params.startDate.toIso8601String().split('T').first,
        'end_date': params.endDate.toIso8601String().split('T').first,
      });
      resp = RevenueOverviewResponse.fromJson(json);
    }

    // 2) se mesmo assim vier 0, tenta o mês cheio anterior
    final bool stillZero = resp.totalSales == 0 &&
        resp.totalOrders == 0 &&
        resp.topChannels.isEmpty;
    if (stillZero) {
      final monthRange = _previousFullMonthRange();
      json = await _getJson(ref, 'revenue-overview', {
        'store_id': (resp.storeId != 0
                ? resp.storeId
                : (fallbackStore ?? params.storeId))
            .toString(),
        'start_date': monthRange['start_date']!,
        'end_date': monthRange['end_date']!,
      });
      resp = RevenueOverviewResponse.fromJson(json);
    }
  }

  return resp;
});

final storeComparisonProvider = FutureProvider.family<
    StoreComparisonResponse, StoreComparisonParams>((ref, params) async {
  // 1) tenta com as lojas que vieram da UI
  Map<String, dynamic> json = await _getJson(ref, 'store-comparison', {
    'store_a_id': params.storeA.toString(),
    'store_b_id': params.storeB.toString(),
    'start_date': params.startDate.toIso8601String().split('T').first,
    'end_date': params.endDate.toIso8601String().split('T').first,
  });
  var resp = StoreComparisonResponse.fromJson(json);

  if (resp.stores.isEmpty) {
    // pega as duas primeiras lojas com dado
    final list = await _getList(ref, 'available-stores');
    if (list.length >= 2) {
      final a = list[0] as Map<String, dynamic>;
      final b = list[1] as Map<String, dynamic>;
      final aId = _asInt(a['store_id'] ?? a['id']);
      final bId = _asInt(b['store_id'] ?? b['id']);
      json = await _getJson(ref, 'store-comparison', {
        'store_a_id': aId.toString(),
        'store_b_id': bId.toString(),
        'start_date': params.startDate.toIso8601String().split('T').first,
        'end_date': params.endDate.toIso8601String().split('T').first,
      });
      resp = StoreComparisonResponse.fromJson(json);
    }
  }

  return resp;
});
