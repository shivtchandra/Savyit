// lib/models/transaction.dart
class Transaction {
  final String id;
  final String merchant;
  final String category;
  final String bank;
  final String? account; // last 4 digits
  final double amount;
  final DateTime date;
  final String type; // 'credit' | 'debit'
  final String raw;
  /// True when auto-categorization fell back to [Other] (or unknown); user should pick a sector.
  final bool categoryNeedsReview;

  Transaction({
    required this.id,
    required this.merchant,
    required this.category,
    required this.bank,
    this.account,
    required this.amount,
    required this.date,
    required this.type,
    required this.raw,
    this.categoryNeedsReview = false,
  });

  Transaction copyWith({
    String? id,
    String? merchant,
    String? category,
    String? bank,
    String? account,
    double? amount,
    DateTime? date,
    String? type,
    String? raw,
    bool? categoryNeedsReview,
  }) {
    return Transaction(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      bank: bank ?? this.bank,
      account: account ?? this.account,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      raw: raw ?? this.raw,
      categoryNeedsReview: categoryNeedsReview ?? this.categoryNeedsReview,
    );
  }

  bool get isCredit => type == 'credit';
  bool get isDebit => type == 'debit';

  /// Unique key for deduplication: merchant + amount + date (truncated to day)
  String get uniqueKey {
    final day = '${date.year}-${date.month}-${date.day}';
    return '${merchant.trim().toLowerCase()}_${amount.toStringAsFixed(2)}_${day}_$type';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchant': merchant,
        'category': category,
        'bank': bank,
        'account': account,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type,
        'raw': raw,
        'categoryNeedsReview': categoryNeedsReview,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id']?.toString() ?? '',
        merchant: json['merchant']?.toString() ?? 'Unknown',
        category: json['category']?.toString() ?? 'Other',
        bank: json['bank']?.toString() ?? 'Unknown',
        account: json['account']?.toString(),
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        type: json['type']?.toString() ?? 'debit',
        raw: json['raw']?.toString() ?? '',
        categoryNeedsReview: json['categoryNeedsReview'] == true,
      );
}
