import 'package:sqflite_common/sqlite_api.dart';

import '../models/annee_courante.dart';
import '../models/composition.dart';
import '../models/evenement.dart';
import '../models/matiere.dart';
import '../models/note.dart';
import '../models/programme.dart';
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
  static const int _versionSchema = 4;

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
        },
      ),
    );
  }

  static const List<String> _schemaComplet = [
    '''
    CREATE TABLE anneeCourante (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        anneeDebut INTEGER NOT NULL,
        anneeFin INTEGER NOT NULL,
        ecole VARCHAR(100) NOT NULL,
        classe VARCHAR(30) NOT NULL,
        filiere VARCHAR(50) NOT NULL,
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

  /// Insere une annee et ses matieres dans une seule transaction.
  ///
  /// Si l'annee existe deja, une [StateError] est levee : une double
  /// soumission ne doit pas creer une seconde annee en silence.
  Future<int> ajouterAnneeEtMatieres(
    AnneeCourante annee,
    List<Matiere> matieres,
  ) async {
    final db = await database;

    return db.transaction((txn) async {
      final doublon = await txn.query(
        'anneeCourante',
        where: 'anneeDebut = ? AND anneeFin = ? AND ecole = ?',
        whereArgs: [annee.anneeDebut, annee.anneeFin, annee.ecole],
        limit: 1,
      );

      if (doublon.isNotEmpty) {
        throw StateError(
          'L\'annee ${annee.anneeDebut}-${annee.anneeFin} est deja enregistree '
          'pour ${annee.ecole}.',
        );
      }

      final anneeId = await txn.insert('anneeCourante', annee.toMap());

      for (final matiere in matieres) {
        matiere.anneeId = anneeId;
        await txn.insert('matiere', matiere.toMap());
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
      orderBy: 'semestre ASC, libMatiere ASC',
    );

    return resultat.map(Matiere.fromMap).toList();
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
      [
        _formatDate(debut),
        _formatDate(fin),
      ],
    );

    return resultat
        .map((ligne) => CompositionAvecMatiere(
              composition: Composition.fromMap(ligne),
              libMatiere: ligne['libMatiere'] as String,
            ))
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
        .map((ligne) => NoteAvecMatiere(
              note: Note.fromMap(ligne),
              libMatiere: ligne['libMatiere'] as String,
              coef: ligne['coef'] as int,
            ))
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
        Programme(
          jour: jour,
          statut: StatutProgramme.nonRespecte,
        ).toMap(),
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

      programmes.add(ProgrammeAvecMatieres(
        programme: programme,
        matieres: matieres,
      ));
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