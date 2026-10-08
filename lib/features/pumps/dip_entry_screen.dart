import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dip_entry_model.dart';
import '../../services/firestore/dip_chart_provider.dart';
import '../../services/firestore/dip_entry_provider.dart';

class DipEntryScreen extends ConsumerStatefulWidget {
  const DipEntryScreen({super.key});

  @override
  ConsumerState<DipEntryScreen> createState() => _DipEntryScreenState();
}

class _DipEntryScreenState extends ConsumerState<DipEntryScreen> {
  String _fuelType = 'hsd';
  final _dipController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _dipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _dipController.text.trim();
    if (text.isEmpty) {
      _showError('Enter a dip reading');
      return;
    }
    final dipCm = double.tryParse(text);
    if (dipCm == null) {
      _showError('Enter a valid number');
      return;
    }

    final fuelType = _fuelType;
    setState(() => _saving = true);
    try {
      final chart = await ref.read(dipChartFirestoreServiceProvider).getChart(fuelType);
      if (chart == null) {
        _showError('Dip chart not set up yet — go to Settings first');
        return;
      }

      final volume = chart.volumeForDip(dipCm);
      if (volume == null) {
        _showError('Dip value is outside the chart range');
        return;
      }

      final service = ref.read(dipEntryFirestoreServiceProvider);
      await service.addEntry(fuelType: fuelType, dipCm: dipCm, volumeLitres: volume);
      if (mounted) {
        _dipController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved: ${dipCm.toStringAsFixed(1)} cm = ${volume.toStringAsFixed(2)} L')),
        );
      }
    } catch (_) {
      _showError('Could not save dip reading. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editEntry(DipEntryModel entry) async {
    final ctrl = TextEditingController(text: entry.dipCm.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${entry.fuelType.toUpperCase()} Dip'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Dip (cm)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result != true) return;

    final newDip = double.tryParse(ctrl.text.trim());
    if (newDip == null) {
      _showError('Enter a valid number');
      return;
    }

    try {
      final chart = await ref.read(dipChartFirestoreServiceProvider).getChart(entry.fuelType);
      final newVolume = chart?.volumeForDip(newDip);
      if (newVolume == null) {
        _showError('Dip value is outside the chart range');
        return;
      }

      final service = ref.read(dipEntryFirestoreServiceProvider);
      await service.updateEntry(id: entry.id, dipCm: newDip, volumeLitres: newVolume);
    } catch (_) {
      _showError('Could not update dip reading. Check your internet connection and try again.');
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(dipHistoryForFuelProvider(_fuelType));

    return Scaffold(
      appBar: AppBar(title: const Text('Dip Readings')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'hsd', label: Text('HSD')),
                      ButtonSegment(value: 'ms', label: Text('MS')),
                    ],
                    selected: {_fuelType},
                    onSelectionChanged: (selection) => setState(() => _fuelType = selection.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _dipController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Dip Reading (cm)',
                      hintText: 'e.g. 45.5',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Dip Reading'),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('History — ${_fuelType.toUpperCase()}', style: theme.textTheme.titleMedium),
              ),
            ),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Text('No dip readings yet.', style: theme.textTheme.bodyMedium),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final dateStr = '${entry.recordedAt.day.toString().padLeft(2, '0')}/'
                          '${entry.recordedAt.month.toString().padLeft(2, '0')}/'
                          '${entry.recordedAt.year} '
                          '${entry.recordedAt.hour.toString().padLeft(2, '0')}:'
                          '${entry.recordedAt.minute.toString().padLeft(2, '0')}';
                      return Card(
                        child: ListTile(
                          title: Text('${entry.dipCm.toStringAsFixed(1)} cm  →  ${entry.volumeLitres.toStringAsFixed(2)} L'),
                          subtitle: Text(dateStr),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _editEntry(entry),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}