class AtRiskCustomersResponse {
  final int storeId;
  final List<AtRiskCustomer> customers;

  AtRiskCustomersResponse({
    required this.storeId,
    required this.customers,
  });

  factory AtRiskCustomersResponse.fromJson(Map<String, dynamic> json) {
    return AtRiskCustomersResponse(
      storeId: json['store_id'],
      customers: (json['customers'] as List)
          .map((e) => AtRiskCustomer.fromJson(e))
          .toList(),
    );
  }
}

class AtRiskCustomer {
  final String customerName;
  final int customerId;
  final int totalOrders;
  final DateTime lastOrderDate;
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
      customerName: json['customer_name'],
      customerId: json['customer_id'],
      totalOrders: json['total_orders'],
      lastOrderDate: DateTime.parse(json['last_order_date'].toString()),
      daysSinceLastOrder: json['days_since_last_order'],
    );
  }
}