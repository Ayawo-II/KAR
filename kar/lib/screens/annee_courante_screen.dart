import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/annee_courante.dart';
import 'save_ue.dart';

/// Configuration de l'annee academique d'un etudiant.
///
/// Le nombre de matieres n'est plus demande ici : les matieres s'ajoutent une
/// par une sur l'ecran suivant.
class AnneeCouranteScreen extends StatefulWidget {
  const AnneeCouranteScreen({super.key});

  @override
  State<AnneeCouranteScreen> createState() => _AnneeCouranteScreenState();
}

class _AnneeCouranteScreenState extends State<AnneeCouranteScreen> {
  final _form = GlobalKey<FormState>();

  final _universite = TextEditingController();
  final _faculte = TextEditingController();
  final _departement = TextEditingController();
  final _valDevoirs = TextEditingController(text: '50');
  final _valExam = TextEditingController(text: '50');

  /// Le choix se fait au niveau de l'annee : l'etablissement evalue-t-il en
  /// devoirs ? Si non, les deux baremes n'ont pas lieu d'etre saisis et tout
  /// compte sur les examens.
  bool _avecDevoir = true;

  /// Erreur « la somme ne fait pas 100 % », affichee sous le bareme. Les
  /// validateurs de [Form] ne portent que sur un champ a la fois : la somme
  /// est donc verifiee dans [_continuer].
  String? _erreurTotal;

  /// Annee de debut et annee de fin, memorisées séparément : les deux
  /// menus partageaient auparavant le meme champ, ce qui rendait impossible
  /// de choisir une annee de fin différente de l'annee de debut.
  late int _anneeDebut = DateTime.now().year;
  late int _anneeFin = _anneeDebut + 1;

  String _niveau = AnneeCourante.niveaux.first;

  bool _ouvertureEnCours = false;

  /// Somme des deux baremes, null des que l'un des deux est illisible.
  double? get _total {
    final devoirs = _bareme(_valDevoirs.text);
    final examens = _bareme(_valExam.text);
    if (devoirs == null || examens == null) return null;
    return devoirs + examens;
  }

  /// Change le type d'evaluation : sans devoirs, tout est en examen.
  void _changerDevoirs(bool valeur) {
    setState(() {
      _avecDevoir = valeur;
      _erreurTotal = null;
      if (valeur) {
        if ((double.tryParse(_valExam.text) ?? 0) >= 100) {
          _valExam.text = '50';
        }
        if ((double.tryParse(_valDevoirs.text) ?? 0) <= 0) {
          _valDevoirs.text = '50';
        }
      } else {
        _valDevoirs.text = '0';
        _valExam.text = '100';
      }
    });
  }

  @override
  void dispose() {
    _universite.dispose();
    _faculte.dispose();
    _departement.dispose();
    _valDevoirs.dispose();
    _valExam.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    if (_ouvertureEnCours) return;
    if (!(_form.currentState?.validate() ?? false)) return;

    // Le bareme ne se verifie que si l'etablissement evalue en devoirs.
    final total = _total;
    if (_avecDevoir && total != 100) {
      setState(
        () => _erreurTotal =
            'Total : ${_pourcent(total)} % '
            '— les deux parts doivent faire 100 %.',
      );
      return;
    }

    setState(() => _ouvertureEnCours = true);

    final enregistre = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SaveUe(
          anneeDebut: _anneeDebut,
          anneeFin: _anneeFin,
          universite: _universite.text.trim(),
          niveau: _niveau,
          faculte: _faculte.text.trim(),
          departement: _departement.text.trim(),
          avecDevoir: _avecDevoir,
          valDevoirs: _avecDevoir ? _valDevoirs.text.trim() : '0',
          valExam: _avecDevoir ? _valExam.text.trim() : '100',
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
      appBar: AppBar(title: const Text('Année universitaire')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Année académique',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _anneeDebut,
                      decoration: const InputDecoration(labelText: 'Début'),
                      items: annees
                          .map(
                            (annee) => DropdownMenuItem(
                              value: annee,
                              child: Text('$annee'),
                            ),
                          )
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
                          .map(
                            (annee) => DropdownMenuItem(
                              value: annee,
                              child: Text('$annee'),
                            ),
                          )
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
              Text(
                'Établissement',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _universite,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'École / Université',
                ),
                validator: _obligatoire,
              ),
              const SizedBox(height: 20),
              Text('Formation', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _niveau,
                decoration: const InputDecoration(labelText: 'Année d\'études'),
                items: AnneeCourante.niveaux
                    .map(
                      (niveau) =>
                          DropdownMenuItem(value: niveau, child: Text(niveau)),
                    )
                    .toList(),
                onChanged: (niveau) {
                  if (niveau == null) return;
                  setState(() => _niveau = niveau);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _faculte,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Faculté'),
                validator: _obligatoire,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _departement,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Département / Option',
                  helperText: 'Faculté pour certains établissements',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Barème des compositions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Devoirs'),
                subtitle: Text(
                  _avecDevoir
                      ? 'L\'évaluation comporte des devoirs'
                      : 'Aucune note surveillée : tout compte sur les examens',
                ),
                value: _avecDevoir,
                onChanged: _changerDevoirs,
              ),
              if (_avecDevoir) ...[
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
                        decoration: const InputDecoration(
                          labelText: 'Devoirs (%)',
                        ),
                        validator: _pourcentage,
                        onChanged: (_) => setState(() => _erreurTotal = null),
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
                        decoration: const InputDecoration(
                          labelText: 'Examens (%)',
                        ),
                        validator: _pourcentage,
                        onChanged: (_) => setState(() => _erreurTotal = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ligneTotal(),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Barème appliqué : 100 % examens. Les matières de cette '
                    'année ne seront notées qu\'avec des examens.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _ouvertureEnCours ? null : _continuer,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Ajouter les UE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rappel de la somme des deux baremes, qui doit faire 100 %. L'erreur
  /// obtenue en tentant de continuer reste affichee tant que les valeurs ne
  /// changent pas.
  Widget _ligneTotal() {
    final theme = Theme.of(context);
    final total = _total;

    final complet = total == 100;
    final couleur = _erreurTotal != null
        ? theme.colorScheme.error
        : complet
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Text(
      _erreurTotal ?? 'Total : ${_pourcent(total)} % sur 100 %',
      style: theme.textTheme.bodySmall?.copyWith(color: couleur),
    );
  }

  String? _obligatoire(String? valeur) =>
      (valeur == null || valeur.trim().isEmpty) ? 'Champ obligatoire' : null;

  String? _pourcentage(String? valeur) {
    if (valeur == null || valeur.isEmpty) return 'Champ obligatoire';

    final nombre = double.tryParse(valeur.replaceAll(',', '.'));
    if (nombre == null || nombre <= 0) return 'Valeur positive attendue';
    if (nombre > 100) return 'Au plus 100 %';
    return null;
  }

  /// Lecture d'un bareme saisi, virgule ou point decimal. Null si la saisie
  /// n'est pas un nombre.
  static double? _bareme(String? valeur) {
    if (valeur == null || valeur.trim().isEmpty) return null;
    return double.tryParse(valeur.trim().replaceAll(',', '.'));
  }

  /// Ecriture d'un pourcentage a la francaise, sans decimale inutile.
  static String _pourcent(double? valeur) {
    if (valeur == null) return '—';
    if (valeur == valeur.roundToDouble()) return valeur.toStringAsFixed(0);
    return valeur.toStringAsFixed(2).replaceAll('.', ',');
  }
}
