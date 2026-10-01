import 'package:flutter/material.dart';
import 'package:kar/models/composition.dart';
import 'package:kar/models/matiere.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../models/annee_courante.dart';
import '../models/utilisateur.dart';
import 'db_platform.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    WidgetsFlutterBinding.ensureInitialized();
    return platformDatabaseFactory.openDatabase(
      await platformDatabasePath,
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
              statutAnnee TEXT CHECK(statutAnnee IN ('en cours', 'terminée'))
          );
        ''');

          await db.execute('''
          CREATE TABLE utilisateur (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom VARCHAR(100),
            prenoms VARCHAR(100),
            password TEXT NOT NULL
          );
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
          );
        ''');

          await db.execute('''
          CREATE TABLE composition (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type VARCHAR(10) NOT NULL,
            dateCompo TEXT NOT NULL,
            matiereId INTEGER NOT NULL,
            FOREIGN KEY (matiereId) REFERENCES matiere(id) ON DELETE CASCADE
          );  
        ''');

          await db.execute('''
          CREATE TABLE programme (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            jour TEXT NOT NULL,
            statut TEXT CHECK(statut IN ('respecté', 'non respecté'))
          );
        ''');

          await db.execute('''
          CREATE TABLE matiere_programme (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            matiereId INTEGER NOT NULL,
            programmeId INTEGER NOT NULL,
            statut TEXT CHECK(statut IN ('validé', 'non validé')),
            FOREIGN KEY (matiereId) REFERENCES matiere(id) ON DELETE CASCADE,
            FOREIGN KEY (programmeId) REFERENCES programme(id) ON DELETE CASCADE,
            UNIQUE (matiereId, programmeId)
          );
        ''');
        },
      ),
    );
  }

  // enregistrer un utilisateur
  Future<int> ajouterUtilisateur(Utilisateur user) async {
    final Database db = await database;

    return await db.insert(
      'utilisateur',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Enregistrer une nouvelle année et matières
  Future<void> ajouterAnneeEtMatieres(
    AnneeCourante annee,
    List<Matiere> matieres,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      int anneeId = await txn.insert(
        'anneeCourante',
        annee.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (Matiere matiere in matieres) {
        matiere.anneeId = anneeId;
        await txn.insert(
          'matiere',
          matiere.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // récupérer toutes les matières de l'année en cours
  Future<List<Matiere>> recupererMatieres() async {
    final db = await instance.database;

    final anneeResult = await db.query(
      'anneeCourante',
      where: 'statutAnnee = ?',
      whereArgs: ['en cours'],
      limit: 1,
    );

    if (anneeResult.isEmpty) {
      return [];
    }

    final anneeId = anneeResult.first['id'] as int;

    final matieresResult = await db.query(
      'matiere',
      where: 'anneeId = ?',
      whereArgs: [anneeId],
    );

    return matieresResult.map((json) => Matiere.fromMap(json)).toList();
  }

  // plannifier un devoir
  Future<void> planifierDevoir(
    Matiere matiere,
    String type,
    DateTime date,
  ) async {
    final Database db = await database;

    final composition = Composition(
      type: type,
      date: date,
      matiereId: matiere.id!,
    );

    await db.insert(
      'composition',
      composition.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
