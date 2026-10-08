class ShiftAssignmentModel {
  final String id; // '{date}_{staffId}'
  final String date; // yyyy-MM-dd
  final String staffId;
  final String staffName;
  final String pumpId;
  final String pumpName;
  final String shiftType; // "morning" or "night"
  final DateTime assignedAt;

  ShiftAssignmentModel({
    required this.id,
    required this.date,
    required this.staffId,
    required this.staffName,
    required this.pumpId,
    required this.pumpName,
    required this.shiftType,
    required this.assignedAt,
  });

  factory ShiftAssignmentModel.fromMap(String id, Map<String, dynamic> map) {
    return ShiftAssignmentModel(
      id: id,
      date: map['date'] as String? ?? '',
      staffId: map['staffId'] as String? ?? '',
      staffName: map['staffName'] as String? ?? '',
      pumpId: map['pumpId'] as String? ?? '',
      pumpName: map['pumpName'] as String? ?? '',
      shiftType: map['shiftType'] as String? ?? '',
      assignedAt: map['assignedAt'] != null
          ? DateTime.tryParse(map['assignedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'staffId': staffId,
      'staffName': staffName,
      'pumpId': pumpId,
      'pumpName': pumpName,
      'shiftType': shiftType,
      'assignedAt': assignedAt.toIso8601String(),
    };
  }
}