class TopProductsResponse {
  final List<TopProduct> products;

  const TopProductsResponse({required this.products});

  factory TopProductsResponse.fromJson(dynamic json) {
    // o backend pode mandar direto a lista ([]) ou embrulhado { "products": [] }
    if (json is List) {
      return TopProductsResponse(
        products: json
            .map<TopProduct>((e) => TopProduct.fromJson(e))
            .toList(growable: false),
      );
    }

    if (json is Map<String, dynamic>) {
      final list = (json['products'] ?? json['data'] ?? []) as List;
      return TopProductsResponse(
        products:
            list.map<TopProduct>((e) => TopProduct.fromJson(e)).toList(),
      );
    }

    return const TopProductsResponse(products: []);
  }
}

class TopProduct {
  final String productName;
  final int totalQuantitySold;
  final double totalRevenue;
  final double? weekOverWeekChangePct;
  final double? pctOfTotal;

  const TopProduct({
    required this.productName,
    required this.totalQuantitySold,
    required this.totalRevenue,
    this.weekOverWeekChangePct,
    this.pctOfTotal,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productName: (json['product_name'] ??
              json['productName'] ??
              json['name'] ??
              '')
          as String,
      totalQuantitySold:
          ((json['total_quantity'] ??
                      json['totalQuantity'] ??
                      json['total_quantity_sold'] ??
                      json['totalQuantitySold'] ??
                      0) as num)
              .toInt(),
      totalRevenue: _toDouble(
          json['total_revenue'] ?? json['totalRevenue'] ?? json['revenue']),
      weekOverWeekChangePct: _toNullableDouble(
          json['wow_change_pct'] ?? json['weekOverWeekChangePct']),
      pctOfTotal:
          _toNullableDouble(json['pct_of_total'] ?? json['pctOfTotal']),
    );
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static double? _toNullableDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
