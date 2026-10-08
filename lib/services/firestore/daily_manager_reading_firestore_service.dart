import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/daily_manager_reading_model.dart';

/// One document per date, holding all 8 nozzle readings for the manager's
/// daily 6 AM reading. Each day's reading closes the previous day and
/// opens the next — there is no separate opening/closing pair.
class DailyManagerReadingFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('daily_manager_readings');

  Future<void> saveReading({
    required String date,
    required Map<String, double> readings,
    bool isUpdate = false,
  }) async {
    final data = <String, dynamic>{
      'date': date,
      'readings': readings,
      if (!isUpdate) 'recordedAt': DateTime.now().toIso8601String(),
    };
    if (isUpdate) {
      data['updatedAt'] = DateTime.now().toIso8601String();
    }
    await _ref.doc(date).set(data, SetOptions(merge: true));
  }

  Future<DailyManagerReadingModel?> getReading(String date) async {
    final doc = await _ref.doc(date).get();
    if (!doc.exists) return null;
    return DailyManagerReadingModel.fromMap(doc.id, doc.data()!);
  }

  Stream<DailyManagerReadingModel?> watchReading(String date) {
    return _ref.doc(date).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DailyManagerReadingModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// The most recent reading strictly before [date], used to find the
  /// previous day's reading regardless of gaps (though gaps shouldn't
  /// exist given the sequential-entry rule enforced in the UI).
  Future<DailyManagerReadingModel?> getPreviousReading(String date) async {
    final snapshot = await _ref
        .where('date', isLessThan: date)
        .orderBy('date', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return DailyManagerReadingModel.fromMap(doc.id, doc.data());
  }

  /// True if any reading exists at all (used to detect "very first day ever").
  Future<bool> hasAnyReading() async {
    final snapshot = await _ref.limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  /// Live stream of the most recent [limit] readings, newest first — used to
  /// chart recent daily revenue (each day's revenue is the delta between it
  /// and the reading before it).
  Stream<List<DailyManagerReadingModel>> watchRecentReadings(int limit) {
    return _ref.orderBy('date', descending: true).limit(limit).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => DailyManagerReadingModel.fromMap(doc.id, doc.data())).toList(),
        );
  }
}