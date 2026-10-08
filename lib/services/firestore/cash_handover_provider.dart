import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cash_handover_model.dart';
import 'cash_handover_firestore_service.dart';

final cashHandoverFirestoreServiceProvider = Provider<CashHandoverFirestoreService>((ref) {
  return CashHandoverFirestoreService();
});

final cashHandoverForDateProvider =
    StreamProvider.family<CashHandoverModel?, ({String staffId, String date})>((ref, params) {
  final service = ref.watch(cashHandoverFirestoreServiceProvider);
  return service.watchHandover(params.staffId, params.date);
});

/// Every handover (staff + manager) recorded on a given date.
final cashHandoversForDateProvider = StreamProvider.family<List<CashHandoverModel>, String>((ref, date) {
  final service = ref.watch(cashHandoverFirestoreServiceProvider);
  return service.watchHandoversForDate(date);
});