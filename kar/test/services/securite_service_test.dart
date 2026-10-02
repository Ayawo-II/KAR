import 'package:flutter_test/flutter_test.dart';
import 'package:kar/services/securite_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('aucun verrouillage au premier lancement', () async {
    final service = SecuriteService();

    expect(await service.estActif(), isFalse);
    expect(await service.pinSecoursDefini(), isFalse);
  });

  test('active puis desactive le verrouillage', () async {
    final service = SecuriteService();

    await service.activer();
    expect(await service.estActif(), isTrue);

    await service.desactiver();
    expect(await service.estActif(), isFalse);
  });

  test('le verrouillage ne depend pas de l\'existence d\'un code', () async {
    final service = SecuriteService();

    // L'appareil sait s'authentifier : aucun code n'est necessaire.
    await service.definirPinSecours('1234');
    await service.activer();
    expect(await service.estActif(), isTrue);

    // Desactiver ne doit pas pouvoir laisser un verrouillage actif.
    await service.desactiver();
    expect(await service.estActif(), isFalse);
    expect(await service.pinSecoursDefini(), isTrue);
  });

  test('definit puis verifie le code de secours', () async {
    final service = SecuriteService();
    await service.definirPinSecours('1234');

    expect(await service.pinSecoursDefini(), isTrue);
    expect(await service.verifierPinSecours('1234'), isTrue);
    expect(await service.verifierPinSecours('4321'), isFalse);
  });

  test('ne stocke jamais le code en clair', () async {
    await SecuriteService().definirPinSecours('1234');

    final prefs = await SharedPreferences.getInstance();
    for (final valeur in prefs.getKeys().map((cle) => prefs.get(cle))) {
      expect('$valeur', isNot(contains('1234')));
    }
  });

  test('changer de code invalide l\'ancien', () async {
    final service = SecuriteService();
    await service.definirPinSecours('1234');
    await service.definirPinSecours('5678');

    expect(await service.verifierPinSecours('1234'), isFalse);
    expect(await service.verifierPinSecours('5678'), isTrue);
  });

  test('supprimer le code de secours le rend inutilisable', () async {
    final service = SecuriteService();
    await service.definirPinSecours('1234');
    await service.supprimerPinSecours();

    expect(await service.pinSecoursDefini(), isFalse);
    expect(await service.verifierPinSecours('1234'), isFalse);
  });

  test('bloque la saisie apres cinq echecs', () async {
    final service = SecuriteService();
    await service.definirPinSecours('1234');

    for (var essai = 1; essai < SecuriteService.tentativesMax; essai++) {
      expect(await service.verifierPinSecours('9999'), isFalse);
      expect(await service.bloqueJusqua(), isNull);
    }

    expect(await service.verifierPinSecours('9999'), isFalse);
    expect(await service.bloqueJusqua(), isNotNull);
    expect(await service.tentativesRestantes(), SecuriteService.tentativesMax);

    // Le code correct est refuse tant que le blocage dure.
    expect(await service.verifierPinSecours('1234'), isFalse);
  });

  test('un succes reinitialise les tentatives', () async {
    final service = SecuriteService();
    await service.definirPinSecours('1234');

    await service.verifierPinSecours('9999');
    await service.verifierPinSecours('9999');
    expect(await service.tentativesRestantes(), 3);

    expect(await service.verifierPinSecours('1234'), isTrue);
    expect(await service.tentativesRestantes(), SecuriteService.tentativesMax);
  });

  test('sans securite d\'appareil, l\'authentification echoue', () async {
    // Aucun plugin enregistre dans un test : l'appel doit echouer proprement,
    // pas lever une exception.
    final service = SecuriteService();

    expect(await service.appareilSecurise(), isFalse);
    expect(await service.authentifier(raison: 'Déverrouiller KAR'), isFalse);
  });
}
