import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../data/models/top_products_response.dart';
import '../data/models/delivery_heatmap_response.dart';
import '../data/models/at_risk_customers_response.dart';

class ApiService {
  static Future<TopProductsResponse> fetchTopProducts({
    required int storeId,
    required String channel,
    required int dayOfWeek,
    required int hourStart,
    required int hourEnd,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/widgets/top-products')
        .replace(queryParameters: {
      'store_id': storeId.toString(),
      'channel': channel,
      'day_of_week': dayOfWeek.toString(),
      'hour_start': hourStart.toString(),
      'hour_end': hourEnd.toString(),
    });

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return TopProductsResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Falha ao carregar dados: ${response.statusCode}');
    }
  }

  static Future<DeliveryHeatmapResponse> fetchDeliveryHeatmap({
    required int storeId,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/widgets/delivery-heatmap')
        .replace(queryParameters: {'store_id': storeId.toString()});

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
}