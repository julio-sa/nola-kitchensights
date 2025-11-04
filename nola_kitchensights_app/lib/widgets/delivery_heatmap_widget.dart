// lib/widgets/delivery_heatmap_widget.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show deliveryHeatmapProvider, DeliveryRegionInsight;
import 'package:nola_kitchensights_app/data/params/widget_params.dart' as wp;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';
import 'package:nola_kitchensights_app/providers/my_stores_provider.dart';

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

class _DeliveryHeatmapWidgetState extends ConsumerState<DeliveryHeatmapWidget> {
  // Loja selecionada
  late int _storeId;

  // Filtros
  DateTimeRange? _range;
  String _groupBy = 'bairro'; // 'bairro' | 'cidade'
  bool _onlySlow = false;
  int _maxItems = 10;

  @override
  void initState() {
    super.initState();
    _storeId = widget.storeId;
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(myStoresProvider);

    final params = wp.DeliveryHeatmapParams(
      storeId: _storeId,
      startDate: _range?.start,
      endDate: _range?.end,
    );

    final heatmapFuture = ref.watch(deliveryHeatmapProvider(params));
    final storeName = _resolveStoreName(storesAsync, _storeId);

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
            // ---- Montagem das regiões por modo ----
            final List<_UiRegion> regions;
            if (_groupBy == 'bairro') {
              regions = heatmap.regions.map<_UiRegion>((r) {
                final displayCity = r.city;
                final normCity = _normCity(displayCity);
                return _UiRegion(
                  label: '${r.neighborhood} • $displayCity',
                  city: normCity, // usar cidade normalizada internamente
                  deliveryCount: r.deliveryCount,
                  avgMinutes: r.avgDeliveryMinutes,
                  p90Minutes: r.p90DeliveryMinutes,
                  wowChangePct: r.weekOverWeekChangePct,
                );
              }).toList();
            } else {
              regions = _groupByCity(heatmap.regions);
            }

            // filtro SLA > 40
            List<_UiRegion> filtered = regions;
            if (_onlySlow) {
              filtered = filtered.where((r) => r.avgMinutes > 40.0).toList();
            }

            // ordenação por SLA desc
            filtered.sort((a, b) => b.avgMinutes.compareTo(a.avgMinutes));

            // pior região (insight)
            final _UiRegion? worstRegion =
                filtered.isNotEmpty ? filtered.first : null;

            // paginação simples
            final visible = filtered.take(_maxItems).toList();
            final hasMore = filtered.length > _maxItems;

            final hasSlowRegion = filtered.any((r) => r.avgMinutes > 40.0);

            final periodText = _range == null
                ? 'Período: mês atual'
                : 'Período: ${_fmt(_range!.start)} - ${_fmt(_range!.end)}';
            final groupText =
                _groupBy == 'bairro' ? 'Agrupando por bairro' : 'Agrupando por cidade';

            // (debug) checagem opcional de inconsistência
            final List<_UiRegion> byCityForCheck =
                (_groupBy == 'cidade') ? regions : _groupByCity(heatmap.regions);
            final List<_UiRegion> byBairroForCheck =
                (_groupBy == 'bairro') ? regions : heatmap.regions
                    .map<_UiRegion>((r) => _UiRegion(
                          label: '${r.neighborhood} • ${_normCity(r.city)}',
                          city: _normCity(r.city),
                          deliveryCount: r.deliveryCount,
                          avgMinutes: r.avgDeliveryMinutes,
                          p90Minutes: r.p90DeliveryMinutes,
                          wowChangePct: r.weekOverWeekChangePct,
                        ))
                    .toList();
            final bool inconsistent =
                kDebugMode ? _hasInconsistency(byBairroForCheck, byCityForCheck) : false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  icon: Icons.delivery_dining,
                  title: 'Mapa de calor de entregas',
                  subtitle: '$storeName • $periodText • $groupText',
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
                  trailing: IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filtros',
                    onPressed: () => _openFilters(context, storesAsync),
                  ),
                ),
                const SizedBox(height: 8),

                // linha de chips rápidos
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Só SLA > 40min'),
                      selected: _onlySlow,
                      onSelected: (v) => setState(() => _onlySlow = v),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mostrando ${visible.length} de ${filtered.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (hasMore)
                      TextButton(
                        onPressed: () => setState(() => _maxItems += 10),
                        child: const Text('Ver mais'),
                      ),
                    if (!hasMore && filtered.length > 10)
                      TextButton(
                        onPressed: () => setState(() => _maxItems = 10),
                        child: const Text('Voltar'),
                      ),
                  ],
                ),
                if (inconsistent) ...[
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: Icon(Icons.info, size: 16),
                      label: Text(
                        'Aviso (debug): verifique normalização de cidade/bairro',
                      ),
                    ),
                  ),
                ],
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
                          'Entregas: ${r.deliveryCount} • Tempo de entrega médio: ${avgMinutes.toStringAsFixed(1)} min'
                          ' • P90 (90% das entregas até): ${r.p90Minutes != null ? '${r.p90Minutes!.toStringAsFixed(1)} min' : '—'}'
                          ' • Evolução: ${r.wowChangePct != null ? '${r.wowChangePct!.toStringAsFixed(1)}%' : '— (sem comparação)'}',
                        ),
                        trailing: isSlow
                            ? const Chip(
                                label: Text(
                                  'Tempo de Entrega > 40min',
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

  Future<void> _openFilters(
      BuildContext context, AsyncValue<List<KitchenStoreRef>> storesAsync) async {
    int tmpStore = _storeId;
    String tmpGroupBy = _groupBy;
    DateTimeRange tmpRange = _range ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final storeItems = storesAsync.maybeWhen(
              data: (stores) => _storeItems(stores),
              orElse: () => <DropdownMenuItem<int>>[],
            );
            final safeValue = _safeValue(tmpStore, storeItems);

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
                    'Filtros do mapa de calor',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  // Loja
                  DropdownButtonFormField<int>(
                    key: ValueKey('store_${storeItems.length}_$safeValue'),
                    value: safeValue,
                    items: storeItems,
                    decoration: const InputDecoration(
                      labelText: 'Loja',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      if (v != null) setModalState(() => tmpStore = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Agrupamento
                  DropdownButtonFormField<String>(
                    value: tmpGroupBy,
                    items: const [
                      DropdownMenuItem(value: 'bairro', child: Text('Por bairro')),
                      DropdownMenuItem(value: 'cidade', child: Text('Por cidade')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Agrupamento',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      if (v != null) setModalState(() => tmpGroupBy = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Período
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
                              setModalState(() => tmpRange = picked);
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
                              _storeId = tmpStore;
                              _groupBy = tmpGroupBy;
                              _range = tmpRange;
                              _maxItems = 10; // reset ao aplicar
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

  // ---------- Agrupamento por cidade (com normalização) ----------
  List<_UiRegion> _groupByCity(List<DeliveryRegionInsight> original) {
    final Map<String, _UiRegion> map = {};

    for (final r in original) {
      final key = _normCity(r.city);
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
            (totalDeliveries == 0 ? 1 : totalDeliveries);

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
      ..sort((a, b) => b.deliveryCount.compareTo(a.deliveryCount));
    return list;
  }

  // ---------- Helpers ----------
  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _resolveStoreName(AsyncValue<List<KitchenStoreRef>> async, int id) {
    return async.maybeWhen(
      data: (stores) {
        final hit = stores.where((s) => s.id == id);
        return hit.isNotEmpty ? hit.first.name : 'Loja #$id';
      },
      orElse: () => 'Loja #$id',
    );
  }

  List<DropdownMenuItem<int>> _storeItems(List<KitchenStoreRef> stores) {
    final seen = <int>{};
    final items = <DropdownMenuItem<int>>[];
    for (final s in stores) {
      if (seen.add(s.id)) {
        items.add(DropdownMenuItem<int>(value: s.id, child: Text(s.name)));
      }
    }
    return items;
  }

  T? _safeValue<T>(T? value, List<DropdownMenuItem<T>> items) {
    if (value == null) return items.isNotEmpty ? items.first.value : null;
    final matches = items.where((it) => it.value == value).length;
    if (matches == 1) return value;
    return items.isNotEmpty ? items.first.value : null;
  }

  // Normalização simples de cidade (case/acentos/espacos)
  String _normCity(String? s) {
    if (s == null) return 'sem_cidade';
    var t = s.trim().toLowerCase();
    if (t.isEmpty) return 'sem_cidade';
    // substituições rápidas (pode trocar por um normalizador mais robusto se quiser)
    t = t
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ß', 'ss');
    return t;
  }

  // Checagem opcional de inconsistência (debug)
  bool _hasInconsistency(List<_UiRegion> bairros, List<_UiRegion> cidades) {
    final cityTotals = <String, int>{};
    for (final c in cidades) {
      cityTotals[c.city] = (cityTotals[c.city] ?? 0) + c.deliveryCount;
    }
    for (final b in bairros) {
      final cityTotal = cityTotals[b.city] ?? 0;
      if (cityTotal > 0 && b.deliveryCount > cityTotal) {
        return true;
      }
    }
    return false;
  }
}

class _UiRegion {
  final String label;
  final String city; // normalizada
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
              'Insight: ${groupBy == 'bairro' ? 'Bairro' : 'Cidade'} "$name" está com Tempo de entrega médio de ${worstRegion.avgMinutes.toStringAsFixed(1)} min. Sugerir reordenar entregas ou criar rota dedicada para essa região.',
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
