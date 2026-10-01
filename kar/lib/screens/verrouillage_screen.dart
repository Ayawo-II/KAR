import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_service.dart';
import '../state/app_state.dart';

/// Verrouillage par code PIN, affiche au demarrage de l'application.
class VerrouillageScreen extends StatefulWidget {
  /// Appele apres un code correct.
  final VoidCallback onDebloque;

  /// Appele quand l'utilisateur oublie son code. Le seul moyen de le
  /// reinitialiser est d'effacer les donnees de l'application, ce qui est
  /// signale explicitement.
  final VoidCallback onCodeOublie;

  const VerrouillageScreen({
    required this.onDebloque,
    required this.onCodeOublie,
    super.key,
  });

  @override
  State<VerrouillageScreen> createState() => _VerrouillageScreenState();
}

class _VerrouillageScreenState extends State<VerrouillageScreen> {
  final _pin = TextEditingController();
  final _erreur = TextEditingController();

  late final PinService _pinService = AppStateScope.read(context).pinService;

  bool _erreurVisible = false;
  bool _verrouille = false;

  Timer? _minuterieBlocage;
  Duration _resteBlocage = Duration.zero;
  int _tentativesRestantes = 0;

  @override
  void initState() {
    super.initState();
    _lireBlocage();
  }

  @override
  void dispose() {
    _minuterieBlocage?.cancel();
    _pin.dispose();
    _erreur.dispose();
    super.dispose();
  }

  Future<void> _lireBlocage() async {
    final reste = await _pinService.dureeBlocageRestante();
    final restantes = await _pinService.tentativesRestantes();
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

  Future<void> _verifier() async {
    if (_verrouille) return;

    FocusScope.of(context).unfocus();

    final correct = await _pinService.verifierPin(_pin.text);
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

  String _texteRestant() {
    final minutes = _resteBlocage.inMinutes;
    final secondes = _resteBlocage.inSeconds % 60;

    if (minutes > 0) return '$minutes min ${secondes.toString().padLeft(2, '0')} s';
    return '$secondes s';
  }

  Future<void> _confirmerOubli() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Code oublié'),
        content: const Text(
          'Il n\'existe pas de moyen de retrouver le code. La réinitialisation '
          'efface le code et toutes les données de l\'application : année '
          'académique, matières, compositions et notes seront perdues.',
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

    if (confirme == true) widget.onCodeOublie();
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
                      LengthLimitingTextInputFormatter(PinService.longueurPin),
                    ],
                    decoration: InputDecoration(
                      hintText: '•' * PinService.longueurPin,
                      errorText: _erreurVisible ? _erreur.text : null,
                    ),
                    onSubmitted: (_) => _verifier(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _verrouille ? null : _verifier,
                      child: Text(
                        _verrouille ? 'Verrouillé ($_texteRestant())' : 'Déverrouiller',
                      ),
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
                    child: const Text('Code oublié'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}