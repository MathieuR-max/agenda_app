class AvailabilityTypes {
  static const available = 'available';
  static const unavailable = 'unavailable';
  static const personal = 'personal';
  static const maybe = 'maybe';

  static const all = [
    available,
    unavailable,
    personal,
    maybe,
  ];

  static String label(String value) {
    switch (value) {
      case available:
        return 'Disponible';
      case unavailable:
        return 'Indisponible';
      case personal:
        return 'Activité personnelle';
      case maybe:
        return 'Peut-être disponible';
      default:
        return 'Autre';
    }
  }
}