import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'save_matiere.dart';

/// Configuration de l'annee academique.
class AnneeCouranteScreen extends StatefulWidget {
  const AnneeCouranteScreen({super.key});

  @override
  State<AnneeCouranteScreen> createState() => _AnneeCouranteScreenState();
}

class _AnneeCouranteScreenState extends State<AnneeCouranteScreen> {
  final _form = GlobalKey<FormState>();

  final _ecole = TextEditingController();
  final _classe = TextEditingController();
  final _filiere = TextEditingController();
  final _valDevoirs = TextEditingController(text: '50');
  final _valExam = TextEditingController(text: '50');
  final _semestre1 = TextEditingController(text: '0');
  final _semestre2 = TextEditingController(text: '0');

  /// Annee de debut et annee de fin, mémorisées séparément : les deux
  /// menus partageaient auparavant le meme champ, ce qui rendait impossible
  /// de choisir une annee de fin différente de l'annee de debut.
  late int _anneeDebut = DateTime.now().year;
  late int _anneeFin = _anneeDebut + 1;

  bool _ouvertureEnCours = false;

  @override
  void dispose() {
    _ecole.dispose();
    _classe.dispose();
    _filiere.dispose();
    _valDevoirs.dispose();
    _valExam.dispose();
    _semestre1.dispose();
    _semestre2.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    if (_ouvertureEnCours) return;
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _ouvertureEnCours = true);

    final enregistre = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SaveMatiere(
          anneeDebut: _anneeDebut,
          anneeFin: _anneeFin,
          ecole: _ecole.text.trim(),
          classe: _classe.text.trim(),
          filiere: _filiere.text.trim(),
          valDevoirs: _valDevoirs.text.trim(),
          valExam: _valExam.text.trim(),
          nombreSemestre1: int.parse(_semestre1.text),
          nombreSemestre2: int.parse(_semestre2.text),
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _ouvertureEnCours = false);

    if (enregistre == true) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final anneeActuelle = DateTime.now().year;
    final annees = [
      for (int annee = anneeActuelle + 1; annee >= anneeActuelle - 10; annee--)
        annee,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Année courante')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Année académique',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _anneeDebut,
                      decoration: const InputDecoration(labelText: 'Début'),
                      items: annees
                          .map((annee) => DropdownMenuItem(
                                value: annee,
                                child: Text('$annee'),
                              ))
                          .toList(),
                      onChanged: (annee) {
                        if (annee == null) return;
                        setState(() {
                          _anneeDebut = annee;
                          // La fin reste toujours posterieure au debut.
                          if (_anneeFin <= _anneeDebut) {
                            _anneeFin = _anneeDebut + 1;
                          }
                        });
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('—'),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _anneeFin,
                      decoration: const InputDecoration(labelText: 'Fin'),
                      items: annees
                          .where((annee) => annee > _anneeDebut)
                          .map((annee) => DropdownMenuItem(
                                value: annee,
                                child: Text('$annee'),
                              ))
                          .toList(),
                      onChanged: (annee) {
                        if (annee == null) return;
                        setState(() => _anneeFin = annee);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Établissement',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ecole,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'École'),
                validator: _obligatoire,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _classe,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Classe'),
                validator: _obligatoire,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _filiere,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Filière'),
                validator: _obligatoire,
              ),
              const SizedBox(height: 20),
              Text('Barème des compositions',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valDevoirs,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[.,]?\d*'),
                        ),
                      ],
                      decoration:
                          const InputDecoration(labelText: 'Devoirs (%)'),
                      validator: _pourcentage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _valExam,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[.,]?\d*'),
                        ),
                      ],
                      decoration:
                          const InputDecoration(labelText: 'Examens (%)'),
                      validator: _pourcentage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Nombre de matières',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _semestre1,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration:
                          const InputDecoration(labelText: '1er semestre'),
                      validator: _nombreMatieres,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _semestre2,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration:
                          const InputDecoration(labelText: '2e semestre'),
                      validator: _nombreMatieres,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _ouvertureEnCours ? null : _continuer,
                child: const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _obligatoire(String? valeur) =>
      (valeur == null || valeur.trim().isEmpty) ? 'Champ obligatoire' : null;

  String? _pourcentage(String? valeur) {
    if (valeur == null || valeur.isEmpty) return 'Champ obligatoire';

    final nombre = double.tryParse(valeur.replaceAll(',', '.'));
    if (nombre == null || nombre <= 0) return 'Valeur positive attendue';
    return null;
  }

  String? _nombreMatieres(String? valeur) {
    final nombre = int.tryParse(valeur ?? '');
    if (nombre == null) return 'Nombre attendu';
    if (nombre > 30) return 'Maximum 30';
    return null;
  }
}