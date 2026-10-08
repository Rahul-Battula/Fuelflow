import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cash_handover_model.dart';

class CashHandoverFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _ref => _db.collection('cash_handovers');

  String _docId(String staffId, String date) => '${staffId}_$date';

  /// Saves the post-shift handover for a staff member on a date. [cashAmount]
  /// and [onlineAmount] are updated independently — pass only the one being
  /// edited so the other channel is left untouched.
  Future<void> saveHandover({
    required String staffId,
    required String staffName,
    required String date,
    double? cashAmount,
    double? onlineAmount,
  }) async {
    final id = _docId(staffId, date);
    await _ref.doc(id).set({
      'staffId': staffId,
      'staffName': staffName,
      'date': date,
      'amount': ?cashAmount,
      'onlineAmount': ?onlineAmount,
    }, SetOptions(merge: true));
  }

  Stream<CashHandoverModel?> watchHandover(String staffId, String date) {
    final id = _docId(staffId, date);
    return _ref.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CashHandoverModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// Live stream of every handover (staff + manager) recorded on [date] —
  /// used to total up the day's collections across the whole team.
  Stream<List<CashHandoverModel>> watchHandoversForDate(String date) {
    return _ref.where('date', isEqualTo: date).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => CashHandoverModel.fromMap(doc.id, doc.data())).toList(),
        );
  }

  Future<List<CashHandoverModel>> getHandoversForStaff(String staffId) async {
    final snapshot = await _ref.where('staffId', isEqualTo: staffId).get();
    return snapshot.docs.map((doc) => CashHandoverModel.fromMap(doc.id, doc.data())).toList();
  }
}