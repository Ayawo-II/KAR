class Evenement {
  final int? id;
  final String titre;
  final String? description;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String categorie;

  Evenement({
    this.id,
    required this.titre,
    this.description,
    required this.dateDebut,
    required this.dateFin,
    this.categorie = categorieAutre,
  });

  static const String categorieVacances = 'Vacances';
  static const String categorieRentree = 'Rentrée';
  static const String categorieReunion = 'Réunion';
  static const String categorieConseil = 'Conseil';
  static const String categorieExamenBlanc = 'Examen blanc';
  static const String categorieAutre = 'Autre';

  static const List<String> categories = [
    categorieVacances,
    categorieRentree,
    categorieReunion,
    categorieConseil,
    categorieExamenBlanc,
    categorieAutre,
  ];

  bool get estPasse => dateFin.isBefore(DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'description': description,
      'dateDebut': dateDebut.toIso8601String(),
      'dateFin': dateFin.toIso8601String(),
      'categorie': categorie,
    };
  }

  factory Evenement.fromMap(Map<String, dynamic> map) {
    return Evenement(
      id: map['id'] as int?,
      titre: map['titre'] as String,
      description: map['description'] as String?,
      dateDebut: DateTime.parse(map['dateDebut'] as String),
      dateFin: DateTime.parse(map['dateFin'] as String),
      categorie: map['categorie'] as String? ?? categorieAutre,
    );
  }
}