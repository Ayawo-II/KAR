/// Une matiere.
///
/// Le credit n'appartient pas a la matiere mais a l'**UE** qui la porte : une
/// UE composite a un seul credit, partage par plusieurs matieres. Le champ
/// [credit] n'est donc qu'une recopie de celui de l'UE, ecrite a l'insertion
/// et jamais demandee a la saisie.
class Matiere {
  final int? id;
  final String libMatiere;
  final int coef;

  /// Credit de l'UE porteuse, recopie pour l'affichage.
  final int credit;

  final int semestre;

  /// La matiere comporte-t-elle des devoirs ?
  ///
  /// Une matiere sans devoirs (memoire, projet, stage, UE entierement notee
  /// en examen) ne pese que sur les examens : son bareme de devoirs vaut
  /// [Moyenne.moyenneMatiere] 0, d'ou le choix au moment de la saisir.
  final bool avecDevoir;

  /// Renseignees apres insertion de l'annee et de son UE. Volontairement
  /// mutables : ces valeurs ne sont connues qu'une fois les affectations faites
  /// par la base.
  int anneeId;
  int? ueId;

  Matiere({
    this.id,
    required this.libMatiere,
    required this.coef,
    this.credit = 0,
    required this.semestre,
    required this.anneeId,
    this.avecDevoir = true,
    this.ueId,
  });

  /// Clefs d'insertion. `id` est volontairement absent : il est attribue par
  /// SQLite, comme [ueId] que la base renseigne apres avoir insere l'UE.
  Map<String, dynamic> toMap() {
    return {
      'libMatiere': libMatiere,
      'coef': coef,
      'credit': credit,
      'semestre': semestre,
      'anneeId': anneeId,
      'avecDevoir': avecDevoir ? 1 : 0,
      'ueId': ueId,
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
      // SQLite ne renvoie pas de booléen : la colonne est un entier.
      avecDevoir: (map['avecDevoir'] as int? ?? 1) != 0,
      ueId: map['ueId'] as int?,
    );
  }
}
