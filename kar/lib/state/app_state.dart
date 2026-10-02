import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/securite_service.dart';

/// Etat global de l'application.
///
/// Volontairement minimal : l'application est mono-utilisateur, il n'y a donc
/// pas de session a partager ni de cache de donnees a distribuer. Seul le choix
/// de theme, le profil local et l'etat du verrouillage sont necessaires a
/// l'echelle de l'application.
class AppState extends ChangeNotifier {
  static const String _cleThemeSombre = 'theme_sombre';
  static const String _cleConfigure = 'config_terminee';

  final Profil _profil = Profil();

  /// Protection de l'application, partage pour que les reglages puissent
  /// activer le verrouillage sans recreer une instance.
  final SecuriteService securiteService = SecuriteService();

  bool _themeSombre = false;

  Profil get profil => _profil;

  ThemeMode get themeMode => _themeSombre ? ThemeMode.dark : ThemeMode.light;

  bool get themeSombre => _themeSombre;

  String get nomMenuBasculeTheme =>
      _themeSombre ? 'Thème clair' : 'Thème sombre';

  /// Vrai tant que la premiere ouverture n'est pas terminee.
  bool get aConfigurer => _aConfigurer;
  bool _aConfigurer = true;

  /// Vrai si l'utilisateur a demande un verrouillage a l'ouverture.
  ///
  /// Faux par defaut : sans code a taper, l'application s'ouvre directement.
  bool get verrouillageActif => _verrouillageActif;
  bool _verrouillageActif = false;

  /// Vrai si l'appareil sait authentifier l'utilisateur (empreinte, visage,
  /// code). Le code de l'application sert alors de secours.
  bool get appareilSecurise => _appareilSecurise;
  bool _appareilSecurise = false;

  /// Lit les preferences. A appeler une fois au demarrage, avant `runApp`.
  Future<void> initialiser() async {
    final prefs = await SharedPreferences.getInstance();
    _themeSombre = prefs.getBool(_cleThemeSombre) ?? false;

    // Les installations anterieures n'ont pas ce drapeau : leur configuration
    // s'achevait par la definition d'un code PIN, qui prouve qu'elle a ete
    // menee a son terme.
    final configurationLegacy = await securiteService.pinSecoursDefini();
    _aConfigurer = !(prefs.getBool(_cleConfigure) ?? configurationLegacy);

    _verrouillageActif = await securiteService.estActif();
    _appareilSecurise = await securiteService.appareilSecurise();

    await _profil.charger();
    notifyListeners();
  }

  /// Marque la configuration initiale comme terminee.
  Future<void> marquerConfigure() async {
    _aConfigurer = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleConfigure, true);
  }

  Future<void> activerVerrouillage() async {
    _verrouillageActif = true;
    notifyListeners();

    await securiteService.activer();
  }

  Future<void> desactiverVerrouillage() async {
    _verrouillageActif = false;
    notifyListeners();

    await securiteService.desactiver();
  }

  Future<void> basculerTheme() async {
    _themeSombre = !_themeSombre;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleThemeSombre, _themeSombre);
  }
}

/// Profil local de l'utilisateur.
///
/// L'application est mono-utilisateur : ces informations decrivent la seule
/// personne qui l'utilise et n'ont pas besoin d'etre en base.
class Profil {
  static const String _cleNom = 'profil_nom';
  static const String _clePrenoms = 'profil_prenoms';

  String _nom = '';
  String _prenoms = '';

  String get nom => _nom;
  String get prenoms => _prenoms;

  /// Nom et prenoms réunis, avec une espace seulement si les deux sont
  /// renseignes.
  String get nomComplet {
    if (_nom.isEmpty) return _prenoms;
    if (_prenoms.isEmpty) return _nom;
    return '$_nom $_prenoms';
  }

  /// Initiales affichees dans le tiroir, au plus deux caracteres.
  String get initiales {
    final n = _nom.isNotEmpty ? _nom[0] : '';
    final p = _prenoms.isNotEmpty ? _prenoms[0] : '';
    return '$n$p'.toUpperCase();
  }

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    _nom = prefs.getString(_cleNom) ?? '';
    _prenoms = prefs.getString(_clePrenoms) ?? '';
  }

  Future<void> enregistrer({
    required String nom,
    required String prenoms,
  }) async {
    _nom = nom.trim();
    _prenoms = prenoms.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleNom, _nom);
    await prefs.setString(_clePrenoms, _prenoms);
  }
}

/// Rend [AppState] accessible a la descendance.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState state,
    required super.child,
    super.key,
  }) : super(notifier: state);

  /// L'etat de l'application, avec dependance : l'element se reconstruit a
  /// chaque notification.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope est absent de l arborescence.');
    return scope!.notifier!;
  }

  /// L'etat de l'application, sans dependance : a utiliser dans les callbacks
  /// qui ne reconstruisent pas l'element.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope est absent de l arborescence.');
    return scope!.notifier!;
  }
}
