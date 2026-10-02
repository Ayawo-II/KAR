import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/database_helper.dart';
import '../models/composition.dart';
import '../models/matiere.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'compositions_screen.dart';
import 'notes_screen.dart';
import 'evenements_screen.dart';
import 'programme_revision_screen.dart';
import 'reglages_screen.dart';
import 'annee_courante_screen.dart';

class HomeScreen extends StatefulWidget {
  /// Appele quand l'utilisateur demande a reverrouiller l'application.
  final VoidCallback onVerrouiller;

  const HomeScreen({required this.onVerrouiller, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _jourFocus = DateTime.now();
  DateTime _jourSelectionne = DateTime.now();

  bool _anneeConfiguree = true;
  bool _chargement = true;

  /// Ce que contient chaque jour affiche, indexe par journee.
  Map<DateTime, List<_Entree>> _agenda = {};

  @override
  void initState() {
    super.initState();
    _verifierAnnee();
  }

  Future<void> _verifierAnnee() async {
    final annee = await DatabaseHelper.instance.recupererAnneeCourante();
    if (!mounted) return;

    setState(() => _anneeConfiguree = annee != null);

    await _chargerAgenda();
  }

  /// Charge les compositions, les journees de revision et les evenements
  ///_personnels autour du mois affiche, marge comprise pour que le changement
  /// de page n'affiche jamais de mois vide.
  Future<void> _chargerAgenda() async {
    final debut = DateTime(_jourFocus.year, _jourFocus.month - 1, 1);
    final fin = DateTime(_jourFocus.year, _jourFocus.month + 2, 0);

    final db = DatabaseHelper.instance;

    final compositions = await db.recupererCompositions(debut: debut, fin: fin);
    final programmes = await db.recupererProgrammes(debut: debut, fin: fin);
    final evenements = await db.recupererEvenements(debut: debut, fin: fin);

    if (!mounted) return;

    final agenda = <DateTime, List<_Entree>>{};
    void ajouter(DateTime jour, _Entree entree) {
      final cle = _journee(jour);
      agenda.putIfAbsent(cle, () => <_Entree>[]).add(entree);
    }

    for (final item in compositions) {
      final composition = item.composition;
      final estExamen = composition.type == TypeComposition.examen;
      ajouter(
        composition.date,
        _Entree(
          titre: item.libMatiere,
          sousTitre: TypeComposition.libelle(composition.type),
          icone: estExamen
              ? Icons.assignment_turned_in_outlined
              : Icons.assignment_outlined,
          couleur: estExamen
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
      );
    }

    for (final item in programmes) {
      ajouter(
        item.programme.jour,
        _Entree(
          titre: 'Révision',
          sousTitre: item.matieres.isEmpty
              ? 'Aucune matière'
              : item.matieres.map((matiere) => matiere.libMatiere).join(', '),
          icone: Icons.menu_book_outlined,
          couleur: AppTheme.secondaire,
        ),
      );
    }

    for (final evenement in evenements) {
      var jour = _journee(evenement.dateDebut);
      final dernier = _journee(evenement.dateFin);

      while (!jour.isAfter(dernier)) {
        ajouter(
          jour,
          _Entree(
            titre: evenement.titre,
            sousTitre: evenement.categorie,
            icone: Icons.event_outlined,
            couleur: Theme.of(context).colorScheme.tertiary,
          ),
        );
        jour = jour.add(const Duration(days: 1));
      }
    }

    if (!mounted) return;
    setState(() {
      _agenda = agenda;
      _chargement = false;
    });
  }

  static DateTime _journee(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<_Entree> _entreesDuJour() =>
      _agenda[_journee(_jourSelectionne)] ?? const [];

  void _message(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _planifier(DateTime jour) async {
    final matieres = await DatabaseHelper.instance.recupererMatieres();

    if (!mounted) return;

    if (matieres.isEmpty) {
      _message('Aucune matière enregistrée pour cette année.');
      return;
    }

    final matiere = await showDialog<Matiere>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pour quelle matière ?'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: ListView.builder(
            itemCount: matieres.length,
            itemBuilder: (context, index) {
              final item = matieres[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${item.coef}')),
                title: Text(item.libMatiere),
                subtitle: Text(
                  'Semestre ${item.semestre} • ${item.credit} crédit'
                  '${item.credit > 1 ? 's' : ''}',
                ),
                onTap: () => Navigator.of(dialogContext).pop(item),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (matiere == null || !mounted) return;

    final type = await _demanderType(matiere);
    if (type == null || !mounted) return;

    try {
      await DatabaseHelper.instance.planifierComposition(
        matiere: matiere,
        type: type,
        date: jour,
      );
    } catch (erreur) {
      if (!mounted) return;
      _message('Enregistrement impossible : $erreur');
      return;
    }

    if (!mounted) return;
    _message(
      '${type == 'devoir' ? 'Devoir' : 'Examen'} planifié le '
      '${jour.day}/${jour.month}/${jour.year}',
    );
    _chargerAgenda();
  }

  Future<String?> _demanderType(Matiere matiere) {
    // Une matiere sans devoirs n'accepte qu'un examen.
    final options = <({String valeur, IconData icone, String libelle})>[
      if (matiere.avecDevoir)
        (valeur: 'devoir', icone: Icons.assignment_outlined, libelle: 'Devoir'),
      (
        valeur: 'examen',
        icone: Icons.assignment_turned_in_outlined,
        libelle: 'Examen',
      ),
    ];

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Type de composition — ${matiere.libMatiere}'),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(option.valeur),
              child: ListTile(
                leading: Icon(option.icone),
                title: Text(option.libelle),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmerVerrouillage() async {
    final appState = AppStateScope.read(context);

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verrouiller'),
        content: Text(
          appState.appareilSecurise
              ? 'L\'empreinte, le visage ou le code de l\'appareil vous sera '
                    'demandé à la réouverture.'
              : 'Le code vous sera demandé à la réouverture.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Verrouiller'),
          ),
        ],
      ),
    );

    if (confirme == true) widget.onVerrouiller();
  }

  Future<void> _ouvrir(Widget ecran) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecran));

    if (!mounted) return;
    await _verifierAnnee();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final profil = appState.profil;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KAR'),
        actions: [
          IconButton(
            tooltip: appState.nomMenuBasculeTheme,
            icon: Icon(
              appState.themeSombre ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: appState.basculerTheme,
          ),
        ],
      ),
      drawer: _Tiroir(
        nomComplet: profil.nomComplet,
        initiales: profil.initiales,
        libelleTheme: appState.nomMenuBasculeTheme,
        verrouillageActif: appState.verrouillageActif,
        onProfilTap: () => _ouvrir(const ReglagesScreen()),
        onThemeTap: appState.basculerTheme,
        onVerrouiller: _confirmerVerrouillage,
      ),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  TableCalendar<_Entree>(
                    locale: 'fr_FR',
                    firstDay: DateTime.utc(2000),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _jourFocus,
                    availableGestures: AvailableGestures.horizontalSwipe,
                    selectedDayPredicate: (jour) =>
                        isSameDay(_jourSelectionne, jour),
                    eventLoader: (jour) =>
                        _agenda[_journee(jour)] ?? const <_Entree>[],
                    calendarBuilders: CalendarBuilders<_Entree>(
                      markerBuilder: (context, jour, entrees) {
                        if (entrees.isEmpty) return null;

                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final entree in entrees.take(3))
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: entree.couleur,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    onDaySelected: (jourSelectionne, jourFocus) {
                      setState(() {
                        _jourSelectionne = jourSelectionne;
                        _jourFocus = jourFocus;
                      });
                    },
                    onPageChanged: (jourFocus) {
                      setState(() => _jourFocus = jourFocus);
                      _chargerAgenda();
                    },
                  ),
                  _legende(),
                  _agendaDuJour(),
                  _grille([
                    _Carte(
                      titre: 'Compositions',
                      sousTitre: 'Devoirs et examens à venir.',
                      icone: Icons.assignment_outlined,
                      onTap: () => _ouvrir(const CompositionsScreen()),
                    ),
                    _Carte(
                      titre: 'Programme de révision',
                      sousTitre: 'Planifiez vos révisions.',
                      icone: Icons.calendar_month_outlined,
                      onTap: () => _ouvrir(const ProgrammeRevisionScreen()),
                    ),
                    _Carte(
                      titre: 'Notes',
                      sousTitre: 'Saisissez et suivez vos moyennes.',
                      icone: Icons.grading_outlined,
                      onTap: () => _ouvrir(const NotesScreen()),
                    ),
                    _Carte(
                      titre: 'Événements',
                      sousTitre: 'Votre agenda personnel.',
                      icone: Icons.event_outlined,
                      onTap: () => _ouvrir(const EvenementsScreen()),
                    ),
                  ]),
                ],
              ),
      ),
    );
  }

  Widget _legende() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        children: [
          _pastille('Devoir', theme.colorScheme.primary),
          _pastille('Examen', theme.colorScheme.error),
          _pastille('Révision', AppTheme.secondaire),
          _pastille('Événement', theme.colorScheme.tertiary),
        ],
      ),
    );
  }

  Widget _pastille(String libelle, Color couleur) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(libelle, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _agendaDuJour() {
    final theme = Theme.of(context);
    final entrees = _entreesDuJour();

    if (!_anneeConfiguree) {
      return _Bandeau(
        message:
            'Aucune année académique configurée. Commencez par en créer '
            'une.',
        action: 'Configurer',
        onPressed: () => _ouvrir(const AnneeCouranteScreen()),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Planning du ${_jourSelectionne.day}/'
                    '${_jourSelectionne.month}/${_jourSelectionne.year}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _planifier(_jourSelectionne),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Planifier'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (entrees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Rien de planifié ce jour-là.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              ...entrees.map(
                (entree) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(entree.icone, size: 18, color: entree.couleur),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entree.titre,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entree.sousTitre.isNotEmpty)
                        Text(
                          entree.sousTitre,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _grille(List<Widget> cartes) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final colonnes = contraintes.maxWidth > 600 ? 4 : 2;

        // Hauteur fixe plutot qu'un ratio : la carte contient deux textes de
        // une a deux lignes, un ratio calculé sur la largeur deborde des que la
        // fenetre devient etroite.
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: colonnes,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: MediaQuery.of(context).size.height * 0.20,
          ),
          children: cartes,
        );
      },
    );
  }
}

/// Une entree d'agenda : composition, journee de revision ou evenement.
class _Entree {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final Color couleur;

  const _Entree({
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.couleur,
  });
}

class _Carte extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final VoidCallback onTap;

  const _Carte({
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              // Les textes se reduisent plutot que de deborder quand la carte
              // est courte.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        titre,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        sousTitre,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bandeau extends StatelessWidget {
  final String message;
  final String action;
  final VoidCallback onPressed;

  const _Bandeau({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(message),
        trailing: FilledButton.tonal(onPressed: onPressed, child: Text(action)),
      ),
    );
  }
}

class _Tiroir extends StatelessWidget {
  final String nomComplet;
  final String initiales;
  final String libelleTheme;
  final bool verrouillageActif;
  final VoidCallback onProfilTap;
  final VoidCallback onThemeTap;
  final VoidCallback onVerrouiller;

  const _Tiroir({
    required this.nomComplet,
    required this.initiales,
    required this.libelleTheme,
    required this.verrouillageActif,
    required this.onProfilTap,
    required this.onThemeTap,
    required this.onVerrouiller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.secondaire,
                  child: Text(
                    initiales,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nomComplet,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Profil et réglages'),
            onTap: onProfilTap,
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(libelleTheme),
            onTap: onThemeTap,
          ),
          const Divider(),
          // Verrouiller n'a de sens que si le verrouillage est actif : sinon
          // l'application s'ouvrira de nouveau sans rien demander.
          if (verrouillageActif)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Verrouiller'),
              onTap: onVerrouiller,
            ),
        ],
      ),
    );
  }
}
