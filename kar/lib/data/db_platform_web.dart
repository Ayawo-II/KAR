import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Factory web : SQLite compilé en WASM, persisté dans l'IndexedDB.
DatabaseFactory get platformDatabaseFactory => databaseFactoryFfiWebNoWebWorker;

/// Chemin relatif résolu par le filesystem virtuel (IndexedDB) de SQLite WASM.
Future<String> get platformDatabasePath async => 'kar_database.db';
