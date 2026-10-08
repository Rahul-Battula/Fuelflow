import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/manager_model.dart';

/// Handles the single `settings/manager` document — one fixed manager record.
class ManagerFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('settings').doc('manager');

  Future<void> setManager({required String name, required String phone}) async {
    await _ref.set({
      'name': name,
      'phone': phone,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<ManagerModel?> watchManager() {
    return _ref.snapshots().map((doc) {
      if (!doc.exists) return null;
      return ManagerModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<ManagerModel?> getManager() async {
    final doc = await _ref.get();
    if (!doc.exists) return null;
    return ManagerModel.fromMap(doc.id, doc.data()!);
  }
}