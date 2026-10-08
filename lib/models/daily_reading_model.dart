class DailyReadingModel {
  final String id;
  final String date; // yyyy-MM-dd
  final String pumpId;
  final String pumpName;
  final String nozzleId;
  final String nozzleLabel;
  final String fuelType;
  final double opening;
  final double closing;

  DailyReadingModel({
    required this.id,
    required this.date,
    required this.pumpId,
    required this.pumpName,
    required this.nozzleId,
    required this.nozzleLabel,
    required this.fuelType,
    required this.opening,
    required this.closing,
  });

  double get litres => closing - opening;

  factory DailyReadingModel.fromMap(String id, Map<String, dynamic> map) {
    return DailyReadingModel(
      id: id,
      date: map['date'] as String? ?? '',
      pumpId: map['pumpId'] as String? ?? '',
      pumpName: map['pumpName'] as String? ?? '',
      nozzleId: map['nozzleId'] as String? ?? '',
      nozzleLabel: map['nozzleLabel'] as String? ?? '',
      fuelType: map['fuelType'] as String? ?? 'hsd',
      opening: (map['opening'] as num?)?.toDouble() ?? 0,
      closing: (map['closing'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'pumpId': pumpId,
      'pumpName': pumpName,
      'nozzleId': nozzleId,
      'nozzleLabel': nozzleLabel,
      'fuelType': fuelType,
      'opening': opening,
      'closing': closing,
    };
  }
}