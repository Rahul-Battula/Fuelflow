enum StaffStatus { active, inactive }

class StaffModel {
  final String id;
  final String name;
  final String phone;
  final String position;
  final String shiftType; // "morning" or "night"
  final double cashGiven;
  final String? localPhotoPath;
  final StaffStatus status;
  final DateTime createdAt;

  StaffModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.position,
    required this.shiftType,
    required this.cashGiven,
    this.localPhotoPath,
    required this.status,
    required this.createdAt,
  });

  factory StaffModel.fromMap(String id, Map<String, dynamic> map) {
    return StaffModel(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      position: map['position'] as String? ?? '',
      shiftType: map['shiftType'] as String? ?? '',
      cashGiven: (map['cashGiven'] as num?)?.toDouble() ?? 0.0,
      localPhotoPath: map['localPhotoPath'] as String?,
      status: (map['status'] as String? ?? 'active') == 'inactive' ? StaffStatus.inactive : StaffStatus.active,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'position': position,
      'shiftType': shiftType,
      'cashGiven': cashGiven,
      'localPhotoPath': localPhotoPath,
      'status': status == StaffStatus.active ? 'active' : 'inactive',
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
