class AtRiskCustomersResponse {
  final List<AtRiskCustomer> customers;

  const AtRiskCustomersResponse({required this.customers});

  factory AtRiskCustomersResponse.fromJson(dynamic json) {
    if (json is List) {
      return AtRiskCustomersResponse(
        customers: json
            .map<AtRiskCustomer>((e) => AtRiskCustomer.fromJson(e))
            .toList(),
      );
    }

    if (json is Map<String, dynamic>) {
      final list = (json['customers'] ?? json['data'] ?? []) as List;
      return AtRiskCustomersResponse(
        customers:
            list.map<AtRiskCustomer>((e) => AtRiskCustomer.fromJson(e)).toList(),
      );
    }

    return const AtRiskCustomersResponse(customers: []);
  }
}

class AtRiskCustomer {
  final String customerName;
  final int totalOrders;
  final int daysSinceLastOrder;

  const AtRiskCustomer({
    required this.customerName,
    required this.totalOrders,
    required this.daysSinceLastOrder,
  });

  factory AtRiskCustomer.fromJson(Map<String, dynamic> json) {
    return AtRiskCustomer(
      customerName:
          (json['customer_name'] ?? json['customerName'] ?? 'Cliente') as String,
      totalOrders:
          ((json['total_orders'] ?? json['totalOrders'] ?? 0) as num).toInt(),
      daysSinceLastOrder: ((json['days_since_last_order'] ??
                  json['daysSinceLastOrder'] ??
                  0) as num)
              .toInt(),
    );
  }
}
