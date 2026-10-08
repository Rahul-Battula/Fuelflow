import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/staff_model.dart';
import '../../services/firestore/cash_handover_provider.dart';
import '../../services/firestore/shift_collection_provider.dart';
import '../../services/firestore/attendance_provider.dart';
import 'widgets/shift_readings_section.dart';
import 'staff_report_screen.dart';

class StaffDetailScreen extends ConsumerStatefulWidget {
  final StaffModel staff;

  const StaffDetailScreen({super.key, required this.staff});

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  DateTime _visibleMonth = DateTime.now();
  Map<String, bool> _attendanceByDate = {};
  bool _loadingAttendance = true;

  DateTime _cashDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loadingAttendance = true);
    final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('staffId', isEqualTo: widget.staff.id)
          .get();
    } catch (_) {
      // Don't leave the calendar spinning forever when offline.
      if (mounted) {
        setState(() => _loadingAttendance = false);
        _showSnack('Could not load attendance. Check your internet connection.');
      }
      return;
    }

    final map = <String, bool>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = data['date'] as String?;
      final present = data['present'] as bool?;
      if (date != null && present != null) {
        map[date] = present;
      }
    }

    if (mounted) {
      setState(() {
        _attendanceByDate = map;
        _loadingAttendance = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    });
  }

  Future<void> _markDay(String dateStr) async {
    final result = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark $dateStr'),
        content: const Text('Set attendance for this day'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Absent')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Present')),
        ],
      ),
    );

    if (result == null) return;

    final service = ref.read(attendanceFirestoreServiceProvider);
    try {
      await service.markAttendance(
        staffId: widget.staff.id,
        staffName: widget.staff.name,
        date: dateStr,
        present: result,
      );
    } catch (_) {
      _showSnack('Could not save attendance. Please try again.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _attendanceByDate[dateStr] = result;
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _cashDateString =>
      '${_cashDate.year}-${_cashDate.month.toString().padLeft(2, '0')}-${_cashDate.day.toString().padLeft(2, '0')}';

  String get _todayString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickCashDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _cashDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _cashDate = picked);
  }

  Future<void> _editHandover({required bool online, required double current}) async {
    final label = online ? 'Online Amount Given' : 'Cash Given';
    final controller = TextEditingController(
      text: current == 0 ? '' : current.toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label \u2014 $_cashDateString'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      // Empty means 0; anything else must be a valid, non-negative number so a
      // typo never silently overwrites the saved amount with 0.
      final text = controller.text.trim().replaceAll(',', '');
      final amount = text.isEmpty ? 0.0 : double.tryParse(text);
      if (amount == null || amount < 0) {
        _showSnack('Enter a valid amount');
        return;
      }
      final service = ref.read(cashHandoverFirestoreServiceProvider);
      try {
        await service.saveHandover(
          staffId: widget.staff.id,
          staffName: widget.staff.name,
          date: _cashDateString,
          cashAmount: online ? null : amount,
          onlineAmount: online ? amount : null,
        );
      } catch (_) {
        _showSnack('Could not save ${label.toLowerCase()}. Please try again.');
        return;
      }
      _showSnack('$label saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staff = widget.staff;
    final hasPhoto = staff.localPhotoPath != null && File(staff.localPhotoPath!).existsSync();

    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7;

    int presentCount = 0;
    int absentCount = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      final dateStr =
          '${_visibleMonth.year}-${_visibleMonth.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final status = _attendanceByDate[dateStr];
      if (status == true) presentCount++;
      if (status == false) absentCount++;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(staff.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export Report',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StaffReportScreen(staff: staff)),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                backgroundImage: hasPhoto ? FileImage(File(staff.localPhotoPath!)) : null,
                child: !hasPhoto
                    ? Text(
                        staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 32, color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(staff.name, style: theme.textTheme.headlineSmall)),
            Center(
              child: Text(
                staff.shiftType == 'morning' ? 'Morning Shift' : 'Night Shift',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(theme, Icons.phone_outlined, 'Phone', staff.phone),
                    const Divider(height: 20),
                    _infoRow(theme, Icons.badge_outlined, 'Position', staff.position),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final handoverAsync = ref.watch(
                  cashHandoverForDateProvider(
                    (staffId: staff.id, date: _cashDateString),
                  ),
                );
                final collectionAsync = ref.watch(
                  shiftCollectionProvider((
                    staffId: staff.id,
                    date: _cashDateString,
                    shiftType: staff.shiftType,
                  )),
                );

                final handover = handoverAsync.value;
                final cash = handover?.amount ?? 0;
                final online = handover?.onlineAmount ?? 0;
                final collection = collectionAsync.value?.value ?? 0;
                final balance = collection - cash - online;

                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_today_rounded, size: 18),
                        title: Text('Handover \u00b7 $_cashDateString'),
                        subtitle: Text(
                          staff.shiftType == 'morning' ? 'Morning shift' : 'Night shift',
                        ),
                        trailing: TextButton(onPressed: _pickCashDate, child: const Text('Change')),
                      ),
                      const Divider(height: 1),
                      handoverAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, _) => ListTile(title: Text('Error: $err')),
                        data: (_) => Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.payments_outlined, color: theme.colorScheme.primary),
                              title: const Text('Cash Given'),
                              subtitle: Text('\u20b9${cash.toStringAsFixed(2)}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _editHandover(online: false, current: cash),
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(Icons.smartphone_outlined, color: theme.colorScheme.primary),
                              title: const Text('Online Amount Given'),
                              subtitle: Text('\u20b9${online.toStringAsFixed(2)}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _editHandover(online: true, current: online),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          children: [
                            _amountRow(theme, 'Shift Collection', collection),
                            const SizedBox(height: 6),
                            _amountRow(theme, 'Cash Given', -cash),
                            const SizedBox(height: 6),
                            _amountRow(theme, 'Online Given', -online),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                            _amountRow(theme, 'Balance Due', balance, bold: true, highlight: true),
                            if (collectionAsync.isLoading)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Calculating shift collection\u2026',
                                      style: theme.textTheme.bodySmall),
                                ),
                              )
                            else if (!(collectionAsync.value?.hasReadings ?? false))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Shift readings for this date aren\'t complete yet \u2014 '
                                  'collection shows as \u20b90.00 until both open and close readings are in.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ShiftReadingsSection(
              // Fresh form state per date so values typed for one date never
              // carry over (or block the saved readings' prefill) on another.
              key: ValueKey(_cashDateString),
              staffId: staff.id,
              staffName: staff.name,
              shiftType: staff.shiftType,
              date: _cashDateString,
              isToday: _cashDateString == _todayString,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _changeMonth(-1)),
                Text(
                  '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _changeMonth(1)),
              ],
            ),
            if (_loadingAttendance)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statChip(theme, 'Present', presentCount, Colors.green),
                  _statChip(theme, 'Absent', absentCount, theme.colorScheme.error),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Tap a day to mark attendance',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                itemCount: daysInMonth + firstWeekday,
                itemBuilder: (context, index) {
                  if (index < firstWeekday) return const SizedBox();
                  final day = index - firstWeekday + 1;
                  final dateStr =
                      '${_visibleMonth.year}-${_visibleMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final status = _attendanceByDate[dateStr];

                  Color? bgColor;
                  if (status == true) bgColor = Colors.green.withValues(alpha: 0.2);
                  if (status == false) bgColor = theme.colorScheme.error.withValues(alpha: 0.15);

                  return InkWell(
                    onTap: () => _markDay(dateStr),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                      ),
                      alignment: Alignment.center,
                      child: Text('$day', style: theme.textTheme.bodySmall),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(label, style: theme.textTheme.bodySmall),
        const Spacer(),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _amountRow(ThemeData theme, String label, double value,
      {bool bold = false, bool highlight = false}) {
    final text = '${value < 0 ? '-' : ''}₹${value.abs().toStringAsFixed(2)}';
    Color? valueColor;
    if (highlight) {
      valueColor = value > 0 ? theme.colorScheme.error : Colors.green;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: bold
              ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
              : theme.textTheme.bodyMedium,
        ),
        Text(
          text,
          style: (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
              ?.copyWith(
            fontWeight: bold ? FontWeight.w700 : null,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _statChip(ThemeData theme, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $count', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }
}