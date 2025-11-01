import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/widget_provider.dart';

class StoreComparisonWidget extends ConsumerWidget {
  final int storeA;
  final int storeB;
  final DateTime startDate;
  final DateTime endDate;

  const StoreComparisonWidget({
    super.key,
    required this.storeA,
    required this.storeB,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = {
      'store_a': storeA,
      'store_b': storeB,
      'start_date': startDate,
      'end_date': endDate,
    };
    final comparisonFuture = ref.watch(storeComparisonProvider(args));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: comparisonFuture.when(
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text('Erro ao comparar lojas: $err'),
          data: (comparison) {
            if (comparison.stores.isEmpty) {
              return const Text('Sem dados para o período informado.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparativo de lojas (${_formatDate(startDate)} - ${_formatDate(endDate)})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ...comparison.stores.map((store) {
                  final variation = store.salesChangePct;
                  final variationColor = variation >= 0 ? Colors.green : Colors.red;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(store.storeName, style: Theme.of(context).textTheme.titleSmall),
                            Text(
                              '${variation >= 0 ? '↑' : '↓'} ${variation.abs().toStringAsFixed(1)}%',
                              style: TextStyle(color: variationColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Faturamento: R\$ ${store.totalSales.toStringAsFixed(2)}'),
                        Text('Pedidos: ${store.totalOrders}'),
                        Text('Ticket médio: R\$ ${store.averageTicket.toStringAsFixed(2)}'),
                        if (store.topChannel != null)
                          Text(
                            'Canal líder: ${store.topChannel} (${store.topChannelSharePct?.toStringAsFixed(1) ?? '--'}%)',
                          ),
                        const Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
