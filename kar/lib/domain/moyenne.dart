import '../models/matiere.dart';
import '../models/note.dart';
import '../models/ue.dart';

/// Calcul des moyennes.
///
/// Fonctions pures, sans acces a la base : testables isolement.
///
/// L'annee se lit a deux niveaux, l'UE puis l'annee :
/// ```
/// moyenne matiere = (moyenne des devoirs * bareme devoirs
///                  + moyenne des examens * bareme examens)
///                  / (bareme devoirs + bareme examens)
/// ```
/// ```
/// moyenne UE = somme(moyenne matiere * coef matiere) / somme(coef matiere)
/// ```
/// puis la moyenne de l'annee pondere chaque UE par le credit qui lui est
/// propre, le credit d'une UE n'etant jamais partage entre ses matieres :
/// ```
/// moyenne annee = somme(moyenne UE * credit UE) / somme(credit UE)
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
  ///
  /// Une matiere sans devoirs ([avecDevoir] a false) a un bareme de devoirs
  /// nul : elle ne compte que sur ses examens, quelle que soit la valeur de
  /// [valDevoirs].
  static double? moyenneMatiere(
    List<Note> notes, {
    required double valDevoirs,
    required double valExam,
    bool avecDevoir = true,
  }) {
    final devoirs = notes.where((note) => note.estDevoir).toList();
    final examens = notes.where((note) => !note.estDevoir).toList();

    final baremeDevoirs = avecDevoir ? valDevoirs : 0.0;
    final baremeTotal = baremeDevoirs + valExam;
    if (baremeTotal <= 0) return null;

    final moyenneDevoirs = moyenneSimple(devoirs);
    final moyenneExamens = moyenneSimple(examens);

    if (moyenneDevoirs == null && moyenneExamens == null) return null;

    // Une absence de notes ne doit pas peser dans la moyenne : un semestre sans
    // examen ne doit pas faire chuter la matiere a zero.
    final poidsDevoirs = moyenneDevoirs == null ? 0.0 : baremeDevoirs;
    final poidsExamens = moyenneExamens == null ? 0.0 : valExam;
    final poidsTotal = poidsDevoirs + poidsExamens;

    if (poidsTotal <= 0) return null;

    final somme =
        (moyenneDevoirs ?? 0) * poidsDevoirs +
        (moyenneExamens ?? 0) * poidsExamens;

    return somme / poidsTotal;
  }

  /// Moyenne d'une UE : la moyenne de ses matieres, chacune ponderee par son
  /// coefficient.
  ///
  /// [moyennes] associe un identifiant de matiere a la moyenne calculee par
  /// [moyenneMatiere]. Seules les matieres de [ue] comptent ; celles qui n'ont
  /// aucune note sont ignorees. Renvoie null si aucune n'a de moyenne.
  ///
  /// Une UE directe ne porte qu'une matiere : sa moyenne est celle de cette
  /// matiere.
  static double? moyenneUe(
    Ue ue,
    List<Matiere> matieres,
    Map<int, double> moyennes,
  ) {
    var somme = 0.0;
    var poids = 0;

    for (final matiere in matieres) {
      if (matiere.ueId != ue.id) continue;

      final moyenne = moyennes[matiere.id];
      if (moyenne == null || matiere.id == null) continue;

      somme += moyenne * matiere.coef;
      poids += matiere.coef;
    }

    if (poids <= 0) return null;
    return somme / poids;
  }

  /// Moyenne generale de l'annee, chaque UE ponderee par son credit.
  ///
  /// [moyennes] associe un identifiant d'UE a sa moyenne. Les UE sans moyenne
  /// sont ignorees.
  static double? moyenneAnnee(Map<int, double> moyennes, List<Ue> ues) {
    var somme = 0.0;
    var poids = 0;

    for (final ue in ues) {
      final moyenne = moyennes[ue.id];
      if (moyenne == null || ue.id == null) continue;

      somme += moyenne * ue.credit;
      poids += ue.credit;
    }

    if (poids <= 0) return null;
    return somme / poids;
  }

  /// Moyenne d'un semestre, selon la meme ponderation que [moyenneAnnee] : une
  /// UE appartient a un seul semestre.
  static double? moyenneSemestre(
    Map<int, double> moyennes,
    List<Ue> ues,
    int semestre,
  ) {
    return moyenneAnnee(
      moyennes,
      ues.where((ue) => ue.semestre == semestre).toList(),
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
