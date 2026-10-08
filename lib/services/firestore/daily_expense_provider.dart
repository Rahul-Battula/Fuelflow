import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/daily_expense_model.dart';
import 'daily_expense_firestore_service.dart';

final dailyExpenseFirestoreServiceProvider = Provider<DailyExpenseFirestoreService>((ref) {
  return DailyExpenseFirestoreService();
});

/// Loops / testing / other expenses for a date (null when nothing entered yet).
final dailyExpenseForDateProvider = StreamProvider.family<DailyExpenseModel?, String>((ref, date) {
  final service = ref.watch(dailyExpenseFirestoreServiceProvider);
  return service.watchForDate(date);
});
