// lib/widgets/at_risk_customers_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/providers/widget_provider.dart'
    show atRiskCustomersProvider;
import 'package:nola_kitchensights_app/widgets/dashboard_section_header.dart';

class AtRiskCustomersWidget extends ConsumerWidget {
  final int storeId;

  const AtRiskCustomersWidget({
    super.key,
    required this.storeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersFuture = ref.watch(atRiskCustomersProvider(storeId));

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
            final hasCustomers = resp.customers.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  icon: Icons.warning_amber_rounded,
                  title: 'Clientes em risco',
                  subtitle: hasCustomers
                      ? '${resp.customers.length} clientes sem comprar há 30+ dias'
                      : 'Nenhum cliente crítico no período',
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
                  trailing: hasCustomers
                      ? TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Lista de campanha gerada (simulação): aplicar cupom 10% a cada 10 dias até 60%.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Gerar lista'),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                if (!hasCustomers)
                  const Text('Nenhum cliente em risco encontrado.')
                else
                  ...resp.customers.take(5).map((c) {
                    final days = c.daysSinceLastOrder;
                    double? discount;
                    if (days >= 60) {
                      final steps = ((days - 60) / 10).floor();
                      discount = (10 + steps * 10).toDouble();
                      if (discount > 60) discount = 60;
                    }
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.customerName),
                      subtitle: Text(
                          '${c.totalOrders} pedidos • há $days dias • última: ${c.lastOrderDate}'),
                      trailing: discount != null
                          ? DashboardBadge(
                              label: '${discount.toStringAsFixed(0)}% cupom',
                              background: const Color(0xFFE3F2FD),
                              foreground: const Color(0xFF0D47A1),
                              icon: Icons.local_offer,
                            )
                          : null,
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
