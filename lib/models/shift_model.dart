class ShiftModel {
  final String id;
  final String date; // yyyy-MM-dd
  final String label; // e.g. "Morning"
  final String startTime;
  final String endTime;
  final List<String> staffIds;
  final List<String> staffNames;
  final double changeAmount;
  final DateTime createdAt;

  ShiftModel({
    required this.id,
    required this.date,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.staffIds,
    required this.staffNames,
    required this.changeAmount,
    required this.createdAt,
  });

  factory ShiftModel.fromMap(String id, Map<String, dynamic> map) {
    return ShiftModel(
      id: id,
      date: map['date'] as String? ?? '',
      label: map['label'] as String? ?? '',
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
      staffIds: List<String>.from(map['staffIds'] as List? ?? []),
      staffNames: List<String>.from(map['staffNames'] as List? ?? []),
      changeAmount: (map['changeAmount'] as num?)?.toDouble() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'label': label,
      'startTime': startTime,
      'endTime': endTime,
      'staffIds': staffIds,
      'staffNames': staffNames,
      'changeAmount': changeAmount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
