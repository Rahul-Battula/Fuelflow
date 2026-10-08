class PumpReadingModel {
  final String id;
  final String pumpId;
  final String pumpName;
  final String date; // yyyy-MM-dd
  final double openingReading;
  final double closingReading;
  final double pricePerLitre;
  final DateTime recordedAt;

  PumpReadingModel({
    required this.id,
    required this.pumpId,
    required this.pumpName,
    required this.date,
    required this.openingReading,
    required this.closingReading,
    required this.pricePerLitre,
    required this.recordedAt,
  });

  double get litresSold => closingReading - openingReading;
  double get revenue => litresSold * pricePerLitre;

  factory PumpReadingModel.fromMap(String id, Map<String, dynamic> map) {
    return PumpReadingModel(
      id: id,
      pumpId: map['pumpId'] as String? ?? '',
      pumpName: map['pumpName'] as String? ?? '',
      date: map['date'] as String? ?? '',
      openingReading: (map['openingReading'] as num?)?.toDouble() ?? 0,
      closingReading: (map['closingReading'] as num?)?.toDouble() ?? 0,
      pricePerLitre: (map['pricePerLitre'] as num?)?.toDouble() ?? 0,
      recordedAt: map['recordedAt'] != null
          ? DateTime.tryParse(map['recordedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pumpId': pumpId,
      'pumpName': pumpName,
      'date': date,
      'openingReading': openingReading,
      'closingReading': closingReading,
      'pricePerLitre': pricePerLitre,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }
}
