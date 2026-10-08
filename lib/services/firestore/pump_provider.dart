import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pump_model.dart';
import 'pump_firestore_service.dart';

final pumpFirestoreServiceProvider = Provider<PumpFirestoreService>((ref) {
  return PumpFirestoreService();
});

final pumpListProvider = StreamProvider<List<PumpModel>>((ref) {
  final service = ref.watch(pumpFirestoreServiceProvider);
  return service.watchAllPumps();
});
