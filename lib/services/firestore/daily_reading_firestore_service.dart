import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/daily_reading_model.dart';

class DailyReadingFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _ref => _db.collection('daily_pump_readings');

  String _docId(String date, String pumpId, String nozzleId) => '${date}_${pumpId}_$nozzleId';

  Future<void> saveReading({
    required String date,
    required String pumpId,
    required String pumpName,
    required String nozzleId,
    required String nozzleLabel,
    required String fuelType,
    required double opening,
    required double closing,
  }) async {
    final id = _docId(date, pumpId, nozzleId);
    await _ref.doc(id).set({
      'date': date,
      'pumpId': pumpId,
      'pumpName': pumpName,
      'nozzleId': nozzleId,
      'nozzleLabel': nozzleLabel,
      'fuelType': fuelType,
      'opening': opening,
      'closing': closing,
    });
  }

  Stream<List<DailyReadingModel>> watchReadingsForDate(String date) {
    return _ref.where('date', isEqualTo: date).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => DailyReadingModel.fromMap(doc.id, doc.data())).toList(),
    );
  }
}