import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dip_chart_model.dart';
import 'dip_chart_firestore_service.dart';

final dipChartFirestoreServiceProvider = Provider<DipChartFirestoreService>((ref) {
  return DipChartFirestoreService();
});

final dipChartForFuelProvider = StreamProvider.family<DipChartModel?, String>((ref, fuelType) {
  final service = ref.watch(dipChartFirestoreServiceProvider);
  return service.watchChart(fuelType);
});