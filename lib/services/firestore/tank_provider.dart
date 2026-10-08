import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tank_model.dart';
import 'tank_firestore_service.dart';

final tankFirestoreServiceProvider = Provider<TankFirestoreService>((ref) {
  return TankFirestoreService();
});

final tankListProvider = StreamProvider<List<TankModel>>((ref) {
  final service = ref.watch(tankFirestoreServiceProvider);
  return service.watchAllTanks();
});