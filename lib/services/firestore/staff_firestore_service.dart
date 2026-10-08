import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/staff_model.dart';

/// Handles all reads/writes to the `staff` Firestore collection.
class StaffFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _staffRef => _db.collection('staff');

  /// Live stream of all staff, newest first.
  Stream<List<StaffModel>> watchAllStaff() {
    return _staffRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => StaffModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> addStaff({
    required String name,
    required String phone,
    required String position,
    required String shiftType,
    required double cashGiven,
    String? localPhotoPath,
  }) async {
    await _staffRef.add({
      'name': name.trim(),
      'phone': phone.trim(),
      'position': position.trim(),
      'shiftType': shiftType,
      'cashGiven': cashGiven,
      'localPhotoPath': localPhotoPath,
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateStaff({
    required String id,
    required String name,
    required String phone,
    required String position,
  }) async {
    await _staffRef.doc(id).update({'name': name.trim(), 'phone': phone.trim(), 'position': position.trim()});
  }

  Future<void> updateStaffDetails({
    required String id,
    required String name,
    required String phone,
    required String position,
    required String shiftType,
    required double cashGiven,
    String? localPhotoPath,
  }) async {
    await _staffRef.doc(id).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'position': position.trim(),
      'shiftType': shiftType,
      'cashGiven': cashGiven,
      'localPhotoPath': ?localPhotoPath,
    });
  }

  Future<void> setStatus({required String id, required StaffStatus status}) async {
    await _staffRef.doc(id).update({'status': status == StaffStatus.active ? 'active' : 'inactive'});
  }

  Future<void> deleteStaff(String id) async {
    await _staffRef.doc(id).delete();
  }
}