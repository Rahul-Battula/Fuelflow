import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dip_chart_model.dart';

/// One document per fuel type, each holding the full 210-row calibration table.
class DipChartFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _docFor(String fuelType) =>
      _db.collection('dip_charts').doc(fuelType);

  Future<void> setChart(String fuelType, List<DipChartRow> rows) async {
    await _docFor(fuelType).set({'rows': rows.map((r) => r.toMap()).toList()});
  }

  Future<DipChartModel?> getChart(String fuelType) async {
    final doc = await _docFor(fuelType).get();
    if (!doc.exists) return null;
    return DipChartModel.fromMap(fuelType, doc.data()!);
  }

  Stream<DipChartModel?> watchChart(String fuelType) {
    return _docFor(fuelType).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DipChartModel.fromMap(fuelType, doc.data()!);
    });
  }
}