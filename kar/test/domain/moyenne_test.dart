import 'package:flutter_test/flutter_test.dart';
import 'package:kar/domain/moyenne.dart';
import 'package:kar/models/composition.dart';
import 'package:kar/models/matiere.dart';
import 'package:kar/models/note.dart';
import 'package:kar/models/ue.dart';

void main() {
  Note note(double valeur, String type) => Note(
    libelle: 'note',
    date: DateTime(2025, 1, 1),
    valeur: valeur,
    type: type,
    matiereId: 1,
  );

  Ue ue(int id, int credit, {int semestre = 1}) => Ue(
    id: id,
    libelle: 'UE$id',
    credit: credit,
    semestre: semestre,
    anneeId: 1,
  );

  Matiere matiere(int id, int coef, int ueId, {int semestre = 1}) => Matiere(
    id: id,
    libMatiere: 'M$id',
    coef: coef,
    credit: 1,
    semestre: semestre,
    anneeId: 1,
    ueId: ueId,
  );

  group('moyenneSimple', () {
    test('vaut null sans note', () {
      expect(Moyenne.moyenneSimple([]), isNull);
    });

    test('calcule la moyenne arithmetique', () {
      expect(
        Moyenne.moyenneSimple([note(10, 'devoir'), note(14, 'devoir')]),
        12,
      );
    });
  });

  group('moyenneMatiere', () {
    test('vaut null sans note', () {
      expect(Moyenne.moyenneMatiere([], valDevoirs: 50, valExam: 50), isNull);
    });

    test('pondere devoirs et examens', () {
      final resultat = Moyenne.moyenneMatiere(
        [note(10, 'devoir'), note(20, 'examen')],
        valDevoirs: 50,
        valExam: 50,
      );
      expect(resultat, 15);
    });

    test('honore un bareme desequilibre', () {
      final resultat = Moyenne.moyenneMatiere(
        [note(10, 'devoir'), note(20, 'examen')],
        valDevoirs: 25,
        valExam: 75,
      );
      expect(resultat, closeTo(17.5, 1e-9));
    });

    test('ignore un type de note absent au lieu de le compter zero', () {
      final resultat = Moyenne.moyenneMatiere(
        [note(16, 'examen')],
        valDevoirs: 50,
        valExam: 50,
      );
      expect(resultat, 16);
    });

    test('vaut null si le bareme total est nul', () {
      expect(
        Moyenne.moyenneMatiere([note(10, 'devoir')], valDevoirs: 0, valExam: 0),
        isNull,
      );
    });

    test('une matiere sans devoirs ne compte que les examens', () {
      final resultat = Moyenne.moyenneMatiere(
        [note(10, 'devoir'), note(20, 'examen')],
        valDevoirs: 50,
        valExam: 50,
        avecDevoir: false,
      );
      expect(resultat, 20);
    });

    test('une matiere sans devoirs et sans examen vaut null', () {
      final resultat = Moyenne.moyenneMatiere(
        [note(10, 'devoir')],
        valDevoirs: 50,
        valExam: 50,
        avecDevoir: false,
      );
      expect(resultat, isNull);
    });
  });

  group('moyenneUe', () {
    test('pondere les matieres par leur coefficient', () {
      final matieres = [matiere(1, 2, 7), matiere(2, 1, 7)];
      final resultat = Moyenne.moyenneUe(ue(7, 6), matieres, {1: 10, 2: 16});
      expect(resultat, closeTo(12, 1e-9));
    });

    test('ne retient que les matieres de son UE', () {
      final matieres = [matiere(1, 1, 7), matiere(2, 1, 8)];
      final resultat = Moyenne.moyenneUe(ue(7, 6), matieres, {1: 8, 2: 18});
      expect(resultat, 8);
    });

    test('ignore les matieres sans moyenne', () {
      final matieres = [matiere(1, 3, 7), matiere(2, 1, 7)];
      final resultat = Moyenne.moyenneUe(ue(7, 6), matieres, {2: 16});
      expect(resultat, 16);
    });

    test('vaut null sans aucune moyenne', () {
      expect(Moyenne.moyenneUe(ue(7, 6), [matiere(1, 1, 7)], {}), isNull);
    });

    test('le credit ne pese pas dans la moyenne de l UE', () {
      // Le credit porte sur l'annee, pas a l'interieur de l'UE : une UE a
      // 30 credits se moyenne exactement comme une UE a 3.
      final matieres = [matiere(1, 1, 7)];
      expect(Moyenne.moyenneUe(ue(7, 3), matieres, {1: 11}), 11);
      expect(Moyenne.moyenneUe(ue(7, 30), matieres, {1: 11}), 11);
    });
  });

  group('moyenneAnnee', () {
    test('pondere les UE par leur credit', () {
      final ues = [ue(1, 2), ue(2, 1)];
      final resultat = Moyenne.moyenneAnnee({1: 10, 2: 16}, ues);
      expect(resultat, closeTo(12, 1e-9));
    });

    test('ignore les UE sans moyenne', () {
      final ues = [ue(1, 3), ue(2, 1)];
      final resultat = Moyenne.moyenneAnnee({1: 9}, ues);
      expect(resultat, 9);
    });

    test('vaut null sans aucune moyenne', () {
      expect(Moyenne.moyenneAnnee({}, [ue(1, 1)]), isNull);
    });
  });

  group('moyenneSemestre', () {
    test('ne retient que les UE du semestre', () {
      final ues = [ue(1, 1, semestre: 1), ue(2, 1, semestre: 2)];
      final resultat = Moyenne.moyenneSemestre({1: 8, 2: 18}, ues, 2);
      expect(resultat, 18);
    });
  });

  test('formater affiche une virgule et le bareme', () {
    expect(Moyenne.formater(null), '—');
    expect(Moyenne.formater(12.46), '12,5/20');
  });

  test('TypeComposition.libelle traduit les deux types', () {
    expect(TypeComposition.libelle(TypeComposition.devoir), 'Devoir');
    expect(TypeComposition.libelle(TypeComposition.examen), 'Examen');
  });
}
