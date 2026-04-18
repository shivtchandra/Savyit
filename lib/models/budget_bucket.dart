class BudgetBucket {
  final String id;
  final String name;
  final double targetAmount;
  final DateTime createdAt;
  final List<String> transactionIds;

  const BudgetBucket({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.createdAt,
    required this.transactionIds,
  });

  BudgetBucket copyWith({
    String? id,
    String? name,
    double? targetAmount,
    DateTime? createdAt,
    List<String>? transactionIds,
  }) {
    return BudgetBucket(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      createdAt: createdAt ?? this.createdAt,
      transactionIds: transactionIds ?? this.transactionIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'createdAt': createdAt.toIso8601String(),
        'transactionIds': transactionIds,
      };

  factory BudgetBucket.fromJson(Map<String, dynamic> json) {
    return BudgetBucket(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Budget',
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      transactionIds: List<String>.from(json['transactionIds'] ?? const []),
    );
  }
}
