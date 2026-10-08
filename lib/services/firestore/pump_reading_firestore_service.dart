import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pump_reading_model.dart';

/// Handles all reads/writes to the `pump_readings` Firestore collection.
class PumpReadingFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _readingsRef => _db.collection('pump_readings');

  String _docId(String pumpId, String date) => '${pumpId}_$date';

  /// Fetches the most recent reading for a pump before/on a given date,
  /// used to auto-fill "opening reading" from the last closing reading.
  Future<PumpReadingModel?> getLatestReadingBefore({required String pumpId, required String beforeDate}) async {
    final snapshot = await _readingsRef
        .where('pumpId', isEqualTo: pumpId)
        .where('date', isLessThan: beforeDate)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return PumpReadingModel.fromMap(doc.id, doc.data());
  }

  Future<void> saveReading({
    required String pumpId,
    required String pumpName,
    required String date,
    required double openingReading,
    required double closingReading,
    required double pricePerLitre,
  }) async {
    final id = _docId(pumpId, date);
    await _readingsRef.doc(id).set({
      'pumpId': pumpId,
      'pumpName': pumpName,
      'date': date,
      'openingReading': openingReading,
      'closingReading': closingReading,
      'pricePerLitre': pricePerLitre,
      'recordedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Live stream of all readings for one specific date (all pumps).
  Stream<List<PumpReadingModel>> watchReadingsForDate(String date) {
    return _readingsRef
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PumpReadingModel.fromMap(doc.id, doc.data())).toList());
  }

  /// One-time fetch of readings within a date range (for PDF export).
  Future<List<PumpReadingModel>> getReadingsInRange({required String startDate, required String endDate}) async {
    final snapshot = await _readingsRef
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .orderBy('date')
        .get();

    return snapshot.docs.map((doc) => PumpReadingModel.fromMap(doc.id, doc.data())).toList();
  }
}
