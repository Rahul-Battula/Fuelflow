class DipChartRow {
  final int cm;
  final double volume;
  final double diffPerMm;

  DipChartRow({required this.cm, required this.volume, required this.diffPerMm});

  factory DipChartRow.fromMap(Map<String, dynamic> map) {
    return DipChartRow(
      cm: map['cm'] as int? ?? 0,
      volume: (map['volume'] as num?)?.toDouble() ?? 0,
      diffPerMm: (map['diffPerMm'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'cm': cm, 'volume': volume, 'diffPerMm': diffPerMm};
}

class DipChartModel {
  final String fuelType; // 'hsd' or 'ms'
  final List<DipChartRow> rows;

  DipChartModel({required this.fuelType, required this.rows});

  factory DipChartModel.fromMap(String fuelType, Map<String, dynamic> map) {
    final rowsRaw = map['rows'] as List<dynamic>? ?? [];
    return DipChartModel(
      fuelType: fuelType,
      rows: rowsRaw.map((r) => DipChartRow.fromMap(Map<String, dynamic>.from(r as Map))).toList(),
    );
  }

  Map<String, dynamic> toMap() => {'rows': rows.map((r) => r.toMap()).toList()};

  /// Looks up volume for a fractional cm dip using the chart + diff-per-mm interpolation.
  ///
  /// Each row's [DipChartRow.diffPerMm] is the average volume-per-mm across the
  /// interval that *ends* at that row's cm mark (i.e. between `cm - 1` and `cm`).
  /// So to interpolate above a whole-cm mark we must use the *next* row's
  /// diffPerMm, which describes the interval we're actually moving into.
  double? volumeForDip(double dipCm) {
    if (rows.isEmpty) return null;
    final whole = dipCm.floor();
    final fractionMm = (dipCm - whole) * 10;

    final baseRow = rows.where((r) => r.cm == whole).cast<DipChartRow?>().firstOrNull;
    if (baseRow == null) return null;
    if (fractionMm <= 0) return baseRow.volume;

    final nextRow = rows.where((r) => r.cm == whole + 1).cast<DipChartRow?>().firstOrNull;
    final slopePerMm = nextRow?.diffPerMm ?? baseRow.diffPerMm;

    return baseRow.volume + (fractionMm * slopePerMm);
  }
}