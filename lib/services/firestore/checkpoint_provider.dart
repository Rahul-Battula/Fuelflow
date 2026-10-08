import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/checkpoint_model.dart';
import 'checkpoint_firestore_service.dart';

final checkpointFirestoreServiceProvider = Provider<CheckpointFirestoreService>((ref) {
  return CheckpointFirestoreService();
});

/// Live checkpoints for a specific date (yyyy-MM-dd).
final checkpointsForDateProvider = StreamProvider.family<List<CheckpointModel>, String>((ref, date) {
  final service = ref.watch(checkpointFirestoreServiceProvider);
  return service.watchCheckpointsForDate(date);
});
