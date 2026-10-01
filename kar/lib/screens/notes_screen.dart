import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../domain/moyenne.dart';
import '../models/matiere.dart';
import '../models/note.dart';

/// Saisie des notes et suivi des moyennes.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  static final _formatDate = DateFormat('d MMM yyyy', 'fr_FR');

  bool _chargement = true;
  List<Matiere> _matieres = [];
  List<NoteAvecMatiere> _notes = [];
  Map<int, double> _moyennes = {};
  double? _moyenneAnnee;
  double? _moyenneSemestre1;
  double? _moyenneSemestre2;

  double _valDevoirs = 50;
  double _valExam = 50;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final annee = await DatabaseHelper.instance.recupererAnneeCourante();
    final matieres = await DatabaseHelper.instance.recupererMatieres();
    final notes = await DatabaseHelper.instance.recupererToutesNotes();

    if (!mounted) return;

    setState(() {
      if (annee != null) {
        _valDevoirs = double.tryParse(annee.valDevoirs) ?? 50;
        _valExam = double.tryParse(annee.valExam) ?? 50;
      }
      _matieres = matieres;
      _notes = notes;
      _chargement = false;
    });

    _calculer();
  }

  void _calculer() {
    final moyennes = <int, double>{};

    for (final matiere in _matieres) {
      final notesMatiere = _notes
          .where((item) => item.note.matiereId == matiere.id)
          .map((item) => item.note)
          .toList();

      if (notesMatiere.isEmpty) continue;

      final moyenne = Moyenne.moyenneMatiere(
        notesMatiere,
        valDevoirs: _valDevoirs,
        valExam: _valExam,
      );

      if (moyenne != null) moyennes[matiere.id!] = moyenne;
    }

    if (!mounted) return;
    setState(() {
      _moyennes = moyennes;
      _moyenneAnnee = Moyenne.moyenneAnnee(moyennes, _matieres);
      _moyenneSemestre1 = Moyenne.moyenneSemestre(moyennes, _matieres, 1);
      _moyenneSemestre2 = Moyenne.moyenneSemestre(moyennes, _matieres, 2);
    });
  }

  Future<void> _ajouterNote() async {
    if (_matieres.isEmpty) {
      _message('Créez d\'abord des matières dans votre année académique.');
      return;
    }

    final resultat = await showDialog<_SaisieNote>(
      context: context,
      builder: (_) => _DialogueNote(matieres: _matieres),
    );

    if (resultat == null || !mounted) return;

    await DatabaseHelper.instance.ajouterNote(resultat.note);
    if (!mounted) return;
    _charger();
  }

  Future<void> _supprimer(NoteAvecMatiere item) async {
    await DatabaseHelper.instance.supprimerNote(item.note.id!);
    if (!mounted) return;
    _charger();
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterNote,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _resume(theme),
                  const SizedBox(height: 16),
                  if (_matieres.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucune matière : configurez votre année académique '
                        'pour pouvoir saisir des notes.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    Text('Moyennes par matière',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._matieres.map(_ligneMatiere),
                    const SizedBox(height: 24),
                    Text('Dernières notes',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_notes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aucune note enregistrée.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._notes.take(50).map(_ligneNote),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _resume(ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Moyennes de l\'année',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _ligneResume('Année', _moyenneAnnee, theme),
            _ligneResume('Semestre 1', _moyenneSemestre1, theme),
            _ligneResume('Semestre 2', _moyenneSemestre2, theme),
            const Divider(height: 24),
            Text(
              'Barème : devoirs ${_valDevoirs.toStringAsFixed(0)} % / '
              'examens ${_valExam.toStringAsFixed(0)} %',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneResume(String libelle, double? moyenne, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(libelle, style: theme.textTheme.bodyMedium),
          Text(
            Moyenne.formater(moyenne),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligneMatiere(Matiere matiere) {
    final moyenne = _moyennes[matiere.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(child: Text('${matiere.coef}')),
        title: Text(matiere.libMatiere),
        subtitle: Text('Semestre ${matiere.semestre}'),
        trailing: Text(
          Moyenne.formater(moyenne),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _ligneNote(NoteAvecMatiere item) {
    final theme = Theme.of(context);
    final estExamen = item.note.type == 'examen';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Dismissible(
        key: ValueKey(item.note.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) => _supprimer(item),
        child: ListTile(
          leading: Icon(
            estExamen ? Icons.assignment_turned_in_outlined : Icons.edit_note,
            color: estExamen ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          title: Text('${item.note.libelle} — ${item.libMatiere}'),
          subtitle: Text(_formatDate.format(item.note.date)),
          trailing: Text(
            item.note.valeur.toStringAsFixed(2).replaceAll('.', ','),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaisieNote {
  final Note note;

  const _SaisieNote(this.note);
}

class _DialogueNote extends StatefulWidget {
  final List<Matiere> matieres;

  const _DialogueNote({required this.matieres});

  @override
  State<_DialogueNote> createState() => _DialogueNoteState();
}

class _DialogueNoteState extends State<_DialogueNote> {
  final _form = GlobalKey<FormState>();
  final _libelle = TextEditingController();
  final _valeur = TextEditingController();

  Matiere? _matiere;
  String _type = 'devoir';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _matiere = widget.matieres.first;
  }

  @override
  void dispose() {
    _libelle.dispose();
    _valeur.dispose();
    super.dispose();
  }

  void _enregistrer() {
    if (!(_form.currentState?.validate() ?? false)) return;

    Navigator.of(context).pop(
      _SaisieNote(
        Note(
          libelle: _libelle.text.trim(),
          date: _date,
          valeur: double.parse(_valeur.text.replaceAll(',', '.')),
          type: _type,
          matiereId: _matiere!.id!,
        ),
      ),
    );
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (date != null) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle note'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _libelle,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Intitulé'),
                validator: (valeur) => (valeur == null || valeur.trim().isEmpty)
                    ? 'Intitulé obligatoire'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Matiere>(
                initialValue: _matiere,
                decoration: const InputDecoration(labelText: 'Matière'),
                items: widget.matieres
                    .map((matiere) => DropdownMenuItem(
                          value: matiere,
                          child: Text(matiere.libMatiere),
                        ))
                    .toList(),
                onChanged: (matiere) => setState(() => _matiere = matiere),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'devoir', label: Text('Devoir')),
                  ButtonSegment(value: 'examen', label: Text('Examen')),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valeur,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Note sur 20',
                ),
                validator: (texte) {
                  if (texte == null || texte.isEmpty) return 'Valeur obligatoire';
                  final valeur =
                      double.tryParse(texte.replaceAll(',', '.'));
                  if (valeur == null) return 'Nombre invalide';
                  if (valeur < 0 || valeur > 20) return 'La note est sur 20';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Date'),
                subtitle: Text(
                  DateFormat('d MMM yyyy', 'fr_FR').format(_date),
                ),
                onTap: _choisirDate,
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
      ],
    );
  }
}