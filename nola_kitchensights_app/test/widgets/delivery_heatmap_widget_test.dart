// test/widgets/delivery_heatmap_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/widgets/delivery_heatmap_widget.dart';
import 'package:nola_kitchensights_app/providers/widget_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeliveryHeatmapWidget', () {
    testWidgets('renderiza lista básica e badge de SLA quando > 40min',
        (WidgetTester tester) async {
      // --- arrange
      final regions = <DeliveryRegionInsight>[
        DeliveryRegionInsight(
          neighborhood: 'Centro',
          city: 'São Paulo',
          deliveryCount: 42,
          avgDeliveryMinutes: 45.5, // > 40 => badge vermelho
          p90DeliveryMinutes: 60.0,
          weekOverWeekChangePct: 5.0,
        ),
        DeliveryRegionInsight(
          neighborhood: 'Moema',
          city: 'São Paulo',
          deliveryCount: 30,
          avgDeliveryMinutes: 28.0,
          p90DeliveryMinutes: 40.0,
          weekOverWeekChangePct: -2.0,
        ),
      ];

      final fake = DeliveryHeatmapResponse(
        storeId: 1,
        periodStart: '2025-10-01',
        periodEnd: '2025-10-31',
        regions: regions,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryHeatmapProvider.overrideWith((ref, params) async {
              expect(params.storeId, 1);
              return fake;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeliveryHeatmapWidget(storeId: 1),
            ),
          ),
        ),
      );

      // primeiro frame (loading)
      await tester.pump();

      // --- assert
      expect(find.textContaining('Mapa de calor de entregas'), findsOneWidget);

      // títulos das linhas (match EXATO pra não bater no insight)
      expect(find.text('Centro • São Paulo'), findsOneWidget);
      expect(find.text('Moema • São Paulo'), findsOneWidget);

      // badge: match EXATO (evita confundir com o chip "Só SLA > 40min")
      expect(find.text('🛑 SLA > 40min'), findsOneWidget);

      // textos de tempo médio e P90
      expect(find.textContaining('Tempo de entrega médio'), findsWidgets);
      expect(find.textContaining('P90'), findsWidgets);
    });
  });
}
