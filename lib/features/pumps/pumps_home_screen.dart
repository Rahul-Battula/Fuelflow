import 'package:flutter/material.dart';
import 'twenty_four_hour_tab.dart';
import 'twenty_four_hour_report_screen.dart';
import 'dip_entry_screen.dart';
import 'daily_expenses_screen.dart';

class PumpsHomeScreen extends StatelessWidget {
  final bool embedded;

  const PumpsHomeScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: const Text('24-Hour Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Daily Expenses',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailyExpensesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.straighten_rounded),
            tooltip: 'Dip Readings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DipEntryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: '24-Hour Report',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TwentyFourHourReportScreen()),
              );
            },
          ),
        ],
      ),
      body: const TwentyFourHourTab(),
    );
  }
}