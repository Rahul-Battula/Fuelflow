import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/staff_model.dart';
import 'staff_firestore_service.dart';

final staffFirestoreServiceProvider = Provider<StaffFirestoreService>((ref) {
  return StaffFirestoreService();
});

/// Live list of all staff members, updates automatically on any change.
final staffListProvider = StreamProvider<List<StaffModel>>((ref) {
  final service = ref.watch(staffFirestoreServiceProvider);
  return service.watchAllStaff();
});
