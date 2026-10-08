import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/daily_manager_reading_model.dart';
import 'daily_manager_reading_firestore_service.dart';

final dailyManagerReadingFirestoreServiceProvider =
    Provider<DailyManagerReadingFirestoreService>((ref) {
  return DailyManagerReadingFirestoreService();
});

final dailyManagerReadingForDateProvider =
    StreamProvider.family<DailyManagerReadingModel?, String>((ref, date) {
  final service = ref.watch(dailyManagerReadingFirestoreServiceProvider);
  return service.watchReading(date);
});

/// The most recent [limit] daily readings, newest first.
final recentManagerReadingsProvider = StreamProvider.family<List<DailyManagerReadingModel>, int>((ref, limit) {
  final service = ref.watch(dailyManagerReadingFirestoreServiceProvider);
  return service.watchRecentReadings(limit);
});