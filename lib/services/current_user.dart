import 'package:firebase_auth/firebase_auth.dart';

class CurrentUser {
  CurrentUser._();

  /// Retourne l'UID Firebase de l'utilisateur courant.
  /// Lance une exception si aucun utilisateur n'est connecté.
  static String get id {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.trim().isEmpty) {
      throw Exception('No authenticated Firebase user');
    }

    return uid;
  }

  /// Retourne l'UID Firebase courant ou null.
  static String? get idOrNull {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.trim().isEmpty) {
      return null;
    }

    return uid;
  }

  /// Indique si un utilisateur Firebase est connecté.
  static bool get isSet => idOrNull != null;

  /// Conservé temporairement pour compatibilité.
  /// Ne fait plus rien volontairement.
  @Deprecated('Do not use setUser. FirebaseAuth is now the source of truth.')
  static void setUser(String newUserId) {}

  /// Conservé temporairement pour compatibilité.
  /// La déconnexion doit passer par FirebaseAuth.signOut().
  @Deprecated('Do not use clear. FirebaseAuth is now the source of truth.')
  static void clear() {}
}