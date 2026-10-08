// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/theme_provider.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/firestore/fuel_price_provider.dart';
import '../../models/dip_chart_model.dart';
import '../../services/firestore/dip_chart_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editRates(BuildContext context, WidgetRef ref, Map<String, double> current) async {
    final hsdCtrl = TextEditingController(
      text: current['hsd'] == null || current['hsd'] == 0 ? '' : current['hsd'].toString(),
    );
    final msCtrl = TextEditingController(
      text: current['ms'] == null || current['ms'] == 0 ? '' : current['ms'].toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Fuel Rates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hsdCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'HSD Rate (₹/L)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'MS Rate (₹/L)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      // Empty means 0 (not set); anything else must be a valid, non-negative
      // number so a typo never silently wipes a saved rate.
      double? parse(String raw) {
        final text = raw.trim().replaceAll(',', '');
        if (text.isEmpty) return 0;
        final v = double.tryParse(text);
        return (v == null || v < 0) ? null : v;
      }

      final hsd = parse(hsdCtrl.text);
      final ms = parse(msCtrl.text);
      if (hsd == null || ms == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter valid fuel rates. Rates were not changed.')),
          );
        }
        return;
      }
      final service = ref.read(fuelPriceServiceProvider);
      try {
        await service.setPrices(hsd: hsd, ms: ms);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save fuel rates. Please try again.')),
          );
        }
      }
    }
  }

  Future<void> _seedDipCharts(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Up Dip Charts?'),
        content: const Text(
          'This loads the full calibration chart for both HSD and MS tanks. '
          'Only needs to be done once.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Set Up')),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = ref.read(dipChartFirestoreServiceProvider);
    try {
      await service.setChart('hsd', _standardTankChart);
      await service.setChart('ms', _standardTankChart);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load dip charts. Check your internet connection.')),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dip charts loaded for HSD and MS')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentMode = ref.watch(themeModeProvider);
    final pricesAsync = ref.watch(fuelPricesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Appearance', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Light (Latte)'),
                    value: ThemeMode.light,
                    groupValue: currentMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        ref.read(themeModeProvider.notifier).setMode(mode);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark (Mocha)'),
                    value: ThemeMode.dark,
                    groupValue: currentMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        ref.read(themeModeProvider.notifier).setMode(mode);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('System Default'),
                    value: ThemeMode.system,
                    groupValue: currentMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        ref.read(themeModeProvider.notifier).setMode(mode);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Fuel', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.currency_rupee_rounded, color: theme.colorScheme.primary),
                title: const Text('Fuel Rates'),
                subtitle: pricesAsync.when(
                  data: (prices) {
                    final hsd = prices['hsd'] ?? 0;
                    final ms = prices['ms'] ?? 0;
                    if (hsd == 0 && ms == 0) {
                      return const Text('Not set yet — tap to add');
                    }
                    return Text('HSD ₹${hsd.toStringAsFixed(2)}  ·  MS ₹${ms.toStringAsFixed(2)}');
                  },
                  loading: () => const Text('Loading...'),
                  error: (err, _) => const Text('Could not load rates'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _editRates(context, ref, pricesAsync.value ?? {'hsd': 0.0, 'ms': 0.0}),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.straighten_rounded, color: theme.colorScheme.primary),
                title: const Text('Set Up Dip Charts'),
                subtitle: const Text('One-time setup — loads calibration data for both tanks'),
                onTap: () => _seedDipCharts(context, ref),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                title: Text('Logout', style: TextStyle(color: theme.colorScheme.error)),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Log out?'),
                      content: const Text('You will need to sign in again to continue.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authServiceProvider).signOut();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final List<DipChartRow> _standardTankChart = [
  DipChartRow(cm: 1, volume: 11.97, diffPerMm: 1.20),
  DipChartRow(cm: 2, volume: 33.89, diffPerMm: 2.19),
  DipChartRow(cm: 3, volume: 62.22, diffPerMm: 2.83),
  DipChartRow(cm: 4, volume: 95.71, diffPerMm: 3.35),
  DipChartRow(cm: 5, volume: 133.61, diffPerMm: 3.79),
  DipChartRow(cm: 6, volume: 175.43, diffPerMm: 4.18),
  DipChartRow(cm: 7, volume: 220.80, diffPerMm: 4.54),
  DipChartRow(cm: 8, volume: 269.41, diffPerMm: 4.86),
  DipChartRow(cm: 9, volume: 321.05, diffPerMm: 5.16),
  DipChartRow(cm: 10, volume: 375.51, diffPerMm: 5.45),
  DipChartRow(cm: 11, volume: 432.63, diffPerMm: 5.71),
  DipChartRow(cm: 12, volume: 492.26, diffPerMm: 5.96),
  DipChartRow(cm: 13, volume: 554.27, diffPerMm: 6.20),
  DipChartRow(cm: 14, volume: 618.56, diffPerMm: 6.43),
  DipChartRow(cm: 15, volume: 685.03, diffPerMm: 6.65),
  DipChartRow(cm: 16, volume: 753.57, diffPerMm: 6.85),
  DipChartRow(cm: 17, volume: 824.11, diffPerMm: 7.05),
  DipChartRow(cm: 18, volume: 896.57, diffPerMm: 7.25),
  DipChartRow(cm: 19, volume: 970.88, diffPerMm: 7.43),
  DipChartRow(cm: 20, volume: 1046.97, diffPerMm: 7.61),
  DipChartRow(cm: 21, volume: 1124.79, diffPerMm: 7.78),
  DipChartRow(cm: 22, volume: 1204.28, diffPerMm: 7.95),
  DipChartRow(cm: 23, volume: 1285.38, diffPerMm: 8.11),
  DipChartRow(cm: 24, volume: 1368.04, diffPerMm: 8.27),
  DipChartRow(cm: 25, volume: 1452.22, diffPerMm: 8.42),
  DipChartRow(cm: 26, volume: 1537.87, diffPerMm: 8.56),
  DipChartRow(cm: 27, volume: 1624.95, diffPerMm: 8.71),
  DipChartRow(cm: 28, volume: 1713.41, diffPerMm: 8.85),
  DipChartRow(cm: 29, volume: 1803.22, diffPerMm: 8.98),
  DipChartRow(cm: 30, volume: 1894.35, diffPerMm: 9.11),
  DipChartRow(cm: 31, volume: 1986.75, diffPerMm: 9.24),
  DipChartRow(cm: 32, volume: 2080.39, diffPerMm: 9.36),
  DipChartRow(cm: 33, volume: 2175.24, diffPerMm: 9.49),
  DipChartRow(cm: 34, volume: 2271.27, diffPerMm: 9.60),
  DipChartRow(cm: 35, volume: 2368.44, diffPerMm: 9.72),
  DipChartRow(cm: 36, volume: 2466.74, diffPerMm: 9.83),
  DipChartRow(cm: 37, volume: 2566.12, diffPerMm: 9.94),
  DipChartRow(cm: 38, volume: 2666.57, diffPerMm: 10.04),
  DipChartRow(cm: 39, volume: 2768.05, diffPerMm: 10.15),
  DipChartRow(cm: 40, volume: 2870.54, diffPerMm: 10.25),
  DipChartRow(cm: 41, volume: 2974.02, diffPerMm: 10.35),
  DipChartRow(cm: 42, volume: 3078.46, diffPerMm: 10.44),
  DipChartRow(cm: 43, volume: 3183.83, diffPerMm: 10.54),
  DipChartRow(cm: 44, volume: 3290.12, diffPerMm: 10.63),
  DipChartRow(cm: 45, volume: 3397.31, diffPerMm: 10.72),
  DipChartRow(cm: 46, volume: 3505.36, diffPerMm: 10.81),
  DipChartRow(cm: 47, volume: 3614.26, diffPerMm: 10.89),
  DipChartRow(cm: 48, volume: 3723.99, diffPerMm: 10.97),
  DipChartRow(cm: 49, volume: 3834.53, diffPerMm: 11.05),
  DipChartRow(cm: 50, volume: 3945.86, diffPerMm: 11.13),
  DipChartRow(cm: 51, volume: 4057.96, diffPerMm: 11.21),
  DipChartRow(cm: 52, volume: 4170.80, diffPerMm: 11.28),
  DipChartRow(cm: 53, volume: 4284.38, diffPerMm: 11.36),
  DipChartRow(cm: 54, volume: 4398.67, diffPerMm: 11.43),
  DipChartRow(cm: 55, volume: 4513.65, diffPerMm: 11.50),
  DipChartRow(cm: 56, volume: 4629.31, diffPerMm: 11.57),
  DipChartRow(cm: 57, volume: 4745.63, diffPerMm: 11.63),
  DipChartRow(cm: 58, volume: 4862.59, diffPerMm: 11.70),
  DipChartRow(cm: 59, volume: 4980.18, diffPerMm: 11.76),
  DipChartRow(cm: 60, volume: 5098.38, diffPerMm: 11.82),
  DipChartRow(cm: 61, volume: 5217.17, diffPerMm: 11.88),
  DipChartRow(cm: 62, volume: 5336.53, diffPerMm: 11.94),
  DipChartRow(cm: 63, volume: 5456.46, diffPerMm: 11.99),
  DipChartRow(cm: 64, volume: 5576.94, diffPerMm: 12.05),
  DipChartRow(cm: 65, volume: 5697.94, diffPerMm: 12.10),
  DipChartRow(cm: 66, volume: 5819.46, diffPerMm: 12.15),
  DipChartRow(cm: 67, volume: 5941.48, diffPerMm: 12.20),
  DipChartRow(cm: 68, volume: 6063.98, diffPerMm: 12.25),
  DipChartRow(cm: 69, volume: 6186.96, diffPerMm: 12.30),
  DipChartRow(cm: 70, volume: 6310.39, diffPerMm: 12.34),
  DipChartRow(cm: 71, volume: 6434.26, diffPerMm: 12.39),
  DipChartRow(cm: 72, volume: 6558.56, diffPerMm: 12.43),
  DipChartRow(cm: 73, volume: 6683.28, diffPerMm: 12.47),
  DipChartRow(cm: 74, volume: 6808.39, diffPerMm: 12.51),
  DipChartRow(cm: 75, volume: 6933.89, diffPerMm: 12.55),
  DipChartRow(cm: 76, volume: 7059.77, diffPerMm: 12.59),
  DipChartRow(cm: 77, volume: 7186.00, diffPerMm: 12.62),
  DipChartRow(cm: 78, volume: 7312.58, diffPerMm: 12.66),
  DipChartRow(cm: 79, volume: 7439.49, diffPerMm: 12.69),
  DipChartRow(cm: 80, volume: 7566.72, diffPerMm: 12.72),
  DipChartRow(cm: 81, volume: 7694.26, diffPerMm: 12.75),
  DipChartRow(cm: 82, volume: 7822.09, diffPerMm: 12.78),
  DipChartRow(cm: 83, volume: 7950.20, diffPerMm: 12.81),
  DipChartRow(cm: 84, volume: 8078.58, diffPerMm: 12.84),
  DipChartRow(cm: 85, volume: 8207.21, diffPerMm: 12.86),
  DipChartRow(cm: 86, volume: 8336.09, diffPerMm: 12.89),
  DipChartRow(cm: 87, volume: 8465.20, diffPerMm: 12.91),
  DipChartRow(cm: 88, volume: 8594.52, diffPerMm: 12.93),
  DipChartRow(cm: 89, volume: 8724.05, diffPerMm: 12.95),
  DipChartRow(cm: 90, volume: 8853.77, diffPerMm: 12.97),
  DipChartRow(cm: 91, volume: 8983.68, diffPerMm: 12.99),
  DipChartRow(cm: 92, volume: 9113.75, diffPerMm: 13.01),
  DipChartRow(cm: 93, volume: 9243.97, diffPerMm: 13.02),
  DipChartRow(cm: 94, volume: 9374.34, diffPerMm: 13.04),
  DipChartRow(cm: 95, volume: 9504.85, diffPerMm: 13.05),
  DipChartRow(cm: 96, volume: 9635.47, diffPerMm: 13.06),
  DipChartRow(cm: 97, volume: 9766.20, diffPerMm: 13.07),
  DipChartRow(cm: 98, volume: 9897.02, diffPerMm: 13.08),
  DipChartRow(cm: 99, volume: 10027.93, diffPerMm: 13.09),
  DipChartRow(cm: 100, volume: 10158.91, diffPerMm: 13.10),
  DipChartRow(cm: 101, volume: 10289.95, diffPerMm: 13.10),
  DipChartRow(cm: 102, volume: 10421.04, diffPerMm: 13.11),
  DipChartRow(cm: 103, volume: 10552.16, diffPerMm: 13.11),
  DipChartRow(cm: 104, volume: 10683.31, diffPerMm: 13.11),
  DipChartRow(cm: 105, volume: 10814.47, diffPerMm: 13.12),
  DipChartRow(cm: 106, volume: 10945.62, diffPerMm: 13.12),
  DipChartRow(cm: 107, volume: 11076.77, diffPerMm: 13.11),
  DipChartRow(cm: 108, volume: 11207.89, diffPerMm: 13.11),
  DipChartRow(cm: 109, volume: 11338.98, diffPerMm: 13.11),
  DipChartRow(cm: 110, volume: 11470.02, diffPerMm: 13.10),
  DipChartRow(cm: 111, volume: 11601.00, diffPerMm: 13.10),
  DipChartRow(cm: 112, volume: 11731.91, diffPerMm: 13.09),
  DipChartRow(cm: 113, volume: 11862.73, diffPerMm: 13.08),
  DipChartRow(cm: 114, volume: 11993.46, diffPerMm: 13.07),
  DipChartRow(cm: 115, volume: 12124.08, diffPerMm: 13.06),
  DipChartRow(cm: 116, volume: 12254.59, diffPerMm: 13.05),
  DipChartRow(cm: 117, volume: 12384.96, diffPerMm: 13.04),
  DipChartRow(cm: 118, volume: 12515.18, diffPerMm: 13.02),
  DipChartRow(cm: 119, volume: 12645.26, diffPerMm: 13.01),
  DipChartRow(cm: 120, volume: 12775.16, diffPerMm: 12.99),
  DipChartRow(cm: 121, volume: 12904.88, diffPerMm: 12.97),
  DipChartRow(cm: 122, volume: 13034.41, diffPerMm: 12.95),
  DipChartRow(cm: 123, volume: 13163.73, diffPerMm: 12.93),
  DipChartRow(cm: 124, volume: 13292.84, diffPerMm: 12.91),
  DipChartRow(cm: 125, volume: 13421.72, diffPerMm: 12.89),
  DipChartRow(cm: 126, volume: 13550.35, diffPerMm: 12.86),
  DipChartRow(cm: 127, volume: 13678.73, diffPerMm: 12.84),
  DipChartRow(cm: 128, volume: 13806.84, diffPerMm: 12.81),
  DipChartRow(cm: 129, volume: 13934.67, diffPerMm: 12.78),
  DipChartRow(cm: 130, volume: 14062.21, diffPerMm: 12.75),
  DipChartRow(cm: 131, volume: 14189.44, diffPerMm: 12.72),
  DipChartRow(cm: 132, volume: 14316.35, diffPerMm: 12.69),
  DipChartRow(cm: 133, volume: 14442.93, diffPerMm: 12.66),
  DipChartRow(cm: 134, volume: 14569.16, diffPerMm: 12.62),
  DipChartRow(cm: 135, volume: 14695.04, diffPerMm: 12.59),
  DipChartRow(cm: 136, volume: 14820.54, diffPerMm: 12.55),
  DipChartRow(cm: 137, volume: 14945.65, diffPerMm: 12.51),
  DipChartRow(cm: 138, volume: 15070.37, diffPerMm: 12.47),
  DipChartRow(cm: 139, volume: 15194.67, diffPerMm: 12.43),
  DipChartRow(cm: 140, volume: 15318.54, diffPerMm: 12.39),
  DipChartRow(cm: 141, volume: 15441.97, diffPerMm: 12.34),
  DipChartRow(cm: 142, volume: 15564.95, diffPerMm: 12.30),
  DipChartRow(cm: 143, volume: 15687.45, diffPerMm: 12.25),
  DipChartRow(cm: 144, volume: 15809.47, diffPerMm: 12.20),
  DipChartRow(cm: 145, volume: 15930.99, diffPerMm: 12.15),
  DipChartRow(cm: 146, volume: 16051.99, diffPerMm: 12.10),
  DipChartRow(cm: 147, volume: 16172.47, diffPerMm: 12.05),
  DipChartRow(cm: 148, volume: 16292.40, diffPerMm: 11.99),
  DipChartRow(cm: 149, volume: 16411.76, diffPerMm: 11.94),
  DipChartRow(cm: 150, volume: 16530.55, diffPerMm: 11.88),
  DipChartRow(cm: 151, volume: 16648.75, diffPerMm: 11.82),
  DipChartRow(cm: 152, volume: 16766.34, diffPerMm: 11.76),
  DipChartRow(cm: 153, volume: 16883.30, diffPerMm: 11.70),
  DipChartRow(cm: 154, volume: 16999.62, diffPerMm: 11.63),
  DipChartRow(cm: 155, volume: 17115.28, diffPerMm: 11.57),
  DipChartRow(cm: 156, volume: 17230.26, diffPerMm: 11.50),
  DipChartRow(cm: 157, volume: 17344.55, diffPerMm: 11.43),
  DipChartRow(cm: 158, volume: 17458.13, diffPerMm: 11.36),
  DipChartRow(cm: 159, volume: 17570.97, diffPerMm: 11.28),
  DipChartRow(cm: 160, volume: 17683.07, diffPerMm: 11.21),
  DipChartRow(cm: 161, volume: 17794.40, diffPerMm: 11.13),
  DipChartRow(cm: 162, volume: 17904.94, diffPerMm: 11.05),
  DipChartRow(cm: 163, volume: 18014.67, diffPerMm: 10.97),
  DipChartRow(cm: 164, volume: 18123.57, diffPerMm: 10.89),
  DipChartRow(cm: 165, volume: 18231.62, diffPerMm: 10.81),
  DipChartRow(cm: 166, volume: 18338.81, diffPerMm: 10.72),
  DipChartRow(cm: 167, volume: 18445.10, diffPerMm: 10.63),
  DipChartRow(cm: 168, volume: 18550.47, diffPerMm: 10.54),
  DipChartRow(cm: 169, volume: 18654.91, diffPerMm: 10.44),
  DipChartRow(cm: 170, volume: 18758.39, diffPerMm: 10.35),
  DipChartRow(cm: 171, volume: 18860.88, diffPerMm: 10.25),
  DipChartRow(cm: 172, volume: 18962.36, diffPerMm: 10.15),
  DipChartRow(cm: 173, volume: 19062.81, diffPerMm: 10.04),
  DipChartRow(cm: 174, volume: 19162.19, diffPerMm: 9.94),
  DipChartRow(cm: 175, volume: 19260.49, diffPerMm: 9.83),
  DipChartRow(cm: 176, volume: 19357.66, diffPerMm: 9.72),
  DipChartRow(cm: 177, volume: 19453.69, diffPerMm: 9.60),
  DipChartRow(cm: 178, volume: 19548.54, diffPerMm: 9.49),
  DipChartRow(cm: 179, volume: 19642.18, diffPerMm: 9.36),
  DipChartRow(cm: 180, volume: 19734.58, diffPerMm: 9.24),
  DipChartRow(cm: 181, volume: 19825.71, diffPerMm: 9.11),
  DipChartRow(cm: 182, volume: 19915.52, diffPerMm: 8.98),
  DipChartRow(cm: 183, volume: 20003.98, diffPerMm: 8.85),
  DipChartRow(cm: 184, volume: 20091.06, diffPerMm: 8.71),
  DipChartRow(cm: 185, volume: 20176.71, diffPerMm: 8.56),
  DipChartRow(cm: 186, volume: 20260.89, diffPerMm: 8.42),
  DipChartRow(cm: 187, volume: 20343.55, diffPerMm: 8.27),
  DipChartRow(cm: 188, volume: 20424.65, diffPerMm: 8.11),
  DipChartRow(cm: 189, volume: 20504.14, diffPerMm: 7.95),
  DipChartRow(cm: 190, volume: 20581.96, diffPerMm: 7.78),
  DipChartRow(cm: 191, volume: 20658.05, diffPerMm: 7.61),
  DipChartRow(cm: 192, volume: 20732.36, diffPerMm: 7.43),
  DipChartRow(cm: 193, volume: 20804.82, diffPerMm: 7.25),
  DipChartRow(cm: 194, volume: 20875.36, diffPerMm: 7.05),
  DipChartRow(cm: 195, volume: 20943.91, diffPerMm: 6.85),
  DipChartRow(cm: 196, volume: 21010.37, diffPerMm: 6.65),
  DipChartRow(cm: 197, volume: 21074.66, diffPerMm: 6.43),
  DipChartRow(cm: 198, volume: 21136.67, diffPerMm: 6.20),
  DipChartRow(cm: 199, volume: 21196.30, diffPerMm: 5.96),
  DipChartRow(cm: 200, volume: 21253.42, diffPerMm: 5.71),
  DipChartRow(cm: 201, volume: 21307.88, diffPerMm: 5.45),
  DipChartRow(cm: 202, volume: 21359.52, diffPerMm: 5.16),
  DipChartRow(cm: 203, volume: 21408.13, diffPerMm: 4.86),
  DipChartRow(cm: 204, volume: 21453.50, diffPerMm: 4.54),
  DipChartRow(cm: 205, volume: 21495.32, diffPerMm: 4.18),
  DipChartRow(cm: 206, volume: 21533.22, diffPerMm: 3.79),
  DipChartRow(cm: 207, volume: 21566.71, diffPerMm: 3.35),
  DipChartRow(cm: 208, volume: 21595.04, diffPerMm: 2.83),
  DipChartRow(cm: 209, volume: 21616.96, diffPerMm: 2.19),
  DipChartRow(cm: 210, volume: 21628.93, diffPerMm: 1.20),
];