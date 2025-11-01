import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/widget_provider.dart';

class RevenueOverviewWidget extends ConsumerWidget {
  final int storeId;
  final DateTime startDate;
  final DateTime endDate;

  const RevenueOverviewWidget({
    super.key,
    required this.storeId,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = {
      'store_id': storeId,
      'start_date': startDate,
      'end_date': endDate,
    };
    final overviewFuture = ref.watch(revenueOverviewProvider(args));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: overviewFuture.when(
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text('Erro ao carregar overview: $err'),
          data: (overview) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Faturamento (${_formatDate(startDate)} - ${_formatDate(endDate)})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _MetricTile(
                      label: 'Faturamento',
                      value: overview.totalSales,
                      currency: true,
                      variation: overview.salesChangePct,
                    ),
                    _MetricTile(
                      label: 'Pedidos',
                      value: overview.totalOrders.toDouble(),
                      variation: overview.ordersChangePct,
                    ),
                    _MetricTile(
                      label: 'Ticket médio',
                      value: overview.averageTicket,
                      currency: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Top canais'),
                const SizedBox(height: 8),
                if (overview.topChannels.isEmpty)
                  const Text('Nenhum canal com vendas no período.')
                else
                  Column(
                    children: overview.topChannels.take(3).map((channel) {
                      final percentage = (channel.sharePct / 100).clamp(0.0, 1.0).toDouble();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(channel.channel),
                                Text('${channel.sharePct.toStringAsFixed(1)}%'),
                              ],
                            ),
                            LinearProgressIndicator(value: percentage),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

class _MetricTile extends StatelessWidget {
  final String label;
  final double value;
  final bool currency;
  final double? variation;

  const _MetricTile({
    required this.label,
    required this.value,
    this.currency = false,
    this.variation,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = currency ? 'R\$ ${value.toStringAsFixed(2)}' : value.toStringAsFixed(0);
    final variationText = variation == null
        ? null
        : '${variation! >= 0 ? '↑' : '↓'} ${variation!.abs().toStringAsFixed(1)}%';
    final variationColor = variation == null
        ? null
        : variation! >= 0
            ? Colors.green
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          formatted,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (variationText != null)
          Text(
            variationText,
            style: TextStyle(color: variationColor, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}
