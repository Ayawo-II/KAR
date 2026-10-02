import 'package:sqflite_common/sqlite_api.dart';

import '../models/annee_courante.dart';
import '../models/composition.dart';
import '../models/evenement.dart';
import '../models/matiere.dart';
import '../models/note.dart';
import '../models/programme.dart';
import '../models/ue.dart';
import 'db_platform.dart';

/// Acces bas niveau a la base SQLite : cycle de vie, schema et transactions.
///
/// Les cas d'usage metier sont exposes par les services de `lib/services/`.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  /// Version du schema.
  ///
  /// 1 : schema initial (anneeCourante, utilisateur, matiere, composition,
  ///     programme, matiere_programme).
  /// 2 : suppression de `utilisateur`. Le profil et le code PIN vivent desormais
  ///     dans les preferences, l'application devient mono-utilisateur.
  /// 3 : ajout de `note`.
  /// 4 : ajout de `evenement`.
  /// 5 : refonte etudiant. `ecole` devient `universite`, `classe` devient
  ///     `niveau`, `filiere` devient `faculte`, `departement` est ajoute, et
  ///     chaque matiere indique si elle comporte des devoirs.
  /// 6 : unite d'enseignement. `ue` porte le credit et le semestre, et chaque
  ///     matiere y est rattachee par `ueId`.
  static const int _versionSchema = 6;

  static Database? _database;

  Future<Database> get database async {
    final existante = _database;
    if (existante != null) return existante;

    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    return platformDatabaseFactory.openDatabase(
      await platformDatabasePath,
      options: OpenDatabaseOptions(
        version: _versionSchema,
        onConfigure: (db) async {
          // SQLite desactive les cles etrangeres par defaut : sans ce PRAGMA,
          // les ON DELETE CASCADE du schema ne s'appliquent jamais.
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          for (final instruction in _schemaComplet) {
            await db.execute(instruction);
          }
        },
        onUpgrade: (db, ancienVersion, nouvelleVersion) async {
          if (ancienVersion < 2) {
            // Le profil et le PIN sont passes en preferences : plus aucune
            // donnee a conserver ici.
            await db.execute('DROP TABLE IF EXISTS utilisateur');
          }
          if (ancienVersion < 3) {
            await db.execute(_schemaNote);
          }
          if (ancienVersion < 4) {
            await db.execute(_schemaEvenement);
          }
          if (ancienVersion < 5) {
            await _versSchemaEtudiant(db);
          }
          if (ancienVersion < 6) {
            await _versSchemaUe(db);
          }
        },
      ),
    );
  }

  /// Passage au modele etudiant : nomenclature universitaire et presence ou
  /// non de devoirs par matiere.
  ///
  /// Les renommages se font colonne par colonne plutot qu'en recreant la
  /// table : `ALTER TABLE ... RENAME COLUMN` ne touche que le schema, sans
  /// reecrire les lignes, et laisse intactes les cles etrangeres, qui
  /// referencent la table et non ses colonnes. Recreer la table aurait
  /// declenche les `ON DELETE CASCADE` de `matiere`, `composition` et `note`,
  /// donc perdu toutes les donnees de l'annee.
  ///
  /// Le renommage de colonne demande SQLite 3.25 (2018) : il est honore par
  /// la bibliotheque SQLite compilee pour le web et par sqflite_common_ffi,
  /// ainsi que par tout appareil Android shipping depuis Android 10.
  static Future<void> _versSchemaEtudiant(Database db) async {
    await db.execute(
      'ALTER TABLE anneeCourante RENAME COLUMN ecole TO universite',
    );
    await db.execute(
      'ALTER TABLE anneeCourante RENAME COLUMN classe TO niveau',
    );
    await db.execute(
      'ALTER TABLE anneeCourante RENAME COLUMN filiere TO faculte',
    );
    await db.execute(
      "ALTER TABLE anneeCourante ADD COLUMN departement VARCHAR(50) "
      "NOT NULL DEFAULT ''",
    );
    await db.execute(
      'ALTER TABLE matiere ADD COLUMN avecDevoir INTEGER NOT NULL DEFAULT 1',
    );
  }

  /// Introduction des unites d'enseignement.
  ///
  /// `ue` est creee avant la colonne `ueId`, et chaque matiere devient une UE
  /// directe a son image : elle conserve son nom, son coefficient et son
  /// credit. Aucune donnee n'est perdue, et aucune matiere ne se retrouve sans
  /// UE.
  static Future<void> _versSchemaUe(Database db) async {
    await db.execute(_schemaUe);
    await db.execute(
      'ALTER TABLE matiere ADD COLUMN ueId INTEGER REFERENCES ue(id) '
      'ON DELETE CASCADE',
    );

    final matieres = await db.query('matiere', orderBy: 'id ASC');

    for (final matiere in matieres) {
      final ueId = await db.insert('ue', {
        'libelle': matiere['libMatiere'],
        'credit': matiere['credit'],
        'semestre': matiere['semestre'],
        'anneeId': matiere['anneeId'],
      });

      await db.update(
        'matiere',
        {'ueId': ueId},
        where: 'id = ?',
        whereArgs: [matiere['id']],
      );
    }
  }

  static const List<String> _schemaComplet = [
    _schemaUe,
    '''
    CREATE TABLE anneeCourante (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        anneeDebut INTEGER NOT NULL,
        anneeFin INTEGER NOT NULL,
        universite VARCHAR(100) NOT NULL,
        niveau VARCHAR(30) NOT NULL,
        faculte VARCHAR(50) NOT NULL,
        departement VARCHAR(50) NOT NULL DEFAULT '',
        valDevoirs INTEGER NOT NULL,
        valExam INTEGER NOT NULL,
        statutAnnee TEXT CHECK(statutAnnee IN ('en cours', 'terminée'))
    )
    ''',
    '''
    CREATE TABLE matiere (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      libMatiere VARCHAR(100) NOT NULL,
      coef INTEGER NOT NULL,
      credit INTEGER NOT NULL,
      anneeId INTEGER NOT NULL,
      semestre INTEGER NOT NULL,
      avecDevoir INTEGER NOT NULL DEFAULT 1,
      ueId INTEGER REFERENCES ue(id) ON DELETE CASCADE,
      FOREIGN KEY (anneeId) REFERENCES anneeCourante(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE composition (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type VARCHAR(10) NOT NULL,
      dateCompo TEXT NOT NULL,
      matiereId INTEGER NOT NULL,
      FOREIGN KEY (matiereId) REFERENCES matiere(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE programme (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      jour TEXT NOT NULL,
      statut TEXT CHECK(statut IN ('respecté', 'non respecté'))
    )
    ''',
    '''
    CREATE TABLE matiere_programme (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      matiereId INTEGER NOT NULL,
      programmeId INTEGER NOT NULL,
      statut TEXT CHECK(statut IN ('validé', 'non validé')),
      FOREIGN KEY (matiereId) REFERENCES matiere(id) ON DELETE CASCADE,
      FOREIGN KEY (programmeId) REFERENCES programme(id) ON DELETE CASCADE,
      UNIQUE (matiereId, programmeId)
    )
    ''',
    _schemaNote,
    _schemaEvenement,
  ];

  /// Unite d'enseignement : porteuse du credit, elle regroupe une ou
  /// plusieurs matieres.
  static const String _schemaUe = '''
    CREATE TABLE ue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      libelle VARCHAR(100) NOT NULL,
      credit INTEGER NOT NULL,
      semestre INTEGER NOT NULL,
      anneeId INTEGER NOT NULL,
      FOREIGN KEY (anneeId) REFERENCES anneeCourante(id) ON DELETE CASCADE
    )
    ''';

  /// Notes : un devoir ou un examen rapporte pour une matiere.
  static const String _schemaNote = '''
    CREATE TABLE note (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      libelle VARCHAR(100) NOT NULL,
      dateNote TEXT NOT NULL,
      valeur REAL NOT NULL,
      type VARCHAR(10) NOT NULL CHECK(type IN ('devoir', 'examen')),
      matiereId INTEGER NOT NULL,
      FOREIGN KEY (matiereId) REFERENCES matiere(id) ON DELETE CASCADE
    )
    ''';

  /// Agenda personnel : sans lien avec les matieres.
  static const String _schemaEvenement = '''
    CREATE TABLE evenement (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      titre VARCHAR(150) NOT NULL,
      description TEXT,
      dateDebut TEXT NOT NULL,
      dateFin TEXT NOT NULL,
      categorie VARCHAR(30) NOT NULL DEFAULT 'Autre'
    )
    ''';

  Future<void> close() async {
    final existante = _database;
    _database = null;
    await existante?.close();
  }

  /// Supprime la base et rouvre une base vide.
  ///
  /// Utilise quand le code PIN est perdu : le profil et le code vivent dans les
  /// preferences, cette methode ne touche pas a celles-ci.
  Future<void> supprimerBase() async {
    await close();
    await platformDatabaseFactory.deleteDatabase(await platformDatabasePath);
  }

  // ---------------------------------------------------------------- annee

  /// Insere une annee, ses unites d'enseignement et leurs matieres dans une
  /// seule transaction.
  ///
  /// Les matieres sont inserees apres leur UE, dont SQLite vient d'attribuer
  /// l'identifiant : c'est lui qui est reporte dans `ueId`. Le credit de l'UE
  /// est egalement recopie sur ses matieres, qui n'en portent pas d'autre.
  ///
  /// Si l'annee existe deja, une [StateError] est levee : une double
  /// soumission ne doit pas creer une seconde annee en silence.
  Future<int> ajouterAnneeEtUes(
    AnneeCourante annee,
    List<UeAvecMatieres> unites,
  ) async {
    final db = await database;

    return db.transaction((txn) async {
      final doublon = await txn.query(
        'anneeCourante',
        where: 'anneeDebut = ? AND anneeFin = ? AND universite = ?',
        whereArgs: [annee.anneeDebut, annee.anneeFin, annee.universite],
        limit: 1,
      );

      if (doublon.isNotEmpty) {
        throw StateError(
          'L\'annee ${annee.anneeDebut}-${annee.anneeFin} est deja enregistree '
          'pour ${annee.universite}.',
        );
      }

      final anneeId = await txn.insert('anneeCourante', annee.toMap());

      for (final bloc in unites) {
        final ue = bloc.ue;
        ue.anneeId = anneeId;
        final ueId = await txn.insert('ue', ue.toMap());

        for (final matiere in bloc.matieres) {
          matiere.anneeId = anneeId;
          matiere.ueId = ueId;
          await txn.insert('matiere', {
            ...matiere.toMap(),
            'credit': ue.credit,
          });
        }
      }

      return anneeId;
    });
  }

  /// L'annee acadamique en cours, ou null si aucune n'est configuree.
  Future<AnneeCourante?> recupererAnneeCourante() async {
    final db = await database;

    final resultat = await db.query(
      'anneeCourante',
      where: 'statutAnnee = ?',
      whereArgs: ['en cours'],
      limit: 1,
    );

    if (resultat.isEmpty) return null;
    return AnneeCourante.fromMap(resultat.first);
  }

  /// Toutes les matieres de l'annee en cours.
  Future<List<Matiere>> recupererMatieres() async {
    final db = await database;

    final annee = await recupererAnneeCourante();
    if (annee?.id == null) return [];

    final resultat = await db.query(
      'matiere',
      where: 'anneeId = ?',
      whereArgs: [annee!.id],
      orderBy: 'semestre ASC, ueId ASC, libMatiere ASC',
    );

    return resultat.map(Matiere.fromMap).toList();
  }

  /// Les unites d'enseignement de l'annee en cours, chacune avec ses
  /// matieres.
  ///
  /// Le credit et le semestre sont lus sur l'UE : une UE composite garde son
  /// credit, ses matieres n'en ont pas en propre.
  Future<List<UeAvecMatieres>> recupererUes() async {
    final db = await database;

    final annee = await recupererAnneeCourante();
    if (annee?.id == null) return [];

    final resultatUes = await db.query(
      'ue',
      where: 'anneeId = ?',
      whereArgs: [annee!.id],
      orderBy: 'semestre ASC, libelle ASC',
    );

    final resultatMatieres = await db.query(
      'matiere',
      where: 'anneeId = ?',
      whereArgs: [annee.id],
      orderBy: 'libMatiere ASC',
    );

    final matieres = resultatMatieres.map(Matiere.fromMap).toList();

    return resultatUes.map((ligne) {
      final ue = Ue.fromMap(ligne);
      return UeAvecMatieres(
        ue: ue,
        matieres: matieres.where((matiere) => matiere.ueId == ue.id).toList(),
      );
    }).toList();
  }

  // ---------------------------------------------------------- composition

  /// Planifie une composition (devoir ou examen) pour une matiere.
  Future<int> planifierComposition({
    required Matiere matiere,
    required String type,
    required DateTime date,
  }) async {
    final db = await database;

    final composition = Composition(
      type: type,
      date: date,
      matiereId: matiere.id!,
    );

    return db.insert('composition', composition.toMap());
  }

  /// Les compositions comprises dans [debut, fin] (bornes incluses).
  ///
  /// Chaque composition est renvoyee avec le nom de sa matiere resolu, pour
  /// eviter un second aller-retour en base a l'affichage.
  Future<List<CompositionAvecMatiere>> recupererCompositions({
    required DateTime debut,
    required DateTime fin,
  }) async {
    final db = await database;

    final resultat = await db.rawQuery(
      '''
      SELECT c.id AS id,
             c.type AS type,
             c.dateCompo AS dateCompo,
             c.matiereId AS matiereId,
             m.libMatiere AS libMatiere
        FROM composition c
        JOIN matiere m ON m.id = c.matiereId
       WHERE date(c.dateCompo) BETWEEN date(?) AND date(?)
       ORDER BY c.dateCompo ASC, m.libMatiere ASC
      ''',
      [_formatDate(debut), _formatDate(fin)],
    );

    return resultat
        .map(
          (ligne) => CompositionAvecMatiere(
            composition: Composition.fromMap(ligne),
            libMatiere: ligne['libMatiere'] as String,
          ),
        )
        .toList();
  }

  Future<void> supprimerComposition(int id) async {
    final db = await database;
    await db.delete('composition', where: 'id = ?', whereArgs: [id]);
  }

  // ----------------------------------------------------------------- notes

  /// Enregistre une note. Le type est normalise sur les deux valeurs du
  /// domaine pour ne jamais violer la contrainte CHECK.
  Future<int> ajouterNote(Note note) async {
    final db = await database;

    return db.insert('note', note.toMap());
  }

  /// Notes d'une matiere, de la plus recente a la plus ancienne.
  Future<List<Note>> recupererNotesMatiere(int matiereId) async {
    final db = await database;

    final resultat = await db.query(
      'note',
      where: 'matiereId = ?',
      whereArgs: [matiereId],
      orderBy: 'dateNote DESC',
    );

    return resultat.map(Note.fromMap).toList();
  }

  /// Toutes les notes de l'annee en cours, avec le nom et le coefficient de
  /// leur matiere.
  Future<List<NoteAvecMatiere>> recupererToutesNotes() async {
    final db = await database;

    final resultat = await db.rawQuery('''
      SELECT n.id AS id,
             n.libelle AS libelle,
             n.dateNote AS dateNote,
             n.valeur AS valeur,
             n.type AS type,
             n.matiereId AS matiereId,
             m.libMatiere AS libMatiere,
             m.coef AS coef
        FROM note n
        JOIN matiere m ON m.id = n.matiereId
       ORDER BY n.dateNote DESC, m.libMatiere ASC
    ''');

    return resultat
        .map(
          (ligne) => NoteAvecMatiere(
            note: Note.fromMap(ligne),
            libMatiere: ligne['libMatiere'] as String,
            coef: ligne['coef'] as int,
          ),
        )
        .toList();
  }

  Future<void> supprimerNote(int id) async {
    final db = await database;
    await db.delete('note', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------- programme

  /// Planifie une journee de revision pour les matieres [matiereIds].
  Future<int> planifierProgramme({
    required DateTime jour,
    required List<int> matiereIds,
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      final programmeId = await txn.insert(
        'programme',
        Programme(jour: jour, statut: StatutProgramme.nonRespecte).toMap(),
      );

      for (final matiereId in matiereIds) {
        await txn.insert('matiere_programme', {
          'matiereId': matiereId,
          'programmeId': programmeId,
          'statut': StatutProgramme.nonValide,
        });
      }

      return programmeId;
    });
  }

  /// Les journees de revision comprises dans [debut, fin].
  Future<List<ProgrammeAvecMatieres>> recupererProgrammes({
    required DateTime debut,
    required DateTime fin,
  }) async {
    final db = await database;

    final resultat = await db.query(
      'programme',
      where: 'date(jour) BETWEEN date(?) AND date(?)',
      whereArgs: [_formatDate(debut), _formatDate(fin)],
      orderBy: 'jour ASC',
    );

    final programmes = <ProgrammeAvecMatieres>[];

    for (final ligne in resultat) {
      final programme = Programme.fromMap(ligne);

      final liens = await db.query(
        'matiere_programme',
        where: 'programmeId = ?',
        whereArgs: [programme.id],
      );

      final matieres = <Matiere>[];
      for (final lien in liens) {
        final matiereId = lien['matiereId'] as int;
        final matieresLigne = await db.query(
          'matiere',
          where: 'id = ?',
          whereArgs: [matiereId],
          limit: 1,
        );
        if (matieresLigne.isNotEmpty) {
          matieres.add(Matiere.fromMap(matieresLigne.first));
        }
      }

      programmes.add(
        ProgrammeAvecMatieres(programme: programme, matieres: matieres),
      );
    }

    return programmes;
  }

  /// Bascule le statut d'une journee de revision entre « respecté » et
  /// « non respecté ».
  Future<void> changerStatutProgramme(int programmeId, String statut) async {
    final db = await database;
    await db.update(
      'programme',
      {'statut': statut},
      where: 'id = ?',
      whereArgs: [programmeId],
    );
  }

  Future<void> supprimerProgramme(int programmeId) async {
    final db = await database;
    await db.delete('programme', where: 'id = ?', whereArgs: [programmeId]);
  }

  // ------------------------------------------------------------ evenements

  Future<int> ajouterEvenement(Evenement evenement) async {
    final db = await database;
    return db.insert('evenement', evenement.toMap());
  }

  Future<void> modifierEvenement(Evenement evenement) async {
    final db = await database;
    await db.update(
      'evenement',
      evenement.toMap(),
      where: 'id = ?',
      whereArgs: [evenement.id],
    );
  }

  /// Les evenements commencant dans [debut, fin], du plus ancien au plus
  /// recent.
  Future<List<Evenement>> recupererEvenements({
    required DateTime debut,
    required DateTime fin,
  }) async {
    final db = await database;

    final resultat = await db.query(
      'evenement',
      where: 'date(dateDebut) BETWEEN date(?) AND date(?)',
      whereArgs: [_formatDate(debut), _formatDate(fin)],
      orderBy: 'dateDebut ASC',
    );

    return resultat.map(Evenement.fromMap).toList();
  }

  Future<void> supprimerEvenement(int id) async {
    final db = await database;
    await db.delete('evenement', where: 'id = ?', whereArgs: [id]);
  }

  /// Date au format `AAAA-MM-JJ`, seule forme acceptee par les fonctions
  /// `date()` de SQLite.
  static String _formatDate(DateTime date) {
    final mois = date.month.toString().padLeft(2, '0');
    final jour = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mois-$jour';
  }
}

/// Une journee de revision avec les matieres concernees.
class ProgrammeAvecMatieres {
  final Programme programme;
  final List<Matiere> matieres;

  const ProgrammeAvecMatieres({
    required this.programme,
    required this.matieres,
  });
}

/// Une composition associee au nom de sa matiere, pour l'affichage.
class CompositionAvecMatiere {
  final Composition composition;
  final String libMatiere;

  const CompositionAvecMatiere({
    required this.composition,
    required this.libMatiere,
  });
}
