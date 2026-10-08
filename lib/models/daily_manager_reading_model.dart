class DailyManagerReadingModel {
  final String date; // yyyy-MM-dd, also the document id
  final Map<String, double> readings; // key: "pumpId_nozzleId", value: reading
  final DateTime recordedAt;
  final DateTime? updatedAt;

  DailyManagerReadingModel({
    required this.date,
    required this.readings,
    required this.recordedAt,
    this.updatedAt,
  });

  factory DailyManagerReadingModel.fromMap(String date, Map<String, dynamic> map) {
    final readingsRaw = map['readings'] as Map<String, dynamic>? ?? {};
    return DailyManagerReadingModel(
      date: date,
      readings: readingsRaw.map((k, v) => MapEntry(k, (v as num).toDouble())),
      recordedAt: map['recordedAt'] != null
          ? DateTime.tryParse(map['recordedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'readings': readings,
        'recordedAt': recordedAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}