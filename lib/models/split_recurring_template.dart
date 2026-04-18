enum SplitRecurringFrequency { weekly, monthly }

class SplitRecurringTemplate {
  final String id;
  final String title;
  final double amount;
  final String paidByPersonId;
  final Map<String, double> participantWeights;
  final SplitRecurringFrequency frequency;
  final DateTime startDate;
  final DateTime nextRunAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? pauseReason;

  const SplitRecurringTemplate({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidByPersonId,
    required this.participantWeights,
    required this.frequency,
    required this.startDate,
    required this.nextRunAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.pauseReason,
  });

  SplitRecurringTemplate copyWith({
    String? id,
    String? title,
    double? amount,
    String? paidByPersonId,
    Map<String, double>? participantWeights,
    SplitRecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? nextRunAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? pauseReason,
    bool clearPauseReason = false,
  }) {
    return SplitRecurringTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paidByPersonId: paidByPersonId ?? this.paidByPersonId,
      participantWeights: participantWeights ?? this.participantWeights,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pauseReason: clearPauseReason ? null : (pauseReason ?? this.pauseReason),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'paidByPersonId': paidByPersonId,
        'participantWeights': participantWeights,
        'frequency': frequency.name,
        'startDate': startDate.toIso8601String(),
        'nextRunAt': nextRunAt.toIso8601String(),
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pauseReason': pauseReason,
      };

  factory SplitRecurringTemplate.fromJson(Map<String, dynamic> json) {
    final rawWeights =
        Map<String, dynamic>.from((json['participantWeights'] as Map?) ?? {});
    final weights = rawWeights.map((key, value) {
      return MapEntry(key, (value as num?)?.toDouble() ?? 0);
    });

    final frequencyRaw = json['frequency']?.toString() ?? 'monthly';
    final frequency = frequencyRaw == SplitRecurringFrequency.weekly.name
        ? SplitRecurringFrequency.weekly
        : SplitRecurringFrequency.monthly;

    final now = DateTime.now();
    return SplitRecurringTemplate(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paidByPersonId: json['paidByPersonId']?.toString() ?? '',
      participantWeights: weights,
      frequency: frequency,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? now,
      nextRunAt: DateTime.tryParse(json['nextRunAt']?.toString() ?? '') ?? now,
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
      pauseReason: json['pauseReason']?.toString(),
    );
  }
}
