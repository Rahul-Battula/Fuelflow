import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/nozzle_reading_model.dart';

/// Handles all reads/writes to the `nozzle_readings` Firestore collection.
class NozzleReadingFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _readingsRef => _db.collection('nozzle_readings');

  String _docId(String checkpointId, String pumpId, String nozzleId) => '${checkpointId}_${pumpId}_$nozzleId';

  Future<void> saveReading({
    required String checkpointId,
    required String pumpId,
    required String pumpName,
    required String nozzleId,
    required String nozzleLabel,
    required String fuelType,
    required double reading,
  }) async {
    final id = _docId(checkpointId, pumpId, nozzleId);
    await _readingsRef.doc(id).set({
      'checkpointId': checkpointId,
      'pumpId': pumpId,
      'pumpName': pumpName,
      'nozzleId': nozzleId,
      'nozzleLabel': nozzleLabel,
      'fuelType': fuelType,
      'reading': reading,
      'recordedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Live stream of all nozzle readings for a specific checkpoint.
  Stream<List<NozzleReadingModel>> watchReadingsForCheckpoint(String checkpointId) {
    return _readingsRef
        .where('checkpointId', isEqualTo: checkpointId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => NozzleReadingModel.fromMap(doc.id, doc.data())).toList());
  }

  /// Gets the most recent reading for a specific nozzle before a checkpoint,
  /// used to show "previous reading" for reference (litres only increase).
  Future<NozzleReadingModel?> getLatestReadingForNozzle({
    required String pumpId,
    required String nozzleId,
    required DateTime beforeTime,
  }) async {
    final snapshot = await _readingsRef
        .where('pumpId', isEqualTo: pumpId)
        .where('nozzleId', isEqualTo: nozzleId)
        .orderBy('recordedAt', descending: true)
        .limit(5)
        .get();

    for (final doc in snapshot.docs) {
      final reading = NozzleReadingModel.fromMap(doc.id, doc.data());
      if (reading.recordedAt.isBefore(beforeTime)) {
        return reading;
      }
    }
    return null;
  }
}
