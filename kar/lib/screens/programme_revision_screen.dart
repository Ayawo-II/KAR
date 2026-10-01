import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/matiere.dart';
import '../models/programme.dart';

/// Programme de revision : planifier des journees de travail par matiere.
class ProgrammeRevisionScreen extends StatefulWidget {
  const ProgrammeRevisionScreen({super.key});

  @override
  State<ProgrammeRevisionScreen> createState() =>
      _ProgrammeRevisionScreenState();
}

class _ProgrammeRevisionScreenState extends State<ProgrammeRevisionScreen> {
  static final _formatDate = DateFormat('EEEE d MMMM yyyy', 'fr_FR');

  bool _chargement = true;
  List<ProgrammeAvecMatieres> _programmes = [];
  final DateTime _jour = DateTime.now();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final debut = _jour.subtract(const Duration(days: 365));
    final fin = _jour.add(const Duration(days: 365));

    final resultat = await DatabaseHelper.instance.recupererProgrammes(
      debut: debut,
      fin: fin,
    );

    if (!mounted) return;
    setState(() {
      _programmes = resultat;
      _chargement = false;
    });
  }

  Future<void> _planifier() async {
    final matieres = await DatabaseHelper.instance.recupererMatieres();
    if (!mounted) return;

    if (matieres.isEmpty) {
      _message('Créez d\'abord des matières dans votre année académique.');
      return;
    }

    final jour = await showDatePicker(
      context: context,
      initialDate: _jour,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (jour == null || !mounted) return;

    final selectionnees = await showDialog<Set<Matiere>>(
      context: context,
      builder: (dialogContext) => _DialogueMatieres(matieres: matieres),
    );

    if (selectionnees == null || selectionnees.isEmpty || !mounted) return;

    await DatabaseHelper.instance.planifierProgramme(
      jour: jour,
      matiereIds: selectionnees.map((matiere) => matiere.id!).toList(),
    );

    if (!mounted) return;
    _message('Journée de révision planifiée.');
    _charger();
  }

  Future<void> _basculerStatut(ProgrammeAvecMatieres item) async {
    final nouveau = item.programme.statut == StatutProgramme.respecte
        ? StatutProgramme.nonRespecte
        : StatutProgramme.respecte;

    await DatabaseHelper.instance
        .changerStatutProgramme(item.programme.id!, nouveau);
    if (!mounted) return;
    _charger();
  }

  Future<void> _supprimer(ProgrammeAvecMatieres item) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer la journée du ${_formatDate.format(item.programme.jour)} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    await DatabaseHelper.instance.supprimerProgramme(item.programme.id!);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Programme de révision')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _planifier,
        icon: const Icon(Icons.add),
        label: const Text('Planifier'),
      ),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : _programmes.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucune journée de révision planifiée.\n'
                        'Utilisez le bouton « Planifier » pour en créer une.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _programmes.length,
                    itemBuilder: (context, index) {
                      final item = _programmes[index];
                      final respecte =
                          item.programme.statut == StatutProgramme.respecte;

                      return Card(
                        child: Dismissible(
                          key: ValueKey(item.programme.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                          onDismissed: (_) => _supprimer(item),
                          child: ListTile(
                            onTap: () => _basculerStatut(item),
                            leading: Checkbox(
                              value: respecte,
                              onChanged: (_) => _basculerStatut(item),
                            ),
                            title: Text(
                              _capitaliser(_formatDate.format(item.programme.jour)),
                              style: TextStyle(
                                decoration: respecte
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              item.matieres.isEmpty
                                  ? 'Aucune matière'
                                  : item.matieres
                                      .map((matiere) => matiere.libMatiere)
                                      .join(' • '),
                            ),
                            trailing: Chip(
                              label: Text(
                                respecte ? 'Respecté' : 'À faire',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  String _capitaliser(String texte) =>
      texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
}

/// Selection multiple des matieres a reviser.
class _DialogueMatieres extends StatefulWidget {
  final List<Matiere> matieres;

  const _DialogueMatieres({required this.matieres});

  @override
  State<_DialogueMatieres> createState() => _DialogueMatieresState();
}

class _DialogueMatieresState extends State<_DialogueMatieres> {
  final Set<Matiere> _selection = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quelles matières ?'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: ListView.builder(
          itemCount: widget.matieres.length,
          itemBuilder: (context, index) {
            final matiere = widget.matieres[index];
            return CheckboxListTile(
              value: _selection.contains(matiere),
              title: Text(matiere.libMatiere),
              subtitle: Text('Semestre ${matiere.semestre}'),
              onChanged: (coche) {
                setState(() {
                  if (coche == true) {
                    _selection.add(matiere);
                  } else {
                    _selection.remove(matiere);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _selection.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selection),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}