// lib/widgets/revenue_overview_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show revenueOverviewProvider;
import 'package:nola_kitchensights_app/data/params/widget_params.dart'
    as wp;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';

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
    final params = wp.RevenueOverviewParams(
      storeId: storeId,
      startDate: startDate,
      endDate: endDate,
    );

    final overviewFuture = ref.watch(revenueOverviewProvider(params));

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
            final realStart = overview.startDate ?? startDate;
            final realEnd = overview.endDate ?? endDate;

            final salesDrop = overview.salesChangePct < -10;
            final lowShareChannels = overview.topChannels
                .where((c) => c.sharePct < 10)
                .map((c) => c.channel)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  icon: Icons.attach_money,
                  title: 'Faturamento',
                  subtitle:
                      'Período ${_formatDate(realStart)} - ${_formatDate(realEnd)}',
                  badge: salesDrop
                      ? const DashboardBadge(
                          label: '🛑 queda > 10%',
                          background: Color(0xFFFFEBEE),
                          foreground: Color(0xFFC62828),
                          icon: Icons.warning_amber_rounded,
                        )
                      : (overview.salesChangePct > 8
                          ? const DashboardBadge(
                              label: '⚡ crescimento',
                              background: Color(0xFFE3F2FD),
                              foreground: Color(0xFF1565C0),
                              icon: Icons.trending_up,
                            )
                          : null),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {},
                  ),
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
                Text(
                  'Top canais',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (overview.topChannels.isEmpty)
                  const Text('Nenhum canal com vendas no período.')
                else
                  Column(
                    children: overview.topChannels.take(3).map((channel) {
                      final percentage =
                          (channel.sharePct / 100).clamp(0.0, 1.0).toDouble();
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
                if (salesDrop && lowShareChannels.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Insight: faturamento caiu mais de 10%. Verifique promoções / exposição em: ${lowShareChannels.join(', ')}.',
                      style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
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
    final formatted =
        currency ? 'R\$ ${value.toStringAsFixed(2)}' : value.toStringAsFixed(0);
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
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (variationText != null)
          Text(
            variationText,
            style: TextStyle(
              color: variationColor,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
