import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/daily_expense_model.dart';

/// One document per date in `daily_expenses`, holding the loops sales,
/// testing litres and other expenses for that day. Each tab saves only its
/// own field (merge) so the three tabs never overwrite each other.
class DailyExpenseFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref => _db.collection('daily_expenses');

  Future<void> _merge(String date, Map<String, dynamic> fields) async {
    await _ref.doc(date).set({
      'date': date,
      ...fields,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> saveLoops(String date, List<ExpenseItem> loops) =>
      _merge(date, {'loops': loops.map((i) => i.toMap()).toList()});

  Future<void> saveTesting(String date, {required double hsdLitres, required double msLitres}) =>
      _merge(date, {'testingHsdLitres': hsdLitres, 'testingMsLitres': msLitres});

  Future<void> saveOtherExpenses(String date, List<ExpenseItem> expenses) =>
      _merge(date, {'otherExpenses': expenses.map((i) => i.toMap()).toList()});

  Future<DailyExpenseModel?> getForDate(String date) async {
    final doc = await _ref.doc(date).get();
    if (!doc.exists) return null;
    return DailyExpenseModel.fromMap(doc.id, doc.data()!);
  }

  Stream<DailyExpenseModel?> watchForDate(String date) {
    return _ref.doc(date).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DailyExpenseModel.fromMap(doc.id, doc.data()!);
    });
  }
}
