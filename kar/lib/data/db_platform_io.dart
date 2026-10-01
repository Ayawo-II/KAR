import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Factory native (Android, iOS, desktop) avec le plugin sqflite.
DatabaseFactory get platformDatabaseFactory => databaseFactory;

/// Chemin réel du fichier base de données sur le système de fichiers.
Future<String> get platformDatabasePath async =>
    join(await getDatabasesPath(), 'kar_database.db');
