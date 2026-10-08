import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'fuel_price_service.dart';

final fuelPriceServiceProvider = Provider<FuelPriceService>((ref) {
  return FuelPriceService();
});

final fuelPricesProvider = StreamProvider<Map<String, double>>((ref) {
  final service = ref.watch(fuelPriceServiceProvider);
  return service.watchPrices();
});
