import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../data/models/top_products_response.dart';
import '../data/models/delivery_heatmap_response.dart';
import '../data/models/at_risk_customers_response.dart';

final topProductsProvider = FutureProvider.family<TopProductsResponse, Map<String, dynamic>>((ref, args) {
  return ApiService.fetchTopProducts(
    storeId: args['store_id'] as int,
    channel: args['channel'] as String,
    dayOfWeek: args['day_of_week'] as int,
    hourStart: args['hour_start'] as int,
    hourEnd: args['hour_end'] as int,
  );
});

final deliveryHeatmapProvider = FutureProvider.family<DeliveryHeatmapResponse, int>((ref, storeId) {
  return ApiService.fetchDeliveryHeatmap(storeId: storeId);
});

final atRiskCustomersProvider = FutureProvider.family<AtRiskCustomersResponse, int>((ref, storeId) {
  return ApiService.fetchAtRiskCustomers(storeId: storeId);
});