import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/daily_expense_model.dart';
import '../../services/firestore/daily_expense_provider.dart';
import '../../services/firestore/fuel_price_provider.dart';

/// Daily Expenses portal for the 24-hour portal: three tabs —
/// Loops (added to revenue), Testing of HSD/MS (subtracted, litres × current
/// rate) and Other Expenses (subtracted).
class DailyExpensesScreen extends ConsumerStatefulWidget {
  const DailyExpensesScreen({super.key});

  @override
  ConsumerState<DailyExpensesScreen> createState() => _DailyExpensesScreenState();
}

class _DailyExpensesScreenState extends ConsumerState<DailyExpensesScreen> {
  DateTime _date = DateTime.now();

  String get _dateString =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _dateString;
    final expenseAsync = ref.watch(dailyExpenseForDateProvider(date));
    final prices = ref.watch(fuelPricesProvider).value ?? const {'hsd': 0.0, 'ms': 0.0};

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daily Expenses'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Loops', icon: Icon(Icons.oil_barrel_outlined)),
              Tab(text: 'Testing', icon: Icon(Icons.science_outlined)),
              Tab(text: 'Other Expenses', icon: Icon(Icons.payments_outlined)),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: InkWell(
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
                        Text('Date: $date'),
                        const Icon(Icons.calendar_today_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: expenseAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load expenses for $date. Check your internet connection.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => ref.invalidate(dailyExpenseForDateProvider(date)),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (model) {
                    final expenses = model ?? DailyExpenseModel.empty(date);
                    final service = ref.read(dailyExpenseFirestoreServiceProvider);
                    return Column(
                      children: [
                        _SummaryCard(expenses: expenses, prices: prices),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _ItemListTab(
                                key: ValueKey('loops_$date'),
                                items: expenses.loops,
                                emptyText: 'No loops added for this day.\nTap "Add Loop" to add 2T oil, engine oil, etc.',
                                addLabel: 'Add Loop',
                                nameLabel: 'Item (e.g. 2T Oil)',
                                suggestions: const ['2T Oil', 'Engine Oil', 'Distilled Water', 'Coolant', 'Grease'],
                                totalLabel: 'Total Loops (added to revenue)',
                                isAddition: true,
                                onSave: (items) => service.saveLoops(date, items),
                              ),
                              _TestingTab(
                                key: ValueKey('testing_$date'),
                                date: date,
                                initial: expenses,
                                prices: prices,
                              ),
                              _ItemListTab(
                                key: ValueKey('other_$date'),
                                items: expenses.otherExpenses,
                                emptyText: 'No other expenses for this day.\nTap "Add Expense" to add one.',
                                addLabel: 'Add Expense',
                                nameLabel: 'Description (e.g. Tea, Electricity)',
                                suggestions: const ['Tea / Snacks', 'Electricity', 'Repairs', 'Cleaning', 'Transport'],
                                totalLabel: 'Total Other Expenses (subtracted)',
                                isAddition: false,
                                onSave: (items) => service.saveOtherExpenses(date, items),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _rupees(double v) => '₹${v.toStringAsFixed(2)}';

class _SummaryCard extends StatelessWidget {
  final DailyExpenseModel expenses;
  final Map<String, double> prices;

  const _SummaryCard({required this.expenses, required this.prices});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = expenses.netAdjustment(prices);

    Widget line(String label, String value, {Color? color, bool bold = false}) {
      final style = (bold ? theme.textTheme.titleSmall : theme.textTheme.bodySmall)
          ?.copyWith(color: color, fontWeight: bold ? FontWeight.w700 : null);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label, style: style), Text(value, style: style)],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            line('Loops', '+ ${_rupees(expenses.loopsTotal)}', color: Colors.green),
            line('Testing (HSD + MS)', '− ${_rupees(expenses.testingValue(prices))}', color: theme.colorScheme.error),
            line('Other Expenses', '− ${_rupees(expenses.otherExpensesTotal)}', color: theme.colorScheme.error),
            const Divider(height: 12),
            line(
              'Net change to revenue',
              '${net < 0 ? '−' : '+'} ${_rupees(net.abs())}',
              bold: true,
              color: net < 0 ? theme.colorScheme.error : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of named amounts the owner can grow as much as he likes —
/// used for both Loops and Other Expenses. Every change saves the whole
/// list for the day.
class _ItemListTab extends StatefulWidget {
  final List<ExpenseItem> items;
  final String emptyText;
  final String addLabel;
  final String nameLabel;
  final List<String> suggestions;
  final String totalLabel;
  final bool isAddition;
  final Future<void> Function(List<ExpenseItem>) onSave;

  const _ItemListTab({
    super.key,
    required this.items,
    required this.emptyText,
    required this.addLabel,
    required this.nameLabel,
    required this.suggestions,
    required this.totalLabel,
    required this.isAddition,
    required this.onSave,
  });

  @override
  State<_ItemListTab> createState() => _ItemListTabState();
}

class _ItemListTabState extends State<_ItemListTab> {
  bool _saving = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _persist(List<ExpenseItem> items, String successMsg) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(items);
      _snack(successMsg);
    } catch (_) {
      _snack('Could not save. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Shows the add/edit dialog. Returns null when cancelled.
  Future<ExpenseItem?> _itemDialog({ExpenseItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2),
    );
    String? error;

    return showDialog<ExpenseItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? widget.addLabel : 'Edit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: widget.nameLabel),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 0,
                  children: widget.suggestions
                      .map((s) => ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setDialogState(() => nameCtrl.text = s),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Amount (₹)', errorText: error),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim());
                if (name.isEmpty) {
                  setDialogState(() => error = 'Enter a name');
                  return;
                }
                if (amount == null || amount <= 0) {
                  setDialogState(() => error = 'Enter an amount greater than 0');
                  return;
                }
                Navigator.pop(ctx, ExpenseItem(name: name, amount: amount));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    final item = await _itemDialog();
    if (item == null) return;
    await _persist([...widget.items, item], '${item.name} added');
  }

  Future<void> _edit(int index) async {
    final item = await _itemDialog(existing: widget.items[index]);
    if (item == null) return;
    final updated = [...widget.items]..[index] = item;
    await _persist(updated, '${item.name} updated');
  }

  Future<void> _delete(int index) async {
    final item = widget.items[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove "${item.name}" (${_rupees(item.amount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = [...widget.items]..removeAt(index);
    await _persist(updated, '${item.name} removed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.items;
    final total = items.fold<double>(0, (sum, i) => sum + i.amount);
    final amountColor = widget.isAddition ? Colors.green : theme.colorScheme.error;
    final sign = widget.isAddition ? '+' : '−';

    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(widget.emptyText, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text('$sign ${_rupees(item.amount)}', style: TextStyle(color: amountColor)),
                        onTap: _saving ? null : () => _edit(index),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          tooltip: 'Remove',
                          onPressed: _saving ? null : () => _delete(index),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(widget.totalLabel, style: theme.textTheme.bodySmall)),
                  Text(
                    '$sign ${_rupees(total)}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: amountColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _saving ? null : _add,
                icon: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_rounded),
                label: Text(widget.addLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// HSD and MS litres dispensed for testing. Their value (litres × current
/// rate) is subtracted from the day's revenue.
class _TestingTab extends ConsumerStatefulWidget {
  final String date;
  final DailyExpenseModel initial;
  final Map<String, double> prices;

  const _TestingTab({super.key, required this.date, required this.initial, required this.prices});

  @override
  ConsumerState<_TestingTab> createState() => _TestingTabState();
}

class _TestingTabState extends ConsumerState<_TestingTab> {
  late final TextEditingController _hsdCtrl;
  late final TextEditingController _msCtrl;
  bool _saving = false;

  String _initialText(double litres) => litres == 0 ? '' : litres.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _hsdCtrl = TextEditingController(text: _initialText(widget.initial.testingHsdLitres))
      ..addListener(_onChanged);
    _msCtrl = TextEditingController(text: _initialText(widget.initial.testingMsLitres))..addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _hsdCtrl.dispose();
    _msCtrl.dispose();
    super.dispose();
  }

  /// Empty means 0 litres; anything else must be a non-negative number.
  double? _parse(TextEditingController c) {
    final text = c.text.trim();
    if (text.isEmpty) return 0;
    final v = double.tryParse(text);
    return (v == null || v < 0) ? null : v;
  }

  Future<void> _save() async {
    final hsd = _parse(_hsdCtrl);
    final ms = _parse(_msCtrl);
    if (hsd == null || ms == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid litres (0 or more) for HSD and MS')),
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dailyExpenseFirestoreServiceProvider).saveTesting(widget.date, hsdLitres: hsd, msLitres: ms);
      messenger.showSnackBar(const SnackBar(content: Text('Testing litres saved')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Check your internet connection and try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fuelField(ThemeData theme, String label, TextEditingController ctrl, double rate) {
    final litres = _parse(ctrl);
    final amount = (litres ?? 0) * rate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '$label testing (litres)',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: litres == null ? 'Enter a valid number' : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(litres ?? 0).toStringAsFixed(2)} L × ${_rupees(rate)} = − ${_rupees(amount)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hsdRate = widget.prices['hsd'] ?? 0;
    final msRate = widget.prices['ms'] ?? 0;
    final total = (_parse(_hsdCtrl) ?? 0) * hsdRate + (_parse(_msCtrl) ?? 0) * msRate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (hsdRate == 0 || msRate == 0)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Fuel rates are not set. Set the HSD and MS rates in Settings so testing amounts are calculated.',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),
          ),
        _fuelField(theme, 'HSD (Diesel)', _hsdCtrl, hsdRate),
        _fuelField(theme, 'MS (Petrol)', _msCtrl, msRate),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Testing (subtracted)', style: theme.textTheme.bodySmall),
            Text(
              '− ${_rupees(total)}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.error),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Calculated at the current fuel rates.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Testing'),
        ),
      ],
    );
  }
}
