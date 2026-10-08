import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/daily_reading_model.dart';
import 'daily_reading_firestore_service.dart';

final dailyReadingFirestoreServiceProvider = Provider<DailyReadingFirestoreService>((ref) {
  return DailyReadingFirestoreService();
});

final dailyReadingsForDateProvider = StreamProvider.family<List<DailyReadingModel>, String>((ref, date) {
  final service = ref.watch(dailyReadingFirestoreServiceProvider);
  return service.watchReadingsForDate(date);
});