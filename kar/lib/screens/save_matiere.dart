import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database_helper.dart';
import '../models/annee_courante.dart';
import '../models/matiere.dart';

/// Saisie des matieres d'une annee, semestre par semestre.
///
/// Les coefficients et credits sont des valeurs libres : seules la positivite
/// et la presence sont verifiees. L'ancien menu deroulant limite a 15 a ete
/// remplace par une saisie directe.
class SaveMatiere extends StatefulWidget {
  final int anneeDebut;
  final int anneeFin;
  final String ecole;
  final String classe;
  final String filiere;
  final String valDevoirs;
  final String valExam;
  final int nombreSemestre1;
  final int nombreSemestre2;

  const SaveMatiere({
    required this.anneeDebut,
    required this.anneeFin,
    required this.ecole,
    required this.classe,
    required this.filiere,
    required this.valDevoirs,
    required this.valExam,
    required this.nombreSemestre1,
    required this.nombreSemestre2,
    super.key,
  });

  @override
  State<SaveMatiere> createState() => _SaveMatiereState();
}

class _SaveMatiereState extends State<SaveMatiere> {
  final _form = GlobalKey<FormState>();

  final List<_LigneMatiere> _semestre1 = [];
  final List<_LigneMatiere> _semestre2 = [];

  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.nombreSemestre1; i++) {
      _semestre1.add(_LigneMatiere());
    }
    for (var i = 0; i < widget.nombreSemestre2; i++) {
      _semestre2.add(_LigneMatiere());
    }
  }

  @override
  void dispose() {
    for (final ligne in [..._semestre1, ..._semestre2]) {
      ligne.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (_enregistrement) return;
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _enregistrement = true);

    final annee = AnneeCourante(
      anneeDebut: widget.anneeDebut,
      anneeFin: widget.anneeFin,
      ecole: widget.ecole,
      classe: widget.classe,
      filiere: widget.filiere,
      valDevoirs: widget.valDevoirs,
      valExam: widget.valExam,
      statutAnnee: AnneeCourante.enCours,
    );

    final matieres = <Matiere>[
      ..._semestre1.map((ligne) => ligne.versMatiere(1)),
      ..._semestre2.map((ligne) => ligne.versMatiere(2)),
    ];

    try {
      await DatabaseHelper.instance.ajouterAnneeEtMatieres(annee, matieres);
    } on StateError catch (erreur) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      _message(erreur.message);
      return;
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      _message('Enregistrement impossible : $erreur');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matières')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'Année ${widget.anneeDebut}-${widget.anneeFin} • '
                '${widget.classe}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (_semestre1.isNotEmpty) ...[
                _titre('1er semestre'),
                ..._semestre1.map(_champMatiere),
                const SizedBox(height: 16),
              ],
              if (_semestre2.isNotEmpty) ...[
                _titre('2e semestre'),
                ..._semestre2.map(_champMatiere),
                const SizedBox(height: 16),
              ],
              if (_semestre1.isEmpty && _semestre2.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Aucune matière à saisir : le nombre de matières était '
                    'nul.',
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton.icon(
                onPressed: _enregistrement ? null : _enregistrer,
                icon: _enregistrement
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Enregistrer les matières'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titre(String texte) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _champMatiere(_LigneMatiere ligne) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              controller: ligne.libelle,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Matière'),
              validator: (valeur) =>
                  (valeur == null || valeur.trim().isEmpty)
                      ? 'Intitulé obligatoire'
                      : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: ligne.coef,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(labelText: 'Coefficient'),
                    validator: _nombrePositif,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: ligne.credit,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(labelText: 'Crédit'),
                    validator: _nombrePositif,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _nombrePositif(String? valeur) {
    final nombre = int.tryParse(valeur ?? '');
    if (nombre == null) return 'Nombre attendu';
    if (nombre <= 0) return 'Valeur positive';
    return null;
  }
}

/// Controleurs d'une matiere : intitule, coefficient, credit.
class _LigneMatiere {
  final TextEditingController libelle = TextEditingController();
  final TextEditingController coef = TextEditingController(text: '1');
  final TextEditingController credit = TextEditingController(text: '1');

  Matiere versMatiere(int semestre) {
    return Matiere(
      libMatiere: libelle.text.trim(),
      coef: int.parse(coef.text),
      credit: int.parse(credit.text),
      semestre: semestre,
      anneeId: 0,
    );
  }

  void dispose() {
    libelle.dispose();
    coef.dispose();
    credit.dispose();
  }
}