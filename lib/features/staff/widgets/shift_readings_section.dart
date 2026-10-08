import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/pump_model.dart';
import '../../../models/checkpoint_model.dart';
import '../../../services/firestore/pump_provider.dart';
import '../../../services/firestore/checkpoint_provider.dart';
import '../../../services/firestore/nozzle_reading_provider.dart';
import '../../../services/firestore/fuel_price_provider.dart';
import '../../../services/firestore/shift_assignment_provider.dart';
import '../../../services/firestore/shift_collection_provider.dart';

class ShiftReadingsSection extends ConsumerStatefulWidget {
  final String staffId;
  final String staffName;
  final String shiftType; // "morning" or "night"
  final String date; // yyyy-MM-dd
  final bool isToday;

  const ShiftReadingsSection({
    super.key,
    required this.staffId,
    required this.staffName,
    required this.shiftType,
    required this.date,
    required this.isToday,
  });

  @override
  ConsumerState<ShiftReadingsSection> createState() => _ShiftReadingsSectionState();
}

class _ShiftReadingsSectionState extends ConsumerState<ShiftReadingsSection> {
  final Map<String, TextEditingController> _openingControllers = {};
  final Map<String, TextEditingController> _closingControllers = {};
  bool _savingOpening = false;
  bool _savingClosing = false;
  bool _editingResults = false;

  TextEditingController _openingFor(String nozzleId) =>
      _openingControllers.putIfAbsent(nozzleId, () => TextEditingController());

  TextEditingController _closingFor(String nozzleId) =>
      _closingControllers.putIfAbsent(nozzleId, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _openingControllers.values) {
      c.dispose();
    }
    for (final c in _closingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _assignPump(PumpModel pump) async {
    final service = ref.read(shiftAssignmentFirestoreServiceProvider);
    try {
      await service.assignPump(
        date: widget.date,
        staffId: widget.staffId,
        staffName: widget.staffName,
        pumpId: pump.id,
        pumpName: pump.name,
        shiftType: widget.shiftType,
      );
      _refreshShiftCollection();
    } catch (_) {
      if (mounted) _showError('Could not assign pump. Check your internet connection and try again.');
    }
  }

  /// The staff screen's shift collection / balance is a one-shot fetch, so
  /// it must be refreshed whenever this section changes the underlying data.
  void _refreshShiftCollection() {
    if (!mounted) return;
    ref.invalidate(shiftCollectionProvider((
      staffId: widget.staffId,
      date: widget.date,
      shiftType: widget.shiftType,
    )));
  }

  CheckpointModel? _findCheckpoint(List<CheckpointModel> checkpoints, String targetTime) {
    for (final cp in checkpoints) {
      if (cp.time == targetTime) return cp;
    }
    return null;
  }

  /// Returns the checkpoint for this date/time, creating it if absent.
  Future<CheckpointModel> _ensureCheckpoint({
    required List<CheckpointModel> existing,
    required String label,
    required String time,
    required int order,
  }) async {
    final found = _findCheckpoint(existing, time);
    if (found != null) return found;

    final service = ref.read(checkpointFirestoreServiceProvider);
    final newId = await service.addCheckpoint(
      label: label,
      time: time,
      actualTime: time,
      date: widget.date,
      order: order,
    );

    return CheckpointModel(
      id: newId,
      label: label,
      time: time,
      actualTime: time,
      date: widget.date,
      order: order,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _saveOpening(PumpModel pump, List<CheckpointModel> checkpoints) async {
    if (!widget.isToday) return;

    for (final nozzle in pump.nozzles) {
      final text = _openingFor(nozzle.id).text.trim();
      if (text.isEmpty) {
        _showError('${nozzle.label}: opening reading is required');
        return;
      }
      if (double.tryParse(text) == null) {
        _showError('${nozzle.label}: enter a valid number');
        return;
      }
    }

    setState(() => _savingOpening = true);
    try {
      final openLabel = widget.shiftType == 'morning' ? 'CP2' : 'CP3';
      final openTime = widget.shiftType == 'morning' ? '8:00 AM' : '7:00 PM';
      final openOrder = widget.shiftType == 'morning' ? 2 : 3;

      final openCp = await _ensureCheckpoint(
        existing: checkpoints,
        label: openLabel,
        time: openTime,
        order: openOrder,
      );

      final service = ref.read(nozzleReadingFirestoreServiceProvider);
      for (final nozzle in pump.nozzles) {
        final open = double.parse(_openingFor(nozzle.id).text.trim());
        final fuelTypeStr = nozzle.fuelType == FuelType.ms ? 'ms' : 'hsd';
        await service.saveReading(
          checkpointId: openCp.id,
          pumpId: pump.id,
          pumpName: pump.name,
          nozzleId: nozzle.id,
          nozzleLabel: nozzle.label,
          fuelType: fuelTypeStr,
          reading: open,
        );
      }
      _refreshShiftCollection();
      if (mounted) {
        setState(() => _editingResults = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening readings saved')));
      }
    } catch (_) {
      if (mounted) _showError('Could not save opening readings. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _savingOpening = false);
    }
  }

  Future<void> _saveClosing(
    PumpModel pump,
    List<CheckpointModel> checkpoints,
    Map<String, double> savedOpenings,
  ) async {
    if (!widget.isToday) return;

    for (final nozzle in pump.nozzles) {
      final text = _closingFor(nozzle.id).text.trim();
      if (text.isEmpty) {
        _showError('${nozzle.label}: closing reading is required');
        return;
      }
      final close = double.tryParse(text);
      if (close == null) {
        _showError('${nozzle.label}: enter a valid number');
        return;
      }
      // The opening fields are empty when the screen is reopened after the
      // opening was saved, so fall back to the saved opening reading.
      final openText = _openingFor(nozzle.id).text.trim();
      final open = double.tryParse(openText) ?? savedOpenings[nozzle.id];
      if (open != null && close < open) {
        _showError('${nozzle.label}: closing cannot be less than opening');
        return;
      }
    }

    setState(() => _savingClosing = true);
    try {
      final closeLabel = widget.shiftType == 'morning' ? 'CP3' : 'CP4';
      final closeTime = widget.shiftType == 'morning' ? '7:00 PM' : '6:00 AM (Next Day)';
      final closeOrder = widget.shiftType == 'morning' ? 3 : 4;

      final closeCp = await _ensureCheckpoint(
        existing: checkpoints,
        label: closeLabel,
        time: closeTime,
        order: closeOrder,
      );

      final service = ref.read(nozzleReadingFirestoreServiceProvider);
      for (final nozzle in pump.nozzles) {
        final close = double.parse(_closingFor(nozzle.id).text.trim());
        final fuelTypeStr = nozzle.fuelType == FuelType.ms ? 'ms' : 'hsd';
        await service.saveReading(
          checkpointId: closeCp.id,
          pumpId: pump.id,
          pumpName: pump.name,
          nozzleId: nozzle.id,
          nozzleLabel: nozzle.label,
          fuelType: fuelTypeStr,
          reading: close,
        );
      }
      _refreshShiftCollection();
      if (mounted) {
        setState(() => _editingResults = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Closing readings saved')));
      }
    } catch (_) {
      if (mounted) _showError('Could not save closing readings. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _savingClosing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final assignmentAsync = ref.watch(
      shiftAssignmentForStaffDateProvider((date: widget.date, staffId: widget.staffId)),
    );

    return assignmentAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      error: (err, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Error: $err')),
      data: (assignment) {
        if (assignment == null) {
          return _AssignPumpCard(date: widget.date, onAssign: _assignPump);
        }

        final pumpsAsync = ref.watch(pumpListProvider);
        final checkpointsAsync = ref.watch(checkpointsForDateProvider(widget.date));

        return pumpsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error: $err'),
          data: (pumps) {
            final pump = pumps.where((p) => p.id == assignment.pumpId).cast<PumpModel?>().firstOrNull;
            if (pump == null) return const Text('Assigned pump not found.');

            return checkpointsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
              data: (checkpoints) {
                final openTime = widget.shiftType == 'morning' ? '8:00 AM' : '7:00 PM';
                final closeTime = widget.shiftType == 'morning' ? '7:00 PM' : '6:00 AM (Next Day)';
                final openCp = _findCheckpoint(checkpoints, openTime);
                final closeCp = _findCheckpoint(checkpoints, closeTime);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Readings — ${pump.name}', style: theme.textTheme.titleMedium),
                            if (widget.isToday)
                              IconButton(
                                icon: Icon(_editingResults ? Icons.close : Icons.edit_outlined, size: 18),
                                tooltip: _editingResults ? 'Cancel edit' : 'Edit readings',
                                onPressed: () => setState(() => _editingResults = !_editingResults),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _ReadingsFlow(
                          pump: pump,
                          openCp: openCp,
                          closeCp: closeCp,
                          isToday: widget.isToday,
                          editing: _editingResults,
                          openingFor: _openingFor,
                          closingFor: _closingFor,
                          savingOpening: _savingOpening,
                          savingClosing: _savingClosing,
                          onSaveOpening: () => _saveOpening(pump, checkpoints),
                          onSaveClosing: (savedOpenings) => _saveClosing(pump, checkpoints, savedOpenings),
                        ),
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

class _AssignPumpCard extends ConsumerWidget {
  final String date;
  final Future<void> Function(PumpModel) onAssign;

  const _AssignPumpCard({required this.date, required this.onAssign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pumpsAsync = ref.watch(pumpListProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Not assigned to a pump for $date', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            pumpsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (err, _) => Text('Error: $err'),
              data: (pumps) {
                final active = pumps.where((p) => p.status == PumpStatus.active).toList();
                if (active.isEmpty) return const Text('No active pumps.');
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: active.map((pump) {
                    return ActionChip(label: Text(pump.name), onPressed: () => onAssign(pump));
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Handles the three states: opening not yet entered, opening entered
/// but closing not yet done, and both entered (shows results or edit form).
class _ReadingsFlow extends ConsumerWidget {
  final PumpModel pump;
  final CheckpointModel? openCp;
  final CheckpointModel? closeCp;
  final bool isToday;
  final bool editing;
  final TextEditingController Function(String) openingFor;
  final TextEditingController Function(String) closingFor;
  final bool savingOpening;
  final bool savingClosing;
  final VoidCallback onSaveOpening;
  final void Function(Map<String, double> savedOpenings) onSaveClosing;

  const _ReadingsFlow({
    required this.pump,
    required this.openCp,
    required this.closeCp,
    required this.isToday,
    required this.editing,
    required this.openingFor,
    required this.closingFor,
    required this.savingOpening,
    required this.savingClosing,
    required this.onSaveOpening,
    required this.onSaveClosing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (openCp == null) {
      return _OpeningForm(
        pump: pump,
        openingFor: openingFor,
        saving: savingOpening,
        onSave: onSaveOpening,
        isToday: isToday,
      );
    }

    final openReadingsAsync = ref.watch(readingsForCheckpointProvider(openCp!.id));

    return openReadingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error: $err'),
      data: (openReadings) {
        // Filter by pumpId too — nozzle ids repeat across pumps.
        final openForThisPump = openReadings.where((r) => r.pumpId == pump.id).toList();
        final openMap = {for (final r in openForThisPump) r.nozzleId: r.reading};
        final hasAllOpenings = pump.nozzles.every((n) => openMap.containsKey(n.id));

        if (!hasAllOpenings) {
          return _OpeningForm(
            pump: pump,
            openingFor: openingFor,
            saving: savingOpening,
            onSave: onSaveOpening,
            prefill: openMap,
            isToday: isToday,
          );
        }

        if (closeCp == null) {
          if (isToday && !editing) {
            // Opening complete, closing not started, viewing today — go straight to closing form.
            return _ClosingForm(
              pump: pump,
              openMap: openMap,
              closingFor: closingFor,
              saving: savingClosing,
              onSave: () => onSaveClosing(openMap),
              isToday: isToday,
            );
          }
          return _ClosingForm(
            pump: pump,
            openMap: openMap,
            closingFor: closingFor,
            saving: savingClosing,
            onSave: () => onSaveClosing(openMap),
            isToday: isToday,
          );
        }

        final closeReadingsAsync = ref.watch(readingsForCheckpointProvider(closeCp!.id));

        return closeReadingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error: $err'),
          data: (closeReadings) {
            final closeForThisPump = closeReadings.where((r) => r.pumpId == pump.id).toList();
            final closeMap = {for (final r in closeForThisPump) r.nozzleId: r.reading};
            final hasAllClosings = pump.nozzles.every((n) => closeMap.containsKey(n.id));

            if (!hasAllClosings) {
              return _ClosingForm(
                pump: pump,
                openMap: openMap,
                closingFor: closingFor,
                saving: savingClosing,
                onSave: () => onSaveClosing(openMap),
                prefill: closeMap,
                isToday: isToday,
              );
            }

            // Both readings complete.
            if (isToday && editing) {
              // Owner chose to edit today's already-saved readings.
              return _EditBothForm(
                pump: pump,
                openMap: openMap,
                closeMap: closeMap,
                openingFor: openingFor,
                closingFor: closingFor,
                savingOpening: savingOpening,
                savingClosing: savingClosing,
                onSaveOpening: onSaveOpening,
                onSaveClosing: () => onSaveClosing(openMap),
              );
            }

            final pricesAsync = ref.watch(fuelPricesProvider);
            final prices = pricesAsync.value ?? {'hsd': 0.0, 'ms': 0.0};
            double hsdLitres = 0, msLitres = 0;
            final rows = <Widget>[];

            for (final nozzle in pump.nozzles) {
              final open = openMap[nozzle.id]!;
              final close = closeMap[nozzle.id]!;
              final litres = close - open;
              if (nozzle.fuelType == FuelType.hsd) {
                hsdLitres += litres;
              } else {
                msLitres += litres;
              }
              rows.add(Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${nozzle.label}: ${open.toStringAsFixed(2)} → ${close.toStringAsFixed(2)}  =  ${litres.toStringAsFixed(2)} L',
                  style: theme.textTheme.bodySmall,
                ),
              ));
            }

            final hsdValue = hsdLitres * (prices['hsd'] ?? 0);
            final msValue = msLitres * (prices['ms'] ?? 0);
            final total = hsdValue + msValue;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...rows,
                const Divider(height: 20),
                Text('HSD: ${hsdLitres.toStringAsFixed(2)} L  =  ₹${hsdValue.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall),
                Text('MS: ${msLitres.toStringAsFixed(2)} L  =  ₹${msValue.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Text('Total Sale Value: ₹${total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (!isToday) ...[
                  const SizedBox(height: 8),
                  Text('Locked — past readings cannot be edited', style: theme.textTheme.bodySmall),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// Shown when the owner taps edit on today's already-complete readings.
/// Both opening and closing fields are shown together, pre-filled, and
/// either Save button re-saves that half independently.
class _EditBothForm extends StatelessWidget {
  final PumpModel pump;
  final Map<String, double> openMap;
  final Map<String, double> closeMap;
  final TextEditingController Function(String) openingFor;
  final TextEditingController Function(String) closingFor;
  final bool savingOpening;
  final bool savingClosing;
  final VoidCallback onSaveOpening;
  final VoidCallback onSaveClosing;

  const _EditBothForm({
    required this.pump,
    required this.openMap,
    required this.closeMap,
    required this.openingFor,
    required this.closingFor,
    required this.savingOpening,
    required this.savingClosing,
    required this.onSaveOpening,
    required this.onSaveClosing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Editing today\'s readings', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 10),
        ...pump.nozzles.map((nozzle) {
          final openCtrl = openingFor(nozzle.id);
          final closeCtrl = closingFor(nozzle.id);
          if (openCtrl.text.isEmpty && openMap.containsKey(nozzle.id)) {
            openCtrl.text = openMap[nozzle.id]!.toStringAsFixed(2);
          }
          if (closeCtrl.text.isEmpty && closeMap.containsKey(nozzle.id)) {
            closeCtrl.text = closeMap[nozzle.id]!.toStringAsFixed(2);
          }
          final isHsd = nozzle.fuelType == FuelType.hsd;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${nozzle.label} (${isHsd ? 'HSD' : 'MS'})', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: openCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Opening',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: closeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Closing',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: savingOpening ? null : onSaveOpening,
                child: savingOpening
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Opening'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: savingClosing ? null : onSaveClosing,
                child: savingClosing
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Closing'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OpeningForm extends StatelessWidget {
  final PumpModel pump;
  final TextEditingController Function(String) openingFor;
  final bool saving;
  final VoidCallback onSave;
  final bool isToday;
  final Map<String, double>? prefill;

  const _OpeningForm({
    required this.pump,
    required this.openingFor,
    required this.saving,
    required this.onSave,
    required this.isToday,
    this.prefill,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isToday ? 'Enter opening readings' : 'Opening readings incomplete — locked (past date)',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        ...pump.nozzles.map((nozzle) {
          final ctrl = openingFor(nozzle.id);
          if (prefill != null && prefill!.containsKey(nozzle.id) && ctrl.text.isEmpty) {
            ctrl.text = prefill![nozzle.id]!.toStringAsFixed(2);
          }
          final isHsd = nozzle.fuelType == FuelType.hsd;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: ctrl,
              enabled: isToday,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${nozzle.label} (${isHsd ? 'HSD' : 'MS'}) — Opening',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        if (isToday)
          ElevatedButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Opening'),
          ),
      ],
    );
  }
}

class _ClosingForm extends StatelessWidget {
  final PumpModel pump;
  final Map<String, double> openMap;
  final TextEditingController Function(String) closingFor;
  final bool saving;
  final VoidCallback onSave;
  final bool isToday;
  final Map<String, double>? prefill;

  const _ClosingForm({
    required this.pump,
    required this.openMap,
    required this.closingFor,
    required this.saving,
    required this.onSave,
    required this.isToday,
    this.prefill,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isToday
              ? 'Opening readings saved. Enter closing readings.'
              : 'Closing readings incomplete — locked (past date)',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        ...pump.nozzles.map((nozzle) {
          final ctrl = closingFor(nozzle.id);
          if (prefill != null && prefill!.containsKey(nozzle.id) && ctrl.text.isEmpty) {
            ctrl.text = prefill![nozzle.id]!.toStringAsFixed(2);
          }
          final isHsd = nozzle.fuelType == FuelType.hsd;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: ctrl,
              enabled: isToday,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    '${nozzle.label} (${isHsd ? 'HSD' : 'MS'}) — Closing (opening: ${openMap[nozzle.id]?.toStringAsFixed(2)})',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        if (isToday)
          ElevatedButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Closing'),
          ),
      ],
    );
  }
}