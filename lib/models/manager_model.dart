class ManagerModel {
  final String id;
  final String name;
  final String phone;
  final DateTime updatedAt;

  ManagerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.updatedAt,
  });

  factory ManagerModel.fromMap(String id, Map<String, dynamic> map) {
    return ManagerModel(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'updatedAt': updatedAt.toIso8601String(),
      };
}