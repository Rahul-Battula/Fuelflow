class CheckpointModel {
  final String id;
  final String label; // e.g. "CP1"
  final String time;
  final String actualTime; // when the reading was physically taken // e.g. "06:00", Owner-entered
  final String date; // yyyy-MM-dd
  final int order;
  final DateTime createdAt;

  CheckpointModel({
    required this.id,
    required this.label,
    required this.time,
    required this.actualTime,
    required this.date,
    required this.order,
    required this.createdAt,
  });

  factory CheckpointModel.fromMap(String id, Map<String, dynamic> map) {
    return CheckpointModel(
      id: id,
      label: map['label'] as String? ?? '',
      time: map['time'] as String? ?? '',
      actualTime: map['actualTime'] as String? ?? '',
      date: map['date'] as String? ?? '',
      order: map['order'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'time': time,
      'actualTime': actualTime,
      'date': date,
      'order': order,
      'createdAt': createdAt.toIso8601String()
    };
  }
}
