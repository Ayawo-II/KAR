import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Premiere utilisation : definit le profil.
///
/// Aucun code n'est demande : l'application s'ouvre directement. Le
/// verrouillage reste une option, activee plus tard dans les reglages.
class ConfigurationScreen extends StatefulWidget {
  /// Appele apres l'enregistrement du profil.
  final VoidCallback onTermine;

  const ConfigurationScreen({required this.onTermine, super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  final _form = GlobalKey<FormState>();

  final _nom = TextEditingController();
  final _prenoms = TextEditingController();

  bool _enregistrement = false;

  @override
  void dispose() {
    _nom.dispose();
    _prenoms.dispose();
    super.dispose();
  }

  Future<void> _terminer() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _enregistrement = true);
    await AppStateScope.read(
      context,
    ).profil.enregistrer(nom: _nom.text, prenoms: _prenoms.text);

    if (!mounted) return;
    setState(() => _enregistrement = false);
    widget.onTermine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenue')),
      body: SafeArea(
        child: Form(
          key: _form,
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
                onPressed: _enregistrement ? null : _terminer,
                child: _enregistrement
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Terminer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validerNonVide(String? valeur) {
    if (valeur == null || valeur.trim().isEmpty) return 'Champ obligatoire';
    return null;
  }
}
