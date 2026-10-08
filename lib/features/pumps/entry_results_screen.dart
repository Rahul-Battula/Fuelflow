import 'package:flutter/material.dart';

class EntryResultRow {
  final String pumpName;
  final String nozzleLabel;
  final String fuelType;
  final double opening;
  final double closing;
  final double litres;
  final double rate;
  final double revenue;

  EntryResultRow({
    required this.pumpName,
    required this.nozzleLabel,
    required this.fuelType,
    required this.opening,
    required this.closing,
    required this.litres,
    required this.rate,
    required this.revenue,
  });
}

class EntryResultsScreen extends StatelessWidget {
  final List<EntryResultRow> rows;

  const EntryResultsScreen({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalLitres = rows.fold<double>(0, (sum, r) => sum + r.litres);
    final totalRevenue = rows.fold<double>(0, (sum, r) => sum + r.revenue);

    return Scaffold(
      appBar: AppBar(title: const Text('Readings Saved')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Litres', style: TextStyle(color: theme.colorScheme.onPrimary)),
                        Text(
                          '${totalLitres.toStringAsFixed(2)} L',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Revenue', style: TextStyle(color: theme.colorScheme.onPrimary)),
                        Text(
                          '₹${totalRevenue.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Breakdown', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...rows.map((row) {
              final isHsd = row.fuelType == 'hsd';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${row.pumpName} · ${row.nozzleLabel}', style: theme.textTheme.titleMedium),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isHsd ? Colors.blue : Colors.green).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isHsd ? 'HSD' : 'MS',
                              style: TextStyle(fontSize: 11, color: isHsd ? Colors.blue : Colors.green),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _row(context, 'Opening', '${row.opening.toStringAsFixed(2)} L'),
                      _row(context, 'Closing', '${row.closing.toStringAsFixed(2)} L'),
                      _row(context, 'Litres Sold', '${row.litres.toStringAsFixed(2)} L'),
                      _row(context, 'Rate', '₹${row.rate.toStringAsFixed(2)}/L'),
                      _row(context, 'Revenue', '₹${row.revenue.toStringAsFixed(2)}', bold: true),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            value,
            style: bold
                ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
