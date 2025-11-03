import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nola_kitchensights_app/widgets/revenue_overview_widget.dart';
import 'package:nola_kitchensights_app/providers/widget_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RevenueOverviewWidget', () {
    testWidgets('exibe top canais e badge de queda (>10%)',
        (WidgetTester tester) async {
      // --- arrange
      final start = DateTime(2025, 10, 1);
      final end = DateTime(2025, 10, 31);

      final fake = RevenueOverviewResponse(
        storeId: 1,
        startDate: start,
        endDate: end,
        totalSales: 12345.67,
        totalOrders: 321,
        averageTicket: 38.45,
        salesChangePct: -12.3, // força badge de queda
        ordersChangePct: -4.1,
        topChannels: <RevenueTopChannel>[
          RevenueTopChannel(channel: 'iFood', totalSales: 7000, sharePct: 56.7),
          RevenueTopChannel(channel: 'Rappi', totalSales: 3500, sharePct: 28.3),
          RevenueTopChannel(channel: 'WhatsApp', totalSales: 1800, sharePct: 14.6),
        ],
        dailyBreakdown: const [],
      );

      final params = (
        storeId: 1,
        startDate: start,
        endDate: end,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            revenueOverviewProvider.overrideWith((ref, p) async {
              // garante que estamos recebendo o mesmo parâmetro da UI
              expect(p.storeId, params.storeId);
              expect(p.startDate, params.startDate);
              expect(p.endDate, params.endDate);
              return fake;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RevenueOverviewWidget(
                storeId: 1,
                startDate: DateTime(2025, 10, 1),
                endDate: DateTime(2025, 10, 31),
              ),
            ),
          ),
        ),
      );

      // carrega (primeiro frame mostra CircularProgressIndicator)
      await tester.pump();

      // --- assert

      // Não exigimos "exatamente 1" porque há dois textos "Faturamento" (título e label do tile).
      expect(find.text('Faturamento'), findsAtLeastNWidgets(1));

      // Badge de queda agora tem o sufixo "• em relação ao período anterior"
      expect(
        find.textContaining('queda > 10%'),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.textContaining('em relação ao período anterior'),
        findsAtLeastNWidgets(1),
      );

      // Top canais (nomes + porcentagens)
      expect(find.text('iFood'), findsOneWidget);
      expect(find.textContaining('56.7%'), findsOneWidget);

      expect(find.text('Rappi'), findsOneWidget);
      expect(find.textContaining('28.3%'), findsOneWidget);

      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.textContaining('14.6%'), findsOneWidget);
    });
  });
}
