import 'package:flutter_test/flutter_test.dart';
import 'package:kar/main.dart';
import 'package:kar/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('premiere ouverture : ecran de configuration', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final appState = AppState();
    await appState.initialiser();

    await tester.pumpWidget(
      AppStateScope(state: appState, child: const KarApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue'), findsOneWidget);
  });
}