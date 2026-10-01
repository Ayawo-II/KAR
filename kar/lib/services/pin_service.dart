import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verrouillage de l'application par code PIN.
///
/// L'application est mono-utilisateur : il n'y a pas de compte a creer ni de
/// mot de passe a retenir. Un code PIN protege l'acces a l'appareil.
///
/// Le code n'est jamais stocke en clair. Les preferences contiennent :
/// - `pin_sel` : un sel aleatoire de 128 bits, genere a la configuration ;
/// - `pin_empreinte` : SHA-256(sel + code).
///
/// Ce stockage est adapte a un verrou local, pas a un mot de passe de compte en
/// ligne : il resiste a la lecture directe du stockage mais pas a une
/// retro-ingenierie materielle sur l'appareil.
class PinService {
  static const String _cleSel = 'pin_sel';
  static const String _cleEmpreinte = 'pin_empreinte';

  /// Nombre d'echecs de saisie consecutifs.
  static const String _cleEchecs = 'pin_echecs';

  /// Delai avant re-essai apres [tentativesMax] echecs.
  static const String _cleBloqueJusqua = 'pin_bloque_jusqua';

  static const int tentativesMax = 5;
  static const Duration dureeBlocage = Duration(minutes: 5);

  /// Nombre de chiffres du code.
  static const int longueurPin = 4;

  /// Code refuse a la configuration : trivial a deviner.
  static const String codeInterdit = '0000';

  final Random _aleatoire = Random.secure();

  /// Vrai si un code PIN a deja ete defini, donc si l'ecran de configuration
  /// doit etre affiche.
  Future<bool> estConfigure() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_cleEmpreinte) ?? '').isNotEmpty;
  }

  /// Definit le code PIN. Remplace tout code existant.
  Future<void> definirPin(String pin) async {
    final sel = _genererSel();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_cleSel, sel);
    await prefs.setString(_cleEmpreinte, _empreinte(pin, sel));
    await prefs.remove(_cleEchecs);
    await prefs.remove(_cleBloqueJusqua);
  }

  /// Verifie le code saisi.
  ///
  /// Renvoie toujours false tant qu'un blocage est en cours, meme avec le bon
  /// code : la temporisation protege contre le balayage de toutes les combinaisons
  /// sur l'appareil, elle ne doit pas pouvoir etre contournee.
  Future<bool> verifierPin(String pin) async {
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
      await prefs.setInt(
        _cleBloqueJusqua,
        instant.millisecondsSinceEpoch,
      );
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