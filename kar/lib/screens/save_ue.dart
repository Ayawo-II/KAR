import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database_helper.dart';
import '../models/annee_courante.dart';
import '../models/matiere.dart';
import '../models/ue.dart';

/// Saisie des unites d'enseignement d'une annee, semestre par semestre.
///
/// Deux formes d'UE coexistent :
/// - l'UE directe, notee d'un seul tenant, qui porte son coefficient et son
///   credit ;
/// - l'UE composite, qui regroupe plusieurs matieres. Chacune a son
///   coefficient, le credit restant celui de l'UE.
///
/// Les matieres ne se saisissent donc jamais seules : une matiere hors UE
/// n'existe pas.
///
/// [avecDevoir] vient de la configuration de l'annee : lorsque
/// l'etablissement n'evalue pas en devoirs, aucune UE ne peut en comporter et
/// le reglage individuel disparait.
class SaveUe extends StatefulWidget {
  final int anneeDebut;
  final int anneeFin;
  final String universite;
  final String niveau;
  final String faculte;
  final String departement;
  final bool avecDevoir;
  final String valDevoirs;
  final String valExam;

  const SaveUe({
    required this.anneeDebut,
    required this.anneeFin,
    required this.universite,
    required this.niveau,
    required this.faculte,
    required this.departement,
    required this.avecDevoir,
    required this.valDevoirs,
    required this.valExam,
    super.key,
  });

  @override
  State<SaveUe> createState() => _SaveUeState();
}

class _SaveUeState extends State<SaveUe> {
  final _form = GlobalKey<FormState>();

  final List<_Ue> _semestre1 = [];
  final List<_Ue> _semestre2 = [];

  bool _enregistrement = false;

  /// Bareme des devoirs annonce, repris pour rappeler la consequence du
  /// choix « pas de devoir ».
  late final double _valDevoirs =
      double.tryParse(widget.valDevoirs.replaceAll(',', '.')) ?? 50;

  int get _nombreUes => _semestre1.length + _semestre2.length;

  @override
  void dispose() {
    for (final ue in [..._semestre1, ..._semestre2]) {
      ue.dispose();
    }
    super.dispose();
  }

  void _ajouterUe(List<_Ue> semestre, {required bool directe}) {
    setState(
      () => semestre.add(
        _Ue(directe: directe, avecDevoirAutorise: widget.avecDevoir),
      ),
    );
  }

  void _supprimerUe(List<_Ue> semestre, _Ue ue) {
    setState(() {
      semestre.remove(ue);
      ue.dispose();
    });
  }

  Future<void> _enregistrer() async {
    if (_enregistrement) return;

    // Une UE composite sans matiere ne note personne : elle est rejetee avant
    // meme la validation des autres champs.
    for (final ue in [..._semestre1, ..._semestre2]) {
      if (!ue.directe && ue.matieres.isEmpty) {
        if (!mounted) return;
        setState(() => ue.sansMatiere = true);
        _message('« ${ue.titre} » doit contenir au moins une matière.');
        return;
      }
    }

    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _enregistrement = true;
      for (final ue in [..._semestre1, ..._semestre2]) {
        ue.sansMatiere = false;
      }
    });

    final annee = AnneeCourante(
      anneeDebut: widget.anneeDebut,
      anneeFin: widget.anneeFin,
      universite: widget.universite,
      niveau: widget.niveau,
      faculte: widget.faculte,
      departement: widget.departement,
      valDevoirs: widget.valDevoirs,
      valExam: widget.valExam,
      statutAnnee: AnneeCourante.enCours,
    );

    final unites = <UeAvecMatieres>[
      ..._semestre1.map((ue) => ue.versUeAvecMatieres(1)),
      ..._semestre2.map((ue) => ue.versUeAvecMatieres(2)),
    ];

    try {
      await DatabaseHelper.instance.ajouterAnneeEtUes(annee, unites);
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
      appBar: AppBar(title: const Text('Unités d\'enseignement')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'Année ${widget.anneeDebut}-${widget.anneeFin} • '
                '${widget.niveau} • ${widget.faculte}'
                '${widget.departement.isEmpty ? '' : ' • ${widget.departement}'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (!widget.avecDevoir)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Pas de devoirs cette année : les matières ne seront '
                    'notées qu\'avec des examens.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 16),
              _semestre(titre: '1er semestre', ues: _semestre1),
              const SizedBox(height: 16),
              _semestre(titre: '2e semestre', ues: _semestre2),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _enregistrement || _nombreUes == 0
                    ? null
                    : _enregistrer,
                icon: _enregistrement
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Enregistrer les UE'),
              ),
              if (_nombreUes == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Ajoutez au moins une UE pour continuer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _semestre({required String titre, required List<_Ue> ues}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _ajouterUe(ues, directe: true),
                icon: const Icon(Icons.school_outlined, size: 18),
                label: const Text('UE simple'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _ajouterUe(ues, directe: false),
                icon: const Icon(Icons.account_tree_outlined, size: 18),
                label: const Text('UE + matières'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (ues.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aucune UE : « UE simple » pour une UE notée en bloc, '
              '« UE + matières » pour une UE qui en regroupe plusieurs.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ...List.generate(ues.length, (index) {
            final ue = ues[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _carteUe(ue: ue, onSupprimer: () => _supprimerUe(ues, ue)),
            );
          }),
      ],
    );
  }

  Widget _carteUe({required _Ue ue, required VoidCallback onSupprimer}) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: ue.libelle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: ue.directe ? 'UE' : 'Intitulé de l\'UE',
                      hintText: ue.directe
                          ? 'Algorithmique'
                          : 'Analyse numérique',
                    ),
                    validator: _obligatoire,
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer l\'UE',
                  onPressed: onSupprimer,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (ue.directe) ...[
                  Expanded(
                    child: TextFormField(
                      controller: ue.coef,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Coefficient',
                      ),
                      validator: _nombrePositif,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextFormField(
                    controller: ue.credit,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Crédit'),
                    validator: _nombrePositif,
                  ),
                ),
              ],
            ),
            if (widget.avecDevoir)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Devoirs'),
                subtitle: Text(
                  ue.avecDevoir
                      ? 'Coefficient des devoirs : '
                            '${_valDevoirs.toStringAsFixed(0)} %'
                      : 'Pas de devoir : coefficient des devoirs à 0',
                ),
                value: ue.avecDevoir,
                onChanged: (valeur) => setState(() => ue.avecDevoir = valeur),
              ),
            if (!ue.directe) ...[
              const SizedBox(height: 8),
              Text(
                'Matières de l\'UE — le crédit est celui de l\'UE',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              ...List.generate(ue.matieres.length, (index) {
                final matiere = ue.matieres[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _carteMatiere(
                    matiere: matiere,
                    onSupprimer: () =>
                        setState(() => ue.matieres.remove(matiere)),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => ue.matieres.add(
                      _Matiere(avecDevoirAutorise: widget.avecDevoir),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter une matière'),
                ),
              ),
              if (ue.sansMatiere)
                Text(
                  'Ajoutez au moins une matière à cette UE.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _carteMatiere({
    required _Matiere matiere,
    required VoidCallback onSupprimer,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: matiere.libelle,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Matière',
                    isDense: true,
                  ),
                  validator: _obligatoire,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: TextFormField(
                  controller: matiere.coef,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Coef',
                    isDense: true,
                  ),
                  validator: _nombrePositif,
                ),
              ),
              IconButton(
                tooltip: 'Supprimer la matière',
                onPressed: onSupprimer,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          if (widget.avecDevoir)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Devoirs', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                matiere.avecDevoir
                    ? '${_valDevoirs.toStringAsFixed(0)} %'
                    : 'Sans devoir',
                style: const TextStyle(fontSize: 12),
              ),
              value: matiere.avecDevoir,
              onChanged: (valeur) =>
                  setState(() => matiere.avecDevoir = valeur),
            ),
        ],
      ),
    );
  }

  String? _obligatoire(String? valeur) =>
      (valeur == null || valeur.trim().isEmpty) ? 'Champ obligatoire' : null;

  String? _nombrePositif(String? valeur) {
    final nombre = int.tryParse(valeur ?? '');
    if (nombre == null) return 'Nombre attendu';
    if (nombre <= 0) return 'Valeur positive';
    return null;
  }
}

/// Controleurs d'une unite d'enseignement.
///
/// Une UE directe se confond avec sa matiere : elle porte alors le nom, le
/// coefficient et le credit de cette derniere, et aucune matiere n'est saisie
/// separement. Une UE composite a ses propres matieres, chacune avec son
/// coefficient, et le credit ne bouge pas.
class _Ue {
  final bool directe;

  /// Le choix de l'annee interdit de declarer des devoirs dans une
  /// etablissement qui n'en evalue pas.
  final bool avecDevoirAutorise;

  final TextEditingController libelle = TextEditingController();
  final TextEditingController credit = TextEditingController(text: '4');
  final TextEditingController coef = TextEditingController(text: '2');

  final List<_Matiere> matieres = [];

  /// L'UE est-elle notee en devoirs ?
  bool avecDevoir;

  /// Signale une UE composite laissee sans matiere.
  bool sansMatiere = false;

  _Ue({required this.directe, required this.avecDevoirAutorise})
    : avecDevoir = avecDevoirAutorise;

  String get titre =>
      libelle.text.trim().isEmpty ? 'UE sans nom' : libelle.text;

  UeAvecMatieres versUeAvecMatieres(int semestre) {
    final creditUe = int.parse(credit.text);
    final ue = Ue(
      libelle: libelle.text.trim(),
      credit: creditUe,
      semestre: semestre,
      anneeId: 0,
    );

    if (directe) {
      return UeAvecMatieres(
        ue: ue,
        matieres: [
          Matiere(
            libMatiere: libelle.text.trim(),
            coef: int.parse(coef.text),
            credit: creditUe,
            semestre: semestre,
            anneeId: 0,
            avecDevoir: avecDevoir,
          ),
        ],
      );
    }

    return UeAvecMatieres(
      ue: ue,
      matieres: matieres
          .map((matiere) => matiere.versMatiere(semestre, creditUe))
          .toList(),
    );
  }

  void dispose() {
    libelle.dispose();
    credit.dispose();
    coef.dispose();
    for (final matiere in matieres) {
      matiere.dispose();
    }
  }
}

/// Controleurs d'une matiere d'UE composite : intitule, coefficient, presence
/// de devoirs. Le credit n'y figure pas : il appartient a l'UE.
class _Matiere {
  final bool avecDevoirAutorise;

  final TextEditingController libelle = TextEditingController();
  final TextEditingController coef = TextEditingController(text: '1');

  bool avecDevoir;

  _Matiere({required this.avecDevoirAutorise})
    : avecDevoir = avecDevoirAutorise;

  Matiere versMatiere(int semestre, int creditUe) {
    return Matiere(
      libMatiere: libelle.text.trim(),
      coef: int.parse(coef.text),
      credit: creditUe,
      semestre: semestre,
      anneeId: 0,
      avecDevoir: avecDevoirAutorise && avecDevoir,
    );
  }

  void dispose() {
    libelle.dispose();
    coef.dispose();
  }
}
