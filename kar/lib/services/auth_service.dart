import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kar/data/database_helper.dart';
import 'package:kar/models/utilisateur.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String hashPassword(String password){
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }



  // Connexion
  static Future<Utilisateur?> login({
    required String password,
  })async{
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    final hashedPassword = hashPassword(password);

    final result = await db.query(
        'utilisateur',
      where: 'password = ?',
      whereArgs: [hashedPassword]
    );

    if (result.isNotEmpty){
      final utilisateur = Utilisateur.fromMap(result.first);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nom', utilisateur.nom);
      await prefs.setString('prenoms', utilisateur.prenoms);

      return utilisateur;
    }else{
      return null;
    }
  }


  //Déconnexion
  static Future<void> logout() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

  }

}