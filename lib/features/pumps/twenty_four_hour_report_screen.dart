import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pump_model.dart';
import '../../models/daily_expense_model.dart';
import '../../services/firestore/fuel_price_provider.dart';
import '../../services/firestore/pump_provider.dart';
import '../../services/firestore/daily_manager_reading_provider.dart';

class TwentyFourHourReportScreen extends ConsumerStatefulWidget {
  const TwentyFourHourReportScreen({super.key});

  @override
  ConsumerState<TwentyFourHourReportScreen> createState() => _TwentyFourHourReportScreenState();
}

class _TwentyFourHourReportScreenState extends ConsumerState<TwentyFourHourReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isGenerating = false;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _previousDateString(String date) {
    final parts = date.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final prev = d.subtract(const Duration(days: 1));
    return _fmt(prev);
  }

  List<String> _datesInRange() {
    final dates = <String>[];
    var cursor = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final last = DateTime(_endDate.year, _endDate.month, _endDate.day);
    while (!cursor.isAfter(last)) {
      dates.add(_fmt(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _generatePdf() async {
    // Compare calendar days only — the default start date carries a time of day.
    if (_fmt(_endDate).compareTo(_fmt(_startDate)) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be on or after the start date')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final pumps = (ref.read(pumpListProvider).value ?? [])
          .where((p) => p.status == PumpStatus.active)
          .toList();
      if (pumps.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pumps not loaded yet — try again')),
          );
        }
        return;
      }

      final db = FirebaseFirestore.instance;
            final readingService = ref.read(dailyManagerReadingFirestoreServiceProvider);
      final prices = ref.read(fuelPricesProvider).value ?? {'hsd': 0.0, 'ms': 0.0};
      final dates = _datesInRange();

      // Attendance for the manager across the range.
      final attSnap = await db
          .collection('attendance')
          .where('staffId', isEqualTo: 'manager')
          .where('date', isGreaterThanOrEqualTo: dates.first)
          .where('date', isLessThanOrEqualTo: dates.last)
          .get();
      final attendanceByDate = <String, bool>{};
      for (final doc in attSnap.docs) {
        final d = doc.data()['date'] as String?;
        final p = doc.data()['present'] as bool?;
        if (d != null && p != null) attendanceByDate[d] = p;
      }

      // Post-shift handover (cash + online) given to the manager, fetched by
      // document id (`manager_<date>`) so no composite index is required.
      final handoverByDate = <String, ({double cash, double online})>{};
      final handoverDocs = await Future.wait(
        dates.map((d) => db.collection('cash_handovers').doc('manager_$d').get()),
      );
      for (var i = 0; i < dates.length; i++) {
        final doc = handoverDocs[i];
        if (!doc.exists) continue;
        handoverByDate[dates[i]] = (
          cash: (doc.data()?['amount'] as num?)?.toDouble() ?? 0,
          online: (doc.data()?['onlineAmount'] as num?)?.toDouble() ?? 0,
        );
      }

      // Loops / testing / other expenses from the Daily Expenses portal,
      // fetched by document id (the date).
      final expenseDocs = await Future.wait(
        dates.map((d) => db.collection('daily_expenses').doc(d).get()),
      );
      final expensesByDate = <String, DailyExpenseModel>{};
      for (var i = 0; i < dates.length; i++) {
        final doc = expenseDocs[i];
        if (!doc.exists) continue;
        expensesByDate[dates[i]] = DailyExpenseModel.fromMap(dates[i], doc.data()!);
      }


      final tableData = <List<String>>[];
      double grandHsd = 0, grandMs = 0, grandFuelRevenue = 0, grandLoops = 0, grandTesting = 0;
      double grandOther = 0, grandRevenue = 0, grandCash = 0, grandOnline = 0;

      for (final date in dates) {
        final today = await readingService.getReading(date);
        final present = attendanceByDate[date];
        final attendanceStr = present == null ? '-' : (present ? 'Present' : 'Absent');

        if (today == null) {
          tableData.add([date, attendanceStr, 'No reading recorded', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-']);
          continue;
        }

        final previous = await readingService.getReading(_previousDateString(date));
        if (previous == null) {
          tableData.add([date, attendanceStr, 'Baseline (no prior day)', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-']);
          continue;
        }

        double hsdLitres = 0, msLitres = 0;
        for (final pump in pumps) {
          for (final nozzle in pump.nozzles) {
            final key = '${pump.id}_${nozzle.id}';
            final t = today.readings[key];
            final p = previous.readings[key];
            if (t == null || p == null) continue;
            final litres = t - p;
            if (nozzle.fuelType == FuelType.hsd) {
              hsdLitres += litres;
            } else {
              msLitres += litres;
            }
          }
        }

        final fuelRevenue = hsdLitres * (prices['hsd'] ?? 0) + msLitres * (prices['ms'] ?? 0);
        final expenses = expensesByDate[date] ?? DailyExpenseModel.empty(date);
        final loops = expenses.loopsTotal;
        final testing = expenses.testingValue(prices);
        final other = expenses.otherExpensesTotal;
        final revenue = fuelRevenue + loops - testing - other;
        final handover = handoverByDate[date] ?? (cash: 0.0, online: 0.0);
        final balance = revenue - handover.cash - handover.online;

        grandHsd += hsdLitres;
        grandMs += msLitres;
        grandFuelRevenue += fuelRevenue;
        grandLoops += loops;
        grandTesting += testing;
        grandOther += other;
        grandRevenue += revenue;
        grandCash += handover.cash;
        grandOnline += handover.online;

        tableData.add([
          date,
          attendanceStr,
          'OK',
          hsdLitres.toStringAsFixed(2),
          msLitres.toStringAsFixed(2),
          fuelRevenue.toStringAsFixed(2),
          loops.toStringAsFixed(2),
          testing.toStringAsFixed(2),
          other.toStringAsFixed(2),
          revenue.toStringAsFixed(2),
          handover.cash.toStringAsFixed(2),
          handover.online.toStringAsFixed(2),
          balance.toStringAsFixed(2),
        ]);
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'FuelFlow - 24-Hour Portal Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text('Period: ${_fmt(_startDate)} to ${_fmt(_endDate)}'),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Attendance',
                'Status',
                'HSD (L)',
                'MS (L)',
                'Fuel Revenue',
                'Loops (+)',
                'Testing (-)',
                'Other Exp. (-)',
                'Total Revenue',
                'Cash Given',
                'Online Given',
                'Balance Due',
              ],
              data: tableData,
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Grand Total HSD: ${grandHsd.toStringAsFixed(2)} L',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total MS: ${grandMs.toStringAsFixed(2)} L',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total Fuel Revenue: Rs. ${grandFuelRevenue.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total Loops (+): Rs. ${grandLoops.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total Testing (-): Rs. ${grandTesting.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total Other Expenses (-): Rs. ${grandOther.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total Revenue: Rs. ${grandRevenue.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total Cash Given: Rs. ${grandCash.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total Online Given: Rs. ${grandOnline.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Balance Due (Revenue - Cash - Online): Rs. ${(grandRevenue - grandCash - grandOnline).toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text(
              'Note: Revenue and testing use current fuel rates. Total Revenue = Fuel '
              'Revenue + Loops - Testing - Other Expenses. Balance Due is Total Revenue '
              'minus the cash and online amounts handed to the manager. '
              '"Baseline" rows have no prior day to compare against. "No reading '
              'recorded" rows indicate a gap.',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '24hour_report_${_fmt(_startDate)}_to_${_fmt(_endDate)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('24-Hour Portal Report')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select date range', style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              _dateTile(theme, 'Start: ${_fmt(_startDate)}', _pickStartDate),
              const SizedBox(height: 12),
              _dateTile(theme, 'End: ${_fmt(_endDate)}', _pickEndDate),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generatePdf,
                icon: _isGenerating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(_isGenerating ? 'Generating...' : 'Generate & Share PDF'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile(ThemeData theme, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            const Icon(Icons.calendar_today_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}