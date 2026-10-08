import 'package:cloud_firestore/cloud_firestore.dart';

/// Stores current price-per-litre for each fuel type, editable by Owner.
class FuelPriceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _priceDoc => _db.collection('settings').doc('fuel_prices');

  Stream<Map<String, double>> watchPrices() {
    return _priceDoc.snapshots().map((doc) {
      final data = doc.data() ?? {};
      return {'hsd': (data['hsd'] as num?)?.toDouble() ?? 0, 'ms': (data['ms'] as num?)?.toDouble() ?? 0};
    });
  }

  Future<void> setPrices({required double hsd, required double ms}) async {
    await _priceDoc.set({'hsd': hsd, 'ms': ms});
  }
}
