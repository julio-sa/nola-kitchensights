import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../widgets/top_products_widget.dart';
import '../../widgets/delivery_heatmap_widget.dart';
import '../widgets/at_risk_customers_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Maria tem 3 lojas — vamos fixar storeId = 1 para demo
    final authState = ref.watch(authProvider);
    final storeId = authState.storeIds.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard - Maria'),
        actions: [
          IconButton(
            onPressed: () {
              // Simular troca de loja
            },
            icon: const Icon(Icons.store),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Riverpod atualiza automaticamente, mas força refresh visual
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopProductsWidget(
                  storeId: storeId,
                  channel: 'iFood',
                  dayOfWeek: 5, // sexta
                  hourStart: 19,
                  hourEnd: 23,
                ),
                const SizedBox(height: 24),
                DeliveryHeatmapWidget(storeId: storeId),
                const SizedBox(height: 24),
                AtRiskCustomersWidget(storeId: storeId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}