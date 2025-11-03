// lib/widgets/top_products_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show topProductsProvider;
import 'package:nola_kitchensights_app/data/params/widget_params.dart' as wp;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';
import 'package:nola_kitchensights_app/providers/my_stores_provider.dart';

class TopProductsWidget extends ConsumerStatefulWidget {
  final int storeId;

  const TopProductsWidget({
    super.key,
    required this.storeId,
  });

  @override
  ConsumerState<TopProductsWidget> createState() => _TopProductsWidgetState();
}

class _TopProductsWidgetState extends ConsumerState<TopProductsWidget> {
  // Novo: manter loja selecionada em estado local
  late int _storeId;

  String _channel = 'iFood';
  int _dayOfWeek = DateTime.now().weekday;
  int _hourStart = 0;
  int _hourEnd = 23;

  @override
  void initState() {
    super.initState();
    _storeId = widget.storeId;
  }

  String get _dayLabel {
    const dias = {
      1: 'Segunda',
      2: 'Terça',
      3: 'Quarta',
      4: 'Quinta',
      5: 'Sexta',
      6: 'Sábado',
      7: 'Domingo',
    };
    return dias[_dayOfWeek] ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(myStoresProvider);

    final params = wp.TopProductsParams(
      storeId: _storeId,
      channel: _channel,
      dayOfWeek: _dayOfWeek,
      hourStart: _hourStart,
      hourEnd: _hourEnd,
    );

    final productsFuture = ref.watch(topProductsProvider(params));

    // Resolve nome da loja para UI
    final storeName = _resolveStoreName(storesAsync, _storeId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: productsFuture.when(
          loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text('Erro ao carregar produtos: $err'),
          data: (top) {
            final hasCritical =
                top.products.any((p) => (p.weekOverWeekChangePct ?? 0) <= -30);
            final criticalProduct = hasCritical
                ? top.products
                    .firstWhere((p) => (p.weekOverWeekChangePct ?? 0) <= -30)
                : null;

            final opportunityProduct = top.products.isNotEmpty
                ? top.products.reduce((curr, next) =>
                    (next.percentageOfTotal > curr.percentageOfTotal)
                        ? next
                        : curr)
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  icon: Icons.star,
                  title: 'Top produtos',
                  // Subtítulo pedido: Loja, Canal, Dia, Horário
                  subtitle:
                      '$storeName • Canal: $_channel • Dia: $_dayLabel • ${_hourStart}h–${_hourEnd}h',
                  badge: hasCritical
                      ? const DashboardBadge(
                          label: '🛑 produto caindo',
                          background: Color(0xFFFFF3E0),
                          foreground: Color(0xFFE65100),
                          icon: Icons.trending_down,
                        )
                      : (opportunityProduct != null
                          ? const DashboardBadge(
                              label: '⚡ oportunidade',
                              background: Color(0xFFE3F2FD),
                              foreground: Color(0xFF1565C0),
                              icon: Icons.campaign,
                            )
                          : null),
                  trailing: IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filtros',
                    onPressed: () => _openFilters(context, storesAsync),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // Chip com nome da loja
                    Chip(
                      label: Text(storeName),
                      avatar: const Icon(Icons.store, size: 16),
                    ),
                    Chip(
                      label: Text('Canal: $_channel'),
                      avatar: const Icon(Icons.campaign, size: 16),
                    ),
                    Chip(
                      label: Text('Dia: $_dayLabel'),
                      avatar: const Icon(Icons.calendar_today, size: 16),
                    ),
                    Chip(
                      label: Text('Hora: ${_hourStart}h - ${_hourEnd}h'),
                      avatar: const Icon(Icons.schedule, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (top.products.isEmpty)
                  const Text('Sem produtos nesse filtro.')
                else
                  Column(
                    children: top.products.take(5).map((p) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.productName),
                        subtitle: Text(
                          'Qtd: ${p.totalQuantitySold} • Faturou: R\$ ${p.totalRevenue.toStringAsFixed(2)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${p.percentageOfTotal.toStringAsFixed(1)}%'),
                            if (p.weekOverWeekChangePct != null)
                              Text(
                                '${p.weekOverWeekChangePct! >= 0 ? '↑' : '↓'} ${p.weekOverWeekChangePct!.abs().toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: p.weekOverWeekChangePct! >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                if (hasCritical && criticalProduct != null) ...[
                  const SizedBox(height: 12),
                  _InsightBox(
                    title: 'Produto perdendo tração',
                    message:
                        '${criticalProduct.productName} vendeu bem nesse horário na semana passada, mas caiu >30% agora. Sugerir destaque ou promoção nesse mesmo horário.',
                    tone: InsightTone.danger,
                  ),
                ] else if (opportunityProduct != null) ...[
                  const SizedBox(height: 12),
                  _InsightBox(
                    title: 'Produto com potencial',
                    message:
                        '${opportunityProduct.productName} representa ${opportunityProduct.percentageOfTotal.toStringAsFixed(1)}% do faturamento no filtro atual. Vale testar campanha nesse canal/dia/horário.',
                    tone: InsightTone.opportunity,
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
    // Valores temporários
    int tmpStore = _storeId;
    String tmpChannel = _channel;
    int tmpDay = _dayOfWeek;
    int tmpStart = _hourStart;
    int tmpEnd = _hourEnd;

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
                    'Filtros de Top produtos',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filtro de Loja
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

                  // Filtro de Canal
                  DropdownButtonFormField<String>(
                    initialValue: tmpChannel,
                    decoration: const InputDecoration(
                      labelText: 'Canal',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'iFood', child: Text('iFood')),
                      DropdownMenuItem(value: 'Rappi', child: Text('Rappi')),
                      DropdownMenuItem(
                          value: 'Uber Eats', child: Text('Uber Eats')),
                      DropdownMenuItem(
                          value: 'Presencial', child: Text('Presencial')),
                      DropdownMenuItem(
                          value: 'WhatsApp', child: Text('WhatsApp')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => tmpChannel = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Filtro de Dia
                  DropdownButtonFormField<int>(
                    initialValue: tmpDay,
                    decoration: const InputDecoration(
                      labelText: 'Dia da semana',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Segunda')),
                      DropdownMenuItem(value: 2, child: Text('Terça')),
                      DropdownMenuItem(value: 3, child: Text('Quarta')),
                      DropdownMenuItem(value: 4, child: Text('Quinta')),
                      DropdownMenuItem(value: 5, child: Text('Sexta')),
                      DropdownMenuItem(value: 6, child: Text('Sábado')),
                      DropdownMenuItem(value: 7, child: Text('Domingo')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => tmpDay = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Filtro de Hora
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: tmpStart,
                          decoration: const InputDecoration(
                            labelText: 'Hora início',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            24,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('${i.toString().padLeft(2, '0')}:00'),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() {
                                tmpStart = v;
                                if (tmpEnd < tmpStart) tmpEnd = tmpStart;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: tmpEnd,
                          decoration: const InputDecoration(
                            labelText: 'Hora fim',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            24,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('${i.toString().padLeft(2, '0')}:00'),
                            ),
                          ),
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() {
                                tmpEnd = v;
                                if (tmpEnd < tmpStart) tmpStart = tmpEnd;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Ações
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
                              _channel = tmpChannel;
                              _dayOfWeek = tmpDay;
                              _hourStart = tmpStart;
                              _hourEnd = tmpEnd;
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

  // ---------- helpers ----------
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
}

enum InsightTone { danger, opportunity }

class _InsightBox extends StatelessWidget {
  final String title;
  final String message;
  final InsightTone tone;

  const _InsightBox({
    required this.title,
    required this.message,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = tone == InsightTone.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDanger ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.lightbulb_outline,
            color: isDanger ? const Color(0xFFE65100) : const Color(0xFF1565C0),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDanger
                        ? const Color(0xFFE65100)
                        : const Color(0xFF0D47A1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: isDanger
                        ? const Color(0xFFE65100)
                        : const Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
