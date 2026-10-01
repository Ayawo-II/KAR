import 'package:flutter_test/flutter_test.dart';
import 'package:kar/data/database_helper.dart';
import 'package:kar/data/db_platform.dart';
import 'package:kar/models/annee_courante.dart';
import 'package:kar/models/evenement.dart';
import 'package:kar/models/matiere.dart';
import 'package:kar/models/note.dart';
import 'package:kar/models/programme.dart';
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

  AnneeCourante annee({String ecole = 'Lycee'}) => AnneeCourante(
        anneeDebut: 2024,
        anneeFin: 2025,
        ecole: ecole,
        classe: 'Terminale',
        filiere: 'D',
        valDevoirs: '50',
        valExam: '50',
        statutAnnee: AnneeCourante.enCours,
      );

  Matiere matiere(String nom, {int coef = 1, int semestre = 1}) => Matiere(
        libMatiere: nom,
        coef: coef,
        credit: 1,
        semestre: semestre,
        anneeId: 0,
      );

  test('cree une annee et ses matieres, puis les relit', () async {
    final db = DatabaseHelper.instance;
    final anneeId = await db.ajouterAnneeEtMatieres(
      annee(),
      [matiere('Maths', coef: 5), matiere('Physique', semestre: 2)],
    );

    expect(anneeId, greaterThan(0));

    final relue = await db.recupererAnneeCourante();
    expect(relue, isNotNull);
    expect(relue!.anneeDebut, 2024);
    expect(relue.anneeFin, 2025);
    expect(relue.libelle, '2024 - 2025');

    final matieres = await db.recupererMatieres();
    expect(matieres.map((m) => m.libMatiere), ['Maths', 'Physique']);
    expect(matieres.first.anneeId, anneeId);
  });

  test('refuse une seconde annee identique', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtMatieres(annee(), [matiere('Maths')]);

    expect(
      () => db.ajouterAnneeEtMatieres(annee(), [matiere('Maths')]),
      throwsA(isA<StateError>()),
    );
  });

  test('planifie une composition et resout le nom de la matiere', () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtMatieres(annee(), [matiere('Histoire')]);
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
    await db.ajouterAnneeEtMatieres(annee(), [matiere('Anglais', coef: 2)]);
    final anglais = (await db.recupererMatieres()).single;

    await db.ajouterNote(Note(
      libelle: 'Comprehension',
      date: DateTime(2025, 2, 5),
      valeur: 14.5,
      type: 'devoir',
      matiereId: anglais.id!,
    ));
    await db.ajouterNote(Note(
      libelle: 'Oral',
      date: DateTime(2025, 2, 6),
      valeur: 12,
      type: 'examen',
      matiereId: anglais.id!,
    ));

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
    await db.ajouterAnneeEtMatieres(
      annee(),
      [matiere('Maths'), matiere('SVT', semestre: 2)],
    );
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
    final id = await db.ajouterEvenement(Evenement(
      titre: 'Vacances',
      dateDebut: DateTime(2025, 7, 1),
      dateFin: DateTime(2025, 8, 31),
      categorie: Evenement.categorieVacances,
    ));

    var evenements = await db.recupererEvenements(
      debut: DateTime(2025, 1, 1),
      fin: DateTime(2025, 12, 31),
    );
    expect(evenements, hasLength(1));
    expect(evenements.single.titre, 'Vacances');

    await db.modifierEvenement(Evenement(
      id: id,
      titre: 'Grandes vacances',
      dateDebut: DateTime(2025, 7, 1),
      dateFin: DateTime(2025, 8, 31),
      categorie: Evenement.categorieVacances,
    ));

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

  test('les cles etrangeres suppriment compositions et notes en cascade',
      () async {
    final db = DatabaseHelper.instance;
    await db.ajouterAnneeEtMatieres(annee(), [matiere('Maths')]);
    final maths = (await db.recupererMatieres()).single;

    await db.planifierComposition(
      matiere: maths,
      type: 'devoir',
      date: DateTime(2025, 5, 5),
    );
    await db.ajouterNote(Note(
      libelle: 'Interro',
      date: DateTime(2025, 5, 5),
      valeur: 11,
      type: 'devoir',
      matiereId: maths.id!,
    ));

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
  });

  test('met a niveau une base v1 vers le schema courant', () async {
    final chemin = await platformDatabasePath;
    final factory = platformDatabaseFactory;

    await factory.deleteDatabase(chemin);

    // Schema v1 : `utilisateur` existe, les annees sont declarees en TEXT,
    // `note` et `evenement` n'existent pas.
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
            CREATE TABLE utilisateur (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nom VARCHAR(100)
            )
          ''');
          await db.insert('anneeCourante', {
            'anneeDebut': 2019,
            'anneeFin': 2020,
            'ecole': 'College',
            'classe': '3e',
            'filiere': 'Generale',
            'valDevoirs': 50,
            'valExam': 50,
            'statutAnnee': 'en cours',
          });
        },
      ),
    );
    await ancienne.close();

    // L'ouverture par le helper declenche onUpgrade jusqu'a la version 4.
    final db = DatabaseHelper.instance;
    final base = await db.database;

    final tables = await base.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final noms = tables.map((ligne) => ligne['name'] as String).toSet();
    expect(noms, isNot(contains('utilisateur')));
    expect(noms, contains('note'));
    expect(noms, contains('evenement'));

    // Les annees stockees en TEXT restent lisibles malgre l'affinite.
    final relue = await db.recupererAnneeCourante();
    expect(relue, isNotNull);
    expect(relue!.anneeDebut, 2019);
    expect(relue.anneeFin, 2020);
  });
}