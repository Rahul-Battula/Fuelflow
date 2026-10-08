// Unit tests for FuelFlow's pure calculation logic (no Firebase needed).

import 'package:flutter_test/flutter_test.dart';

import 'package:fuelflow/models/cash_handover_model.dart';
import 'package:fuelflow/models/daily_expense_model.dart';
import 'package:fuelflow/models/dip_chart_model.dart';
import 'package:fuelflow/models/pump_reading_model.dart';

void main() {
  group('DipChartModel.volumeForDip', () {
    // diffPerMm on a row describes the interval ENDING at that row's cm mark.
    final chart = DipChartModel(
      fuelType: 'hsd',
      rows: [
        DipChartRow(cm: 1, volume: 11.97, diffPerMm: 1.20),
        DipChartRow(cm: 2, volume: 33.89, diffPerMm: 2.19),
        DipChartRow(cm: 3, volume: 62.22, diffPerMm: 2.83),
      ],
    );

    test('returns the exact row volume on a whole-cm dip', () {
      expect(chart.volumeForDip(2), closeTo(33.89, 1e-9));
    });

    test('interpolates upward using the next interval\'s slope', () {
      // 2.5 cm -> volume at 2 cm plus 5 mm of the 2->3 cm slope (2.83/mm).
      expect(chart.volumeForDip(2.5), closeTo(33.89 + 5 * 2.83, 1e-9));
    });

    test('midpoint interpolation lands near the true chart midpoint', () {
      final mid = chart.volumeForDip(1.5)!;
      final trueMid = (11.97 + 33.89) / 2;
      expect((mid - trueMid).abs(), lessThan(0.5));
    });

    test('falls back to the base row slope at the top of the chart', () {
      expect(chart.volumeForDip(3.4), closeTo(62.22 + 4 * 2.83, 1e-9));
    });

    test('returns null when the whole-cm mark is not in the chart', () {
      expect(chart.volumeForDip(9.5), isNull);
    });

    test('returns null for an empty chart', () {
      expect(DipChartModel(fuelType: 'ms', rows: []).volumeForDip(1.0), isNull);
    });
  });

  group('CashHandoverModel', () {
    test('sums cash and online into totalGiven', () {
      final h = CashHandoverModel(
        id: 's1_2026-09-06',
        staffId: 's1',
        staffName: 'A',
        date: '2026-09-06',
        amount: 12000,
        onlineAmount: 3500,
      );
      expect(h.totalGiven, closeTo(15500, 1e-9));
    });

    test('defaults online amount to zero for legacy records', () {
      final h = CashHandoverModel.fromMap('id', {
        'staffId': 's1',
        'staffName': 'A',
        'date': '2026-09-06',
        'amount': 9000,
      });
      expect(h.onlineAmount, 0);
      expect(h.totalGiven, closeTo(9000, 1e-9));
    });

    test('balance due = shift collection minus cash minus online', () {
      const collection = 18200.0;
      final h = CashHandoverModel(
        id: 'id',
        staffId: 's1',
        staffName: 'A',
        date: '2026-09-06',
        amount: 12000,
        onlineAmount: 3500,
      );
      expect(collection - h.totalGiven, closeTo(2700, 1e-9));
    });
  });

  group('PumpReadingModel', () {
    test('computes litres sold and revenue from meter readings', () {
      final reading = PumpReadingModel(
        id: 'r1',
        pumpId: 'p1',
        pumpName: 'Pump 1',
        date: '2026-09-06',
        openingReading: 1000,
        closingReading: 1250.5,
        pricePerLitre: 100,
        recordedAt: DateTime(2026, 9, 6),
      );

      expect(reading.litresSold, closeTo(250.5, 1e-9));
      expect(reading.revenue, closeTo(25050, 1e-9));
    });
  });

  group('DailyExpenseModel', () {
    const prices = {'hsd': 90.0, 'ms': 100.0};

    test('adds loops and subtracts testing (litres x current rate) and other expenses', () {
      const expenses = DailyExpenseModel(
        date: '2026-10-02',
        loops: [ExpenseItem(name: '2T Oil', amount: 300), ExpenseItem(name: 'Engine Oil', amount: 450)],
        testingHsdLitres: 5,
        testingMsLitres: 2,
        otherExpenses: [ExpenseItem(name: 'Tea', amount: 120)],
      );

      expect(expenses.loopsTotal, 750);
      expect(expenses.testingValue(prices), 5 * 90 + 2 * 100);
      expect(expenses.otherExpensesTotal, 120);
      expect(expenses.netAdjustment(prices), 750 - 650 - 120);
    });

    test('round-trips through a Firestore map and treats missing fields as zero', () {
      final legacy = DailyExpenseModel.fromMap('2026-10-02', {'loops': [{'name': 'Distilled Water', 'amount': 60}]});
      expect(legacy.loopsTotal, 60);
      expect(legacy.testingValue(prices), 0);
      expect(legacy.otherExpenses, isEmpty);

      final copy = DailyExpenseModel.fromMap('2026-10-02', legacy.toMap());
      expect(copy.loops.single.name, 'Distilled Water');
      expect(copy.netAdjustment(prices), 60);
    });

    test('empty day changes nothing', () {
      final empty = DailyExpenseModel.empty('2026-10-02');
      expect(empty.isEmpty, isTrue);
      expect(empty.netAdjustment(prices), 0);
    });
  });
}
