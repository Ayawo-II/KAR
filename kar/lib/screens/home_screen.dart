import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/database_helper.dart';
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
  final VoidCallback onDeconnexion;

  const HomeScreen({required this.onDeconnexion, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _jourFocus = DateTime.now();
  DateTime _jourSelectionne = DateTime.now();

  bool _anneeConfiguree = true;
  bool _verificationAnnee = true;

  @override
  void initState() {
    super.initState();
    _verifierAnnee();
  }

  Future<void> _verifierAnnee() async {
    final annee = await DatabaseHelper.instance.recupererAnneeCourante();
    if (!mounted) return;

    setState(() {
      _anneeConfiguree = annee != null;
      _verificationAnnee = false;
    });
  }

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

    final type = await _demanderType();
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
    _message('${type == 'devoir' ? 'Devoir' : 'Examen'} planifié le '
        '${jour.day}/${jour.month}/${jour.year}');
  }

  Future<String?> _demanderType() {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Type de composition'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('devoir'),
            child: const ListTile(
              leading: Icon(Icons.assignment_outlined),
              title: Text('Devoir'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('examen'),
            child: const ListTile(
              leading: Icon(Icons.assignment_turned_in_outlined),
              title: Text('Examen'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmerDeconnexion() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verrouiller'),
        content: const Text('Le code vous sera demandé à la réouverture.'),
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

    if (confirme == true) widget.onDeconnexion();
  }

  Future<void> _ouvrir(Widget ecran) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ecran),
    );

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
        onProfilTap: () => _ouvrir(const ReglagesScreen()),
        onThemeTap: appState.basculerTheme,
        onDeconnexion: _confirmerDeconnexion,
      ),
      body: SafeArea(
        child: _verificationAnnee
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  TableCalendar<void>(
                    locale: 'fr_FR',
                    firstDay: DateTime.utc(2000),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _jourFocus,
                    selectedDayPredicate: (jour) =>
                        isSameDay(_jourSelectionne, jour),
                    onDaySelected: (jourSelectionne, jourFocus) {
                      setState(() {
                        _jourSelectionne = jourSelectionne;
                        _jourFocus = jourFocus;
                      });
                    },
                  ),
                  if (!_anneeConfiguree)
                    _Bandeau(
                      message:
                          'Aucune année académique configurée. Commencez par en '
                          'créer une.',
                      action: 'Configurer',
                      onPressed: () => _ouvrir(const AnneeCouranteScreen()),
                    )
                  else
                    _Bandeau(
                      message:
                          'Planning du ${_jourSelectionne.day}/'
                          '${_jourSelectionne.month}/${_jourSelectionne.year}',
                      action: 'Planifier',
                      onPressed: () => _planifier(_jourSelectionne),
                    ),
                  _grille(
                    [
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
                        onTap: () =>
                            _ouvrir(const ProgrammeRevisionScreen()),
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
                    ],
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
        return GridView.count(
          crossAxisCount: colonnes,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          childAspectRatio: colonnes == 2 ? 1.15 : 1.4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: cartes,
        );
      },
    );
  }
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
    required this.onTap,
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
              const Spacer(),
              Text(
                titre,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                sousTitre,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
        trailing: FilledButton.tonal(
          onPressed: onPressed,
          child: Text(action),
        ),
      ),
    );
  }
}

class _Tiroir extends StatelessWidget {
  final String nomComplet;
  final String initiales;
  final String libelleTheme;
  final VoidCallback onProfilTap;
  final VoidCallback onThemeTap;
  final VoidCallback onDeconnexion;

  const _Tiroir({
    required this.nomComplet,
    required this.initiales,
    required this.libelleTheme,
    required this.onProfilTap,
    required this.onThemeTap,
    required this.onDeconnexion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
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
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Verrouiller'),
            onTap: onDeconnexion,
          ),
        ],
      ),
    );
  }
}