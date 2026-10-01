import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_service.dart';
import '../state/app_state.dart';

/// Reglages : profil local et code PIN.
class ReglagesScreen extends StatefulWidget {
  const ReglagesScreen({super.key});

  @override
  State<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends State<ReglagesScreen> {
  late final TextEditingController _nom;
  late final TextEditingController _prenoms;

  bool _modifie = false;
  bool _initialise = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialise) return;
    _initialise = true;

    // `of` enregistre une dependance : elle ne peut pas etre appele depuis
    // initState.
    final profil = AppStateScope.of(context).profil;
    _nom = TextEditingController(text: profil.nom);
    _prenoms = TextEditingController(text: profil.prenoms);
  }

  @override
  void dispose() {
    _nom.dispose();
    _prenoms.dispose();
    super.dispose();
  }

  Future<void> _enregistrerProfil() async {
    final nom = _nom.text.trim();
    final prenoms = _prenoms.text.trim();

    if (nom.isEmpty || prenoms.isEmpty) {
      _message('Le nom et les prénoms sont obligatoires.');
      return;
    }

    await AppStateScope.read(context).profil.enregistrer(
          nom: nom,
          prenoms: prenoms,
        );

    if (!mounted) return;
    setState(() => _modifie = false);
    _message('Profil enregistré.');
  }

  Future<void> _changerPin() async {
    final resultat = await showDialog<_ChangementPin>(
      context: context,
      builder: (_) => const _DialogueChangementPin(),
    );

    if (resultat == null) return;
    if (!mounted) return;

    await AppStateScope.read(context).pinService.definirPin(resultat.pin);

    if (!mounted) return;
    _message('Code modifié.');
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Profil',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nom,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom'),
              onChanged: (_) => _marquerModifie(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prenoms,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Prénoms'),
              onChanged: (_) => _marquerModifie(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _modifie ? _enregistrerProfil : null,
              child: const Text('Enregistrer'),
            ),
            const Divider(height: 48),
            Text(
              'Sécurité',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Modifier le code'),
              subtitle: const Text('Quatre chiffres'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changerPin,
            ),
          ],
        ),
      ),
    );
  }

  void _marquerModifie() {
    if (_modifie) return;
    setState(() => _modifie = true);
  }
}

class _ChangementPin {
  final String pin;

  const _ChangementPin(this.pin);
}

class _DialogueChangementPin extends StatefulWidget {
  const _DialogueChangementPin();

  @override
  State<_DialogueChangementPin> createState() =>
      _DialogueChangementPinState();
}

class _DialogueChangementPinState extends State<_DialogueChangementPin> {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _valider() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_ChangementPin(_pin.text));
  }

  @override
  Widget build(BuildContext context) {
    final formatters = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(PinService.longueurPin),
    ];

    return AlertDialog(
      title: const Text('Nouveau code'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: formatters,
              decoration: const InputDecoration(labelText: 'Code'),
              validator: _validerPin,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: formatters,
              decoration:
                  const InputDecoration(labelText: 'Confirmation du code'),
              validator: (valeur) => valeur == _pin.text
                  ? null
                  : 'Les codes ne correspondent pas',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
      ],
    );
  }

  String? _validerPin(String? valeur) {
    if (valeur == null || valeur.isEmpty) return 'Choisissez un code';
    if (valeur.length != PinService.longueurPin) {
      return 'Le code doit contenir ${PinService.longueurPin} chiffres';
    }
    if (valeur == PinService.codeInterdit) {
      return 'Ce code est trop évident, choisissez-en un autre';
    }
    return null;
  }
}