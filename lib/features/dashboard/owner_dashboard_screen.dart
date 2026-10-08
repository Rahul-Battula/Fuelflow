import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/cash_handover_model.dart';
import '../../models/daily_manager_reading_model.dart';
import '../../models/pump_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore/cash_handover_provider.dart';
import '../../services/firestore/daily_manager_reading_provider.dart';
import '../../services/firestore/daily_expense_provider.dart';
import '../../services/firestore/fuel_price_provider.dart';
import '../../services/firestore/staff_provider.dart';
import '../pumps/pumps_home_screen.dart';
import '../staff/staff_list_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/firestore/pump_provider.dart';
import '../../services/firestore/tank_provider.dart';

enum _DashTab { home, fuel, staff, settings }

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  final UserModel profile;

  const OwnerDashboardScreen({super.key, required this.profile});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  _DashTab _selectedTab = _DashTab.home;

  @override
  void initState() {
    super.initState();
    // Best-effort setup: when offline these fail and simply retry on the
    // next app start instead of surfacing an unhandled error.
    ref.read(pumpFirestoreServiceProvider).ensureDefaultPumps().catchError((_) {});
    ref.read(tankFirestoreServiceProvider).ensureDefaultTanks().catchError((_) {});
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case _DashTab.home:
        return _HomeContent(profile: widget.profile);
      case _DashTab.fuel:
        return const PumpsHomeScreen(embedded: true);
      case _DashTab.staff:
        return const StaffListScreen(showAppBar: false);
      case _DashTab.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _selectedTab == _DashTab.home
          ? AppBar(title: const Text('Dashboard'))
          : null,
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppTheme.latteSurface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppTheme.lattePrimary.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: _selectedTab == _DashTab.home,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedTab = _DashTab.home),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.access_time_filled_rounded,
                    label: '24-Hour',
                    isSelected: _selectedTab == _DashTab.fuel,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedTab = _DashTab.fuel),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.groups_rounded,
                    label: 'Staff',
                    isSelected: _selectedTab == _DashTab.staff,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedTab = _DashTab.staff),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isSelected: _selectedTab == _DashTab.settings,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedTab = _DashTab.settings),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  static const _activeColor = Color(0xFFE0A868);

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? _activeColor
        : (isDark ? Colors.white54 : AppTheme.latteText.withValues(alpha: 0.55));

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isSelected ? 1.15 : 1.0,
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  final UserModel profile;

  const _HomeContent({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final staffAsync = ref.watch(staffListProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          Text('Welcome back, ${profile.name.split(' ').first}', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Here\'s what\'s happening with your team', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          const _BusinessStatsSection(),
          const SizedBox(height: 28),
          Text('Team', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          staffAsync.when(
            data: (staffList) {
              final total = staffList.length;
              final active = staffList.where((s) => s.status.name == 'active').length;
              final inactive = total - active;

              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _StatCard(icon: Icons.groups_rounded, label: 'Total Staff', value: '$total'),
                  _StatCard(icon: Icons.check_circle_outline, label: 'Active', value: '$active'),
                  _StatCard(icon: Icons.block_rounded, label: 'Inactive', value: '$inactive'),
                  _StatCard(icon: Icons.history_rounded, label: 'Recent Activity', value: '$total'),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error: $err'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            Text(value, style: theme.textTheme.headlineSmall),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

String _todayDateString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// One day's revenue — fuel split by type (the delta between one daily
/// manager reading and the reading before it, priced at current rates) plus
/// the day's extras: loops − testing − other expenses (Daily Expenses).
/// [total] matches the 24-Hour Portal's Total Revenue for the same day.
class _DayRevenue {
  final String date;
  final double hsdValue;
  final double msValue;
  final double extras;

  const _DayRevenue({required this.date, required this.hsdValue, required this.msValue, this.extras = 0});

  double get fuelTotal => hsdValue + msValue;
  double get total => fuelTotal + extras;

  _DayRevenue withExtras(double extras) =>
      _DayRevenue(date: date, hsdValue: hsdValue, msValue: msValue, extras: extras);
}

_DayRevenue _computeDayRevenue(
  List<PumpModel> pumps,
  DailyManagerReadingModel current,
  DailyManagerReadingModel previous,
  Map<String, double> prices,
) {
  double hsdLitres = 0, msLitres = 0;
  for (final pump in pumps) {
    for (final nozzle in pump.nozzles) {
      final key = '${pump.id}_${nozzle.id}';
      final today = current.readings[key];
      final prev = previous.readings[key];
      if (today == null || prev == null) continue;
      final litres = today - prev;
      if (nozzle.fuelType == FuelType.hsd) {
        hsdLitres += litres;
      } else {
        msLitres += litres;
      }
    }
  }
  return _DayRevenue(
    date: current.date,
    hsdValue: hsdLitres * (prices['hsd'] ?? 0),
    msValue: msLitres * (prices['ms'] ?? 0),
  );
}

/// Formats a rupee amount with Indian-style digit grouping, e.g. 1,23,456.
String _formatInr(num value) {
  final rounded = value.round();
  final isNegative = rounded < 0;
  final digits = rounded.abs().toString();

  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return '${isNegative ? '-' : ''}₹$grouped';
}

/// A compact rupee amount for tight spaces, e.g. ₹1.2L / ₹8.4k.
String _shortInr(double value) {
  if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
  if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}k';
  return _formatInr(value);
}

/// Sales & collections overview: two headline stat tiles for today, plus a
/// short trend of recent daily sales. Reads from the same daily manager
/// reading + cash handover data the 24-Hour Portal and staff screens use.
class _BusinessStatsSection extends ConsumerWidget {
  const _BusinessStatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = _todayDateString();

    final pumpsAsync = ref.watch(pumpListProvider);
    final pricesAsync = ref.watch(fuelPricesProvider);
    final readingsAsync = ref.watch(recentManagerReadingsProvider(8));
    final handoversAsync = ref.watch(cashHandoversForDateProvider(today));

    final loading =
        pumpsAsync.isLoading || pricesAsync.isLoading || readingsAsync.isLoading || handoversAsync.isLoading;
    final hasError =
        pumpsAsync.hasError || pricesAsync.hasError || readingsAsync.hasError || handoversAsync.hasError;

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasError) {
      return Text('Could not load sales & collections data.', style: theme.textTheme.bodySmall);
    }

    final pumps = pumpsAsync.value ?? const <PumpModel>[];
    final prices = pricesAsync.value ?? const {'hsd': 0.0, 'ms': 0.0};
    final readings = [...(readingsAsync.value ?? const <DailyManagerReadingModel>[])]
      ..sort((a, b) => a.date.compareTo(b.date));
    final handovers = handoversAsync.value ?? const <CashHandoverModel>[];

    final trend = <_DayRevenue>[];
    for (var i = 1; i < readings.length; i++) {
      trend.add(_computeDayRevenue(pumps, readings[i], readings[i - 1], prices));
    }
    // Fold each day's loops, testing and other expenses into its revenue so
    // these figures match the 24-Hour Portal's Total Revenue.
    final recentTrend = (trend.length > 7 ? trend.sublist(trend.length - 7) : trend).map((day) {
      final expenses = ref.watch(dailyExpenseForDateProvider(day.date)).value;
      return day.withExtras(expenses?.netAdjustment(prices) ?? 0);
    }).toList();
    final todaySales = recentTrend.isNotEmpty && recentTrend.last.date == today ? recentTrend.last : null;

    final todaysCash = handovers.fold<double>(0, (sum, h) => sum + h.amount);
    final todaysOnline = handovers.fold<double>(0, (sum, h) => sum + h.onlineAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business Overview', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _HeroStatTile(
                icon: Icons.local_gas_station_rounded,
                label: "Today's Sales",
                value: _formatInr(todaySales?.total ?? 0),
                subtitle: todaySales == null
                    ? 'No reading yet today'
                    : todaySales.extras.round() != 0
                        ? 'Fuel ${_formatInr(todaySales.fuelTotal)} · Extras '
                            '${todaySales.extras < 0 ? '−' : '+'}${_formatInr(todaySales.extras.abs())}'
                        : 'HSD ${_formatInr(todaySales.hsdValue)} · MS ${_formatInr(todaySales.msValue)}',
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HeroStatTile(
                icon: Icons.account_balance_wallet_rounded,
                label: "Today's Collections",
                value: _formatInr(todaysCash + todaysOnline),
                subtitle: handovers.isNotEmpty
                    ? 'Cash ${_formatInr(todaysCash)} · Online ${_formatInr(todaysOnline)}'
                    : 'No handovers yet today',
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recentTrend.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'The sales trend will appear once at least two days of 24-hour '
                'readings are recorded.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else
          _SalesTrendCard(trend: recentTrend, today: today),
      ],
    );
  }
}

class _HeroStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _HeroStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesTrendCard extends StatelessWidget {
  final List<_DayRevenue> trend;
  final String today;

  const _SalesTrendCard({required this.trend, required this.today});

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _barMaxHeight = 110.0;

  String _weekdayLabel(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    return _weekdayLabels[parsed.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = trend.map((d) => d.total).fold<double>(0, (m, v) => v > m ? v : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales — Last ${trend.length} Day${trend.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in trend)
                  Expanded(
                    child: _TrendBar(
                      day: day,
                      isToday: day.date == today,
                      heightFraction: maxValue == 0 ? 0 : day.total / maxValue,
                      maxHeight: _barMaxHeight,
                      weekdayLabel: _weekdayLabel(day.date),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  final _DayRevenue day;
  final bool isToday;
  final double heightFraction;
  final double maxHeight;
  final String weekdayLabel;

  const _TrendBar({
    required this.day,
    required this.isToday,
    required this.heightFraction,
    required this.maxHeight,
    required this.weekdayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = isToday ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.35);
    final barHeight = (heightFraction * maxHeight).clamp(day.total > 0 ? 4.0 : 0.0, maxHeight);
    final isPeak = heightFraction >= 0.999 && day.total > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 16,
            child: isPeak
                ? Text(
                    _shortInr(day.total),
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 10),
                  )
                : null,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: barHeight,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isToday ? 'Today' : weekdayLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              color: isToday ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}