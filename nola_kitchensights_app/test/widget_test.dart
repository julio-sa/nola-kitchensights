// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nola_kitchensights_app/main.dart';

void main() {
  testWidgets('app carrega dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const NolaKitchenSightsApp());
    expect(find.text('KitchenSights'), findsOneWidget);
  });
}
