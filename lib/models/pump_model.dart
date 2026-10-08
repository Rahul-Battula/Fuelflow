enum FuelType { hsd, ms }

class NozzleModel {
  final String id; // e.g. "1", "2", "3", "4"
  final String label; // e.g. "Nozzle 1"
  final FuelType fuelType;

  NozzleModel({required this.id, required this.label, required this.fuelType});

  factory NozzleModel.fromMap(Map<String, dynamic> map) {
    return NozzleModel(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      fuelType: (map['fuelType'] as String? ?? 'hsd') == 'ms' ? FuelType.ms : FuelType.hsd,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'label': label, 'fuelType': fuelType == FuelType.ms ? 'ms' : 'hsd'};
  }
}

enum PumpStatus { active, inactive }

class PumpModel {
  final String id;
  final String name;
  final List<NozzleModel> nozzles;
  final PumpStatus status;
  final DateTime createdAt;

  PumpModel({
    required this.id,
    required this.name,
    required this.nozzles,
    required this.status,
    required this.createdAt,
  });

  /// Default layout: Nozzle 1 & 2 = HSD, Nozzle 3 & 4 = MS.
  static List<NozzleModel> defaultNozzles() {
    return [
      NozzleModel(id: '1', label: 'Nozzle 1', fuelType: FuelType.hsd),
      NozzleModel(id: '2', label: 'Nozzle 2', fuelType: FuelType.hsd),
      NozzleModel(id: '3', label: 'Nozzle 3', fuelType: FuelType.ms),
      NozzleModel(id: '4', label: 'Nozzle 4', fuelType: FuelType.ms),
    ];
  }

  factory PumpModel.fromMap(String id, Map<String, dynamic> map) {
    final nozzlesRaw = map['nozzles'] as List<dynamic>? ?? [];
    return PumpModel(
      id: id,
      name: map['name'] as String? ?? '',
      nozzles: nozzlesRaw.map((n) => NozzleModel.fromMap(Map<String, dynamic>.from(n as Map))).toList(),
      status: (map['status'] as String? ?? 'active') == 'inactive' ? PumpStatus.inactive : PumpStatus.active,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nozzles': nozzles.map((n) => n.toMap()).toList(),
      'status': status == PumpStatus.active ? 'active' : 'inactive',
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
