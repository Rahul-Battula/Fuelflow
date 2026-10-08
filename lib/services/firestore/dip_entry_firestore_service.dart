import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dip_entry_model.dart';

class DipEntryFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref => _db.collection('dip_entries');

  Future<void> addEntry({
    required String fuelType,
    required double dipCm,
    required double volumeLitres,
  }) async {
    await _ref.add({
      'fuelType': fuelType,
      'dipCm': dipCm,
      'volumeLitres': volumeLitres,
      'recordedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateEntry({
    required String id,
    required double dipCm,
    required double volumeLitres,
  }) async {
    await _ref.doc(id).update({
      'dipCm': dipCm,
      'volumeLitres': volumeLitres,
    });
  }

  /// Live history for one fuel type, most recent first.
  Stream<List<DipEntryModel>> watchHistory(String fuelType) {
    return _ref
        .where('fuelType', isEqualTo: fuelType)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DipEntryModel.fromMap(doc.id, doc.data())).toList());
  }
}