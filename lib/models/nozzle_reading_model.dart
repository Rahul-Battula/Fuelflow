class NozzleReadingModel {
  final String id;
  final String checkpointId;
  final String pumpId;
  final String pumpName;
  final String nozzleId;
  final String nozzleLabel;
  final String fuelType; // "hsd" or "ms"
  final double reading;
  final DateTime recordedAt;

  NozzleReadingModel({
    required this.id,
    required this.checkpointId,
    required this.pumpId,
    required this.pumpName,
    required this.nozzleId,
    required this.nozzleLabel,
    required this.fuelType,
    required this.reading,
    required this.recordedAt,
  });

  factory NozzleReadingModel.fromMap(String id, Map<String, dynamic> map) {
    return NozzleReadingModel(
      id: id,
      checkpointId: map['checkpointId'] as String? ?? '',
      pumpId: map['pumpId'] as String? ?? '',
      pumpName: map['pumpName'] as String? ?? '',
      nozzleId: map['nozzleId'] as String? ?? '',
      nozzleLabel: map['nozzleLabel'] as String? ?? '',
      fuelType: map['fuelType'] as String? ?? 'hsd',
      reading: (map['reading'] as num?)?.toDouble() ?? 0,
      recordedAt: map['recordedAt'] != null
          ? DateTime.tryParse(map['recordedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkpointId': checkpointId,
      'pumpId': pumpId,
      'pumpName': pumpName,
      'nozzleId': nozzleId,
      'nozzleLabel': nozzleLabel,
      'fuelType': fuelType,
      'reading': reading,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }
}
