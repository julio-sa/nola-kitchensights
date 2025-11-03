// lib/screens/graphs_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show
        revenueOverviewProvider,
        topProductsProvider,
        deliveryHeatmapProvider,
        atRiskCustomersProvider,
        DeliveryRegionInsight;
import 'package:nola_kitchensights_app/data/params/widget_params.dart' as wp;
import 'package:nola_kitchensights_app/providers/my_stores_provider.dart';
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';

class GraphsScreen extends ConsumerStatefulWidget {
  final int storeId;
  final DateTime startDate;
  final DateTime endDate;

  const GraphsScreen({
    super.key,
    required this.storeId,
    required this.startDate,
    required this.endDate,
  });

  @override
  ConsumerState<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends ConsumerState<GraphsScreen> {
  late int _storeId;
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    _storeId = widget.storeId;
    _range = DateTimeRange(start: widget.startDate, end: widget.endDate);
  }

  Future<void> _openStorePicker() async {
    try {
      final stores = await ref.read(myStoresProvider.future);
      if (!mounted) return;

      final pickedId = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text('Trocar loja',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (_, idx) {
                      final s = stores[idx];
                      final selected = s.id == _storeId;
                      return ListTile(
                        leading: const Icon(Icons.storefront),
                        title: Text('Loja ${s.name}'),
                        subtitle: Text('ID: ${s.id}'),
                        trailing: selected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(s.id),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: stores.length,
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (pickedId != null) {
        setState(() {
          _storeId = pickedId;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível carregar lojas: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(myStoresProvider);
    final storeName = storesAsync.maybeWhen(
      data: (stores) {
        final hit = stores.where((s) => s.id == _storeId);
        return hit.isNotEmpty ? hit.first.name : 'Loja #$_storeId';
      },
      orElse: () => 'Loja #$_storeId',
    );

    final revenueParams = wp.RevenueOverviewParams(
      storeId: _storeId,
      startDate: _range.start,
      endDate: _range.end,
    );
    final revenueAsync = ref.watch(revenueOverviewProvider(revenueParams));

    final topParams = wp.TopProductsParams(
      storeId: _storeId,
      channel: 'iFood',
      dayOfWeek: DateTime.now().weekday,
      hourStart: 0,
      hourEnd: 23,
    );
    final topAsync = ref.watch(topProductsProvider(topParams));

    final heatParams = wp.DeliveryHeatmapParams(
      storeId: _storeId,
      startDate: _range.start,
      endDate: _range.end,
    );
    final heatAsync = ref.watch(deliveryHeatmapProvider(heatParams));

    final riskAsync = ref.watch(atRiskCustomersProvider(_storeId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Gráficos • $storeName'),
        actions: [
          IconButton(
            tooltip: 'Trocar loja',
            onPressed: _openStorePicker,
            icon: const Icon(Icons.storefront),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ---------- Faturamento & Canais ----------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: revenueAsync.when(
                    loading: () => const SizedBox(
                        height: 140,
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text('Erro ao carregar faturamento: $e'),
                    data: (ov) {
                      final drop = ov.salesChangePct < -10;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DashboardSectionHeader(
                            icon: Icons.attach_money,
                            title: 'Faturamento e canais',
                            subtitle:
                                '$storeName • ${_d(_range.start)} - ${_d(_range.end)}',
                            badge: drop
                                ? const DashboardBadge(
                                    label:
                                        '🛑 queda > 10% • em relação ao período anterior',
                                    background: Color(0xFFFFEBEE),
                                    foreground: Color(0xFFC62828),
                                    icon: Icons.warning_amber_rounded,
                                  )
                                : (ov.salesChangePct > 8
                                    ? const DashboardBadge(
                                        label: '⚡ crescimento',
                                        background: Color(0xFFE3F2FD),
                                        foreground: Color(0xFF1565C0),
                                        icon: Icons.trending_up,
                                      )
                                    : null),
                          ),
                          const SizedBox(height: 12),
                          _MetricRow(
                            leftLabel: 'Faturamento',
                            leftValue:
                                'R\$ ${ov.totalSales.toStringAsFixed(2)}',
                            rightLabel: 'Pedidos',
                            rightValue: ov.totalOrders.toString(),
                            variationText:
                                '${ov.salesChangePct >= 0 ? '↑' : '↓'} ${ov.salesChangePct.abs().toStringAsFixed(1)}%',
                            variationColor: ov.salesChangePct >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text('Participação por canal',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          if (ov.topChannels.isEmpty)
                            const Text('Nenhum canal com vendas no período.')
                          else
                            Column(
                              children: ov.topChannels.map((c) {
                                final pct =
                                    (c.sharePct / 100).clamp(0.0, 1.0);
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: _BarRow(
                                    label: c.channel,
                                    value: pct,
                                    valueLabel:
                                        '${c.sharePct.toStringAsFixed(1)}%',
                                  ),
                                );
                              }).toList(),
                            ),
                          if (drop &&
                              ov.topChannels.any((c) => c.sharePct < 10))
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _InsightBox(
                                color: const Color(0xFFFFEBEE),
                                icon: Icons.lightbulb,
                                iconColor: const Color(0xFFC62828),
                                text:
                                    'Insight: queda de >10%. Reforce promoções/exposição nos canais com participação <10%.',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---------- Top produtos ----------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: topAsync.when(
                    loading: () => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text('Erro ao carregar top produtos: $e'),
                    data: (tp) {
                      final top = tp.products.take(5).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DashboardSectionHeader(
                            icon: Icons.star,
                            title:
                                'Top produtos (por % do faturamento)',
                            subtitle:
                                'Visualização simplificada • Canal iFood • Dia atual • 00–23h',
                          ),
                          const SizedBox(height: 12),
                          if (top.isEmpty)
                            const Text('Sem produtos no recorte.')
                          else
                            Column(
                              children: top.map((p) {
                                final frac = (p.percentageOfTotal / 100)
                                    .clamp(0.0, 1.0);
                                final wow = p.weekOverWeekChangePct;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    children: [
                                      _BarRow(
                                        label: p.productName,
                                        value: frac,
                                        valueLabel:
                                            '${p.percentageOfTotal.toStringAsFixed(1)}%',
                                      ),
                                      if (wow != null)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            '${wow >= 0 ? '↑' : '↓'} ${wow.abs().toStringAsFixed(1)}% vs. semana anterior',
                                            style: TextStyle(
                                              color: wow >= 0
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
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
              ),
              const SizedBox(height: 16),

              // ---------- Entregas por cidade ----------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: heatAsync.when(
                    loading: () => const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text('Erro ao carregar entregas: $e'),
                    data: (hm) {
                      final cities = _groupByCity(hm.regions);
                      final worst =
                          cities.isNotEmpty ? cities.first : null;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DashboardSectionHeader(
                            icon: Icons.delivery_dining,
                            title:
                                'Tempo médio de entrega por cidade',
                            subtitle:
                                'Quanto menor, melhor • Período selecionado',
                          ),
                          const SizedBox(height: 12),
                          if (cities.isEmpty)
                            const Text('Sem regiões suficientes para exibir.')
                          else
                            Column(
                              children: cities.take(6).map((c) {
                                final cap = 60.0; // 60min = barra cheia
                                final frac = (c.avgMinutes / cap)
                                    .clamp(0.0, 1.0)
                                    .toDouble();
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: _BarRow(
                                    label: c.label,
                                    value: frac,
                                    valueLabel:
                                        '${c.avgMinutes.toStringAsFixed(1)} min',
                                  ),
                                );
                              }).toList(),
                            ),
                          if (worst != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _InsightBox(
                                color: const Color(0xFFFFF3E0),
                                icon: Icons.lightbulb,
                                iconColor: const Color(0xFFE65100),
                                text:
                                    'Insight: cidade "${worst.label}" com maior tempo médio (${worst.avgMinutes.toStringAsFixed(1)} min). Reavalie rotas/janelas.',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---------- Clientes em risco ----------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: riskAsync.when(
                    loading: () => const SizedBox(
                        height: 100,
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text('Erro ao carregar clientes em risco: $e'),
                    data: (r) {
                      final total = r.customers.length;
                      final buckets = <String, int>{
                        '60–69d (10%)': 0,
                        '70–79d (20%)': 0,
                        '80–89d (30%)': 0,
                        '90–99d (40%)': 0,
                        '100–109d (50%)': 0,
                        '110+d (60%)': 0,
                      };
                      for (final c in r.customers) {
                        final d = c.daysSinceLastOrder;
                        if (d >= 110) {
                          buckets['110+d (60%)'] =
                              buckets['110+d (60%)']! + 1;
                        } else if (d >= 100) {
                          buckets['100–109d (50%)'] =
                              buckets['100–109d (50%)']! + 1;
                        } else if (d >= 90) {
                          buckets['90–99d (40%)'] =
                              buckets['90–99d (40%)']! + 1;
                        } else if (d >= 80) {
                          buckets['80–89d (30%)'] =
                              buckets['80–89d (30%)']! + 1;
                        } else if (d >= 70) {
                          buckets['70–79d (20%)'] =
                              buckets['70–79d (20%)']! + 1;
                        } else if (d >= 60) {
                          buckets['60–69d (10%)'] =
                              buckets['60–69d (10%)']! + 1;
                        }
                      }
                      final maxCount = (buckets.values.isEmpty)
                          ? 1
                          : (buckets.values
                              .reduce((a, b) => a > b ? a : b));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DashboardSectionHeader(
                            icon: Icons.warning_amber_rounded,
                            title:
                                'Clientes em risco: distribuição por degrau de cupom',
                            subtitle:
                                '$storeName • Total: $total clientes 60+d sem compra',
                          ),
                          const SizedBox(height: 12),
                          if (total == 0)
                            const Text('Nenhum cliente crítico no período.')
                          else
                            Column(
                              children: buckets.entries.map((e) {
                                final frac = (e.value /
                                        (maxCount == 0 ? 1 : maxCount))
                                    .clamp(0.0, 1.0)
                                    .toDouble();
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: _BarRow(
                                    label: e.key,
                                    value: frac,
                                    valueLabel: e.value.toString(),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 12),
                          const _CouponInsightBox(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  List<_UiCity> _groupByCity(List<DeliveryRegionInsight> original) {
    final Map<String, _UiCity> map = {};
    for (final r in original) {
      final key = (r.city.isNotEmpty ? r.city : 'Sem cidade').trim();
      if (!map.containsKey(key)) {
        map[key] = _UiCity(
          label: key,
          deliveryCount: r.deliveryCount,
          avgMinutes: r.avgDeliveryMinutes,
        );
      } else {
        final current = map[key]!;
        final total = current.deliveryCount + r.deliveryCount;
        final weighted = ((current.avgMinutes * current.deliveryCount) +
                (r.avgDeliveryMinutes * r.deliveryCount)) /
            (total == 0 ? 1 : total);
        map[key] = _UiCity(
          label: key,
          deliveryCount: total,
          avgMinutes: weighted,
        );
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.avgMinutes.compareTo(a.avgMinutes));
    return list;
  }
}

class _UiCity {
  final String label;
  final int deliveryCount;
  final double avgMinutes;
  _UiCity({
    required this.label,
    required this.deliveryCount,
    required this.avgMinutes,
  });
}

class _BarRow extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final String valueLabel;

  const _BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child:
                        Text(label, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(valueLabel,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value.isNaN ? 0 : value.clamp(0.0, 1.0),
                minHeight: 10,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final String? variationText;
  final Color? variationColor;

  const _MetricRow({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    this.variationText,
    this.variationColor,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context)
        .textTheme
        .headlineSmall
        ?.copyWith(fontWeight: FontWeight.bold);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(leftLabel, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(leftValue, style: textStyle),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rightLabel, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(rightValue, style: textStyle),
            ],
          ),
        ),
        if (variationText != null) ...[
          const SizedBox(width: 12),
          Text(
            variationText!,
            style: TextStyle(
              color: variationColor ?? Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _InsightBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InsightBox({
    super.key,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: iconColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponInsightBox extends StatelessWidget {
  const _CouponInsightBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.local_offer, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lógica do cupom: após 60 dias sem compra, o cliente entra em uma escada '
              'de incentivo (10% a partir do 60º dia, +10% a cada 10 dias, teto de 60%). '
              'Ao comprar novamente, a progressão é reiniciada.',
              style: TextStyle(color: Color(0xFF0D47A1)),
            ),
          ),
        ],
      ),
    );
  }
}
