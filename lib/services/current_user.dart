import 'package:firebase_auth/firebase_auth.dart';

class AuthUser {
  AuthUser._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// UID obligatoire (throw si non connecté)
  static String get uid {
    final uid = _auth.currentUser?.uid?.trim();

    if (uid == null || uid.isEmpty) {
      throw Exception('No authenticated Firebase user');
    }

    return uid;
  }

  /// UID optionnel
  static String? get uidOrNull {
    final uid = _auth.currentUser?.uid?.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  /// Email (optionnel)
  static String? get emailOrNull {
    final email = _auth.currentUser?.email?.trim();

    if (email == null || email.isEmpty) {
      return null;
    }

    return email;
  }

  /// Utilisateur connecté ?
  static bool get isSignedIn => uidOrNull != null;

  /// Sign out centralisé
  static Future<void> signOut() async {
    await _auth.signOut();
  }
}

/// ⚠️ À supprimer quand migration terminée
@Deprecated('Use AuthUser instead.')
class CurrentUser {
  CurrentUser._();

  @Deprecated('Use AuthUser.uid instead.')
  static String get id => AuthUser.uid;

  @Deprecated('Use AuthUser.uidOrNull instead.')
  static String? get idOrNull => AuthUser.uidOrNull;

  @Deprecated('Use AuthUser.isSignedIn instead.')
  static bool get isSet => AuthUser.isSignedIn;

  @Deprecated('Use AuthUser.signOut() instead.')
  static Future<void> clear() => AuthUser.signOut();

  @Deprecated('Deprecated - no longer used.')
  static void setUser(String newUserId) {}
}