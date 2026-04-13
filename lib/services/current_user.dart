class CurrentUser {
  static String? _id;

  /// Retourne l'id de l'utilisateur courant.
  /// Lance une exception si aucun utilisateur valide n'est défini.
  static String get id {
    final value = _normalizedId(_id);

    if (value == null) {
      throw Exception('Current user not set');
    }

    return value;
  }

  /// Retourne l'id courant normalisé ou null.
  static String? get idOrNull => _normalizedId(_id);

  /// Indique si un utilisateur valide est défini.
  static bool get isSet => idOrNull != null;

  /// Définit l'utilisateur courant.
  static void setUser(String newUserId) {
    final normalized = _normalizedId(newUserId);

    if (normalized == null) {
      throw Exception('Invalid current user id');
    }

    _id = normalized;
  }

  /// Supprime l'utilisateur courant.
  static void clear() {
    _id = null;
  }

  static String? _normalizedId(String? value) {
    if (value == null) return null;

    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    return trimmed;
  }
}