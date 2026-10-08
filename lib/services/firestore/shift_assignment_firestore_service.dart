import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/shift_assignment_model.dart';

/// Handles all reads/writes to the `shift_assignments` Firestore collection.
class ShiftAssignmentFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref => _db.collection('shift_assignments');

  String _docId(String date, String staffId) => '${date}_$staffId';

  /// Assigns a staff member to a pump for a given date. Overwrites any
  /// existing assignment for that staff member on that date.
  Future<void> assignPump({
    required String date,
    required String staffId,
    required String staffName,
    required String pumpId,
    required String pumpName,
    required String shiftType,
  }) async {
    final id = _docId(date, staffId);
    await _ref.doc(id).set({
      'date': date,
      'staffId': staffId,
      'staffName': staffName,
      'pumpId': pumpId,
      'pumpName': pumpName,
      'shiftType': shiftType,
      'assignedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Live stream of one staff member's assignment for a specific date.
  Stream<ShiftAssignmentModel?> watchAssignment(String date, String staffId) {
    final id = _docId(date, staffId);
    return _ref.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ShiftAssignmentModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<ShiftAssignmentModel?> getAssignment(String date, String staffId) async {
    final id = _docId(date, staffId);
    final doc = await _ref.doc(id).get();
    if (!doc.exists) return null;
    return ShiftAssignmentModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> removeAssignment(String date, String staffId) async {
    final id = _docId(date, staffId);
    await _ref.doc(id).delete();
  }
}