import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/widgets/at_risk_customers_widget.dart';
import 'package:nola_kitchensights_app/providers/widget_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AtRiskCustomersWidget', () {
    testWidgets('Clientes em risco exibe cupom quando >=60 dias',
        (WidgetTester tester) async {
      // --- arrange
      final fake = AtRiskCustomersResponse(
        storeId: 1,
        customers: <AtRiskCustomer>[
          // 70 dias => 10% no 60º + +10% no 70º => 20% (dentro do teto 60)
          AtRiskCustomer(
            customerName: 'João',
            customerId: 101,
            totalOrders: 5,
            lastOrderDate: '2025-08-20',
            daysSinceLastOrder: 70,
          ),
          // 25 dias => sem cupom
          AtRiskCustomer(
            customerName: 'Ana',
            customerId: 102,
            totalOrders: 3,
            lastOrderDate: '2025-09-20',
            daysSinceLastOrder: 25,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            atRiskCustomersProvider.overrideWith((ref, storeId) async {
              expect(storeId, 1);
              return fake;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AtRiskCustomersWidget(storeId: 1),
            ),
          ),
        ),
      );

      // primeiro frame (loading)
      await tester.pump();

      // --- assert

      // Nomes aparecem
      expect(find.text('João'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);

      // Badge/Chip de cupom para o cliente com 70 dias.
      // Aqui usamos busca EXATA por "20% cupom" para não confundir com o texto do insight
      // que também contém a palavra "cupom".
      expect(find.text('20% cupom'), findsOneWidget);

      // E valida que o texto explicativo do insight existe, mas não afeta nosso matcher de badge
      expect(find.textContaining('Lógica do cupom'), findsOneWidget);
    });
  });
}
