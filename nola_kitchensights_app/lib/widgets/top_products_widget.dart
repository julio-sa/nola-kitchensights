import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/widget_provider.dart';

class TopProductsWidget extends ConsumerWidget {
  final int storeId;
  final String channel;
  final int dayOfWeek;
  final int hourStart;
  final int hourEnd;

  const TopProductsWidget({
    super.key,
    required this.storeId,
    required this.channel,
    required this.dayOfWeek,
    required this.hourStart,
    required this.hourEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsFuture = ref.watch(topProductsProvider({
      'store_id': storeId,
      'channel': channel,
      'day_of_week': dayOfWeek,
      'hour_start': hourStart,
      'hour_end': hourEnd,
    }));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Produtos no $channel (Sexta, 19h-23h)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            productsFuture.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Erro: $err'),
              data: (response) {
                if (response.products.isEmpty) {
                  return const Text('Nenhum dado encontrado.');
                }
                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: response.products.length,
                    itemBuilder: (context, index) {
                      final p = response.products[index];
                      return ListTile(
                        title: Text(p.productName),
                        subtitle: Text('${p.totalQuantitySold} vendidos'),
                        trailing: Text('R\$ ${p.totalRevenue.toStringAsFixed(2)}'),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}