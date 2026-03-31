class UserModel {
  final String id;
  final String prenom;
  final String nom;
  final String pseudo;
  final String? genre;
  final String? lieu;
  final String? dateNaissance;
  final List<String> centresInteret;
  final List<String> favoriteCategories;

  UserModel({
    required this.id,
    required this.prenom,
    required this.nom,
    required this.pseudo,
    this.genre,
    this.lieu,
    this.dateNaissance,
    this.centresInteret = const [],
    this.favoriteCategories = const [],
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      prenom: map['prenom'] ?? '',
      nom: map['nom'] ?? '',
      pseudo: map['pseudo'] ?? '',
      genre: map['genre'],
      lieu: map['lieu'],
      dateNaissance: map['dateNaissance'],
      centresInteret: List<String>.from(map['centresInteret'] ?? []),
      favoriteCategories: List<String>.from(map['favoriteCategories'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prenom': prenom,
      'nom': nom,
      'pseudo': pseudo,
      'genre': genre,
      'lieu': lieu,
      'dateNaissance': dateNaissance,
      'centresInteret': centresInteret,
      'favoriteCategories': favoriteCategories,
    };
  }

  UserModel copyWith({
    String? id,
    String? prenom,
    String? nom,
    String? pseudo,
    String? genre,
    String? lieu,
    String? dateNaissance,
    List<String>? centresInteret,
    List<String>? favoriteCategories,
  }) {
    return UserModel(
      id: id ?? this.id,
      prenom: prenom ?? this.prenom,
      nom: nom ?? this.nom,
      pseudo: pseudo ?? this.pseudo,
      genre: genre ?? this.genre,
      lieu: lieu ?? this.lieu,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      centresInteret: centresInteret ?? this.centresInteret,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
    );
  }
}