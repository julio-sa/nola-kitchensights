import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../data/models/at_risk_customers_response.dart';
import '../data/models/delivery_heatmap_response.dart';
import '../data/models/revenue_overview_response.dart';
import '../data/models/store_comparison_response.dart';
import '../data/models/top_products_response.dart';

class ApiService {
  static Future<TopProductsResponse> fetchTopProducts({
    required int storeId,
    String? channel,
    int? dayOfWeek,
    int? hourStart,
    int? hourEnd,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final qp = <String, String>{
      'store_id': storeId.toString(),
    };
    if (channel != null) qp['channel'] = channel;
    if (dayOfWeek != null) qp['day_of_week'] = dayOfWeek.toString();
    if (hourStart != null) qp['hour_start'] = hourStart.toString();
    if (hourEnd != null) qp['hour_end'] = hourEnd.toString();
    if (startDate != null) qp['start_date'] = startDate.toIso8601String().split('T').first;
    if (endDate != null) qp['end_date'] = endDate.toIso8601String().split('T').first;

    final url = Uri.parse('${ApiConstants.baseUrl}/widgets/top-products')
        .replace(queryParameters: qp);

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return TopProductsResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao carregar dados: ${response.statusCode}');
    }
  }

  static Future<DeliveryHeatmapResponse> fetchDeliveryHeatmap({
    required int storeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final qp = <String, String>{'store_id': storeId.toString()};
    if (startDate != null) qp['start_date'] = startDate.toIso8601String().split('T').first;
    if (endDate != null) qp['end_date'] = endDate.toIso8601String().split('T').first;

    final url = Uri.parse('${ApiConstants.baseUrl}/widgets/delivery-heatmap')
        .replace(queryParameters: qp);

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return DeliveryHeatmapResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao carregar mapa de calor: ${response.statusCode}');
    }
  }

  static Future<AtRiskCustomersResponse> fetchAtRiskCustomers({
    required int storeId,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/widgets/at-risk-customers')
        .replace(queryParameters: {'store_id': storeId.toString()});

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return AtRiskCustomersResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao carregar clientes em risco: ${response.statusCode}');
    }
  }

  static Future<RevenueOverviewResponse> fetchRevenueOverview({
    required int storeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/widgets/revenue-overview').replace(
      queryParameters: {
        'store_id': storeId.toString(),
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate.toIso8601String().split('T').first,
      },
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return RevenueOverviewResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao carregar overview: ${response.statusCode}');
    }
  }

  static Future<StoreComparisonResponse> fetchStoreComparison({
    required int storeA,
    required int storeB,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final qp = <String, String>{
      'store_a_id': storeA.toString(),
      'store_b_id': storeB.toString(),
    };
    if (startDate != null) qp['start_date'] = startDate.toIso8601String().split('T').first;
    if (endDate != null) qp['end_date'] = endDate.toIso8601String().split('T').first;

    final url = Uri.parse('${ApiConstants.baseUrl}/widgets/store-comparison')
        .replace(queryParameters: qp);

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return StoreComparisonResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao comparar lojas: ${response.statusCode}');
    }
  }

  static Future<String> exportStorePerformance({
    required List<int> storeIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final base = '${ApiConstants.baseUrl}/reports/store-performance';
    final start = startDate.toIso8601String().split('T').first;
    final end = endDate.toIso8601String().split('T').first;
    final storeQuery = storeIds.map((id) => 'store_ids=$id').join('&');
    final uri = Uri.parse('$base?$storeQuery&start_date=$start&end_date=$end');

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Falha ao exportar relatório: ${response.statusCode}');
    }
  }
}
