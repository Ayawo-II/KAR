import 'package:flutter_test/flutter_test.dart';
import 'package:kar/main.dart';

void main() {
  testWidgets('KAR app shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
  });
}