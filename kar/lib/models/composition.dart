/// Le type de composition, stocke tel quel dans la colonne `type`.
abstract final class TypeComposition {
  static const String devoir = 'devoir';
  static const String examen = 'examen';

  static const List<String> tous = [devoir, examen];

  /// Libelle affiche a l'utilisateur.
  static String libelle(String type) =>
      type == examen ? 'Examen' : 'Devoir';
}

class Composition {
  final int? id;
  final String type;
  final DateTime date;
  final int matiereId;

  Composition({
    this.id,
    required this.type,
    required this.date,
    required this.matiereId,
  });

  /// Clefs d'insertion. `id` est volontairement absent : il est attribue par
  /// SQLite.
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'dateCompo': date.toIso8601String(),
      'matiereId': matiereId,
    };
  }

  factory Composition.fromMap(Map<String, dynamic> map) {
    return Composition(
      id: map['id'] as int?,
      type: map['type'] as String,
      date: DateTime.parse(map['dateCompo'] as String),
      matiereId: map['matiereId'] as int,
    );
  }
}