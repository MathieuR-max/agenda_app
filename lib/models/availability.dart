class Availability {
  final String id;
  final String type;
  final String title;
  final String note;
  final String visibility;
  final String day;
  final String startTime;
  final String endTime;
  final String userId;

  Availability({
    required this.id,
    required this.type,
    required this.title,
    required this.note,
    required this.visibility,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.userId,
  });

  factory Availability.fromFirestore(Map<String, dynamic> data, String id) {
    return Availability(
      id: id,
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      note: data['note'] ?? '',
      visibility: data['visibility'] ?? '',
      day: data['day'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      userId: data['userId'] ?? '',
    );
  }
}