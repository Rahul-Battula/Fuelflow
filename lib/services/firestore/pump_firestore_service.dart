import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pump_model.dart';

/// Handles all reads/writes to the `pumps` Firestore collection.
class PumpFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pumpsRef => _db.collection('pumps');

  Stream<List<PumpModel>> watchAllPumps() {
    return _pumpsRef
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PumpModel.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> addPump({required String name, required List<NozzleModel> nozzles}) async {
    await _pumpsRef.add({
      'name': name.trim(),
      'nozzles': nozzles.map((n) => n.toMap()).toList(),
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> ensureDefaultPumps() async {
    // Ask the server, not the local cache: on a fresh install with no
    // internet the cache is empty and would make us create duplicate pumps.
    final snapshot = await _pumpsRef.limit(1).get(const GetOptions(source: Source.server));
    if (snapshot.docs.isNotEmpty) return;

    await addPump(name: 'Pump 1', nozzles: PumpModel.defaultNozzles());
    await addPump(name: 'Pump 2', nozzles: PumpModel.defaultNozzles());
  }

  Future<void> setStatus({required String id, required PumpStatus status}) async {
    await _pumpsRef.doc(id).update({'status': status == PumpStatus.active ? 'active' : 'inactive'});
  }

  Future<void> deletePump(String id) async {
    await _pumpsRef.doc(id).delete();
  }
}
