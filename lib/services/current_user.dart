class CurrentUser {
  static String? _id;

  /// Retourne l'id de l'utilisateur courant
  /// Lance une exception si aucun utilisateur n'est défini
  static String get id {
    if (_id == null) {
      throw Exception('Current user not set');
    }
    return _id!;
  }

  /// Retourne l'id ou null (sans exception)
  static String? get idOrNull => _id;

  /// Indique si un utilisateur est défini
  static bool get isSet => _id != null;

  /// Définit l'utilisateur courant
  static void setUser(String newUserId) {
    _id = newUserId;
    print('Current user set to: $newUserId');
  }

  /// Supprime l'utilisateur courant
  static void clear() {
    _id = null;
    print('Current user cleared');
  }
}