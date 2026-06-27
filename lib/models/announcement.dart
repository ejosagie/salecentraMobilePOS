class Announcement {
  final int id;
  final String title;
  final String message;
  final String priority;
  final String startDate;
  final String endDate;
  final String? createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.priority = 'info',
    required this.startDate,
    required this.endDate,
    this.createdAt,
  });

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'] as int,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      priority: map['priority'] as String? ?? 'info',
      startDate: map['start_date'] as String? ?? '',
      endDate: map['end_date'] as String? ?? '',
      createdAt: map['created_at'] as String?,
    );
  }
}
