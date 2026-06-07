class Expense {
  final String id;
  final DateTime date;
  final String? vendor;
  final String? category;
  final double amount;
  final String? receiptImageUrl; // data URL or remote URL

  Expense({
    required this.id,
    required this.date,
    required this.amount,
    this.vendor,
    this.category,
    this.receiptImageUrl,
  });

  bool get hasReceipt => receiptImageUrl != null && receiptImageUrl!.isNotEmpty;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['_id'] as String,
      date: DateTime.parse(json['date'] as String),
      vendor: json['vendor'] as String?,
      category: json['category'] as String?,
      amount: (json['amount'] as num).toDouble(),
      receiptImageUrl: json['receiptImageUrl'] as String?,
    );
  }
}
