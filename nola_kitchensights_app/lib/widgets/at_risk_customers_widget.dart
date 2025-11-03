// lib/widgets/at_risk_customers_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show atRiskCustomersProvider;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';
import 'package:nola_kitchensights_app/providers/my_stores_provider.dart';

class AtRiskCustomersWidget extends ConsumerStatefulWidget {
  final int storeId;

  const AtRiskCustomersWidget({
    super.key,
    required this.storeId,
  });

  @override
  ConsumerState<AtRiskCustomersWidget> createState() =>
      _AtRiskCustomersWidgetState();
}

class _AtRiskCustomersWidgetState
    extends ConsumerState<AtRiskCustomersWidget> {
  late int _storeId;
  int _maxItems = 10;

  @override
  void initState() {
    super.initState();
    _storeId = widget.storeId;
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(myStoresProvider);
    final customersFuture = ref.watch(atRiskCustomersProvider(_storeId));

    final storeName = _resolveStoreName(storesAsync, _storeId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: customersFuture.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text('Erro ao carregar clientes em risco: $err'),
          data: (resp) {
            final total = resp.customers.length;
            final hasCustomers = total > 0;

            // paginação igual ao Heatmap
            final visible = hasCustomers
                ? resp.customers.take(_maxItems).toList()
                : const <dynamic>[];
            final hasMore = total > _maxItems;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  icon: Icons.warning_amber_rounded,
                  title: 'Clientes em risco',
                  subtitle: hasCustomers
                      ? '$storeName • $total cliente(s) sem comprar há 30+ dias'
                      : '$storeName • Nenhum cliente crítico no período',
                  badge: hasCustomers
                      ? const DashboardBadge(
                          label: '🛑 ação sugerida',
                          background: Color(0xFFFFEBEE),
                          foreground: Color(0xFFC62828),
                          icon: Icons.campaign_rounded,
                        )
                      : const DashboardBadge(
                          label: '✅ carteira saudável',
                          background: Color(0xFFE8F5E9),
                          foreground: Color(0xFF2E7D32),
                          icon: Icons.check,
                        ),
                  // filtro único: escolher loja
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasCustomers)
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Lista de campanha gerada (simulação).',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Gerar lista'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.tune),
                        tooltip: 'Escolher loja',
                        onPressed: () => _openFilters(storesAsync),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                if (!hasCustomers)
                  const Text('Nenhum cliente em risco encontrado.')
                else ...[
                  // Lista paginada
                  Column(
                    children: visible.map((c) {
                      final days = c.daysSinceLastOrder;
                      final discount = _discountForDays(days); // regra do cupom
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.customerName),
                        subtitle: Text(
                          '${c.totalOrders} pedidos • há $days dias • última: ${c.lastOrderDate}',
                        ),
                        trailing: discount != null
                            ? DashboardBadge(
                                label: '${discount.toStringAsFixed(0)}% cupom',
                                background: const Color(0xFFE3F2FD),
                                foreground: const Color(0xFF0D47A1),
                                icon: Icons.local_offer,
                              )
                            : null,
                      );
                    }).toList(),
                  ),

                  // Ver mais / Voltar
                  Row(
                    children: [
                      Text(
                        'Mostrando ${visible.length} de $total',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      if (hasMore)
                        TextButton(
                          onPressed: () => setState(() => _maxItems += 10),
                          child: const Text('Ver mais'),
                        ),
                      if (!hasMore && total > 10)
                        TextButton(
                          onPressed: () => setState(() => _maxItems = 10),
                          child: const Text('Voltar'),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Insight explicando a regra do cupom
                  const _CouponInsightBox(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- Filtro (só loja) ----------------
  Future<void> _openFilters(
    AsyncValue<List<KitchenStoreRef>> storesAsync,
  ) async {
    if (!storesAsync.hasValue) return;
    final stores = storesAsync.value!;
    if (stores.isEmpty) return;

    int tmpStore = _storeId;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final items = _storeItems(stores);
            final safeValue = _safeValue(tmpStore, items);

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
                    'Clientes em risco — filtro de loja',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey('store_${items.length}_$safeValue'),
                    value: safeValue,
                    items: items,
                    decoration: const InputDecoration(
                      labelText: 'Loja',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      if (v != null) setModalState(() => tmpStore = v);
                    },
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
                              _maxItems = 10; // reset paginação
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

  // ---------------- Helpers ----------------

  /// Regra de cupom:
  /// - Antes de 60 dias: sem cupom
  /// - A partir de 60 dias: começa em 10% e sobe +10% a cada 10 dias
  /// - Teto: 60%
  double? _discountForDays(int days) {
    if (days < 60) return null;
    final steps = ((days - 60) / 10).floor();
    final discount = (10 + steps * 10).toDouble();
    return discount.clamp(10, 60).toDouble();
  }

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
          Icon(Icons.lightbulb_outline, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lógica do cupom: após 60 dias sem compra, o cliente entra em uma escada de incentivo '
              '(10% a partir do 60º dia, aumentando em +10% a cada 10 dias, até o teto de 60%). '
              'Ao realizar nova compra, a progressão é reiniciada.',
              style: TextStyle(color: Color(0xFF0D47A1)),
            ),
          ),
        ],
      ),
    );
  }
}
