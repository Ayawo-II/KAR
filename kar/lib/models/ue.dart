import 'matiere.dart';

/// Une unite d'enseignement : l'unite reelle de credit.
///
/// Deux formes coexistent dans une meme annee :
/// - l'**UE directe**, notee d'un seul tenant, qui porte elle-meme son
///   coefficient et ses credits. Elle se confond avec sa matiere, et c'est la
///   matiere qui recoit les notes ;
/// - l'**UE composite**, qui regroupe plusieurs matieres. Chacune a son
///   coefficient, et le credit reste celui de l'UE : il n'est jamais partage
///   entre les matieres.
class Ue {
  final int? id;
  final String libelle;

  /// Credit de l'UE. Il ne se divise pas entre les matieres d'une UE composite.
  final int credit;

  /// L'UE appartient a un seul des deux semestres de l'annee.
  final int semestre;

  /// Renseignee apres insertion de l'annee, comme pour [Matiere.anneeId].
  int anneeId;

  Ue({
    this.id,
    required this.libelle,
    required this.credit,
    required this.semestre,
    required this.anneeId,
  });

  /// Libelle affichable, par exemple « UE4 — Analyse numérique (4 crédits) ».
  String get libelleComplet =>
      'UE — $libelle ($credit crédit'
      '${credit > 1 ? 's' : ''})';

  /// Clefs d'insertion. `id` est volontairement absent : il est attribue par
  /// SQLite.
  Map<String, dynamic> toMap() {
    return {
      'libelle': libelle,
      'credit': credit,
      'semestre': semestre,
      'anneeId': anneeId,
    };
  }

  factory Ue.fromMap(Map<String, dynamic> map) {
    return Ue(
      id: map['id'] as int?,
      libelle: map['libelle'] as String? ?? '',
      credit: map['credit'] as int,
      semestre: map['semestre'] as int,
      anneeId: map['anneeId'] as int,
    );
  }
}

/// Une UE et les matieres qu'elle porte.
///
/// C'est la forme complete d'une UE, a la saisie comme a la lecture : le
/// credit se lit au niveau de l'UE, les coefficients au niveau des matieres.
class UeAvecMatieres {
  final Ue ue;
  final List<Matiere> matieres;

  const UeAvecMatieres({required this.ue, required this.matieres});

  /// L'UE est directe : elle ne porte qu'une matiere, la UE elle-meme. Sa
  /// moyenne est donc celle de cette matiere.
  bool get directe => matieres.length <= 1;
}
