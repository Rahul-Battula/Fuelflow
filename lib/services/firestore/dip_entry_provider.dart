import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dip_entry_model.dart';
import 'dip_entry_firestore_service.dart';

final dipEntryFirestoreServiceProvider = Provider<DipEntryFirestoreService>((ref) {
  return DipEntryFirestoreService();
});

final dipHistoryForFuelProvider = StreamProvider.family<List<DipEntryModel>, String>((ref, fuelType) {
  final service = ref.watch(dipEntryFirestoreServiceProvider);
  return service.watchHistory(fuelType);
});