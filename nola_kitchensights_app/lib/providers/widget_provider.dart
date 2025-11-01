import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../data/models/at_risk_customers_response.dart';
import '../data/models/delivery_heatmap_response.dart';
import '../data/models/revenue_overview_response.dart';
import '../data/models/store_comparison_response.dart';
import '../data/models/top_products_response.dart';

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

final revenueOverviewProvider =
    FutureProvider.family<RevenueOverviewResponse, Map<String, dynamic>>((ref, args) {
  return ApiService.fetchRevenueOverview(
    storeId: args['store_id'] as int,
    startDate: args['start_date'] as DateTime,
    endDate: args['end_date'] as DateTime,
  );
});

final storeComparisonProvider =
    FutureProvider.family<StoreComparisonResponse, Map<String, dynamic>>((ref, args) {
  return ApiService.fetchStoreComparison(
    storeA: args['store_a'] as int,
    storeB: args['store_b'] as int,
    startDate: args['start_date'] as DateTime,
    endDate: args['end_date'] as DateTime,
  );
});