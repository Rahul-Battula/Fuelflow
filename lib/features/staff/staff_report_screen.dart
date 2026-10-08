import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/staff_model.dart';
import '../../models/pump_model.dart';
import '../../services/firestore/fuel_price_provider.dart';
import '../../services/firestore/pump_provider.dart';

class StaffReportScreen extends ConsumerStatefulWidget {
  final StaffModel staff;

  const StaffReportScreen({super.key, required this.staff});

  @override
  ConsumerState<StaffReportScreen> createState() => _StaffReportScreenState();
}

class _StaffReportScreenState extends ConsumerState<StaffReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isGenerating = false;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Every date string from start to end, inclusive.
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

  /// Builds one row per date for this staff member.
  Future<List<_ReportRow>> _buildRows(List<PumpModel> pumps) async {
    final db = FirebaseFirestore.instance;
    final prices = ref.read(fuelPricesProvider).value ?? {'hsd': 0.0, 'ms': 0.0};
    final dates = _datesInRange();

    final openTime = widget.staff.shiftType == 'morning' ? '8:00 AM' : '7:00 PM';
    final closeTime =
        widget.staff.shiftType == 'morning' ? '7:00 PM' : '6:00 AM (Next Day)';

    final rows = <_ReportRow>[];

    for (final date in dates) {
      // Attendance
      final attDoc = await db
          .collection('attendance')
          .doc('${widget.staff.id}_$date')
          .get();
      final present = attDoc.exists ? (attDoc.data()?['present'] as bool?) : null;

      // Cash given
      final cashDoc = await db
          .collection('cash_handovers')
          .doc('${widget.staff.id}_$date')
          .get();
      final cashGiven = cashDoc.exists
          ? ((cashDoc.data()?['amount'] as num?)?.toDouble() ?? 0.0)
          : 0.0;
      final onlineGiven = cashDoc.exists
          ? ((cashDoc.data()?['onlineAmount'] as num?)?.toDouble() ?? 0.0)
          : 0.0;

      // Pump assignment
      final assignDoc = await db
          .collection('shift_assignments')
          .doc('${date}_${widget.staff.id}')
          .get();
      final pumpId = assignDoc.exists
          ? (assignDoc.data()?['pumpId'] as String?)
          : null;
      final pumpName = assignDoc.exists
          ? ((assignDoc.data()?['pumpName'] as String?) ?? '')
          : '';

      double hsdLitres = 0, msLitres = 0, saleValue = 0;

      if (pumpId != null) {
        final pump =
            pumps.where((p) => p.id == pumpId).cast<PumpModel?>().firstOrNull;

        if (pump != null) {
          // Checkpoints for this date
          final cpSnap = await db
              .collection('checkpoints')
              .where('date', isEqualTo: date)
              .get();

          String? openCpId, closeCpId;
          for (final doc in cpSnap.docs) {
            final t = doc.data()['time'] as String? ?? '';
            if (t == openTime) openCpId = doc.id;
            if (t == closeTime) closeCpId = doc.id;
          }

          if (openCpId != null && closeCpId != null) {
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

            saleValue = hsdLitres * (prices['hsd'] ?? 0) +
                msLitres * (prices['ms'] ?? 0);
          }
        }
      }

      rows.add(_ReportRow(
        date: date,
        attendance: present == null ? '-' : (present ? 'Present' : 'Absent'),
        pump: pumpName.isEmpty ? '-' : pumpName,
        hsdLitres: hsdLitres,
        msLitres: msLitres,
        saleValue: saleValue,
        cashGiven: cashGiven,
        onlineGiven: onlineGiven,
      ));
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

      double totalHsd = 0, totalMs = 0, totalSale = 0, totalCash = 0, totalOnline = 0;
      for (final r in rows) {
        totalHsd += r.hsdLitres;
        totalMs += r.msLitres;
        totalSale += r.saleValue;
        totalCash += r.cashGiven;
        totalOnline += r.onlineGiven;
      }
      final totalBalance = totalSale - totalCash - totalOnline;

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'FuelFlow - Staff Report',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text('Staff: ${widget.staff.name}'),
            pw.Text('Position: ${widget.staff.position}'),
            pw.Text(
              'Shift: ${widget.staff.shiftType == 'morning' ? 'Morning' : 'Night'}',
            ),
            pw.Text('Period: ${_fmt(_startDate)} to ${_fmt(_endDate)}'),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Attendance',
                'Pump',
                'HSD (L)',
                'MS (L)',
                'Sale Value',
                'Cash Given',
                'Online Given',
                'Balance Due',
              ],
              data: rows.map((r) {
                return [
                  r.date,
                  r.attendance,
                  r.pump,
                  r.hsdLitres.toStringAsFixed(2),
                  r.msLitres.toStringAsFixed(2),
                  r.saleValue.toStringAsFixed(2),
                  r.cashGiven.toStringAsFixed(2),
                  r.onlineGiven.toStringAsFixed(2),
                  (r.saleValue - r.cashGiven - r.onlineGiven).toStringAsFixed(2),
                ];
              }).toList(),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle:
                  pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Total HSD: ${totalHsd.toStringAsFixed(2)} L',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Total MS: ${totalMs.toStringAsFixed(2)} L',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Total Sale Value: Rs. ${totalSale.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Total Cash Given: Rs. ${totalCash.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Total Online Given: Rs. ${totalOnline.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Balance Due (Collection - Cash - Online): Rs. ${totalBalance.toStringAsFixed(2)}',
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
            '${widget.staff.name}_${_fmt(_startDate)}_to_${_fmt(_endDate)}.pdf',
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
      appBar: AppBar(title: Text('${widget.staff.name} — Report')),
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(
                    _isGenerating ? 'Generating...' : 'Generate & Share PDF'),
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
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2)),
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

class _ReportRow {
  final String date;
  final String attendance;
  final String pump;
  final double hsdLitres;
  final double msLitres;
  final double saleValue;
  final double cashGiven;
  final double onlineGiven;

  _ReportRow({
    required this.date,
    required this.attendance,
    required this.pump,
    required this.hsdLitres,
    required this.msLitres,
    required this.saleValue,
    required this.cashGiven,
    required this.onlineGiven,
  });
}