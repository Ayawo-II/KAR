import 'composition.dart';

class Note {
  final int? id;
  final String libelle;
  final DateTime date;
  final double valeur;

  /// [TypeComposition.devoir] ou [TypeComposition.examen].
  final String type;

  final int matiereId;

  Note({
    this.id,
    required this.libelle,
    required this.date,
    required this.valeur,
    required this.type,
    required this.matiereId,
  });

  bool get estDevoir => type == TypeComposition.devoir;

  Map<String, dynamic> toMap() {
    return {
      'libelle': libelle,
      'dateNote': date.toIso8601String(),
      'valeur': valeur,
      'type': type,
      'matiereId': matiereId,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      libelle: map['libelle'] as String,
      date: DateTime.parse(map['dateNote'] as String),
      valeur: (map['valeur'] as num).toDouble(),
      type: map['type'] as String,
      matiereId: map['matiereId'] as int,
    );
  }
}

/// Une note avec le nom de sa matiere, pour l'affichage.
class NoteAvecMatiere {
  final Note note;
  final String libMatiere;
  final int coef;

  const NoteAvecMatiere({
    required this.note,
    required this.libMatiere,
    required this.coef,
  });
}