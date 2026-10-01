/// Statut d'une journee de revision, stocke tel quel dans `programme.statut`.
abstract final class StatutProgramme {
  static const String respecte = 'respecté';
  static const String nonRespecte = 'non respecté';

  /// Statut d'une matiere au sein d'une journee de revision, stocke dans
  /// `matiere_programme.statut`. Distinct des precedents : la contrainte CHECK
  /// de cette table n'accepte que ces deux valeurs.
  static const String valide = 'validé';
  static const String nonValide = 'non validé';
}

class Programme {
  final int? id;

  /// Journee de revision planifiee.
  final DateTime jour;

  final String statut;

  /// Matieres revisees ce jour-la, vide tant que le programme est sauvegarde.
  final List<int> matiereIds;

  Programme({
    this.id,
    required this.jour,
    required this.statut,
    this.matiereIds = const [],
  });

  /// Clefs d'insertion. `id` est volontairement absent : il est attribue par
  /// SQLite.
  Map<String, dynamic> toMap() {
    return {
      'jour': jour.toIso8601String(),
      'statut': statut,
    };
  }

  factory Programme.fromMap(Map<String, dynamic> map) {
    return Programme(
      id: map['id'] as int?,
      jour: DateTime.parse(map['jour'] as String),
      statut: map['statut'] as String? ?? StatutProgramme.nonRespecte,
    );
  }
}