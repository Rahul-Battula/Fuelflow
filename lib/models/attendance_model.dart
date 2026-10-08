class AttendanceModel {
  final String id;
  final String staffId;
  final String staffName;
  final String date; // yyyy-MM-dd
  final bool present;
  final DateTime markedAt;

  AttendanceModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.date,
    required this.present,
    required this.markedAt,
  });

  factory AttendanceModel.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceModel(
      id: id,
      staffId: map['staffId'] as String? ?? '',
      staffName: map['staffName'] as String? ?? '',
      date: map['date'] as String? ?? '',
      present: map['present'] as bool? ?? false,
      markedAt: map['markedAt'] != null
          ? DateTime.tryParse(map['markedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'date': date,
      'present': present,
      'markedAt': markedAt.toIso8601String(),
    };
  }
}
