import 'package:flutter_test/flutter_test.dart';
import 'package:kar/services/pin_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('aucun code defini au premier lancement', () async {
    final service = PinService();
    expect(await service.estConfigure(), isFalse);
  });

  test('definit puis verifie le code', () async {
    final service = PinService();
    await service.definirPin('1234');

    expect(await service.estConfigure(), isTrue);
    expect(await service.verifierPin('1234'), isTrue);
    expect(await service.verifierPin('4321'), isFalse);
  });

  test('ne stocke jamais le code en clair', () async {
    await PinService().definirPin('1234');

    final prefs = await SharedPreferences.getInstance();
    for (final valeur in prefs.getKeys().map((cle) => prefs.get(cle))) {
      expect('$valeur', isNot(contains('1234')));
    }
  });

  test('changer de code invalide l\'ancien', () async {
    final service = PinService();
    await service.definirPin('1234');
    await service.definirPin('5678');

    expect(await service.verifierPin('1234'), isFalse);
    expect(await service.verifierPin('5678'), isTrue);
  });

  test('bloque la saisie apres cinq echecs', () async {
    final service = PinService();
    await service.definirPin('1234');

    for (var essai = 1; essai < PinService.tentativesMax; essai++) {
      expect(await service.verifierPin('9999'), isFalse);
      expect(await service.bloqueJusqua(), isNull);
    }

    expect(await service.verifierPin('9999'), isFalse);
    expect(await service.bloqueJusqua(), isNotNull);
    expect(await service.tentativesRestantes(), PinService.tentativesMax);

    // Le code correct est refuse tant que le blocage dure.
    expect(await service.verifierPin('1234'), isFalse);
  });

  test('un succes reinitialise les tentatives', () async {
    final service = PinService();
    await service.definirPin('1234');

    await service.verifierPin('9999');
    await service.verifierPin('9999');
    expect(await service.tentativesRestantes(), 3);

    expect(await service.verifierPin('1234'), isTrue);
    expect(await service.tentativesRestantes(), PinService.tentativesMax);
  });
}