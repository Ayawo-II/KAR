import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/database_helper.dart';
import 'screens/configuration_screen.dart';
import 'screens/deverrouillage_screen.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Symboles de dates francaises, utilises par TableCalendar.
  await initializeDateFormatting('fr_FR', null);

  final appState = AppState();
  await appState.initialiser();

  // La base n'est ouverte qu'a l'ouverture effective : elle ne doit pas etre
  // creee avant que la premiere configuration soit terminee.
  if (!appState.aConfigurer) await DatabaseHelper.instance.database;

  runApp(AppStateScope(state: appState, child: const KarApp()));
}

class KarApp extends StatelessWidget {
  const KarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KAR',
      theme: AppTheme.clair(),
      darkTheme: AppTheme.sombre(),
      themeMode: appState.themeMode,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Accueil(),
    );
  }
}

/// Aiguille entre la configuration initiale, le verrou, et le tableau de bord.
class _Accueil extends StatefulWidget {
  const _Accueil();

  @override
  State<_Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<_Accueil> {
  bool _configurationTerminee = false;
  bool _verrouille = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configurationTerminee) return;

    final appState = AppStateScope.of(context);

    // La configuration initiale n'est proposee qu'une fois : le flag reste a
    // faux tant que l'utilisateur ne l'a pas terminee. Le verrouillage, lui,
    // ne s'affiche que s'il a ete active.
    _configurationTerminee = !appState.aConfigurer;
    _verrouille = appState.verrouillageActif;
  }

  @override
  Widget build(BuildContext context) {
    if (!_configurationTerminee) {
      return ConfigurationScreen(onTermine: _ouvrirBase);
    }

    if (_verrouille) {
      return DeverrouillageScreen(
        onDebloque: () => setState(() => _verrouille = false),
        onVerrouillageDesactive: _desactiverVerrouillage,
      );
    }

    return HomeScreen(onVerrouiller: () => setState(() => _verrouille = true));
  }

  /// La base n'est creee qu'apres la premiere configuration.
  Future<void> _ouvrirBase() async {
    await DatabaseHelper.instance.database;
    if (!mounted) return;

    await AppStateScope.read(context).marquerConfigure();
    if (!mounted) return;

    setState(() {
      _configurationTerminee = true;

      // L'application vient d'etre configuree : la demander au meme moment
      // serait absurde.
      _verrouille = false;
    });
  }

  /// Le verrouillage etant facultatif, un utilisateur bloque peut le couper.
  /// Aucune donnee n'est perdue : c'est la seule raison d'edition restante.
  Future<void> _desactiverVerrouillage() async {
    await AppStateScope.read(context).desactiverVerrouillage();
    if (!mounted) return;

    setState(() {
      _verrouille = false;
      _configurationTerminee = true;
    });
  }
}
