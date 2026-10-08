import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/attendance_model.dart';

/// Handles all reads/writes to the `attendance` Firestore collection.
class AttendanceFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _attendanceRef => _db.collection('attendance');

  String _docId(String staffId, String date) => '${staffId}_$date';

  /// Marks (or updates) a staff member's attendance for a given date.
  Future<void> markAttendance({
    required String staffId,
    required String staffName,
    required String date,
    required bool present,
  }) async {
    final id = _docId(staffId, date);
    await _attendanceRef.doc(id).set({
      'staffId': staffId,
      'staffName': staffName,
      'date': date,
      'present': present,
      'markedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Live stream of all attendance records for one specific date.
  Stream<List<AttendanceModel>> watchAttendanceForDate(String date) {
    return _attendanceRef
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AttendanceModel.fromMap(doc.id, doc.data())).toList());
  }

  /// Live stream of one staff member's full attendance history.
  Stream<List<AttendanceModel>> watchAttendanceForStaff(String staffId) {
    return _attendanceRef
        .where('staffId', isEqualTo: staffId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AttendanceModel.fromMap(doc.id, doc.data())).toList());
  }
}
