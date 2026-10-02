import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Protection de l'application.
///
/// L'application est mono-utilisateur et le verrouillage est facultatif : rien
/// n'est demande tant que l'utilisateur ne l'a pas active dans les reglages.
///
/// Deux moyens de deverrouiller, dans cet ordre :
/// - la securite de l'appareil (empreinte, visage, sinon code, schema ou
///  Mot de passe) via `local_auth` ;
/// - le code de l'application, utilise en secours quand l'appareil ne sait pas
///   s'authentifier. Il n'est demande qu'a ce moment-la, et reste utile si
///   l'authentification systeme echoue.
///
/// Le code n'est jamais stocke en clair. Les preferences contiennent :
/// - `secu_verrouillage` : le verrouillage est-il actif ;
/// - `pin_sel` : un sel aleatoire de 128 bits, genere a la creation du code ;
/// - `pin_empreinte` : SHA-256(sel + code).
///
/// Ce stockage est adapte a un verrou local, pas a un mot de passe de compte en
/// ligne : il resiste a la lecture directe du stockage mais pas a une
/// retro-ingenierie materielle sur l'appareil.
class SecuriteService {
  static const String _cleVerrouillage = 'secu_verrouillage';
  static const String _cleSel = 'pin_sel';
  static const String _cleEmpreinte = 'pin_empreinte';

  /// Nombre d'echecs de saisie consecutifs.
  static const String _cleEchecs = 'pin_echecs';

  /// Delai avant re-essai apres [tentativesMax] echecs.
  static const String _cleBloqueJusqua = 'pin_bloque_jusqua';

  static const int tentativesMax = 5;
  static const Duration dureeBlocage = Duration(minutes: 5);

  /// Nombre de chiffres du code de secours.
  static const int longueurPin = 4;

  /// Code refuse a la creation : trivial a deviner.
  static const String codeInterdit = '0000';

  final LocalAuthentication _auth = LocalAuthentication();
  final Random _aleatoire = Random.secure();

  /// Vrai si l'appareil sait authentifier l'utilisateur.
  ///
  /// Le web n'a pas d'equivalent : l'application s'y ouvre directement.
  Future<bool> appareilSecurise() async {
    if (kIsWeb) return false;

    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      // Plateforme sans implementation : aucun verrouillage possible.
      return false;
    }
  }

  /// Vrai si l'utilisateur a demande un verrouillage.
  Future<bool> estActif() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cleVerrouillage) ?? false;
  }

  Future<void> activer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleVerrouillage, true);
  }

  Future<void> desactiver() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleVerrouillage, false);
  }

  /// Authentifie via la securite de l'appareil.
  ///
  /// Renvoie false si l'utilisateur annule, si l'authentification echoue, ou si
  /// l'appareil ne sait pas s'authentifier : l'appelant peut alors proposer le
  /// code de secours.
  Future<bool> authentifier({required String raison}) async {
    if (!await appareilSecurise()) return false;

    try {
      // `biometricOnly` laisse la boite de dialogue proposer le code de
      // l'appareil quand aucune empreinte n'est enregistree.
      return await _auth.authenticate(
        localizedReason: raison,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Aucun identifiant enregistre, materiel indisponible, authentification
      // en cours... dans tous les cas l'appelant garde la main.
      return false;
    }
  }

  /// Vrai si un code de secours existe.
  Future<bool> pinSecoursDefini() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_cleEmpreinte) ?? '').isNotEmpty;
  }

  /// Definit le code de secours. Remplace tout code existant.
  Future<void> definirPinSecours(String pin) async {
    final sel = _genererSel();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_cleSel, sel);
    await prefs.setString(_cleEmpreinte, _empreinte(pin, sel));
    await prefs.remove(_cleEchecs);
    await prefs.remove(_cleBloqueJusqua);
  }

  /// Supprime le code de secours.
  Future<void> supprimerPinSecours() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cleSel);
    await prefs.remove(_cleEmpreinte);
    await prefs.remove(_cleEchecs);
    await prefs.remove(_cleBloqueJusqua);
  }

  /// Verifie le code de secours saisi.
  ///
  /// Renvoie toujours false tant qu'un blocage est en cours, meme avec le bon
  /// code : la temporisation protege contre le balayage de toutes les combinaisons
  /// sur l'appareil, elle ne doit pas pouvoir etre contournee.
  Future<bool> verifierPinSecours(String pin) async {
    if (await dureeBlocageRestante() != null) return false;

    final prefs = await SharedPreferences.getInstance();

    final empreinteAttendue = prefs.getString(_cleEmpreinte) ?? '';
    if (empreinteAttendue.isEmpty) return false;

    final sel = prefs.getString(_cleSel) ?? '';
    if (_empreinte(pin, sel) != empreinteAttendue) {
      await _enregistrerEchec();
      return false;
    }

    await prefs.remove(_cleEchecs);
    await prefs.remove(_cleBloqueJusqua);
    return true;
  }

  /// Nombre d'echecs restants avant blocage.
  Future<int> tentativesRestantes() async {
    final prefs = await SharedPreferences.getInstance();
    final echecs = prefs.getInt(_cleEchecs) ?? 0;
    final restantes = tentativesMax - echecs;
    return restantes < 0 ? 0 : restantes;
  }

  /// Instant jusqu'auquel la saisie est refusee, ou null si elle est possible.
  Future<DateTime?> bloqueJusqua() async {
    final prefs = await SharedPreferences.getInstance();
    final millisecondes = prefs.getInt(_cleBloqueJusqua);
    if (millisecondes == null) return null;

    final instant = DateTime.fromMillisecondsSinceEpoch(millisecondes);
    return instant.isAfter(DateTime.now()) ? instant : null;
  }

  /// Delai restant avant de re-essayer.
  Future<Duration?> dureeBlocageRestante() async {
    final jusqua = await bloqueJusqua();
    if (jusqua == null) return null;
    return jusqua.difference(DateTime.now());
  }

  Future<void> _enregistrerEchec() async {
    final prefs = await SharedPreferences.getInstance();
    final echecs = (prefs.getInt(_cleEchecs) ?? 0) + 1;
    await prefs.setInt(_cleEchecs, echecs);

    if (echecs >= tentativesMax) {
      final instant = DateTime.now().add(dureeBlocage);
      await prefs.setInt(_cleBloqueJusqua, instant.millisecondsSinceEpoch);
      await prefs.setInt(_cleEchecs, 0);
    }
  }

  /// 128 bits de sel aleatoire, encodes en hexadecimal.
  String _genererSel() {
    final octets = List<int>.generate(16, (_) => _aleatoire.nextInt(256));
    return octets.map((o) => o.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _empreinte(String pin, String sel) {
    return sha256.convert(utf8.encode('$sel$pin')).toString();
  }
}
