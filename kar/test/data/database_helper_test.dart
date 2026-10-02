import 'package:flutter_test/flutter_test.dart';
import 'package:kar/data/database_helper.dart';
import 'package:kar/data/db_platform.dart';
import 'package:kar/models/annee_courante.dart';
import 'package:kar/models/evenement.dart';
import 'package:kar/models/matiere.dart';
import 'package:kar/models/note.dart';
import 'package:kar/models/programme.dart';
import 'package:kar/models/ue.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.supprimerBase();
  });

  tearDown(() async {
    await DatabaseHelper.instance.supprimerBase();
  });

  AnneeCourante annee({String universite = 'Universite de Test'}) =>
      AnneeCourante(
        anneeDebut: 2024,
        anneeFin: 2025,
        universite: universite,
        niveau: 'L2',
        faculte: 'Droit',
        departement: 'Option A',
        valDevoirs: '50',
        valExam: '50',
        statutAnnee: AnneeCourante.enCours,
      );

  Matiere matiere(
    String nom, {
    int coef = 1,
    int semestre = 1,
    bool avecDevoir = true,
  }) => Matiere(
    libMatiere: nom,
    coef: coef,
    credit: 1,
    semestre: semestre,
    anneeId: 0,
    avecDevoir: avecDevoir,
  );

  /// UE directe : une seule matiere, du meme nom, dont le credit est celui de
  /// l'UE.
  UeAvecMatieres ue(
    String nom, {
    int coef = 1,
    int credit = 4,
    int semestre = 1,
    bool avecDevoir = true,
  }) => UeAvecMatieres(
    ue: Ue(libelle: nom, credit: credit, semestre: semestre, anneeId: 0),
    matieres: [
      matiere(nom, coef: coef, semestre: semestre, avecDevoir: avecDevoir),
    ],
  );

  /// UE composite : plusieurs matieres, chacune avec son coefficient, et un
  /// seul credit pour l'ensemble.
  UeAvecMatieres ueComposite(
    String nom, {
    required List<({String nom, int coef})> matieres,
    int credit = 6,
    int semestre = 1,
  }) => UeAvecMatieres(
    ue: Ue(libelle: nom, credit: credit, semestre: semestre, anneeId: 0),
    matieres: [
      for (final item in matieres)
        matiere(item.nom, coef: item.coef, semestre: semestre),
    ],
  );

  test('cree une annee et ses UE, puis les relit', () async {
    final db = DatabaseHelper.instance;
    final anneeId = await db.ajouterAnneeEtUes(annee(), [
      ue('Maths', coef: 5),
      ue('Physique', semestre: 2),
    ]);

    expect(anneeId, greaterThan(0));

    final relue = await db.recupererAnneeCourante();
    expect(relue, isNotNull);
    expect(relue!.anneeDebut, 2024);
    expect(relue.anneeFin, 2025);
    expect(relue.libelle, '2024 - 2025');
    expect(relue.universite, 'Universite de Test');
    expect(relue.niveau, 'L2');
    expect(relue.faculte, 'Droit');
    expect(relue.departement, 'Option A');

    final unites = await db.recupererUes();
    expect(unites.map((bloc) => bloc.ue.libelle), ['Maths', 'Physique']);
    expect(unites.first.ue.anneeId, anneeId);
    expect(unites.first.ue.credit, 4);
    expect(unites.last.ue.semestre, 2);

    final matieres = await db.recupererMatieres();
    expect(matieres.map((m) => m.libMatiere), ['Maths', 'Physique']);
    expect(matieres.first.anneeId, anneeId);
    expect(matieres.every((m) => m.avecDevoir), isTrue);
  });

  test('chaque matiere est rattachee a son UE', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtUes(annee(), [ue('Histoire'), ue('Anglais')]);

    final unites = await db.recupererUes();
    final matieres = await db.recupererMatieres();

    expect(
      unites.map((bloc) => bloc.ue.id),
      matieres.map((m) => m.ueId).toSet(),
    );
    expect(matieres.every((m) => m.ueId != null), isTrue);

    // Une UE directe ne porte qu'une matiere, la UE elle-meme.
    expect(unites.every((bloc) => bloc.directe), isTrue);
    expect(unites.first.matieres.single.libMatiere, unites.first.ue.libelle);
    expect(
      unites.every((bloc) => bloc.matieres.single.ueId == bloc.ue.id),
      isTrue,
    );
  });

  test('une UE composite garde son credit unique', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtUes(annee(), [
      ueComposite(
        'Analyse numérique',
        matieres: [(nom: 'Algèbre', coef: 2), (nom: 'Analyse', coef: 1)],
        credit: 6,
      ),
    ]);

    final unites = await db.recupererUes();
    expect(unites.single.ue.credit, 6);
    expect(unites.single.directe, isFalse);
    expect(
      unites.single.matieres.map((m) => m.libMatiere),
      containsAll(['Algèbre', 'Analyse']),
    );
    expect(unites.single.matieres.map((m) => m.coef), containsAll([1, 2]));

    // Le credit appartient a l'UE : il est recopie sur ses matieres, jamais
    // partage entre elles.
    expect(unites.single.matieres.map((m) => m.credit), everyElement(6));
  });

  test('memmorise qu\'une matiere n\'a pas de devoirs', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtUes(annee(), [
      ue('Memoire', avecDevoir: false),
      ue('Histoire'),
    ]);

    final unites = await db.recupererUes();
    final memoire = unites.firstWhere((bloc) => bloc.ue.libelle == 'Memoire');
    final histoire = unites.firstWhere((bloc) => bloc.ue.libelle == 'Histoire');

    expect(memoire.matieres.single.avecDevoir, isFalse);
    expect(histoire.matieres.single.avecDevoir, isTrue);
  });

  test('refuse une seconde annee identique', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtUes(annee(), [ue('Maths')]);

    expect(
      () => db.ajouterAnneeEtUes(annee(), [ue('Maths')]),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'accepte deux annees de meme etablissement a des dates differentes',
    () async {
      final db = DatabaseHelper.instance;
      await db.ajouterAnneeEtUes(annee(), [ue('Maths')]);

      final suivante = AnneeCourante(
        anneeDebut: 2025,
        anneeFin: 2026,
        universite: 'Universite de Test',
        niveau: 'L3',
        faculte: 'Droit',
        valDevoirs: '40',
        valExam: '60',
        statutAnnee: AnneeCourante.enCours,
      );

      expect(
        await db.ajouterAnneeEtUes(suivante, [ue('Maths')]),
        greaterThan(0),
      );
    },
  );

  test('planifie une composition et resout le nom de la matiere', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtUes(annee(), [ue('Histoire')]);
    final histoire = (await db.recupererMatieres()).single;

    await db.planifierComposition(
      matiere: histoire,
      type: 'examen',
      date: DateTime(2025, 3, 10),
    );

    final compositions = await db.recupererCompositions(
      debut: DateTime(2025, 3, 1),
      fin: DateTime(2025, 3, 31),
    );

    expect(compositions, hasLength(1));
    expect(compositions.single.libMatiere, 'Histoire');
    expect(compositions.single.composition.type, 'examen');

    await db.supprimerComposition(compositions.single.composition.id!);
    expect(
      await db.recupererCompositions(
        debut: DateTime(2025, 3, 1),
        fin: DateTime(2025, 3, 31),
      ),
      isEmpty,
    );
  });

  test('enregistre des notes et les relit avec leur matiere', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtUes(annee(), [ue('Anglais', coef: 2)]);
    final anglais = (await db.recupererMatieres()).single;

    await db.ajouterNote(
      Note(
        libelle: 'Comprehension',
        date: DateTime(2025, 2, 5),
        valeur: 14.5,
        type: 'devoir',
        matiereId: anglais.id!,
      ),
    );
    await db.ajouterNote(
      Note(
        libelle: 'Oral',
        date: DateTime(2025, 2, 6),
        valeur: 12,
        type: 'examen',
        matiereId: anglais.id!,
      ),
    );

    final notes = await db.recupererToutesNotes();
    expect(notes, hasLength(2));
    expect(notes.first.libMatiere, 'Anglais');
    expect(notes.first.coef, 2);
    expect(notes.map((n) => n.note.valeur), contains(14.5));

    await db.supprimerNote(notes.first.note.id!);
    expect(await db.recupererToutesNotes(), hasLength(1));
  });

  test('planifie un programme de revision et bascule son statut', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtUes(annee(), [ue('Maths'), ue('SVT', semestre: 2)]);
    final ids = (await db.recupererMatieres()).map((m) => m.id!).toList();

    await db.planifierProgramme(jour: DateTime(2025, 4, 12), matiereIds: ids);

    var programmes = await db.recupererProgrammes(
      debut: DateTime(2025, 4, 1),
      fin: DateTime(2025, 4, 30),
    );
    expect(programmes, hasLength(1));
    expect(programmes.single.matieres, hasLength(2));
    expect(programmes.single.programme.statut, StatutProgramme.nonRespecte);

    await db.changerStatutProgramme(
      programmes.single.programme.id!,
      StatutProgramme.respecte,
    );

    programmes = await db.recupererProgrammes(
      debut: DateTime(2025, 4, 1),
      fin: DateTime(2025, 4, 30),
    );
    expect(programmes.single.programme.statut, StatutProgramme.respecte);
  });

  test('ajoute, modifie et supprime un evenement', () async {
    final db = DatabaseHelper.instance;
    final id = await db.ajouterEvenement(
      Evenement(
        titre: 'Vacances',
        dateDebut: DateTime(2025, 7, 1),
        dateFin: DateTime(2025, 8, 31),
        categorie: Evenement.categorieVacances,
      ),
    );

    var evenements = await db.recupererEvenements(
      debut: DateTime(2025, 1, 1),
      fin: DateTime(2025, 12, 31),
    );
    expect(evenements, hasLength(1));
    expect(evenements.single.titre, 'Vacances');

    await db.modifierEvenement(
      Evenement(
        id: id,
        titre: 'Grandes vacances',
        dateDebut: DateTime(2025, 7, 1),
        dateFin: DateTime(2025, 8, 31),
        categorie: Evenement.categorieVacances,
      ),
    );

    evenements = await db.recupererEvenements(
      debut: DateTime(2025, 1, 1),
      fin: DateTime(2025, 12, 31),
    );
    expect(evenements.single.titre, 'Grandes vacances');

    await db.supprimerEvenement(id);
    expect(
      await db.recupererEvenements(
        debut: DateTime(2025, 1, 1),
        fin: DateTime(2025, 12, 31),
      ),
      isEmpty,
    );
  });

  test(
    'les cles etrangeres suppriment compositions et notes en cascade',
    () async {
      final db = DatabaseHelper.instance;
      await db.ajouterAnneeEtUes(annee(), [ue('Maths')]);
      final maths = (await db.recupererMatieres()).single;

      await db.planifierComposition(
        matiere: maths,
        type: 'devoir',
        date: DateTime(2025, 5, 5),
      );
      await db.ajouterNote(
        Note(
          libelle: 'Interro',
          date: DateTime(2025, 5, 5),
          valeur: 11,
          type: 'devoir',
          matiereId: maths.id!,
        ),
      );

      final base = await db.database;
      await base.delete('matiere', where: 'id = ?', whereArgs: [maths.id]);

      expect(
        await db.recupererCompositions(
          debut: DateTime(2025, 5, 1),
          fin: DateTime(2025, 5, 31),
        ),
        isEmpty,
      );
      expect(await db.recupererToutesNotes(), isEmpty);
    },
  );

  test('supprimer une annee emporte ses UE et leurs matieres', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtUes(annee(), [
      ueComposite('Analyse numérique', matieres: [(nom: 'Algèbre', coef: 2)]),
    ]);

    final base = await db.database;
    final ligne = (await base.query('anneeCourante', limit: 1)).single;
    await base.delete(
      'anneeCourante',
      where: 'id = ?',
      whereArgs: [ligne['id']],
    );

    expect(await db.recupererUes(), isEmpty);
    expect(await db.recupererMatieres(), isEmpty);
  });

  test('met a niveau une base v1 vers le schema courant', () async {
    final chemin = await platformDatabasePath;
    final factory = platformDatabaseFactory;

    await factory.deleteDatabase(chemin);

    // Schema v1 : `utilisateur` existe, les annees sont declarees en TEXT,
    // `note` et `evenement` n'existent pas, et les matieres n'ont ni colonne
    // `avecDevoir` ni `ueId`.
    final ancienne = await factory.openDatabase(
      chemin,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE anneeCourante (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              anneeDebut TEXT NOT NULL,
              anneeFin TEXT NOT NULL,
              ecole VARCHAR(100) NOT NULL,
              classe VARCHAR(30) NOT NULL,
              filiere VARCHAR(50) NOT NULL,
              valDevoirs INTEGER NOT NULL,
              valExam INTEGER NOT NULL,
              statutAnnee TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE matiere (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              libMatiere VARCHAR(100) NOT NULL,
              coef INTEGER NOT NULL,
              credit INTEGER NOT NULL,
              anneeId INTEGER NOT NULL,
              semestre INTEGER NOT NULL,
              FOREIGN KEY (anneeId) REFERENCES anneeCourante(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE utilisateur (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nom VARCHAR(100)
            )
          ''');
          await db.insert('anneeCourante', {
            'anneeDebut': 2019,
            'anneeFin': 2020,
            'ecole': 'Universite',
            'classe': 'L1',
            'filiere': 'Sciences',
            'valDevoirs': 50,
            'valExam': 50,
            'statutAnnee': 'en cours',
          });
          await db.insert('matiere', {
            'libMatiere': 'Algorithmique',
            'coef': 2,
            'credit': 3,
            'anneeId': 1,
            'semestre': 1,
          });
        },
      ),
    );
    await ancienne.close();

    // L'ouverture par le helper declenche onUpgrade jusqu'a la version 6.
    final db = DatabaseHelper.instance;
    final base = await db.database;

    final tables = await base.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final noms = tables.map((ligne) => ligne['name'] as String).toSet();
    expect(noms, isNot(contains('utilisateur')));
    expect(noms, contains('note'));
    expect(noms, contains('evenement'));
    expect(noms, contains('ue'));

    // Les annees stockees en TEXT restent lisibles malgre l'affinite.
    final relue = await db.recupererAnneeCourante();
    expect(relue, isNotNull);
    expect(relue!.anneeDebut, 2019);
    expect(relue.anneeFin, 2020);

    // La nomenclature scolaire a cede la place a la nomenclature etudiante.
    expect(relue.universite, 'Universite');
    expect(relue.niveau, 'L1');
    expect(relue.faculte, 'Sciences');
    expect(relue.departement, '');

    // Le renommage n'a recree aucune table : les matieres sont intactes et
    // hernitent de la presence de devoirs.
    final matieres = await db.recupererMatieres();
    expect(matieres, hasLength(1));
    expect(matieres.single.libMatiere, 'Algorithmique');
    expect(matieres.single.avecDevoir, isTrue);

    // L'annee anterieure aux UE devient une UE directe : la matiere en garde
    // le nom, le coefficient et le credit, et lui est desormais rattachee.
    final unites = await db.recupererUes();
    expect(unites, hasLength(1));
    expect(unites.single.ue.libelle, 'Algorithmique');
    expect(unites.single.ue.credit, 3);
    expect(unites.single.ue.semestre, 1);
    expect(unites.single.directe, isTrue);
    expect(matieres.single.ueId, unites.single.ue.id);
  });
}
