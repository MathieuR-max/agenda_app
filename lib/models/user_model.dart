class UserModel {
  final String id;
  final String prenom;
  final String nom;
  final String pseudo;
  final String? genre;
  final String? lieu;
  final String? dateNaissance;
  final String? bio;
  final String? photoUrl;
  final List<String> centresInteret;
  final List<String> favoriteCategories;
  final Map<String, dynamic>? explorerFilters;

  UserModel({
    required this.id,
    required this.prenom,
    required this.nom,
    required this.pseudo,
    this.genre,
    this.lieu,
    this.dateNaissance,
    this.bio,
    this.photoUrl,
    this.centresInteret = const [],
    this.favoriteCategories = const [],
    this.explorerFilters,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      prenom: (map['prenom'] ?? '').toString(),
      nom: (map['nom'] ?? '').toString(),
      pseudo: (map['pseudo'] ?? '').toString(),
      genre: map['genre'] is String ? map['genre'] as String : null,
      lieu: map['lieu'] is String ? map['lieu'] as String : null,
      // dateNaissance may be stored as a String "dd/MM/yyyy" — guard against
      // legacy Timestamp values that slipped in before this field was typed.
      dateNaissance: map['dateNaissance'] is String
          ? map['dateNaissance'] as String
          : null,
      bio: map['bio'] is String ? map['bio'] as String : null,
      photoUrl: map['photoUrl'] is String ? map['photoUrl'] as String : null,
      centresInteret: List<String>.from(map['centresInteret'] ?? []),
      favoriteCategories: List<String>.from(map['favoriteCategories'] ?? []),
      explorerFilters: map['explorerFilters'] is Map
          ? Map<String, dynamic>.from(map['explorerFilters'] as Map)
          : null,
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
      'bio': bio,
      'photoUrl': photoUrl,
      'centresInteret': centresInteret,
      'favoriteCategories': favoriteCategories,
      'explorerFilters': explorerFilters,
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
    String? bio,
    String? photoUrl,
    List<String>? centresInteret,
    List<String>? favoriteCategories,
    Map<String, dynamic>? explorerFilters,
  }) {
    return UserModel(
      id: id ?? this.id,
      prenom: prenom ?? this.prenom,
      nom: nom ?? this.nom,
      pseudo: pseudo ?? this.pseudo,
      genre: genre ?? this.genre,
      lieu: lieu ?? this.lieu,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      centresInteret: centresInteret ?? this.centresInteret,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
      explorerFilters: explorerFilters ?? this.explorerFilters,
    );
  }
}
