// lib/widgets/store_comparison_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show StoreComparisonStore, storeComparisonProvider;
import 'package:nola_kitchensights_app/data/params/widget_params.dart'
    as wp;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';
import 'package:nola_kitchensights_app/providers/my_stores_provider.dart';

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

  late int _storeA;
  late int _storeB;
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    _storeA = widget.storeA;
    _storeB = widget.storeB;
    _range = DateTimeRange(start: widget.startDate, end: widget.endDate);
  }

  @override
  Widget build(BuildContext context) {
    final myStoresAsync = ref.watch(myStoresProvider);

    final params = wp.StoreComparisonParams(
      storeA: _storeA,
      storeB: _storeB,
      startDate: _range.start,
      endDate: _range.end,
    );

    final comparisonAsync = ref.watch(storeComparisonProvider(params));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: comparisonAsync.when(
          loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text('Erro ao comparar lojas: $err'),
          data: (comparison) {
            // 1) pegar o que o backend mandou
            // pode ter 1 ou 2 lojas
            final apiStores = comparison.stores;

            // 2) montar objeto view SEMPRE com 2 lojas (A e B)
            final viewA = _buildViewForStore(
              id: _storeA,
              myStores: myStoresAsync,
              apiStores: apiStores,
            );
            final viewB = _buildViewForStore(
              id: _storeB,
              myStores: myStoresAsync,
              apiStores: apiStores,
            );

            final views = [viewA, viewB];

            // 3) descobrir se tem alguma com queda
            final hasDrop = views.any(
              (v) => v.data != null && (v.data!.salesChangePct) < 0,
            );

            // 4) decidir qual destacar
            int highlightIndex = _pickHighlightIndex(views, _metric);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  icon: Icons.storefront,
                  title: 'Comparativo de lojas',
                  subtitle:
                      '${_fmt(_range.start)} - ${_fmt(_range.end)} • ${viewA.name} x ${viewB.name}',
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: 'Escolher minhas lojas',
                        onPressed: () => _openFilter(myStoresAsync),
                      ),
                      PopupMenuButton<_HighlightMetric>(
                        onSelected: (v) {
                          setState(() {
                            _metric = v;
                          });
                        },
                        itemBuilder: (_) => const [
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 5) SEMPRE mostrar 2
                Column(
                  children: List.generate(views.length, (index) {
                    final v = views[index];
                    final isHighlighted = index == highlightIndex;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.04)
                            : const Color(0xFFF3F6F8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isHighlighted
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0xFFE0E6EB),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: isHighlighted
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                if (v.data == null) ...[
                                  Text(
                                    'Sem dados para esse período.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.red[400],
                                        ),
                                  ),
                                ] else ...[
                                  Text('Faturamento: R\$ ${v.data!.totalSales.toStringAsFixed(2)}'),
                                  Text('Pedidos: ${v.data!.totalOrders}'),
                                  Text('Ticket: R\$ ${v.data!.averageTicket.toStringAsFixed(2)}'),
                                  if (v.data!.topChannel != null)
                                    Text('Canal líder: ${v.data!.topChannel} (${v.data!.topChannelSharePct?.toStringAsFixed(1) ?? '--'}%)'),
                                ],
                                Text(
                                  'ID: ${v.id}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // variação
                          if (v.data != null)
                            Text(
                              '${v.data!.salesChangePct >= 0 ? '↑' : '↓'} ${v.data!.salesChangePct.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: v.data!.salesChangePct >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                _ComparisonInsightBox(
                  metric: _metric,
                  stores: views.map((e) => e.name).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // monta o "view" pra loja A ou B
  _StoreView _buildViewForStore({
    required int id,
    required AsyncValue<List<KitchenStoreRef>> myStores,
    required List<dynamic> apiStores, // é List<StoreComparisonStore>
  }) {
    // 1) Nome base
    String name = 'Loja $id';
    if (myStores.hasValue) {
      final list = myStores.value!;
      final found = list.where((e) => e.id == id);
      if (found.isNotEmpty) {
        name = found.first.name;
      }
    }

    // 2) Encontre o item já modelado
    StoreComparisonStore? data;
    for (final s in apiStores) {
      try {
        final sid = (s as dynamic).storeId as int;
        if (sid == id) {
          data = s as StoreComparisonStore;
          break;
        }
      } catch (_) {}
    }

    // 3) Se o backend mandou nome e myStores ainda não tinha, use o do backend
    if ((name == 'Loja $id' || name.trim().isEmpty) && data != null) {
      final apiName = data.storeName.trim();
      if (apiName.isNotEmpty) name = apiName;
    }

    return _StoreView(id: id, name: name, data: data);
  }

  // decide qual índice destacar
  int _pickHighlightIndex(List<_StoreView> views, _HighlightMetric metric) {
    if (views.length < 2) return 0;
    final a = views[0];
    final b = views[1];

    // se uma não tem dado, destaca a que tem
    if (a.data != null && b.data == null) return 0;
    if (b.data != null && a.data == null) return 1;
    if (a.data == null && b.data == null) return 0;

    switch (metric) {
      case _HighlightMetric.revenue:
        return a.data!.totalSales >= b.data!.totalSales ? 0 : 1;
      case _HighlightMetric.orders:
        return a.data!.totalOrders >= b.data!.totalOrders ? 0 : 1;
      case _HighlightMetric.sla:
        return 0;
    }
  }

  Future<void> _openFilter(
      AsyncValue<List<KitchenStoreRef>> myStoresAsync) async {
    if (!myStoresAsync.hasValue) return;
    final stores = myStoresAsync.value!;
    if (stores.isEmpty) return;

    int tmpA = stores.any((s) => s.id == _storeA)
        ? _storeA
        : stores.first.id;
    int tmpB = stores.any((s) => s.id == _storeB && s.id != tmpA)
        ? _storeB
        : (stores.length > 1
            ? stores.firstWhere((s) => s.id != tmpA).id
            : stores.first.id);
    DateTimeRange tmpRange = _range;

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
                    'Comparar minhas lojas',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: tmpA,
                    decoration: const InputDecoration(
                      labelText: 'Loja A',
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
                        setModalState(() {
                          tmpA = v;
                          if (tmpB == tmpA && stores.length > 1) {
                            tmpB = stores
                                .firstWhere((s) => s.id != tmpA)
                                .id;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: tmpB,
                    decoration: const InputDecoration(
                      labelText: 'Loja B',
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
                        setModalState(() {
                          tmpB = v;
                        });
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
                            '${_fmt(tmpRange.start)} - ${_fmt(tmpRange.end)}',
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
                              _storeA = tmpA;
                              _storeB = tmpB;
                              _range = tmpRange;
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

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _StoreView {
  final int id;
  final String name;
  final StoreComparisonStore? data;

  _StoreView({
    required this.id,
    required this.name,
    required this.data,
  });
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
            'Insight: use a loja com maior faturamento como base de estratégia.';
        break;
    case _HighlightMetric.orders:
        msg =
            'Insight: a loja com mais pedidos pode estar com ticket menor. Compare combos.';
        break;
      case _HighlightMetric.sla:
        msg =
            'Insight: destaque por SLA ainda depende do backend mandar essa métrica.';
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