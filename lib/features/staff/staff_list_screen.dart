import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/staff_model.dart';
import '../../services/firestore/staff_provider.dart';
import 'add_staff_screen.dart';
import 'staff_detail_screen.dart';
import '../attendance/mark_attendance_screen.dart';
import 'shift_report_screen.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const StaffListScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  String _shiftType = 'morning';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Staff'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.event_available_rounded),
                  tooltip: 'Mark Attendance',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MarkAttendanceScreen()),
                    );
                  },
                ),
              ],
            )
          : null,
      body: SafeArea(
        top: !widget.showAppBar,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'morning',
                          label: Text('Morning Shift'),
                          icon: Icon(Icons.wb_sunny_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: 'night',
                          label: Text('Night Shift'),
                          icon: Icon(Icons.nightlight_outlined, size: 16),
                        ),
                      ],
                      selected: {_shiftType},
                      onSelectionChanged: (selection) => setState(() => _shiftType = selection.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    tooltip: '${_shiftType == 'morning' ? 'Morning' : 'Night'} Shift Report',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ShiftReportScreen(shiftType: _shiftType)),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: staffAsync.when(
                data: (staffList) {
                  final filtered = staffList.where((s) => s.shiftType == _shiftType).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No ${_shiftType == 'morning' ? 'morning' : 'night'} shift staff yet.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _StaffTile(staff: filtered[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading staff: $err')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddStaffScreen(initialShiftType: _shiftType)),
          );
        },
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final StaffModel staff;

  const _StaffTile({required this.staff});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = staff.localPhotoPath != null && File(staff.localPhotoPath!).existsSync();

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          backgroundImage: hasPhoto ? FileImage(File(staff.localPhotoPath!)) : null,
          child: !hasPhoto
              ? Text(
                  staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                )
              : null,
        ),
        title: Text(staff.name),
        subtitle: Text('${staff.position} \u00b7 ${staff.phone}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StaffDetailScreen(staff: staff)),
          );
        },
      ),
    );
  }
}