import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pump_model.dart';
import '../../models/manager_model.dart';
import '../../services/firestore/fuel_price_provider.dart';
import '../../services/firestore/pump_provider.dart';
import '../../services/firestore/attendance_provider.dart';
import '../../services/firestore/cash_handover_provider.dart';
import '../../services/firestore/manager_provider.dart';
import '../../services/firestore/daily_manager_reading_provider.dart';
import '../../models/daily_manager_reading_model.dart';
import '../../models/daily_expense_model.dart';
import '../../services/firestore/daily_expense_provider.dart';

class TwentyFourHourTab extends ConsumerStatefulWidget {
  const TwentyFourHourTab({super.key});

  @override
  ConsumerState<TwentyFourHourTab> createState() => _TwentyFourHourTabState();
}

class _TwentyFourHourTabState extends ConsumerState<TwentyFourHourTab> {
  DateTime _businessDate = DateTime.now();
  DateTime _visibleMonth = DateTime.now();
  Map<String, bool> _attendanceByDate = {};
  bool _loadingAttendance = true;

  String get _dateString =>
      '${_businessDate.year}-${_businessDate.month.toString().padLeft(2, '0')}-${_businessDate.day.toString().padLeft(2, '0')}';

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
          .where('staffId', isEqualTo: 'manager')
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

  Future<void> _markDay(String dateStr, ManagerModel manager) async {
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
        staffId: 'manager',
        staffName: manager.name,
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _businessDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _businessDate = picked);
  }

  Future<void> _editManager(ManagerModel? current) async {
    final nameCtrl = TextEditingController(text: current?.name ?? '');
    final phoneCtrl = TextEditingController(text: current?.phone ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Manager'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();

    if (result == true && name.isNotEmpty) {
      final service = ref.read(managerFirestoreServiceProvider);
      try {
        await service.setManager(name: name, phone: phone);
      } catch (_) {
        _showSnack('Could not save manager. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final managerAsync = ref.watch(managerProvider);

    return managerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LoadErrorCard(
            message: 'Could not load the 24-hour portal manager. '
                'Check your internet connection.',
            error: err,
            onRetry: () => ref.invalidate(managerProvider),
          ),
        ],
      ),
      data: (manager) {
        if (manager == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No manager set for the 24-hour portal.', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => _editManager(null), child: const Text('Set Manager')),
                ],
              ),
            ),
          );
        }

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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(manager.name),
                subtitle: Text(manager.phone),
                trailing: TextButton(onPressed: () => _editManager(manager), child: const Text('Change')),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
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
                    Text('6 AM Reading Date: $_dateString'),
                    const Icon(Icons.calendar_today_rounded, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _DailyReadingSection(
              key: ValueKey(_dateString),
              date: _dateString,
              managerName: manager.name,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _changeMonth(-1)),
                Text('${_monthName(_visibleMonth.month)} ${_visibleMonth.year}', style: theme.textTheme.titleMedium),
                IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _changeMonth(1)),
              ],
            ),
            if (_loadingAttendance)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
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
                child: Text('Tap a day to mark attendance', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
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

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _markDay(dateStr, manager),
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
        );
      },
    );
  }

  Widget _statChip(ThemeData theme, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
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

/// One reading per date, 8 nozzles across both pumps. Each day's reading
/// is simultaneously "yesterday's closing" and "today's opening" — there
/// is no separate open/close pair. Revenue for a date = today's reading
/// minus the previous date's reading. Entry is blocked unless the
/// previous date already has a reading, except for the very first
/// reading ever taken. Any date is freely editable by the manager.
class _DailyReadingSection extends ConsumerStatefulWidget {
  final String date;
  final String managerName;

  const _DailyReadingSection({
    super.key,
    required this.date,
    required this.managerName,
  });

  @override
  ConsumerState<_DailyReadingSection> createState() => _DailyReadingSectionState();
}

class _DailyReadingSectionState extends ConsumerState<_DailyReadingSection> {
  final Map<String, TextEditingController> _controllers = {};
  bool _editing = false;
  bool _saving = false;

  // Cached one-shot reads. Creating these inside build() would refetch (and
  // flash a spinner over the form) on every rebuild, e.g. when Save is tapped.
  Future<List<Object?>>? _gateFuture;
  Future<DailyManagerReadingModel?>? _previousFuture;

  Future<List<Object?>> _gateData() {
    final service = ref.read(dailyManagerReadingFirestoreServiceProvider);
    return _gateFuture ??= Future.wait<Object?>([
      service.getReading(_previousDateString(widget.date)),
      service.hasAnyReading(),
    ]);
  }

  Future<DailyManagerReadingModel?> _previousReading() =>
      _previousFuture ??= ref.read(dailyManagerReadingFirestoreServiceProvider).getPreviousReading(widget.date);

  String _key(String pumpId, String nozzleId) => '${pumpId}_$nozzleId';

  TextEditingController _controllerFor(String pumpId, String nozzleId) =>
      _controllers.putIfAbsent(_key(pumpId, nozzleId), () => TextEditingController());

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save(List<PumpModel> pumps, {required bool isUpdate}) async {
    for (final pump in pumps) {
      for (final nozzle in pump.nozzles) {
        final text = _controllerFor(pump.id, nozzle.id).text.trim();
        if (text.isEmpty) {
          _showError('${pump.name} ${nozzle.label}: reading is required');
          return;
        }
        if (double.tryParse(text) == null) {
          _showError('${pump.name} ${nozzle.label}: enter a valid number');
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final readings = <String, double>{};
      for (final pump in pumps) {
        for (final nozzle in pump.nozzles) {
          readings[_key(pump.id, nozzle.id)] =
              double.parse(_controllerFor(pump.id, nozzle.id).text.trim());
        }
      }

      final service = ref.read(dailyManagerReadingFirestoreServiceProvider);
      await service.saveReading(date: widget.date, readings: readings, isUpdate: isUpdate);

      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reading saved')));
      }
    } catch (_) {
      if (mounted) _showError('Could not save reading. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pumpsAsync = ref.watch(pumpListProvider);
    final readingAsync = ref.watch(dailyManagerReadingForDateProvider(widget.date));

    return pumpsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _LoadErrorCard(
        message: 'Could not load pumps. Check your internet connection.',
        error: err,
        onRetry: () => ref.invalidate(pumpListProvider),
      ),
      data: (allPumps) {
        final pumps = allPumps.where((p) => p.status == PumpStatus.active).toList();
        if (pumps.isEmpty) return const Text('No active pumps.');

        return readingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _LoadErrorCard(
            message: 'Could not load the 24-hour reading for ${widget.date}. '
                'Check your internet connection.',
            error: err,
            onRetry: () => ref.invalidate(dailyManagerReadingForDateProvider(widget.date)),
          ),
          data: (reading) {
            if (reading == null || _editing) {
              return _EntryOrGate(
                date: widget.date,
                gateData: _gateData(),
                onRetry: () => setState(() => _gateFuture = null),
                pumps: pumps,
                controllerFor: _controllerFor,
                saving: _saving,
                editing: _editing && reading != null,
                onCancelEdit: () => setState(() => _editing = false),
                onSave: (isUpdate) => _save(pumps, isUpdate: isUpdate),
                existingReadings: reading?.readings,
              );
            }

            // Reading exists and not editing — show results.
            return FutureBuilder(
              future: _previousReading(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _LoadErrorCard(
                    message: 'Could not load the previous day\'s reading.',
                    error: snapshot.error,
                    onRetry: () => setState(() => _previousFuture = null),
                  );
                }
                final previous = snapshot.data;
                final pricesAsync = ref.watch(fuelPricesProvider);
                final prices = pricesAsync.value ?? {'hsd': 0.0, 'ms': 0.0};
                // Loops (+), testing and other expenses (−) from the Daily Expenses portal.
                final expenses = ref.watch(dailyExpenseForDateProvider(widget.date)).value;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('24-Hour Reading — ${widget.date}', style: theme.textTheme.titleMedium),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit reading',
                              onPressed: () => setState(() => _editing = true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (previous == null)
                          Text(
                            'This is the first recorded reading — no previous day to compare against, so no revenue yet.',
                            style: theme.textTheme.bodySmall,
                          )
                        else ...[
                          _RevenueSummary(
                            pumps: pumps,
                            todayReadings: reading.readings,
                            previousReadings: previous.readings,
                            prices: prices,
                            expenses: expenses,
                          ),
                          _ManagerHandoverSection(
                            date: widget.date,
                            managerName: widget.managerName,
                            collection: _dayCollectionValue(
                                  pumps,
                                  reading.readings,
                                  previous.readings,
                                  prices,
                                ) +
                                (expenses?.netAdjustment(prices) ?? 0),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Shown when no reading exists yet for this date, or when editing.
/// First checks whether the previous date has a reading; blocks entry
/// with a clear message if not (unless this is the very first reading).
String _previousDateString(String date) {
  final parts = date.split('-');
  final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  final prev = d.subtract(const Duration(days: 1));
  return '${prev.year}-${prev.month.toString().padLeft(2, '0')}-${prev.day.toString().padLeft(2, '0')}';
}

class _EntryOrGate extends StatelessWidget {
  final String date;
  final Future<List<Object?>> gateData;
  final VoidCallback onRetry;
  final List<PumpModel> pumps;
  final TextEditingController Function(String, String) controllerFor;
  final bool saving;
  final bool editing;
  final VoidCallback onCancelEdit;
  final void Function(bool isUpdate) onSave;
  final Map<String, double>? existingReadings;

  const _EntryOrGate({
    required this.date,
    required this.gateData,
    required this.onRetry,
    required this.pumps,
    required this.controllerFor,
    required this.saving,
    required this.editing,
    required this.onCancelEdit,
    required this.onSave,
    this.existingReadings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Editing an existing reading skips the gate check entirely —
    // it already exists, so the chain is already intact.
    if (editing) {
      return _Form(
        pumps: pumps,
        controllerFor: controllerFor,
        saving: saving,
        onSave: () => onSave(true),
        onCancel: onCancelEdit,
        existingReadings: existingReadings,
        title: 'Editing reading for $date',
      );
    }

    return FutureBuilder(
      future: gateData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _LoadErrorCard(
            message: 'Could not load 24-hour reading data. Check your internet '
                'connection and try again.',
            error: snapshot.error,
            onRetry: onRetry,
          );
        }

        final results = snapshot.data as List;
        final previousReading = results[0] as DailyManagerReadingModel?;
        final anyReadingExists = results[1] as bool;

        final isVeryFirstReading = !anyReadingExists;
        final canEnter = isVeryFirstReading || previousReading != null;

        if (!canEnter) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cannot enter reading for $date', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${_previousDateString(date)}\'s reading is missing. Select that date first and enter it before continuing.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        return _Form(
          pumps: pumps,
          controllerFor: controllerFor,
          saving: saving,
          onSave: () => onSave(false),
          onCancel: null,
          existingReadings: null,
          title: isVeryFirstReading
              ? 'First reading — enter today\'s meter values'
              : 'Enter reading for $date',
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  final List<PumpModel> pumps;
  final TextEditingController Function(String, String) controllerFor;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback? onCancel;
  final Map<String, double>? existingReadings;
  final String title;

  const _Form({
    required this.pumps,
    required this.controllerFor,
    required this.saving,
    required this.onSave,
    required this.onCancel,
    required this.existingReadings,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                if (onCancel != null)
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onCancel),
              ],
            ),
            const SizedBox(height: 12),
            ...pumps.expand((pump) => [
                  Text(pump.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ...pump.nozzles.map((nozzle) {
                    final ctrl = controllerFor(pump.id, nozzle.id);
                    final key = '${pump.id}_${nozzle.id}';
                    if (existingReadings != null && existingReadings!.containsKey(key) && ctrl.text.isEmpty) {
                      ctrl.text = existingReadings![key]!.toStringAsFixed(2);
                    }
                    final isHsd = nozzle.fuelType == FuelType.hsd;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '${nozzle.label} (${isHsd ? 'HSD' : 'MS'}) — Reading',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                ]),
            ElevatedButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Reading'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueSummary extends StatelessWidget {
  final List<PumpModel> pumps;
  final Map<String, double> todayReadings;
  final Map<String, double> previousReadings;
  final Map<String, double> prices;
  final DailyExpenseModel? expenses;

  const _RevenueSummary({
    required this.pumps,
    required this.todayReadings,
    required this.previousReadings,
    required this.prices,
    this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double hsdLitres = 0, msLitres = 0;
    final rows = <Widget>[];

    for (final pump in pumps) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(pump.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ));
      for (final nozzle in pump.nozzles) {
        final key = '${pump.id}_${nozzle.id}';
        final today = todayReadings[key];
        final prev = previousReadings[key];
        if (today == null || prev == null) continue;
        final litres = today - prev;
        if (nozzle.fuelType == FuelType.hsd) {
          hsdLitres += litres;
        } else {
          msLitres += litres;
        }
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '${nozzle.label}: ${prev.toStringAsFixed(2)} → ${today.toStringAsFixed(2)}  =  ${litres.toStringAsFixed(2)} L',
            style: theme.textTheme.bodySmall,
          ),
        ));
      }
    }

    final hsdValue = hsdLitres * (prices['hsd'] ?? 0);
    final msValue = msLitres * (prices['ms'] ?? 0);
    final total = hsdValue + msValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows,
        const Divider(height: 20),
        Text('HSD: ${hsdLitres.toStringAsFixed(2)} L  =  ₹${hsdValue.toStringAsFixed(2)}', style: theme.textTheme.bodySmall),
        Text('MS: ${msLitres.toStringAsFixed(2)} L  =  ₹${msValue.toStringAsFixed(2)}', style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        if (expenses != null && !expenses!.isEmpty) ...[
          Text('Fuel Revenue: ₹${total.toStringAsFixed(2)}', style: theme.textTheme.bodySmall),
          Text('+ Loops: ₹${expenses!.loopsTotal.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
          Text(
              '− Testing (HSD ${expenses!.testingHsdLitres.toStringAsFixed(2)} L, '
              'MS ${expenses!.testingMsLitres.toStringAsFixed(2)} L): '
              '₹${expenses!.testingValue(prices).toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          Text('− Other Expenses: ₹${expenses!.otherExpensesTotal.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          const SizedBox(height: 6),
        ],
        Text('Total Revenue: ₹${(total + (expenses?.netAdjustment(prices) ?? 0)).toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Graceful fallback when a one-shot Firestore read fails (usually offline).
/// Replaces the raw "type 'Null' is not a subtype of List" crash.
class _LoadErrorCard extends StatelessWidget {
  final String message;
  final Object? error;
  final VoidCallback? onRetry;

  const _LoadErrorCard({required this.message, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 20, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Offline', style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodySmall),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text('$error',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Day's fuel collection for the 24-hour portal: sum of (today − previous)
/// litres across every nozzle, priced at the current rates.
double _dayCollectionValue(
  List<PumpModel> pumps,
  Map<String, double> todayReadings,
  Map<String, double> previousReadings,
  Map<String, double> prices,
) {
  double hsdLitres = 0, msLitres = 0;
  for (final pump in pumps) {
    for (final nozzle in pump.nozzles) {
      final key = '${pump.id}_${nozzle.id}';
      final today = todayReadings[key];
      final prev = previousReadings[key];
      if (today == null || prev == null) continue;
      final litres = today - prev;
      if (nozzle.fuelType == FuelType.hsd) {
        hsdLitres += litres;
      } else {
        msLitres += litres;
      }
    }
  }
  return hsdLitres * (prices['hsd'] ?? 0) + msLitres * (prices['ms'] ?? 0);
}

/// Cash + online amounts handed to the manager after the 24-hour shift, and
/// the balance still owed once both are subtracted from the day's collection.
class _ManagerHandoverSection extends ConsumerWidget {
  final String date;
  final String managerName;
  final double collection;

  const _ManagerHandoverSection({
    required this.date,
    required this.managerName,
    required this.collection,
  });

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required bool online,
    required double current,
  }) async {
    final label = online ? 'Online Amount Given' : 'Cash Given';
    final controller =
        TextEditingController(text: current == 0 ? '' : current.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label — $date'),
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
    if (result != true) return;

    // Empty means 0; anything else must be a valid, non-negative number so a
    // typo never silently overwrites the saved amount with 0.
    final text = controller.text.trim().replaceAll(',', '');
    final amount = text.isEmpty ? 0.0 : double.tryParse(text);
    if (amount == null || amount < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      }
      return;
    }
    String message = '$label saved';
    try {
      await ref.read(cashHandoverFirestoreServiceProvider).saveHandover(
            staffId: 'manager',
            staffName: managerName.trim().isEmpty ? 'Manager' : managerName.trim(),
            date: date,
            cashAmount: online ? null : amount,
            onlineAmount: online ? amount : null,
          );
    } catch (_) {
      message = 'Could not save ${label.toLowerCase()}. Please try again.';
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final handoverAsync =
        ref.watch(cashHandoverForDateProvider((staffId: 'manager', date: date)));
    final handover = handoverAsync.value;
    final cash = handover?.amount ?? 0;
    final online = handover?.onlineAmount ?? 0;
    final balance = collection - cash - online;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text('Manager Handover',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        _editableRow(context, ref, theme, 'Cash Given', cash, online: false),
        _editableRow(context, ref, theme, 'Online Amount Given', online, online: true),
        const SizedBox(height: 8),
        _summaryLine(theme, 'Day Collection', collection),
        _summaryLine(theme, 'Cash Given', -cash),
        _summaryLine(theme, 'Online Given', -online),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1),
        ),
        _summaryLine(theme, 'Balance Due', balance, bold: true, highlight: true),
      ],
    );
  }

  Widget _editableRow(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    String label,
    double value, {
    required bool online,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₹${value.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit $label',
              onPressed: () => _edit(context, ref, online: online, current: value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryLine(ThemeData theme, String label, double value,
      {bool bold = false, bool highlight = false}) {
    final text = '${value < 0 ? '-' : ''}₹${value.abs().toStringAsFixed(2)}';
    Color? color;
    if (highlight) {
      color = value > 0 ? theme.colorScheme.error : Colors.green;
    }
    final labelStyle = bold
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodySmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(
          text,
          style: (bold ? theme.textTheme.titleSmall : theme.textTheme.bodySmall)
              ?.copyWith(fontWeight: bold ? FontWeight.w700 : null, color: color),
        ),
      ],
    );
  }
}
