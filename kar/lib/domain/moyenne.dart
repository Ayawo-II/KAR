import '../models/matiere.dart';
import '../models/note.dart';

/// Calcul des moyennes.
///
/// Fonctions pures, sans acces a la base : testables isolement.
///
/// Bareme d'une matiere, dans le systeme de notation de l'annee :
/// ```
/// moyenne matiere = (moyenne des devoirs * bareme devoirs
///                  + moyenne des examens * bareme examens)
///                  / (bareme devoirs + bareme examens)
/// ```
/// puis la moyenne de l'annee pondere chaque matiere par son coefficient :
/// ```
/// moyenne annee = somme(moyenne matiere * coef) / somme(coef)
/// ```
abstract final class Moyenne {
  /// Moyenne arithmetique des [notes]. Vaut null si la liste est vide.
  static double? moyenneSimple(List<Note> notes) {
    if (notes.isEmpty) return null;

    var total = 0.0;
    for (final note in notes) {
      total += note.valeur;
    }
    return total / notes.length;
  }

  /// Moyenne d'une matiere, en tenant compte du bareme de l'annee.
  ///
  /// [valDevoirs] et [valExam] sont les ponderations en pourcentage. Renvoie
  /// null si aucune note, ou si les deux baremes sont nuls.
  static double? moyenneMatiere(
    List<Note> notes, {
    required double valDevoirs,
    required double valExam,
  }) {
    final devoirs = notes.where((note) => note.estDevoir).toList();
    final examens = notes.where((note) => !note.estDevoir).toList();

    final baremeTotal = valDevoirs + valExam;
    if (baremeTotal <= 0) return null;

    final moyenneDevoirs = moyenneSimple(devoirs);
    final moyenneExamens = moyenneSimple(examens);

    if (moyenneDevoirs == null && moyenneExamens == null) return null;

    // Une absence de notes ne doit pas peser dans la moyenne : un semestre sans
    // examen ne doit pas faire chuter la matiere a zero.
    final poidsDevoirs = moyenneDevoirs == null ? 0.0 : valDevoirs;
    final poidsExamens = moyenneExamens == null ? 0.0 : valExam;
    final poidsTotal = poidsDevoirs + poidsExamens;

    if (poidsTotal <= 0) return null;

    final somme = (moyenneDevoirs ?? 0) * poidsDevoirs +
        (moyenneExamens ?? 0) * poidsExamens;

    return somme / poidsTotal;
  }

  /// Moyenne generale de l'annee, chaque matiere ponderee par son coefficient.
  ///
  /// [moyennes] associe un identifiant de matiere a sa moyenne. Les matieres de
  /// [matieres] sans note sont ignorees.
  static double? moyenneAnnee(
    Map<int, double> moyennes,
    List<Matiere> matieres,
  ) {
    var somme = 0.0;
    var poids = 0;

    for (final matiere in matieres) {
      final moyenne = moyennes[matiere.id];
      if (moyenne == null || matiere.id == null) continue;

      somme += moyenne * matiere.coef;
      poids += matiere.coef;
    }

    if (poids <= 0) return null;
    return somme / poids;
  }

  /// Moyenne d'un semestre, selon la meme ponderation que [moyenneAnnee].
  static double? moyenneSemestre(
    Map<int, double> moyennes,
    List<Matiere> matieres,
    int semestre,
  ) {
    return moyenneAnnee(
      moyennes,
      matieres.where((matiere) => matiere.semestre == semestre).toList(),
    );
  }

  /// Formate une moyenne pour l'affichage : « 12,5/20 ».
  static String formater(double? moyenne) {
    if (moyenne == null) return '—';

    final arrondi = (moyenne * 10).round() / 10;
    final texte = arrondi.toStringAsFixed(1).replaceAll('.', ',');
    return '$texte/20';
  }
}