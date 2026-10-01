import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_service.dart';
import '../state/app_state.dart';

/// Premiere utilisation : definit le profil et le code PIN.
///
/// Deux etapes successives plutot qu'un formulaire unique : demander un code a
/// l'utilisateur qui n'en a pas encore choisi n'a pas de sens.
class ConfigurationScreen extends StatefulWidget {
  /// Appele apres la creation du profil et du PIN.
  final VoidCallback onTermine;

  const ConfigurationScreen({required this.onTermine, super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  final _formProfil = GlobalKey<FormState>();
  final _formPin = GlobalKey<FormState>();

  final _nom = TextEditingController();
  final _prenoms = TextEditingController();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();

  bool _etapeProfil = true;
  bool _enregistrement = false;

  @override
  void dispose() {
    _nom.dispose();
    _prenoms.dispose();
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _validerProfil() {
    if (!(_formProfil.currentState?.validate() ?? false)) return;

    setState(() => _etapeProfil = false);
  }

  Future<void> _validerPin() async {
    if (!(_formPin.currentState?.validate() ?? false)) return;

    setState(() => _enregistrement = true);
    await AppStateScope.read(context).pinService.definirPin(_pin.text);

    if (!mounted) return;
    setState(() => _enregistrement = false);
    widget.onTermine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_etapeProfil ? 'Bienvenue' : 'Code de sécurité'),
      ),
      body: SafeArea(
        child: _etapeProfil ? _buildProfil(context) : _buildPin(context),
      ),
    );
  }

  Widget _buildProfil(BuildContext context) {
    return Form(
      key: _formProfil,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'KAR',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Application de gestion des matières, compositions et révisions.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nom,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom'),
            validator: _validerNonVide,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _prenoms,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Prénoms'),
            validator: _validerNonVide,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _validerProfil,
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPin(BuildContext context) {
    return Form(
      key: _formPin,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choisissez un code à 4 chiffres',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Il vous sera demandé à chaque ouverture de l’application.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: PinService.longueurPin,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(PinService.longueurPin),
            ],
            decoration: const InputDecoration(
              labelText: 'Code',
              counterText: '',
            ),
            validator: _validerCode,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmation,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: PinService.longueurPin,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(PinService.longueurPin),
            ],
            decoration: const InputDecoration(
              labelText: 'Confirmation du code',
              counterText: '',
            ),
            validator: _validerConfirmation,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _enregistrement ? null : _validerPin,
            child: _enregistrement
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Terminer'),
          ),
          TextButton(
            onPressed: _enregistrement
                ? null
                : () => setState(() => _etapeProfil = true),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  String? _validerNonVide(String? valeur) {
    if (valeur == null || valeur.trim().isEmpty) return 'Champ obligatoire';
    return null;
  }

  String? _validerCode(String? valeur) {
    if (valeur == null || valeur.isEmpty) return 'Choisissez un code';
    if (valeur.length != PinService.longueurPin) {
      return 'Le code doit contenir ${PinService.longueurPin} chiffres';
    }
    if (valeur == PinService.codeInterdit) {
      return 'Ce code est trop évident, choisissez-en un autre';
    }
    return null;
  }

  String? _validerConfirmation(String? valeur) {
    if (valeur != _pin.text) return 'Les codes ne correspondent pas';
    return null;
  }
}