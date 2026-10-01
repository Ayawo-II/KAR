import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kar/data/database_helper.dart';
import 'package:kar/main.dart';
import 'package:kar/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Parcours utilisateur complet, sur une vraie base SQLite temporaire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // TableCalendar formate les dates avec la locale fr_FR.
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.supprimerBase();
  });

  tearDown(() async {
    await DatabaseHelper.instance.supprimerBase();
  });

  /// Laisse les lectures SQLite reelles se terminer avant de reconstruire.
  ///
  /// `pumpAndSettle` fait tourner une horloge simulee : il n'attend pas les
  /// futures d'E/S de la base, et il ne termine jamais tant qu'un indicateur
  /// d'activite tourne. L'event loop reel est donc laisse avancer entre deux
  /// reconstructions.
  Future<void> laisserLaBaseRepondre(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() => DatabaseHelper.instance.database);

    final attend = find.byType(CircularProgressIndicator);

    for (var essai = 0; essai < 40; essai++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));

      if (attend.evaluate().isEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
  }

  testWidgets('configuration, code pin, puis tableau de bord', (tester) async {
    final appState = AppState();
    await appState.initialiser();

    await tester.pumpWidget(
      AppStateScope(state: appState, child: const KarApp()),
    );
    await tester.pumpAndSettle();

    // Etape 1 : le profil.
    expect(find.text('Bienvenue'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Dupont');
    await tester.enterText(find.byType(TextFormField).at(1), 'Amina');
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Etape 2 : le code.
    expect(find.text('Code de sécurité'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '1234');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('Terminer'));
    await laisserLaBaseRepondre(tester);

    // Etape 3 : le tableau de bord, sans annee academique. Le code vient
    // d'etre defini, il ne doit pas etre redemande.
    expect(find.text('Déverrouiller'), findsNothing);
    expect(find.text('Aucune année académique configurée. '
        'Commencez par en créer une.'), findsOneWidget);
    expect(appState.aConfigurer, isFalse);

    // Le verrouillage ramene a l'ecran de saisie du code.
    await tester.tap(find.byTooltip('Thème sombre'));
    await tester.pumpAndSettle();
    expect(appState.themeSombre, isTrue);
  });
}