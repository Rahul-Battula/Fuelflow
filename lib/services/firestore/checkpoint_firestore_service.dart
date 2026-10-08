import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/checkpoint_model.dart';

/// Handles all reads/writes to the `checkpoints` Firestore collection.
class CheckpointFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _checkpointsRef => _db.collection('checkpoints');

  /// Creates a checkpoint and returns its generated document ID.
  Future<String> addCheckpoint({
    required String label,
    required String time,
    required String actualTime,
    required String date,
    required int order,
  }) async {
    final docRef = await _checkpointsRef.add({
      'label': label.trim(),
      'time': time.trim(),
      'actualTime': actualTime.trim(),
      'date': date,
      'order': order,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return docRef.id;
  }

  /// Live stream of all checkpoints for a specific date, in order.
  Stream<List<CheckpointModel>> watchCheckpointsForDate(String date) {
    return _checkpointsRef
        .where('date', isEqualTo: date)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CheckpointModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> deleteCheckpoint(String id) async {
    await _checkpointsRef.doc(id).delete();
  }
}