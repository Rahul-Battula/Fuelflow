import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pump_reading_model.dart';
import 'pump_reading_firestore_service.dart';

final pumpReadingFirestoreServiceProvider = Provider<PumpReadingFirestoreService>((ref) {
  return PumpReadingFirestoreService();
});

/// Live readings for a specific date (all pumps).
final pumpReadingsForDateProvider = StreamProvider.family<List<PumpReadingModel>, String>((ref, date) {
  final service = ref.watch(pumpReadingFirestoreServiceProvider);
  return service.watchReadingsForDate(date);
});
