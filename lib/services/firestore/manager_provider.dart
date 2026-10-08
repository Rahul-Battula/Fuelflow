import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/manager_model.dart';
import 'manager_firestore_service.dart';

final managerFirestoreServiceProvider = Provider<ManagerFirestoreService>((ref) {
  return ManagerFirestoreService();
});

final managerProvider = StreamProvider<ManagerModel?>((ref) {
  final service = ref.watch(managerFirestoreServiceProvider);
  return service.watchManager();
});