// lib/widgets/top_products_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show topProductsProvider;
import 'package:nola_kitchensights_app/data/params/widget_params.dart'
    as wp;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';

class TopProductsWidget extends ConsumerStatefulWidget {
  final int storeId;

  const TopProductsWidget({
    super.key,
    required this.storeId,
  });

  @override
  ConsumerState<TopProductsWidget> createState() =>
      _TopProductsWidgetState();
}

class _TopProductsWidgetState extends ConsumerState<TopProductsWidget> {
  String _channel = 'iFood';
  int _dayOfWeek = DateTime.now().weekday;
  int _hourStart = 0;
  int _hourEnd = 23;

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
    final params = wp.TopProductsParams(
      storeId: widget.storeId,
      channel: _channel,
      dayOfWeek: _dayOfWeek,
      hourStart: _hourStart,
      hourEnd: _hourEnd,
    );

    final productsFuture = ref.watch(topProductsProvider(params));

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
            final hasCritical = top.products.any(
              (p) => (p.weekOverWeekChangePct ?? 0) <= -30,
            );
            final criticalProduct = hasCritical
                ? top.products.firstWhere(
                    (p) => (p.weekOverWeekChangePct ?? 0) <= -30,
                  )
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
                  subtitle:
                      'Canal: $_channel • Dia: $_dayLabel • ${_hourStart}h–${_hourEnd}h',
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
                    onPressed: () => _openFilters(context),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
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

  Future<void> _openFilters(BuildContext context) async {
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
                      if (v != null) {
                        setModalState(() => tmpChannel = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
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
                      if (v != null) {
                        setModalState(() => tmpDay = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
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
                                if (tmpEnd < tmpStart) {
                                  tmpEnd = tmpStart;
                                }
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
                                if (tmpEnd < tmpStart) {
                                  tmpStart = tmpEnd;
                                }
                              });
                            }
                          },
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
