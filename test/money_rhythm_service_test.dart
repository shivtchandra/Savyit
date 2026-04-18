import 'package:flutter_test/flutter_test.dart';
import 'package:money_lens/models/transaction.dart';
import 'package:money_lens/services/money_rhythm_service.dart';

Transaction _debit({
  required String id,
  required String category,
  required double amount,
  required DateTime date,
  String merchant = 'Test Cafe',
}) {
  return Transaction(
    id: id,
    merchant: merchant,
    category: category,
    bank: 'Test',
    amount: amount,
    date: date,
    type: 'debit',
    raw: '',
  );
}

void main() {
  test('empty / sparse data returns onboarding-style insight', () {
    final r = MoneyRhythmService.build(
      allTxns: [_debit(id: '1', category: 'Food & Dining', amount: 100, date: DateTime(2026, 4, 1))],
      sectorMonthlyLimits: {},
    );
    expect(r.insights, isNotEmpty);
    expect(r.insights.first.kind, RhythmInsightKind.needMoreData);
    expect(r.hasEnoughHistory, false);
  });

  test('projects over sector cap', () {
    final now = DateTime(2026, 4, 15);
    // 15 days elapsed, 3000 mtd -> ~6000 projected; cap 5000
    final txns = List.generate(5, (i) {
      return _debit(
        id: 'f$i',
        category: 'Food & Dining',
        amount: 600,
        date: DateTime(2026, 4, 2 + i),
      );
    });
    final r = MoneyRhythmService.build(
      allTxns: txns,
      sectorMonthlyLimits: {'Food & Dining': 5000},
      now: now,
    );
    final cap = r.insights.where((x) => x.kind == RhythmInsightKind.cap);
    expect(cap, isNotEmpty);
    expect(cap.first.headline, contains('Food & Dining'));
  });

  test('recurring-like stable amounts surface insight', () {
    final now = DateTime(2026, 4, 17);
    final txns = <Transaction>[
      _debit(
        id: 's1',
        category: 'Entertainment',
        amount: 649,
        date: DateTime(2026, 2, 5),
        merchant: 'NETFLIX INDIA',
      ),
      _debit(
        id: 's2',
        category: 'Entertainment',
        amount: 649,
        date: DateTime(2026, 3, 5),
        merchant: 'NETFLIX INDIA',
      ),
      _debit(
        id: 's3',
        category: 'Entertainment',
        amount: 649,
        date: DateTime(2026, 4, 5),
        merchant: 'NETFLIX INDIA',
      ),
      // pad history
      ...List.generate(
        12,
        (i) => _debit(
          id: 'p$i',
          category: 'Food & Dining',
          amount: 50,
          date: DateTime(2026, 1, 1 + i),
        ),
      ),
    ];
    final r = MoneyRhythmService.build(
      allTxns: txns,
      sectorMonthlyLimits: {},
      now: now,
    );
    final rec = r.insights.where((x) => x.kind == RhythmInsightKind.recurring);
    expect(rec, isNotEmpty);
  });
}
