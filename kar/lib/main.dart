import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database_helper.dart';
import 'screens/configuration_screen.dart';
import 'screens/home_screen.dart';
import 'screens/verrouillage_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Symboles de dates francaises, utilises par TableCalendar.
  await initializeDateFormatting('fr_FR', null);

  final appState = AppState();
  await appState.initialiser();

  // La base n'est ouverte qu'a l'ouverture effective : elle ne doit pas etre
  // creee avant que le code PIN soit defini.
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

    // La configuration initiale n'est proposee qu'une fois : le flag reste a
    // faux tant que l'utilisateur ne l'a pas terminee.
    _configurationTerminee = !AppStateScope.of(context).aConfigurer;
  }

  @override
  Widget build(BuildContext context) {
    if (!_configurationTerminee) {
      return ConfigurationScreen(
        onTermine: _ouvrirBase,
      );
    }

    if (_verrouille) {
      return VerrouillageScreen(
        onDebloque: () => setState(() => _verrouille = false),
        onCodeOublie: _toutEffacer,
      );
    }

    return HomeScreen(
      onDeconnexion: () => setState(() => _verrouille = true),
    );
  }

  /// La base n'est creee qu'apres la saisie du premier code PIN.
  Future<void> _ouvrirBase() async {
    await DatabaseHelper.instance.database;
    if (!mounted) return;

    AppStateScope.read(context).marquerConfigure();
    setState(() {
      _configurationTerminee = true;

      // Le code vient d'etre defini : le redemander dans la foullee serait
      // absurde.
      _verrouille = false;
    });
  }

  /// Oubli du code : seule issue possible, efface preferences et base.
  Future<void> _toutEffacer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Réinitialisation'),
        content: const Text(
          'Le code est irrécupérable. Sa réinitialisation efface toutes les '
          'données de l\'application : année académique, matières, '
          'compositions, notes et programme de révision. Cette action est '
          'définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    await DatabaseHelper.instance.supprimerBase();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    AppStateScope.read(context).viderProfil();

    setState(() {
      _configurationTerminee = false;
      _verrouille = true;
    });
  }
}