import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/composition.dart';

/// Liste des devoirs et examens, groupes par mois.
class CompositionsScreen extends StatefulWidget {
  final DateTime? jourInitial;

  const CompositionsScreen({this.jourInitial, super.key});

  @override
  State<CompositionsScreen> createState() => _CompositionsScreenState();
}

class _CompositionsScreenState extends State<CompositionsScreen> {
  late DateTime _mois = DateTime(
    widget.jourInitial?.year ?? DateTime.now().year,
    widget.jourInitial?.month ?? DateTime.now().month,
  );

  bool _chargement = true;
  List<CompositionAvecMatiere> _compositions = [];

  static final _formatDate = DateFormat('d MMMM yyyy', 'fr_FR');
  static final _formatMois = DateFormat('MMMM yyyy', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final debut = DateTime(_mois.year, _mois.month);
    final fin = DateTime(_mois.year, _mois.month + 1, 0, 23, 59, 59);

    final resultat = await DatabaseHelper.instance.recupererCompositions(
      debut: debut,
      fin: fin,
    );

    if (!mounted) return;
    setState(() {
      _compositions = resultat;
      _chargement = false;
    });
  }

  void _changerMois(int delta) {
    setState(() {
      _mois = DateTime(_mois.year, _mois.month + delta);
      _chargement = true;
    });
    _charger();
  }

  Future<void> _supprimer(CompositionAvecMatiere item) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text(
          'Supprimer ce ${TypeComposition.libelle(item.composition.type).toLowerCase()} '
          'de ${item.libMatiere} ?',
        ),
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

    await DatabaseHelper.instance.supprimerComposition(item.composition.id!);
    if (!mounted) return;
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devoirs et examens'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _charger,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _barreMois(context),
            const Divider(height: 1),
            Expanded(child: _liste(context)),
          ],
        ),
      ),
    );
  }

  Widget _barreMois(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Mois précédent',
            onPressed: () => _changerMois(-1),
          ),
          Expanded(
            child: Text(
              _capitaliser(_formatMois.format(_mois)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Mois suivant',
            onPressed: () => _changerMois(1),
          ),
        ],
      ),
    );
  }

  Widget _liste(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_compositions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune composition ce mois-ci.\n'
            'Planifiez-en depuis l\'écran principal.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _compositions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _compositions[index];
        final composition = item.composition;
        final estExamen = composition.type == TypeComposition.examen;

        return Dismissible(
          key: ValueKey(composition.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _supprimer(item),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: estExamen
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  estExamen
                      ? Icons.assignment_turned_in_outlined
                      : Icons.assignment_outlined,
                  size: 20,
                ),
              ),
              title: Text(item.libMatiere),
              subtitle: Text(
                '${TypeComposition.libelle(composition.type)} • '
                '${_formatDate.format(composition.date)}',
              ),
            ),
          ),
        );
      },
    );
  }

  String _capitaliser(String texte) =>
      texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
}