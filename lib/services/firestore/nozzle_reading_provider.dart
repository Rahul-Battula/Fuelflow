import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/nozzle_reading_model.dart';
import 'nozzle_reading_firestore_service.dart';

final nozzleReadingFirestoreServiceProvider = Provider<NozzleReadingFirestoreService>((ref) {
  return NozzleReadingFirestoreService();
});

/// Live nozzle readings for a specific checkpoint.
final readingsForCheckpointProvider = StreamProvider.family<List<NozzleReadingModel>, String>((ref, checkpointId) {
  final service = ref.watch(nozzleReadingFirestoreServiceProvider);
  return service.watchReadingsForCheckpoint(checkpointId);
});
