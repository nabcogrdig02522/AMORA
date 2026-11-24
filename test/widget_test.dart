import 'package:flutter_test/flutter_test.dart';
import 'package:amora/main.dart';
void main() {
  testWidgets('AMORA setup screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AmoraApp(configured: false));
    expect(find.text('Welcome to AMORA'), findsOneWidget);
  });
}
