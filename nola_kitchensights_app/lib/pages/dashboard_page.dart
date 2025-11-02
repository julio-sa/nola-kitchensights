// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';

import 'package:nola_kitchensights_app/widgets/revenue_overview_widget.dart';
import 'package:nola_kitchensights_app/widgets/top_products_widget.dart';
import 'package:nola_kitchensights_app/widgets/store_comparison_widget.dart';
import 'package:nola_kitchensights_app/widgets/delivery_heatmap_widget.dart';
import 'package:nola_kitchensights_app/widgets/at_risk_customers_widget.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KitchenSights'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RevenueOverviewWidget(
              storeId: 97, // coloca a loja que você testou aí
              startDate: monthStart,
              endDate: now,
            ),
            const SizedBox(height: 16),
            const TopProductsWidget(storeId: 97),
            const SizedBox(height: 16),
            StoreComparisonWidget(
              storeA: 97,
              storeB: 1,
              startDate: monthStart,
              endDate: now,
            ),
            const SizedBox(height: 16),
            const DeliveryHeatmapWidget(storeId: 97),
            const SizedBox(height: 16),
            const AtRiskCustomersWidget(storeId: 97),
          ],
        ),
      ),
    );
  }
}
