import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pump_model.dart';
import 'fuel_price_provider.dart';
import 'pump_provider.dart';

/// Fuel money collected by one staff member on one shift.
class ShiftCollection {
  final double hsdLitres;
  final double msLitres;
  final double value; // hsdLitres * hsdPrice + msLitres * msPrice
  final bool hasReadings; // false when opening/closing checkpoints aren't both in

  const ShiftCollection({
    required this.hsdLitres,
    required this.msLitres,
    required this.value,
    required this.hasReadings,
  });

  static const empty = ShiftCollection(
    hsdLitres: 0,
    msLitres: 0,
    value: 0,
    hasReadings: false,
  );
}

typedef ShiftCollectionArgs = ({String staffId, String date, String shiftType});

/// Computes a staff member's fuel collection for a given date + shift, using
/// the same open/close nozzle-reading maths as the shift and staff reports.
/// This is the figure the post-shift cash and online handovers are subtracted
/// from to get the balance still owed.
final shiftCollectionProvider =
    FutureProvider.family<ShiftCollection, ShiftCollectionArgs>((ref, args) async {
  final db = FirebaseFirestore.instance;
  final pumps = ref.watch(pumpListProvider).value ?? const [];
  final prices = ref.watch(fuelPricesProvider).value ?? const {'hsd': 0.0, 'ms': 0.0};

  final assignDoc =
      await db.collection('shift_assignments').doc('${args.date}_${args.staffId}').get();
  if (!assignDoc.exists) return ShiftCollection.empty;

  final pumpId = assignDoc.data()?['pumpId'] as String?;
  if (pumpId == null || pumpId.isEmpty) return ShiftCollection.empty;

  final pump = pumps.where((p) => p.id == pumpId).cast<PumpModel?>().firstOrNull;
  if (pump == null) return ShiftCollection.empty;

  final openTime = args.shiftType == 'morning' ? '8:00 AM' : '7:00 PM';
  final closeTime = args.shiftType == 'morning' ? '7:00 PM' : '6:00 AM (Next Day)';

  final cpSnap =
      await db.collection('checkpoints').where('date', isEqualTo: args.date).get();
  String? openCpId, closeCpId;
  for (final doc in cpSnap.docs) {
    final t = doc.data()['time'] as String? ?? '';
    if (t == openTime) openCpId = doc.id;
    if (t == closeTime) closeCpId = doc.id;
  }
  if (openCpId == null || closeCpId == null) return ShiftCollection.empty;

  final openSnap = await db
      .collection('nozzle_readings')
      .where('checkpointId', isEqualTo: openCpId)
      .where('pumpId', isEqualTo: pumpId)
      .get();
  final closeSnap = await db
      .collection('nozzle_readings')
      .where('checkpointId', isEqualTo: closeCpId)
      .where('pumpId', isEqualTo: pumpId)
      .get();

  final openMap = <String, double>{
    for (final d in openSnap.docs)
      (d.data()['nozzleId'] as String? ?? ''): (d.data()['reading'] as num?)?.toDouble() ?? 0,
  };
  final closeMap = <String, double>{
    for (final d in closeSnap.docs)
      (d.data()['nozzleId'] as String? ?? ''): (d.data()['reading'] as num?)?.toDouble() ?? 0,
  };

  double hsdLitres = 0, msLitres = 0;
  var sawAny = false;
  for (final nozzle in pump.nozzles) {
    final o = openMap[nozzle.id];
    final c = closeMap[nozzle.id];
    if (o == null || c == null) continue;
    sawAny = true;
    final litres = c - o;
    if (nozzle.fuelType == FuelType.hsd) {
      hsdLitres += litres;
    } else {
      msLitres += litres;
    }
  }

  final value = hsdLitres * (prices['hsd'] ?? 0) + msLitres * (prices['ms'] ?? 0);
  return ShiftCollection(
    hsdLitres: hsdLitres,
    msLitres: msLitres,
    value: value,
    hasReadings: sawAny,
  );
});
