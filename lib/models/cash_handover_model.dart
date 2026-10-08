class CashHandoverModel {
  final String id;
  final String staffId;
  final String staffName;
  final String date; // yyyy-MM-dd

  /// Hand-cash given to the staff member after the shift. Stored under the
  /// legacy `amount` field so older records keep working.
  final double amount;

  /// Money transferred to the staff member online (UPI / bank) after the shift.
  final double onlineAmount;

  CashHandoverModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.date,
    required this.amount,
    this.onlineAmount = 0,
  });

  /// Total handed over across both channels — this is what gets subtracted
  /// from the shift's fuel collection.
  double get totalGiven => amount + onlineAmount;

  factory CashHandoverModel.fromMap(String id, Map<String, dynamic> map) {
    return CashHandoverModel(
      id: id,
      staffId: map['staffId'] as String? ?? '',
      staffName: map['staffName'] as String? ?? '',
      date: map['date'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      onlineAmount: (map['onlineAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'date': date,
      'amount': amount,
      'onlineAmount': onlineAmount,
    };
  }
}
