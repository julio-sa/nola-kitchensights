import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/widget_provider.dart';

class AtRiskCustomersWidget extends ConsumerWidget {
  final int storeId;

  const AtRiskCustomersWidget({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersFuture = ref.watch(atRiskCustomersProvider(storeId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clientes em Risco',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            customersFuture.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Erro: $err'),
              data: (response) {
                if (response.customers.isEmpty) {
                  return const Text('Nenhum cliente em risco.');
                }
                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: response.customers.length,
                    itemBuilder: (context, index) {
                      final c = response.customers[index];
                      return ListTile(
                        title: Text(c.customerName),
                        subtitle: Text('${c.totalOrders} pedidos'),
                        trailing: Text('${c.daysSinceLastOrder} dias'),
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