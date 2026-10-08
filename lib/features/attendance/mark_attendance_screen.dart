import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore/attendance_provider.dart';
import '../../services/firestore/staff_provider.dart';

class MarkAttendanceScreen extends ConsumerStatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  ConsumerState<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _dateString =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = _dateString;
    final staffAsync = ref.watch(staffListProvider);
    final attendanceAsync = ref.watch(attendanceForDateProvider(today));

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance · $today'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today_rounded), onPressed: _pickDate),
        ],
      ),
      body: staffAsync.when(
        data: (staffList) {
          final activeStaff = staffList.where((s) => s.status.name == 'active').toList();

          if (activeStaff.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No active staff to mark attendance for.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );
          }

          return attendanceAsync.when(
            data: (records) {
              final recordMap = {for (var r in records) r.staffId: r.present};

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: activeStaff.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final staff = activeStaff[index];
                  final isPresent = recordMap[staff.id];

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(staff.name),
                      subtitle: Text(staff.position),
                      trailing: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Present'), icon: Icon(Icons.check_rounded)),
                          ButtonSegment(value: false, label: Text('Absent'), icon: Icon(Icons.close_rounded)),
                        ],
                        selected: isPresent == null ? {} : {isPresent},
                        emptySelectionAllowed: true,
                        onSelectionChanged: (selection) async {
                          if (selection.isEmpty) return;
                          final service = ref.read(attendanceFirestoreServiceProvider);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await service.markAttendance(
                              staffId: staff.id,
                              staffName: staff.name,
                              date: today,
                              present: selection.first,
                            );
                          } catch (_) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Could not save attendance. Please try again.')),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading attendance: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading staff: $err')),
      ),
    );
  }
}