import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/attendance_model.dart';
import 'attendance_firestore_service.dart';

final attendanceFirestoreServiceProvider = Provider<AttendanceFirestoreService>((ref) {
  return AttendanceFirestoreService();
});

/// Live attendance records for a specific date (yyyy-MM-dd).
final attendanceForDateProvider = StreamProvider.family<List<AttendanceModel>, String>((ref, date) {
  final service = ref.watch(attendanceFirestoreServiceProvider);
  return service.watchAttendanceForDate(date);
});
