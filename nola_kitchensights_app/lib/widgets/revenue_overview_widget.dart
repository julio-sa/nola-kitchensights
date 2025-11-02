// lib/widgets/revenue_overview_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show revenueOverviewProvider;
import 'package:nola_kitchensights_app/data/params/widget_params.dart'
    as wp;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';
import 'package:nola_kitchensights_app/providers/my_stores_provider.dart';

class RevenueOverviewWidget extends ConsumerStatefulWidget {
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
  ConsumerState<RevenueOverviewWidget> createState() =>
      _RevenueOverviewWidgetState();
}

class _RevenueOverviewWidgetState
    extends ConsumerState<RevenueOverviewWidget> {
  late int _currentStoreId;
  DateTimeRange? _currentRange;

  @override
  void initState() {
    super.initState();
    _currentStoreId = widget.storeId;
    _currentRange = DateTimeRange(
      start: widget.startDate,
      end: widget.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    // aqui é ConsumerState -> usa ref direto
    final storesAsync = ref.watch(myStoresProvider);

    final params = wp.RevenueOverviewParams(
      storeId: _currentStoreId,
      startDate: _currentRange?.start ?? widget.startDate,
      endDate: _currentRange?.end ?? widget.endDate,
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
            final realStart = overview.startDate ??
                (_currentRange?.start ?? widget.startDate);
            final realEnd =
                overview.endDate ?? (_currentRange?.end ?? widget.endDate);

            final salesDrop = overview.salesChangePct < -10;
            final lowShareChannels = overview.topChannels
                .where((c) => c.sharePct < 10)
                .map((c) => c.channel)
                .toList();

            // nome amigável da loja
            final storeName = storesAsync.maybeWhen(
              data: (stores) {
                final found =
                    stores.where((s) => s.id == _currentStoreId).toList();
                if (found.isNotEmpty) {
                  return found.first.name;
                }
                return 'Loja $_currentStoreId';
              },
              orElse: () => 'Loja $_currentStoreId',
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  icon: Icons.attach_money,
                  title: 'Faturamento',
                  subtitle:
                      '$storeName • ${_formatDate(realStart)} - ${_formatDate(realEnd)}',
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
                  // mesmo ícone do Top Products
                  trailing: IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filtrar período / loja',
                    onPressed: () => _openFilters(storesAsync),
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
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
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
                      'Insight: faturamento caiu mais de 10%. Reforçar promoções/exposição em: ${lowShareChannels.join(', ')}.',
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

  Future<void> _openFilters(
      AsyncValue<List<KitchenStoreRef>> storesAsync) async {
    // se ainda está carregando as lojas, não abre
    if (!storesAsync.hasValue) return;
    final stores = storesAsync.value!;

    int tmpStore = _currentStoreId;
    DateTimeRange tmpRange = _currentRange ??
        DateTimeRange(start: widget.startDate, end: widget.endDate);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Filtro de faturamento',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    // aqui o Flutter reclamou do value -> usar initialValue
                    initialValue: tmpStore,
                    decoration: const InputDecoration(
                      labelText: 'Loja',
                      border: OutlineInputBorder(),
                    ),
                    items: stores
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() => tmpStore = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: ctx,
                              firstDate: DateTime(DateTime.now().year - 1),
                              lastDate: DateTime(DateTime.now().year + 1),
                              initialDateRange: tmpRange,
                            );
                            if (picked != null) {
                              setModalState(() {
                                tmpRange = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            '${_formatDate(tmpRange.start)} - ${_formatDate(tmpRange.end)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentStoreId = tmpStore;
                              _currentRange = tmpRange;
                            });
                            Navigator.of(ctx).pop();
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
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
    final formatted = currency
        ? 'R\$ ${value.toStringAsFixed(2)}'
        : value.toStringAsFixed(0);
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
