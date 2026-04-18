import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:money_lens/models/date_range_option.dart';
import 'package:money_lens/providers/transaction_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'homeRecentVisible is canonical latest-first regardless of insertion order',
      () {
    final provider = TransactionProvider();
    final now = DateTime.now();

    provider.setRange(DateRangeOption.allTime);

    provider.addManualTransaction(
      merchant: 'Older txn',
      amount: 10,
      type: 'debit',
      category: 'Other',
      bank: 'Bank A',
      date: now.subtract(const Duration(days: 3)),
    );
    provider.addManualTransaction(
      merchant: 'Newest txn',
      amount: 20,
      type: 'debit',
      category: 'Other',
      bank: 'Bank A',
      date: now.subtract(const Duration(days: 1)),
    );
    provider.addManualTransaction(
      merchant: 'Middle txn',
      amount: 15,
      type: 'debit',
      category: 'Other',
      bank: 'Bank A',
      date: now.subtract(const Duration(days: 2)),
    );

    final recent = provider.homeRecentVisible;
    expect(recent.map((e) => e.merchant).toList(), [
      'Newest txn',
      'Middle txn',
      'Older txn',
    ]);
  });

  test('activityVisible respects range and active filters', () {
    final provider = TransactionProvider();
    final now = DateTime.now();

    provider.addManualTransaction(
      merchant: 'Very old cafe',
      amount: 99,
      type: 'debit',
      category: 'Food & Dining',
      bank: 'Axis Bank',
      date: now.subtract(const Duration(days: 20)),
    );
    provider.addManualTransaction(
      merchant: 'Cafe recent',
      amount: 40,
      type: 'debit',
      category: 'Food & Dining',
      bank: 'Axis Bank',
      date: now.subtract(const Duration(days: 1)),
    );
    provider.addManualTransaction(
      merchant: 'Salary recent',
      amount: 2000,
      type: 'credit',
      category: 'Transfer',
      bank: 'SBI',
      date: now.subtract(const Duration(days: 2)),
    );

    provider.setRange(DateRangeOption.lastWeek);
    provider.setType('debit');
    provider.setSearch('cafe');

    final activity = provider.activityVisible;
    expect(activity.length, 1);
    expect(activity.first.merchant, 'Cafe recent');

    final homeRecent = provider.homeRecentVisible;
    expect(homeRecent.length, 2);
    expect(homeRecent.any((e) => e.merchant == 'Cafe recent'), isTrue);
    expect(homeRecent.any((e) => e.merchant == 'Salary recent'), isTrue);
    expect(homeRecent.any((e) => e.merchant == 'Very old cafe'), isFalse);
  });

  test('clearTransactionFilters resets search and chip filters', () {
    final provider = TransactionProvider();

    provider.setSearch('abc');
    provider.setType('debit');
    provider.setSector('Food & Dining');
    provider.setBank('Axis Bank');

    expect(provider.hasActiveTransactionFilters, isTrue);
    expect(provider.activeTransactionFilterCount, 4);

    provider.clearTransactionFilters();

    expect(provider.searchQuery, '');
    expect(provider.filterType, '');
    expect(provider.filterSector, '');
    expect(provider.filterBank, '');
    expect(provider.hasActiveTransactionFilters, isFalse);
    expect(provider.activeTransactionFilterCount, 0);
  });
}
