class Matiere {
  final int? id;
  final String libMatiere;
  final int coef;
  final int credit;
  final int semestre;

  /// Renseignee apres insertion de l'annee. Volontairement mutable : la valeur
  /// n'est connue qu'une fois l'affectation faite par la base.
  int anneeId;

  Matiere({
    this.id,
    required this.libMatiere,
    required this.coef,
    required this.credit,
    required this.semestre,
    required this.anneeId,
  });

  /// Clefs d'insertion. `id` est volontairement absent : il est attribue par
  /// SQLite.
  Map<String, dynamic> toMap() {
    return {
      'libMatiere': libMatiere,
      'coef': coef,
      'credit': credit,
      'semestre': semestre,
      'anneeId': anneeId,
    };
  }

  factory Matiere.fromMap(Map<String, dynamic> map) {
    return Matiere(
      id: map['id'] as int?,
      libMatiere: map['libMatiere'] as String,
      coef: map['coef'] as int,
      credit: map['credit'] as int,
      semestre: map['semestre'] as int,
      anneeId: map['anneeId'] as int,
    );
  }
}