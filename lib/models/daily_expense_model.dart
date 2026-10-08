/// One named amount — a loops sale (2T oil, engine oil, distilled water…)
/// or an extra spending.
class ExpenseItem {
  final String name;
  final double amount;

  const ExpenseItem({required this.name, required this.amount});

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};
}

/// The owner's daily adjustments to the 24-hour portal's fuel revenue.
/// One document per date (the document id is the date).
///
/// - Loops sales are ADDED to the day's revenue.
/// - Testing litres (fuel dispensed for pump testing and returned to the
///   tank) are SUBTRACTED, valued at the current fuel rates — the same
///   rates the fuel revenue itself is calculated with.
/// - Other expenses are SUBTRACTED.
class DailyExpenseModel {
  final String date; // yyyy-MM-dd
  final List<ExpenseItem> loops;
  final double testingHsdLitres;
  final double testingMsLitres;
  final List<ExpenseItem> otherExpenses;
  final DateTime? updatedAt;

  const DailyExpenseModel({
    required this.date,
    this.loops = const [],
    this.testingHsdLitres = 0,
    this.testingMsLitres = 0,
    this.otherExpenses = const [],
    this.updatedAt,
  });

  factory DailyExpenseModel.empty(String date) => DailyExpenseModel(date: date);

  double get loopsTotal => loops.fold(0, (sum, i) => sum + i.amount);
  double get otherExpensesTotal => otherExpenses.fold(0, (sum, i) => sum + i.amount);

  double testingHsdValue(Map<String, double> prices) => testingHsdLitres * (prices['hsd'] ?? 0);
  double testingMsValue(Map<String, double> prices) => testingMsLitres * (prices['ms'] ?? 0);
  double testingValue(Map<String, double> prices) => testingHsdValue(prices) + testingMsValue(prices);

  /// Net change to the day's revenue: + loops − testing − other expenses.
  double netAdjustment(Map<String, double> prices) => loopsTotal - testingValue(prices) - otherExpensesTotal;

  bool get isEmpty =>
      loops.isEmpty && otherExpenses.isEmpty && testingHsdLitres == 0 && testingMsLitres == 0;

  static List<ExpenseItem> _itemsFrom(dynamic raw) {
    final list = raw as List<dynamic>? ?? [];
    return list.map((e) => ExpenseItem.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  factory DailyExpenseModel.fromMap(String date, Map<String, dynamic> map) {
    return DailyExpenseModel(
      date: date,
      loops: _itemsFrom(map['loops']),
      testingHsdLitres: (map['testingHsdLitres'] as num?)?.toDouble() ?? 0,
      testingMsLitres: (map['testingMsLitres'] as num?)?.toDouble() ?? 0,
      otherExpenses: _itemsFrom(map['otherExpenses']),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'loops': loops.map((i) => i.toMap()).toList(),
        'testingHsdLitres': testingHsdLitres,
        'testingMsLitres': testingMsLitres,
        'otherExpenses': otherExpenses.map((i) => i.toMap()).toList(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}
