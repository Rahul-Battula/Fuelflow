class TankModel {
  final String id;
  final String name;
  final String fuelType; // "hsd" or "ms"
  final DateTime createdAt;

  TankModel({
    required this.id,
    required this.name,
    required this.fuelType,
    required this.createdAt,
  });

  factory TankModel.fromMap(String id, Map<String, dynamic> map) {
    return TankModel(
      id: id,
      name: map['name'] as String? ?? '',
      fuelType: map['fuelType'] as String? ?? 'hsd',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'fuelType': fuelType,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}