import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/shift_assignment_model.dart';
import 'shift_assignment_firestore_service.dart';

final shiftAssignmentFirestoreServiceProvider = Provider<ShiftAssignmentFirestoreService>((ref) {
  return ShiftAssignmentFirestoreService();
});

final shiftAssignmentForStaffDateProvider =
    StreamProvider.family<ShiftAssignmentModel?, ({String date, String staffId})>((ref, params) {
  final service = ref.watch(shiftAssignmentFirestoreServiceProvider);
  return service.watchAssignment(params.date, params.staffId);
});