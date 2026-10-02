import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kar/data/database_helper.dart';
import 'package:kar/main.dart';
import 'package:kar/services/securite_service.dart';
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

  testWidgets('configuration du profil, puis tableau de bord', (tester) async {
    final appState = AppState();
    await appState.initialiser();

    await tester.pumpWidget(
      AppStateScope(state: appState, child: const KarApp()),
    );
    await tester.pumpAndSettle();

    // Le profil, et lui seul : aucun code n'est demande.
    expect(find.text('Bienvenue'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Dupont');
    await tester.enterText(find.byType(TextFormField).at(1), 'Amina');
    await tester.tap(find.text('Terminer'));
    await laisserLaBaseRepondre(tester);

    // Le tableau de bord s'affiche : le verrouillage n'est pas actif, donc
    // rien n'est demande.
    expect(find.text('Déverrouiller'), findsNothing);
    expect(
      find.text(
        'Aucune année académique configurée. '
        'Commencez par en créer une.',
      ),
      findsOneWidget,
    );
    expect(appState.aConfigurer, isFalse);
    expect(appState.verrouillageActif, isFalse);
    expect(appState.profil.nomComplet, 'Dupont Amina');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('config_terminee'), isTrue);

    // L'etat de theme se recharge depuis les preferences.
    await tester.tap(find.byTooltip('Thème sombre'));
    await tester.pumpAndSettle();
    expect(appState.themeSombre, isTrue);
  });

  testWidgets('verrouillage actif : le code est demande au redemarrage', (
    tester,
  ) async {
    // Une installation deja configuree, verrouillage active, appareil sans
    // securite : le code de l'application fait foi.
    SharedPreferences.setMockInitialValues({'config_terminee': true});
    final service = SecuriteService();
    await service.definirPinSecours('1234');
    await service.activer();

    final appState = AppState();
    await appState.initialiser();

    expect(appState.aConfigurer, isFalse);
    expect(appState.verrouillageActif, isTrue);
    expect(appState.appareilSecurise, isFalse);

    await tester.pumpWidget(
      AppStateScope(state: appState, child: const KarApp()),
    );
    await laisserLaBaseRepondre(tester);

    expect(find.text('Déverrouiller'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Déverrouiller'));
    await laisserLaBaseRepondre(tester);

    expect(find.text('Déverrouiller'), findsNothing);
    expect(
      find.text(
        'Aucune année académique configurée. '
        'Commencez par en créer une.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('verrouillage actif, code oublie : il suffit de le couper', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'config_terminee': true});
    final service = SecuriteService();
    await service.definirPinSecours('1234');
    await service.activer();

    final appState = AppState();
    await appState.initialiser();

    await tester.pumpWidget(
      AppStateScope(state: appState, child: const KarApp()),
    );
    await laisserLaBaseRepondre(tester);

    await tester.tap(find.text('Je ne peux pas me déverrouiller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Désactiver'));
    await laisserLaBaseRepondre(tester);

    // Aucune donnee n'est effacee : seul le verrouillage est coupe.
    expect(appState.verrouillageActif, isFalse);
    expect(await service.pinSecoursDefini(), isTrue);
    expect(find.text('Déverrouiller'), findsNothing);
    expect(
      find.text(
        'Aucune année académique configurée. '
        'Commencez par en créer une.',
      ),
      findsOneWidget,
    );
  });
}
