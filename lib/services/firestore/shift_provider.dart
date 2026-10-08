import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/shift_model.dart';
import 'shift_firestore_service.dart';

final shiftFirestoreServiceProvider = Provider<ShiftFirestoreService>((ref) {
  return ShiftFirestoreService();
});

/// Live shifts for a specific date (yyyy-MM-dd).
final shiftsForDateProvider = StreamProvider.family<List<ShiftModel>, String>((ref, date) {
  final service = ref.watch(shiftFirestoreServiceProvider);
  return service.watchShiftsForDate(date);
});
