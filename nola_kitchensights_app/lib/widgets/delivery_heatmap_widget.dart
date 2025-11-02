// lib/widgets/delivery_heatmap_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show deliveryHeatmapProvider, DeliveryRegionInsight;
import 'package:nola_kitchensights_app/data/params/widget_params.dart'
    as wp;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';

class DeliveryHeatmapWidget extends ConsumerStatefulWidget {
  final int storeId;

  const DeliveryHeatmapWidget({
    super.key,
    required this.storeId,
  });

  @override
  ConsumerState<DeliveryHeatmapWidget> createState() =>
      _DeliveryHeatmapWidgetState();
}

class _DeliveryHeatmapWidgetState
    extends ConsumerState<DeliveryHeatmapWidget> {
  DateTimeRange? _range;
  String _groupBy = 'bairro'; // bairro | cidade
  bool _onlySlow = false;
  int _maxItems = 10;

  @override
  Widget build(BuildContext context) {
    final params = wp.DeliveryHeatmapParams(
      storeId: widget.storeId,
      startDate: _range?.start,
      endDate: _range?.end,
    );

    final heatmapFuture = ref.watch(deliveryHeatmapProvider(params));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: heatmapFuture.when(
          loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text('Erro ao carregar mapa de calor: $err'),
          data: (heatmap) {
            final List<_UiRegion> regions;
            if (_groupBy == 'bairro') {
              regions = heatmap.regions
                  .map<_UiRegion>((r) => _UiRegion(
                        label: '${r.neighborhood} • ${r.city}',
                        city: r.city,
                        deliveryCount: r.deliveryCount,
                        avgMinutes: r.avgDeliveryMinutes,
                        p90Minutes: r.p90DeliveryMinutes,
                        wowChangePct: r.weekOverWeekChangePct,
                      ))
                  .toList();
            } else {
              regions = _groupByCity(heatmap.regions);
            }

            // aplica filtro SLA > 40 se marcado
            List<_UiRegion> filtered = regions;
            if (_onlySlow) {
              filtered = filtered
                  .where((r) => (r.avgMinutes) > 40.0)
                  .toList();
            }

            // ordena por SLA desc
            filtered.sort((a, b) => b.avgMinutes.compareTo(a.avgMinutes));

            // insight: pega pior
            final _UiRegion? worstRegion =
                filtered.isNotEmpty ? filtered.first : null;

            // limitar a 10
            final visible = filtered.take(_maxItems).toList();
            final hasMore = filtered.length > _maxItems;

            final hasSlowRegion =
                filtered.any((r) => (r.avgMinutes) > 40.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  icon: Icons.delivery_dining,
                  title: 'Mapa de calor de entregas',
                  subtitle: _range == null
                      ? 'Período: mês atual • Agrupando por $_groupBy'
                      : 'Período: ${_fmt(_range!.start)} - ${_fmt(_range!.end)} • Agrupando por $_groupBy',
                  badge: hasSlowRegion
                      ? const DashboardBadge(
                          label: '🛑 SLA > 40min',
                          background: Color(0xFFFFEBEE),
                          foreground: Color(0xFFC62828),
                          icon: Icons.access_time_filled_rounded,
                        )
                      : const DashboardBadge(
                          label: '⚡ tudo dentro do SLA',
                          background: Color(0xFFE8F5E9),
                          foreground: Color(0xFF2E7D32),
                          icon: Icons.check_circle,
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: _groupBy,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _groupBy = v;
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'bairro',
                            child: Text('Por bairro'),
                          ),
                          DropdownMenuItem(
                            value: 'cidade',
                            child: Text('Por cidade'),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 1),
                            initialDateRange: _range ??
                                DateTimeRange(
                                  start: now.subtract(const Duration(days: 7)),
                                  end: now,
                                ),
                          );
                          if (picked != null) {
                            setState(() {
                              _range = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // filtros rápidos
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Só SLA > 40min'),
                      selected: _onlySlow,
                      onSelected: (v) {
                        setState(() {
                          _onlySlow = v;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mostrando ${visible.length} de ${filtered.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (hasMore)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _maxItems += 10;
                          });
                        },
                        child: const Text('Ver mais'),
                      ),
                    if (!hasMore && filtered.length > 10)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _maxItems = 10;
                          });
                        },
                        child: const Text('Voltar'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  const Text('Nenhuma região com entregas suficientes.')
                else
                  Column(
                    children: visible.map((r) {
                      final avgMinutes = r.avgMinutes;
                      final isSlow = avgMinutes > 40;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.location_on,
                          color: isSlow ? Colors.red : Colors.green,
                        ),
                        title: Text(r.label),
                        subtitle: Text(
                          'Entregas: ${r.deliveryCount} • SLA médio: ${avgMinutes.toStringAsFixed(1)} min'
                          ' • P90: ${r.p90Minutes != null ? '${r.p90Minutes!.toStringAsFixed(1)} min' : '—'}'
                          ' • Evolução: ${r.wowChangePct != null ? '${r.wowChangePct!.toStringAsFixed(1)}%' : '—'}',
                        ),
                        trailing: isSlow
                            ? const Chip(
                                label: Text(
                                  'SLA > 40min',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.red,
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                if (worstRegion != null) ...[
                  const SizedBox(height: 12),
                  _DeliveryInsightBox(
                    worstRegion: worstRegion,
                    groupBy: _groupBy,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<_UiRegion> _groupByCity(List<DeliveryRegionInsight> original) {
    final Map<String, _UiRegion> map = {};

    for (final r in original) {
      final key = r.city.isNotEmpty ? r.city : 'Sem cidade';
      if (!map.containsKey(key)) {
        map[key] = _UiRegion(
          label: key,
          city: key,
          deliveryCount: r.deliveryCount,
          avgMinutes: r.avgDeliveryMinutes,
          p90Minutes: r.p90DeliveryMinutes,
          wowChangePct: r.weekOverWeekChangePct,
        );
      } else {
        final current = map[key]!;
        final totalDeliveries = current.deliveryCount + r.deliveryCount;

        final weightedAvg = ((current.avgMinutes * current.deliveryCount) +
                (r.avgDeliveryMinutes * r.deliveryCount)) /
            totalDeliveries;

        map[key] = _UiRegion(
          label: key,
          city: key,
          deliveryCount: totalDeliveries,
          avgMinutes: weightedAvg,
          p90Minutes: current.p90Minutes ?? r.p90DeliveryMinutes,
          wowChangePct: current.wowChangePct ?? r.weekOverWeekChangePct,
        );
      }
    }

    final list = map.values.toList()
      ..sort(
        (a, b) => b.deliveryCount.compareTo(a.deliveryCount),
      );
    return list;
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _UiRegion {
  final String label;
  final String city;
  final int deliveryCount;
  final double avgMinutes;
  final double? p90Minutes;
  final double? wowChangePct;

  _UiRegion({
    required this.label,
    required this.city,
    required this.deliveryCount,
    required this.avgMinutes,
    this.p90Minutes,
    this.wowChangePct,
  });
}

class _DeliveryInsightBox extends StatelessWidget {
  final _UiRegion worstRegion;
  final String groupBy;

  const _DeliveryInsightBox({
    required this.worstRegion,
    required this.groupBy,
  });

  @override
  Widget build(BuildContext context) {
    final name = worstRegion.label;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFFE65100)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Insight: ${groupBy == 'bairro' ? 'Bairro' : 'Cidade'} "$name" está com SLA médio de ${worstRegion.avgMinutes.toStringAsFixed(1)} min. Sugerir reordenar entregas ou criar rota dedicada para essa região.',
              style: const TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
