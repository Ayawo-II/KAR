import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/securite_service.dart';
import '../state/app_state.dart';

/// Ecran de verrouillage, affiche au demarrage quand le verrouillage est actif.
///
/// La securite de l'appareil est tentee sans attendre : le code de l'application
/// n'est propose qu'en repli, quand l'appareil ne sait pas s'authentifier ou
/// quand l'utilisateur a refuse l'authentification systeme.
class DeverrouillageScreen extends StatefulWidget {
  /// Appele apres une authentification reussie.
  final VoidCallback onDebloque;

  /// Appele quand l'utilisateur ne peut plus authentifier. Le verrouillage
  /// etant facultatif, la seule issue reste de le desactiver : les donnees
  /// ne sont pas perdues.
  final VoidCallback onVerrouillageDesactive;

  const DeverrouillageScreen({
    required this.onDebloque,
    required this.onVerrouillageDesactive,
    super.key,
  });

  @override
  State<DeverrouillageScreen> createState() => _DeverrouillageScreenState();
}

class _DeverrouillageScreenState extends State<DeverrouillageScreen> {
  final _pin = TextEditingController();
  final _erreur = TextEditingController();

  late final SecuriteService _securite = AppStateScope.read(
    context,
  ).securiteService;

  late final bool _appareilSecurise = AppStateScope.read(
    context,
  ).appareilSecurise;

  bool _erreurVisible = false;
  bool _authentificationEnCours = false;

  /// L'authentification systeme a ete tentee sans reussir : le code de
  /// l'application peut etre saisi.
  bool _repliCode = false;

  /// Un code de secours existe dans les preferences.
  bool _codeDisponible = false;

  bool _verrouille = false;
  Timer? _minuterieBlocage;
  Duration _resteBlocage = Duration.zero;
  int _tentativesRestantes = 0;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  @override
  void dispose() {
    _minuterieBlocage?.cancel();
    _pin.dispose();
    _erreur.dispose();
    super.dispose();
  }

  Future<void> _initialiser() async {
    final codeDisponible = await _securite.pinSecoursDefini();
    if (!mounted) return;
    setState(() => _codeDisponible = codeDisponible);

    await _lireBlocage();

    if (_appareilSecurise) _authentifier();
  }

  /// Le code de l'application n'est saisissable que s'il existe, et seulement
  /// en repli de la securite de l'appareil.
  bool get _champCodeVisible =>
      _codeDisponible && (_repliCode || !_appareilSecurise);

  Future<void> _lireBlocage() async {
    final reste = await _securite.dureeBlocageRestante();
    final restantes = await _securite.tentativesRestantes();
    if (!mounted) return;

    setState(() {
      _resteBlocage = reste ?? Duration.zero;
      _verrouille = _resteBlocage > Duration.zero;
      _tentativesRestantes = restantes;
    });

    if (_verrouille) _planifierMinuteur();
  }

  void _planifierMinuteur() {
    _minuterieBlocage?.cancel();
    _minuterieBlocage = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _resteBlocage -= const Duration(seconds: 1);
        if (_resteBlocage <= Duration.zero) {
          _resteBlocage = Duration.zero;
          _verrouille = false;
        }
      });

      if (!_verrouille) timer.cancel();
    });
  }

  /// Authentification par la securite de l'appareil : empreinte, visage, ou code
  /// de l'appareil si aucune empreinte n'est enregistree.
  Future<void> _authentifier() async {
    setState(() {
      _authentificationEnCours = true;
      _erreurVisible = false;
    });

    final reussi = await _securite.authentifier(raison: 'Déverrouiller KAR');

    if (!mounted) return;
    setState(() {
      _authentificationEnCours = false;
      _repliCode = true;
    });

    if (reussi) {
      widget.onDebloque();
      return;
    }

    _afficherErreur('Authentification refusée.');
  }

  /// Code de l'application, utilise quand la securite de l'appareil echoue.
  Future<void> _verifierCode() async {
    if (_verrouille) return;

    FocusScope.of(context).unfocus();

    final correct = await _securite.verifierPinSecours(_pin.text);
    if (!mounted) return;

    if (correct) {
      widget.onDebloque();
      return;
    }

    _pin.clear();
    await _lireBlocage();
    if (!mounted) return;

    setState(() {
      _erreur.text = _verrouille
          ? 'Trop de tentatives. Réessayez dans ${_texteRestant()}.'
          : 'Code incorrect.';
      _erreurVisible = true;
    });
  }

  void _afficherErreur(String texte) {
    setState(() {
      _erreur.text = texte;
      _erreurVisible = true;
    });
  }

  String _texteRestant() {
    final minutes = _resteBlocage.inMinutes;
    final secondes = _resteBlocage.inSeconds % 60;

    if (minutes > 0) {
      return '$minutes min ${secondes.toString().padLeft(2, '0')} s';
    }
    return '$secondes s';
  }

  Future<void> _confirmerOubli() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Désactiver le verrouillage ?'),
        content: const Text(
          'Le verrouillage n\'est qu\'une protection : le désactiver laisse '
          'accès à l\'application sans authentification. Vos données ne sont pas '
          'effacées, vous pourrez le réactiver dans les réglages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirme == true) widget.onVerrouillageDesactive();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text('KAR', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 32),
                  if (_champCodeVisible) ..._code(context),
                  if (_authentificationEnCours && !_champCodeVisible) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                  ],
                  if (_appareilSecurise && !_authentificationEnCours) ...[
                    if (_champCodeVisible)
                      TextButton(
                        onPressed: _verrouille ? null : _authentifier,
                        child: const Text(
                          'Utiliser la sécurité de l\'appareil',
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _authentifier,
                          child: const Text('Déverrouiller'),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  if (_erreurVisible && !_champCodeVisible)
                    Text(
                      _erreur.text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  if (_tentativesRestantes > 0 && !_verrouille) ...[
                    const SizedBox(height: 12),
                    Text(
                      '$_tentativesRestantes '
                      'tentative${_tentativesRestantes > 1 ? 's' : ''} '
                      'avant blocage',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _verrouille ? null : _confirmerOubli,
                    child: const Text('Je ne peux pas me déverrouiller'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _code(BuildContext context) {
    final theme = Theme.of(context);

    return [
      TextField(
        controller: _pin,
        autofocus: true,
        enabled: !_verrouille,
        obscureText: true,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: theme.textTheme.headlineSmall,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(SecuriteService.longueurPin),
        ],
        decoration: InputDecoration(
          labelText: 'Code de l\'application',
          hintText: '•' * SecuriteService.longueurPin,
          errorText: _erreurVisible ? _erreur.text : null,
        ),
        onSubmitted: (_) => _verifierCode(),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _verrouille ? null : _verifierCode,
          child: const Text('Déverrouiller'),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }
}
