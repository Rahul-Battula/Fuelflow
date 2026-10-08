class DipEntryModel {
  final String id;
  final String fuelType; // 'hsd' or 'ms'
  final double dipCm;
  final double volumeLitres; // looked up from chart at entry time
  final DateTime recordedAt;

  DipEntryModel({
    required this.id,
    required this.fuelType,
    required this.dipCm,
    required this.volumeLitres,
    required this.recordedAt,
  });

  factory DipEntryModel.fromMap(String id, Map<String, dynamic> map) {
    return DipEntryModel(
      id: id,
      fuelType: map['fuelType'] as String? ?? 'hsd',
      dipCm: (map['dipCm'] as num?)?.toDouble() ?? 0,
      volumeLitres: (map['volumeLitres'] as num?)?.toDouble() ?? 0,
      recordedAt: map['recordedAt'] != null
          ? DateTime.tryParse(map['recordedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'fuelType': fuelType,
        'dipCm': dipCm,
        'volumeLitres': volumeLitres,
        'recordedAt': recordedAt.toIso8601String(),
      };
}