// lib/widgets/store_comparison_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show storeComparisonProvider, StoreComparisonStore;
import 'package:nola_kitchensights_app/data/params/widget_params.dart'
    as wp;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';

enum _HighlightMetric { revenue, orders, sla }

class StoreComparisonWidget extends ConsumerStatefulWidget {
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
  ConsumerState<StoreComparisonWidget> createState() =>
      _StoreComparisonWidgetState();
}

class _StoreComparisonWidgetState
    extends ConsumerState<StoreComparisonWidget> {
  _HighlightMetric _metric = _HighlightMetric.revenue;

  @override
  Widget build(BuildContext context) {
    final params = wp.StoreComparisonParams(
      storeA: widget.storeA,
      storeB: widget.storeB,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );

    final comparisonFuture = ref.watch(storeComparisonProvider(params));

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

            // ordenar conforme o destaque escolhido
            final stores = [...comparison.stores];
            switch (_metric) {
              case _HighlightMetric.revenue:
                stores.sort(
                    (a, b) => b.totalSales.compareTo(a.totalSales));
                break;
              case _HighlightMetric.orders:
                stores.sort(
                    (a, b) => b.totalOrders.compareTo(a.totalOrders));
                break;
              case _HighlightMetric.sla:
                // ainda não temos SLA
                break;
            }

            final hasDrop =
                stores.any((s) => (s.salesChangePct) < 0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  icon: Icons.storefront,
                  title: 'Comparativo de lojas',
                  subtitle:
                      '${_formatDate(widget.startDate)} - ${_formatDate(widget.endDate)}',
                  badge: hasDrop
                      ? const DashboardBadge(
                          label: '🛑 loja com queda',
                          background: Color(0xFFFFEBEE),
                          foreground: Color(0xFFC62828),
                          icon: Icons.trending_down,
                        )
                      : const DashboardBadge(
                          label: '⚡ bom desempenho',
                          background: Color(0xFFE8F5E9),
                          foreground: Color(0xFF2E7D32),
                          icon: Icons.trending_up,
                        ),
                  trailing: PopupMenuButton<_HighlightMetric>(
                    onSelected: (v) {
                      setState(() {
                        _metric = v;
                      });
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: _HighlightMetric.revenue,
                        child: Text('Destacar faturamento'),
                      ),
                      PopupMenuItem(
                        value: _HighlightMetric.orders,
                        child: Text('Destacar pedidos'),
                      ),
                      PopupMenuItem(
                        value: _HighlightMetric.sla,
                        child: Text('Destacar SLA'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ),
                const SizedBox(height: 16),
                ...stores.map((store) {
                  final variation = store.salesChangePct;
                  final variationColor =
                      variation >= 0 ? Colors.green : Colors.red;

                  final displayName = _displayStoreName(store);

                  // destaque visual
                  final isHighlighted = store == stores.first;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.06)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isHighlighted
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.1,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // nome completo da loja
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: isHighlighted
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                              ),
                            ),
                            Text(
                              '${variation >= 0 ? '↑' : '↓'} ${variation.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: variationColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'Faturamento: R\$ ${store.totalSales.toStringAsFixed(2)}'),
                        Text('Pedidos: ${store.totalOrders}'),
                        Text(
                            'Ticket médio: R\$ ${store.averageTicket.toStringAsFixed(2)}'),
                        if (store.topChannel != null)
                          Text(
                            'Canal líder: ${store.topChannel} (${store.topChannelSharePct?.toStringAsFixed(1) ?? '--'}%)',
                          ),
                        // id sempre visível pra não ficar no escuro
                        Text(
                          'ID: ${store.storeId}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _ComparisonInsightBox(
                  metric: _metric,
                  stores: stores.map((e) => _displayStoreName(e)).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  // aqui a gente garante que nunca vai aparecer só "Loja"
  String _displayStoreName(StoreComparisonStore store) {
    final raw = store.storeName.trim();
    // se o backend devolveu alguma coisa, usa
    if (raw.isNotEmpty && raw.toLowerCase() != 'loja') {
      return raw;
    }
    // senão, mostra algo útil
    return 'Loja ${store.storeId.toString().padLeft(2, '0')}';
  }
}

class _ComparisonInsightBox extends StatelessWidget {
  final _HighlightMetric metric;
  final List<String> stores;

  const _ComparisonInsightBox({
    required this.metric,
    required this.stores,
  });

  @override
  Widget build(BuildContext context) {
    String msg;
    switch (metric) {
      case _HighlightMetric.revenue:
        msg =
            'Insight: coloque a loja que mais fatura como referência (promoções, canais, horários) e replique nas demais.';
        break;
      case _HighlightMetric.orders:
        msg =
            'Insight: loja com mais pedidos pode estar com ticket menor. Vale revisar combos / upsell.';
        break;
      case _HighlightMetric.sla:
        msg =
            'Insight: destaque por SLA ainda depende de o backend mandar esta métrica.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
