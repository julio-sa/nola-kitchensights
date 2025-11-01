import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/widget_provider.dart';

class DeliveryHeatmapWidget extends ConsumerWidget {
  final int storeId;

  const DeliveryHeatmapWidget({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapFuture = ref.watch(deliveryHeatmapProvider(storeId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mapa de Calor de Entregas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            heatmapFuture.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Erro: $err'),
              data: (response) {
                if (response.regions.isEmpty) {
                  return const Text('Sem dados de entrega.');
                }
                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: response.regions.length,
                    itemBuilder: (context, index) {
                      final r = response.regions[index];
                      final isWorse = r.weekOverWeekChangePct != null && r.weekOverWeekChangePct! > 0;
                      return ListTile(
                        title: Text('${r.neighborhood}, ${r.city}'),
                        subtitle: Text('${r.deliveryCount} entregas'),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${r.avgDeliveryMinutes.toStringAsFixed(1)} min'),
                            if (r.weekOverWeekChangePct != null)
                              Text(
                                '${isWorse ? '↑' : '↓'} ${r.weekOverWeekChangePct!.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: isWorse ? Colors.red : Colors.green,
                                ),
                              ),
                          ],
                        ),
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