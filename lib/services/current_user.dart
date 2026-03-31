class CurrentUser {
  static String? _id;

  static String get id {
    if (_id == null || _id!.isEmpty) {
      throw Exception('Current user not set');
    }
    return _id!;
  }

  static void setUser(String newUserId) {
    _id = newUserId;
  }

  static void clear() {
    _id = null;
  }
}