import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pump_model.dart';
import '../../services/firestore/fuel_price_provider.dart';
import '../../services/firestore/pump_provider.dart';

class ShiftReportScreen extends ConsumerStatefulWidget {
  final String shiftType; // "morning" or "night"

  const ShiftReportScreen({super.key, required this.shiftType});

  @override
  ConsumerState<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends ConsumerState<ShiftReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isGenerating = false;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  /// One row per staff member who was actually assigned a pump on that date,
  /// for this specific shift type.
  Future<List<_ShiftRow>> _buildRows(List<PumpModel> pumps) async {
    final db = FirebaseFirestore.instance;
    final prices = ref.read(fuelPricesProvider).value ?? {'hsd': 0.0, 'ms': 0.0};
    final dates = _datesInRange();

    final openTime = widget.shiftType == 'morning' ? '8:00 AM' : '7:00 PM';
    final closeTime =
        widget.shiftType == 'morning' ? '7:00 PM' : '6:00 AM (Next Day)';

    final rows = <_ShiftRow>[];

    for (final date in dates) {
      final assignSnap = await db
          .collection('shift_assignments')
          .where('date', isEqualTo: date)
          .where('shiftType', isEqualTo: widget.shiftType)
          .get();

      if (assignSnap.docs.isEmpty) continue;

      // Checkpoints are stored under the shift's start date, including
      // night shift's closing checkpoint (6AM next day), so this single
      // date-filtered query covers both open and close checkpoints.
      final cpSnap =
          await db.collection('checkpoints').where('date', isEqualTo: date).get();
      String? openCpId, closeCpId;
      for (final doc in cpSnap.docs) {
        final t = doc.data()['time'] as String? ?? '';
        if (t == openTime) openCpId = doc.id;
        if (t == closeTime) closeCpId = doc.id;
      }

      for (final assignDoc in assignSnap.docs) {
        final data = assignDoc.data();
        final staffId = data['staffId'] as String? ?? '';
        final staffName = data['staffName'] as String? ?? '';
        final pumpId = data['pumpId'] as String? ?? '';
        final pumpName = data['pumpName'] as String? ?? '';

        final cashDoc = await db
            .collection('cash_handovers')
            .doc('${staffId}_$date')
            .get();
        final cashGiven = cashDoc.exists
            ? ((cashDoc.data()?['amount'] as num?)?.toDouble() ?? 0.0)
            : 0.0;
        final onlineGiven = cashDoc.exists
            ? ((cashDoc.data()?['onlineAmount'] as num?)?.toDouble() ?? 0.0)
            : 0.0;

        double hsdLitres = 0, msLitres = 0, saleValue = 0;

        final pump = pumps.where((p) => p.id == pumpId).cast<PumpModel?>().firstOrNull;

        if (pump != null && openCpId != null && closeCpId != null) {
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

          final openMap = <String, double>{};
          for (final d in openSnap.docs) {
            openMap[d.data()['nozzleId'] as String? ?? ''] =
                (d.data()['reading'] as num?)?.toDouble() ?? 0;
          }
          final closeMap = <String, double>{};
          for (final d in closeSnap.docs) {
            closeMap[d.data()['nozzleId'] as String? ?? ''] =
                (d.data()['reading'] as num?)?.toDouble() ?? 0;
          }

          for (final nozzle in pump.nozzles) {
            final o = openMap[nozzle.id];
            final c = closeMap[nozzle.id];
            if (o == null || c == null) continue;
            final litres = c - o;
            if (nozzle.fuelType == FuelType.hsd) {
              hsdLitres += litres;
            } else {
              msLitres += litres;
            }
          }

          saleValue = hsdLitres * (prices['hsd'] ?? 0) + msLitres * (prices['ms'] ?? 0);
        }

        rows.add(_ShiftRow(
          date: date,
          staffName: staffName,
          pump: pumpName,
          hsdLitres: hsdLitres,
          msLitres: msLitres,
          saleValue: saleValue,
          cashGiven: cashGiven,
          onlineGiven: onlineGiven,
        ));
      }
    }

    return rows;
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
      final pumps = ref.read(pumpListProvider).value ?? [];
      if (pumps.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pumps not loaded yet — try again')),
          );
        }
        return;
      }

      final rows = await _buildRows(pumps);

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No ${widget.shiftType} shift assignments found in this range',
              ),
            ),
          );
        }
        return;
      }

      final Map<String, List<_ShiftRow>> byDate = {};
      for (final r in rows) {
        byDate.putIfAbsent(r.date, () => []).add(r);
      }
      final sortedDates = byDate.keys.toList()..sort();

      double grandHsd = 0, grandMs = 0, grandSale = 0, grandCash = 0, grandOnline = 0;

      final tableData = <List<String>>[];
      for (final date in sortedDates) {
        final dayRows = byDate[date]!;
        double dayHsd = 0, dayMs = 0, daySale = 0, dayCash = 0, dayOnline = 0;

        for (final r in dayRows) {
          tableData.add([
            r.date,
            r.staffName,
            r.pump,
            r.hsdLitres.toStringAsFixed(2),
            r.msLitres.toStringAsFixed(2),
            r.saleValue.toStringAsFixed(2),
            r.cashGiven.toStringAsFixed(2),
            r.onlineGiven.toStringAsFixed(2),
            (r.saleValue - r.cashGiven - r.onlineGiven).toStringAsFixed(2),
          ]);
          dayHsd += r.hsdLitres;
          dayMs += r.msLitres;
          daySale += r.saleValue;
          dayCash += r.cashGiven;
          dayOnline += r.onlineGiven;
        }

        tableData.add([
          '',
          'Day Total',
          '',
          dayHsd.toStringAsFixed(2),
          dayMs.toStringAsFixed(2),
          daySale.toStringAsFixed(2),
          dayCash.toStringAsFixed(2),
          dayOnline.toStringAsFixed(2),
          (daySale - dayCash - dayOnline).toStringAsFixed(2),
        ]);

        grandHsd += dayHsd;
        grandMs += dayMs;
        grandSale += daySale;
        grandCash += dayCash;
        grandOnline += dayOnline;
      }

      final shiftLabel = widget.shiftType == 'morning' ? 'Morning' : 'Night';

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'FuelFlow - $shiftLabel Shift Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text('Period: ${_fmt(_startDate)} to ${_fmt(_endDate)}'),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Staff',
                'Pump',
                'HSD (L)',
                'MS (L)',
                'Sale Value',
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
            pw.Text('Grand Total Sale Value: Rs. ${grandSale.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total Cash Given: Rs. ${grandCash.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Grand Total Online Given: Rs. ${grandOnline.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Balance Due (Collection - Cash - Online): Rs. ${(grandSale - grandCash - grandOnline).toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text(
              'Note: Sale values use current fuel rates. Balance Due is the shift '
              'collection minus the cash and online amounts handed to the staff member.',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            '${widget.shiftType}_shift_${_fmt(_startDate)}_to_${_fmt(_endDate)}.pdf',
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
    final shiftLabel = widget.shiftType == 'morning' ? 'Morning' : 'Night';

    return Scaffold(
      appBar: AppBar(title: Text('$shiftLabel Shift Report')),
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

class _ShiftRow {
  final String date;
  final String staffName;
  final String pump;
  final double hsdLitres;
  final double msLitres;
  final double saleValue;
  final double cashGiven;
  final double onlineGiven;

  _ShiftRow({
    required this.date,
    required this.staffName,
    required this.pump,
    required this.hsdLitres,
    required this.msLitres,
    required this.saleValue,
    required this.cashGiven,
    required this.onlineGiven,
  });
}