import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/evenement.dart';

/// Agenda personnel : vacances, reunions, conseils, examens blancs.
class EvenementsScreen extends StatefulWidget {
  const EvenementsScreen({super.key});

  @override
  State<EvenementsScreen> createState() => _EvenementsScreenState();
}

class _EvenementsScreenState extends State<EvenementsScreen> {
  static final _formatDate = DateFormat('d MMMM yyyy', 'fr_FR');
  static final _formatDates = DateFormat('d MMM', 'fr_FR');

  bool _chargement = true;
  List<Evenement> _avenir = [];
  List<Evenement> _passes = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final maintenant = DateTime.now();
    final debut = maintenant.subtract(const Duration(days: 730));
    final fin = maintenant.add(const Duration(days: 1095));

    final resultat = await DatabaseHelper.instance.recupererEvenements(
      debut: debut,
      fin: fin,
    );

    if (!mounted) return;
    setState(() {
      _avenir = resultat.where((evenement) => !evenement.estPasse).toList();
      _passes = resultat.where((evenement) => evenement.estPasse).toList()
        ..sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
      _chargement = false;
    });
  }

  Future<void> _modifier([Evenement? existant]) async {
    final resultat = await showDialog<Evenement>(
      context: context,
      builder: (_) => _DialogueEvenement(evenement: existant),
    );

    if (resultat == null || !mounted) return;

    if (resultat.id == null) {
      await DatabaseHelper.instance.ajouterEvenement(resultat);
    } else {
      await DatabaseHelper.instance.modifierEvenement(resultat);
    }

    if (!mounted) return;
    _charger();
  }

  Future<void> _supprimer(Evenement evenement) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer « ${evenement.titre} » ?'),
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

    await DatabaseHelper.instance.supprimerEvenement(evenement.id!);
    if (!mounted) return;
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Événements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _modifier,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  if (_avenir.isEmpty && _passes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucun événement.\n'
                        'Ajoutez vacances, réunions, conseils de classe ou '
                        'examens blancs.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_avenir.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('À venir'),
                    ),
                    ..._avenir.map((evenement) => _ligne(evenement)),
                  ],
                  if (_passes.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                      child: Text('Passés'),
                    ),
                    ..._passes.map((evenement) => _ligne(evenement)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _ligne(Evenement evenement) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Dismissible(
        key: ValueKey(evenement.id),
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
        onDismissed: (_) => _supprimer(evenement),
        child: ListTile(
          onTap: () => _modifier(evenement),
          leading: CircleAvatar(
            backgroundColor: evenement.estPasse
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primaryContainer,
            child: Icon(
              _icone(evenement.categorie),
              size: 20,
              color: evenement.estPasse
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
            ),
          ),
          title: Text(evenement.titre),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_daterange(evenement)),
              if (evenement.description != null &&
                  evenement.description!.isNotEmpty)
                Text(
                  evenement.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          isThreeLine:
              evenement.description != null && evenement.description!.isNotEmpty,
          trailing: Chip(
            label: Text(
              evenement.categorie,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }

  String _daterange(Evenement evenement) {
    final memeJour =
        evenement.dateDebut.year == evenement.dateFin.year &&
            evenement.dateDebut.month == evenement.dateFin.month &&
            evenement.dateDebut.day == evenement.dateFin.day;

    if (memeJour) return _formatDate.format(evenement.dateDebut);

    return '${_formatDates.format(evenement.dateDebut)}'
        ' – ${_formatDates.format(evenement.dateFin)}';
  }

  IconData _icone(String categorie) => switch (categorie) {
        Evenement.categorieVacances => Icons.beach_access_outlined,
        Evenement.categorieRentree => Icons.school_outlined,
        Evenement.categorieReunion => Icons.groups_outlined,
        Evenement.categorieConseil => Icons.campaign_outlined,
        Evenement.categorieExamenBlanc => Icons.fact_check_outlined,
        _ => Icons.event_outlined,
      };
}

class _DialogueEvenement extends StatefulWidget {
  final Evenement? evenement;

  const _DialogueEvenement({this.evenement});

  @override
  State<_DialogueEvenement> createState() => _DialogueEvenementState();
}

class _DialogueEvenementState extends State<_DialogueEvenement> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _titre;
  late final TextEditingController _description;

  late DateTime _debut;
  late DateTime _fin;
  late String _categorie;

  @override
  void initState() {
    super.initState();
    final existant = widget.evenement;

    _titre = TextEditingController(text: existant?.titre ?? '');
    _description = TextEditingController(text: existant?.description ?? '');
    _debut = existant?.dateDebut ?? DateTime.now();
    _fin = existant?.dateFin ?? DateTime.now();
    _categorie = existant?.categorie ?? Evenement.categorieAutre;
  }

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    super.dispose();
  }

  void _enregistrer() {
    if (!(_form.currentState?.validate() ?? false)) return;

    Navigator.of(context).pop(
      Evenement(
        id: widget.evenement?.id,
        titre: _titre.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        dateDebut: _debut,
        dateFin: _fin,
        categorie: _categorie,
      ),
    );
  }

  Future<void> _choisir({required bool debut}) async {
    final initiale = debut ? _debut : _fin;
    final date = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );

    if (date == null) return;

    setState(() {
      if (debut) {
        _debut = date;
        if (_fin.isBefore(date)) _fin = date;
      } else {
        _fin = date.isBefore(_debut) ? _debut : date;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d MMMM yyyy', 'fr_FR');

    return AlertDialog(
      title: Text(widget.evenement == null ? 'Nouvel événement' : 'Modifier'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: (valeur) => (valeur == null || valeur.trim().isEmpty)
                    ? 'Titre obligatoire'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categorie,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: Evenement.categories
                    .map((categorie) => DropdownMenuItem(
                          value: categorie,
                          child: Text(categorie),
                        ))
                    .toList(),
                onChanged: (valeur) =>
                    setState(() => _categorie = valeur ?? Evenement.categorieAutre),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow),
                title: const Text('Début'),
                subtitle: Text(format.format(_debut)),
                onTap: () => _choisir(debut: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stop),
                title: const Text('Fin'),
                subtitle: Text(format.format(_fin)),
                onTap: () => _choisir(debut: false),
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