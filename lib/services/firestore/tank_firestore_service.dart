import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/tank_model.dart';

class TankFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tanksRef =>
      _db.collection('tanks');

  Future<void> addTank({required String name, required String fuelType}) async {
    await _tanksRef.add({
      'name': name.trim(),
      'fuelType': fuelType,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<TankModel>> watchAllTanks() {
    return _tanksRef.orderBy('createdAt').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => TankModel.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Future<void> ensureDefaultTanks() async {
    // Ask the server, not the local cache: on a fresh install with no
    // internet the cache is empty and would make us create duplicate tanks.
    final snapshot = await _tanksRef.limit(1).get(const GetOptions(source: Source.server));
    if (snapshot.docs.isNotEmpty) return;

    await addTank(name: 'HSD Tank', fuelType: 'hsd');
    await addTank(name: 'MS Tank', fuelType: 'ms');
  }
}