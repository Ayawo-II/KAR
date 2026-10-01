/// L'annee academique en cours.
///
/// `anneeDebut` et `anneeFin` sont stockees en INTEGER. Le schema v1 les
/// declarait en TEXT : SQLite applique alors son affinite de type et renvoie
/// une chaine au lieu d'un entier. [_entier] accepte les deux formes pour que
/// les bases creees avant la version 2 du schema restent lisibles.
class AnneeCourante {
  final int? id;
  final int anneeDebut;
  final int anneeFin;
  final String ecole;
  final String classe;
  final String filiere;

  /// Bareme du devoir, conserve sous forme de chaine car la saisie libre
  /// autorise « 20 » comme « 20,5 ».
  final String valDevoirs;

  /// Bareme des examens.
  final String valExam;

  final String statutAnnee;

  static const String enCours = 'en cours';
  static const String terminee = 'terminée';

  AnneeCourante({
    this.id,
    required this.anneeDebut,
    required this.anneeFin,
    required this.ecole,
    required this.classe,
    required this.filiere,
    required this.valDevoirs,
    required this.valExam,
    required this.statutAnnee,
  });

  /// Libelle affichable, par exemple « 2024 - 2025 ».
  String get libelle => '$anneeDebut - $anneeFin';

  /// Clefs d'insertion. `id` est volontairement absent : il est attribue par
  /// SQLite.
  Map<String, dynamic> toMap() {
    return {
      'anneeDebut': anneeDebut,
      'anneeFin': anneeFin,
      'ecole': ecole,
      'classe': classe,
      'filiere': filiere,
      'valDevoirs': valDevoirs,
      'valExam': valExam,
      'statutAnnee': statutAnnee,
    };
  }

  factory AnneeCourante.fromMap(Map<String, dynamic> map) {
    return AnneeCourante(
      id: map['id'] as int?,
      anneeDebut: _entier(map['anneeDebut']),
      anneeFin: _entier(map['anneeFin']),
      ecole: map['ecole'] as String,
      classe: map['classe'] as String,
      filiere: map['filiere'] as String,
      valDevoirs: map['valDevoirs'].toString(),
      valExam: map['valExam'].toString(),
      statutAnnee: map['statutAnnee'] as String? ?? enCours,
    );
  }

  /// Lit un entier stocke soit comme entier, soit comme chaine selon
  /// l'affinite de la colonne.
  static int _entier(Object? valeur) {
    if (valeur is int) return valeur;
    if (valeur is String) return int.tryParse(valeur) ?? 0;
    throw FormatException('Valeur annuelle illisible : $valeur');
  }
}