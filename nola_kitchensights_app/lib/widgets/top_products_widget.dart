import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/widget_provider.dart';

class TopProductsWidget extends ConsumerStatefulWidget {
  final int storeId;

  const TopProductsWidget({super.key, required this.storeId});

  @override
  ConsumerState<TopProductsWidget> createState() => _TopProductsWidgetState();
}

class _TopProductsWidgetState extends ConsumerState<TopProductsWidget> {
  final List<String> _channels = const ['iFood', 'Rappi', 'Presencial', 'WhatsApp'];
  final Map<int, String> _weekdays = const {
    1: 'Segunda',
    2: 'Terça',
    3: 'Quarta',
    4: 'Quinta',
    5: 'Sexta',
    6: 'Sábado',
    7: 'Domingo',
  };

  String _selectedChannel = 'iFood';
  int _selectedDay = 5;
  int _hourStart = 18;
  int _hourEnd = 23;

  void _updateHourStart(int? value) {
    if (value == null) return;
    setState(() {
      _hourStart = value;
      if (_hourStart > _hourEnd) {
        _hourEnd = _hourStart;
      }
    });
  }

  void _updateHourEnd(int? value) {
    if (value == null) return;
    setState(() {
      _hourEnd = value;
      if (_hourEnd < _hourStart) {
        _hourStart = _hourEnd;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filterArgs = {
      'store_id': widget.storeId,
      'channel': _selectedChannel,
      'day_of_week': _selectedDay,
      'hour_start': _hourStart,
      'hour_end': _hourEnd,
    };
    final productsFuture = ref.watch(topProductsProvider(filterArgs));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Produtos que lideram em ${_weekdays[_selectedDay]} ($_selectedChannel)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  tooltip: 'Atualizar',
                  onPressed: () => ref.invalidate(topProductsProvider(filterArgs)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                DropdownButton<String>(
                  value: _selectedChannel,
                  items: _channels
                      .map((channel) => DropdownMenuItem(
                            value: channel,
                            child: Text(channel),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedChannel = value ?? _selectedChannel),
                ),
                DropdownButton<int>(
                  value: _selectedDay,
                  items: _weekdays.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedDay = value ?? _selectedDay),
                ),
                DropdownButton<int>(
                  value: _hourStart,
                  items: List.generate(
                    24,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text('${index.toString().padLeft(2, '0')}h'),
                    ),
                  ),
                  onChanged: _updateHourStart,
                ),
                DropdownButton<int>(
                  value: _hourEnd,
                  items: List.generate(
                    24,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text('${index.toString().padLeft(2, '0')}h'),
                    ),
                  ),
                  onChanged: _updateHourEnd,
                ),
              ],
            ),
            const SizedBox(height: 12),
            productsFuture.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Erro: $err'),
              data: (response) {
                if (response.products.isEmpty) {
                  return const Text('Nenhum dado encontrado para o filtro selecionado.');
                }
                return Column(
                  children: response.products.take(10).map((product) {
                    final trend = product['week_over_week_change_pct'] as double?;
                    final isPositive = trend != null && trend >= 0;
                    return ListTile(
                      dense: true,
                      title: Text(product['product_name'] as String),
                      subtitle: Text('${product['total_quantity_sold']} vendidos'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('R\$ ${(product['total_revenue'] as double).toStringAsFixed(2)}'),
                          if (trend != null)
                            Text(
                              '${isPositive ? '↑' : '↓'} ${trend.abs().toStringAsFixed(1)}%',
                              style: TextStyle(color: isPositive ? Colors.green : Colors.red),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
