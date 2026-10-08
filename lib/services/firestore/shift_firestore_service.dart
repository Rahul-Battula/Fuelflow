import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/shift_model.dart';

/// Handles all reads/writes to the `shifts` Firestore collection.
class ShiftFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _shiftsRef => _db.collection('shifts');

Future<void> addShift({
    required String date,
    required String label,
    required String startTime,
    required String endTime,
    required List<String> staffIds,
    required List<String> staffNames,
    required double changeAmount,
  }) async {
    await _shiftsRef.add({
      'date': date,
      'label': label.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      'staffIds': staffIds,
      'staffNames': staffNames,
      'changeAmount': changeAmount,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

Future<void> updateShift({
    required String id,
    required String label,
    required String startTime,
    required String endTime,
    required List<String> staffIds,
    required List<String> staffNames,
    required double changeAmount,
  }) async {
    await _shiftsRef.doc(id).update({
      'label': label.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      'staffIds': staffIds,
      'staffNames': staffNames,
      'changeAmount': changeAmount,
    });
  }

  /// Live stream of all shifts for a specific date.
  Stream<List<ShiftModel>> watchShiftsForDate(String date) {
    return _shiftsRef
        .where('date', isEqualTo: date)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ShiftModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> deleteShift(String id) async {
    await _shiftsRef.doc(id).delete();
  }
}
