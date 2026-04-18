import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'dart:math';
import '../models/transaction.dart';
import '../models/date_range_option.dart';
import '../models/budget_bucket.dart';
import '../models/split_person.dart';
import '../models/split_expense.dart';
import '../models/split_recurring_template.dart';
import '../models/split_settlement.dart';

import '../services/sms_service.dart';
import '../services/openai_service.dart';
import '../services/local_parser_service.dart';
import '../services/stats_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../utils/money_format.dart';
import '../services/engagement_notifications_service.dart';
import '../theme/app_theme.dart';
import '../widgets/manual_transaction_sheet.dart';

enum LoadState { idle, loading, loaded, permissionDenied, error }

enum PdfChunkMode { firstHalf, secondHalf, bothHalves }

class _PdfTextSegment {
  final String label;
  final String text;
  const _PdfTextSegment({required this.label, required this.text});
}

class TransactionProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  Stats _stats = StatsService.compute([]);
  LoadState _state = LoadState.idle;
  String? _error;
  String _userName = '';
  String _selectedCurrency = '₹';
  String _themeMode = 'pastel';
  bool _isInitialized = false;
  Map<String, double> _sectorMonthlyLimits = {};
  List<BudgetBucket> _budgetBuckets = [];
  List<SplitPerson> _splitPeople = [];
  List<SplitExpense> _splitExpenses = [];
  List<SplitRecurringTemplate> _splitRecurringTemplates = [];

  // Progress tracking

  int _progressCurrent = 0;
  int _progressTotal = 0;
  String _progressLabel = '';

  // Debug info — shown in app for troubleshooting
  String _debugInfo = '';

  // Date range selection
  DateRangeOption _rangeOption = DateRangeOption.lastWeek;
  DateTime? _customFrom;
  DateTime? _customTo;

  /// Bumped when the user should see a fresh buddy line (new txns, SMS merge, open app).
  int _buddyBubbleSignal = 0;
  int get buddyBubbleSignal => _buddyBubbleSignal;

  // Filters
  String _searchQuery = '';
  String _filterType = '';
  String _filterSector = '';
  String _filterBank = '';

  // ── Getters ─────────────────────────────────────────────────
  List<Transaction> get transactions => _transactions;

  /// Parsed as spend/income but only assigned the generic "Other" sector — needs user pick.
  List<Transaction> get transactionsNeedingCategoryReview =>
      _transactions.where((t) => t.categoryNeedsReview).toList();
  Stats get stats => _stats;
  LoadState get state => _state;
  String? get error => _error;
  DateRangeOption get rangeOption => _rangeOption;
  DateTime? get customFrom => _customFrom;
  DateTime? get customTo => _customTo;
  int get progressCurrent => _progressCurrent;
  int get progressTotal => _progressTotal;
  String get progressLabel => _progressLabel;
  String get debugInfo => _debugInfo;
  bool get isInitialized => _isInitialized;
  String get userName => _userName;
  String get selectedCurrency => _selectedCurrency;

  /// Display amounts using the user-selected currency symbol (Settings).
  String formatAmount(double val, {bool showSign = false}) =>
      formatMoneyAmount(val, _selectedCurrency, showSign: showSign);
  String get themeMode => _themeMode;
  bool get isMonochrome => _themeMode == 'monochrome';
  Map<String, double> get sectorMonthlyLimits =>
      Map.unmodifiable(_sectorMonthlyLimits);
  List<BudgetBucket> get budgetBuckets => List.unmodifiable(_budgetBuckets);
  List<SplitPerson> get splitPeople => List.unmodifiable(_splitPeople);
  List<SplitExpense> get splitExpenses => List.unmodifiable(_splitExpenses);
  List<SplitRecurringTemplate> get splitRecurringTemplates =>
      List.unmodifiable(_splitRecurringTemplates);
  SplitSettlementSummary get splitSummary => _buildSplitSummary();

  String get searchQuery => _searchQuery;

  String get filterType => _filterType;
  String get filterSector => _filterSector;
  String get filterBank => _filterBank;
  bool get hasActiveTransactionFilters =>
      _searchQuery.trim().isNotEmpty ||
      _filterType.isNotEmpty ||
      _filterSector.isNotEmpty ||
      _filterBank.isNotEmpty;
  int get activeTransactionFilterCount {
    var count = 0;
    if (_searchQuery.trim().isNotEmpty) count++;
    if (_filterType.isNotEmpty) count++;
    if (_filterSector.isNotEmpty) count++;
    if (_filterBank.isNotEmpty) count++;
    return count;
  }

  String get rangeLabel {
    if (_rangeOption == DateRangeOption.custom &&
        _customFrom != null &&
        _customTo != null) {
      final f = '${_customFrom!.day}/${_customFrom!.month}';
      final t = '${_customTo!.day}/${_customTo!.month}';
      return '$f – $t';
    }
    return _rangeOption.label;
  }

  List<Transaction> get filtered {
    return activityVisible;
  }

  List<Transaction> get historyFiltered {
    return _sortedTransactions(_transactions.where(_matchesActiveFilters));
  }

  List<Transaction> get activityVisible {
    final range =
        _rangeOption.resolve(customFrom: _customFrom, customTo: _customTo);
    return _sortedTransactions(_transactions.where((t) {
      if (t.date.isBefore(range[0]) || t.date.isAfter(range[1])) return false;
      return _matchesActiveFilters(t);
    }));
  }

  List<Transaction> get homeRecentVisible {
    final range =
        _rangeOption.resolve(customFrom: _customFrom, customTo: _customTo);
    return _sortedTransactions(_transactions.where((t) {
      return !t.date.isBefore(range[0]) && !t.date.isAfter(range[1]);
    }));
  }

  List<String> get availableSectors =>
      _transactions.map((t) => t.category).toSet().toList()..sort();
  List<String> get availableBanks =>
      _transactions.map((t) => t.bank).toSet().toList()..sort();

  double currentMonthSpendForSector(String sector, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    return _transactions
        .where((t) =>
            t.isDebit &&
            t.category == sector &&
            t.date.year == ref.year &&
            t.date.month == ref.month)
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  double? monthlyLimitForSector(String sector) {
    return _sectorMonthlyLimits[sector];
  }

  Future<void> setSectorMonthlyLimit(String sector, double amount) async {
    final cleanSector = sector.trim();
    if (cleanSector.isEmpty) return;

    if (amount <= 0) {
      _sectorMonthlyLimits.remove(cleanSector);
    } else {
      _sectorMonthlyLimits[cleanSector] = amount;
    }
    await StorageService.saveSectorMonthlyLimits(_sectorMonthlyLimits);
    notifyListeners();
  }

  Future<void> clearSectorMonthlyLimit(String sector) async {
    final cleanSector = sector.trim();
    if (!_sectorMonthlyLimits.containsKey(cleanSector)) return;
    _sectorMonthlyLimits.remove(cleanSector);
    await StorageService.saveSectorMonthlyLimits(_sectorMonthlyLimits);
    notifyListeners();
  }

  double spentForBucket(BudgetBucket bucket) {
    final selectedIds = bucket.transactionIds.toSet();
    return _transactions
        .where((t) => selectedIds.contains(t.id) && t.isDebit)
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  List<Transaction> transactionsForBucket(BudgetBucket bucket) {
    final map = {for (final t in _transactions) t.id: t};
    final list = <Transaction>[];
    for (final id in bucket.transactionIds) {
      final txn = map[id];
      if (txn != null) list.add(txn);
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  BudgetBucket? getBucketById(String bucketId) {
    for (final bucket in _budgetBuckets) {
      if (bucket.id == bucketId) return bucket;
    }
    return null;
  }

  Future<void> createBudgetBucket({
    required String name,
    required double targetAmount,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || targetAmount <= 0) return;

    final bucket = BudgetBucket(
      id: _generateId(prefix: 'bucket'),
      name: trimmedName,
      targetAmount: targetAmount,
      createdAt: DateTime.now(),
      transactionIds: const [],
    );
    _budgetBuckets = [bucket, ..._budgetBuckets];
    await StorageService.saveBudgetBuckets(_budgetBuckets);
    notifyListeners();
  }

  Future<void> updateBudgetBucket(BudgetBucket updated) async {
    final index = _budgetBuckets.indexWhere((b) => b.id == updated.id);
    if (index == -1) return;
    _budgetBuckets[index] = updated;
    await StorageService.saveBudgetBuckets(_budgetBuckets);
    notifyListeners();
  }

  Future<void> deleteBudgetBucket(String bucketId) async {
    final before = _budgetBuckets.length;
    _budgetBuckets.removeWhere((b) => b.id == bucketId);
    if (_budgetBuckets.length == before) return;
    await StorageService.saveBudgetBuckets(_budgetBuckets);
    notifyListeners();
  }

  Future<void> setBudgetBucketTransactions(
    String bucketId,
    List<String> transactionIds,
  ) async {
    final index = _budgetBuckets.indexWhere((b) => b.id == bucketId);
    if (index == -1) return;

    final allIds = _transactions.map((t) => t.id).toSet();
    final sanitized = transactionIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && allIds.contains(e))
        .toSet()
        .toList();

    _budgetBuckets[index] =
        _budgetBuckets[index].copyWith(transactionIds: sanitized);
    await StorageService.saveBudgetBuckets(_budgetBuckets);
    notifyListeners();
  }

  Future<void> removeTransactionFromBucket(
    String bucketId,
    String transactionId,
  ) async {
    final bucket = getBucketById(bucketId);
    if (bucket == null) return;
    final updatedIds = bucket.transactionIds.where((id) => id != transactionId);
    await setBudgetBucketTransactions(bucketId, updatedIds.toList());
  }

  Future<void> addSplitPerson(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (_splitPeople.any((p) => p.name.toLowerCase() == clean.toLowerCase())) {
      return;
    }

    _splitPeople = [
      ..._splitPeople,
      SplitPerson(
        id: _generateId(prefix: 'person', seed: clean),
        name: clean,
      ),
    ];
    _splitExpenses = _normalizeSplitExpenses(_splitExpenses, _splitPeople);
    await _saveSplitData();
  }

  Future<void> removeSplitPerson(String personId) async {
    final before = _splitPeople.length;
    _splitPeople = _splitPeople.where((p) => p.id != personId).toList();
    if (_splitPeople.length == before) return;
    _splitExpenses = _normalizeSplitExpenses(_splitExpenses, _splitPeople);
    _splitRecurringTemplates = _normalizeSplitRecurringTemplates(
        _splitRecurringTemplates, _splitPeople);
    await _saveSplitData();
  }

  Future<void> addSplitExpense({
    required String title,
    required double amount,
    required String paidByPersonId,
    required Map<String, double> participantWeights,
    String? sourceTemplateId,
    DateTime? occurrenceDate,
    bool isAutoGenerated = false,
    DateTime? createdAt,
  }) async {
    final expense = _buildValidatedSplitExpense(
      title: title,
      amount: amount,
      paidByPersonId: paidByPersonId,
      participantWeights: participantWeights,
      sourceTemplateId: sourceTemplateId,
      occurrenceDate: occurrenceDate,
      isAutoGenerated: isAutoGenerated,
      createdAt: createdAt,
    );
    if (expense == null) return;

    _splitExpenses = [expense, ..._splitExpenses];
    await _saveSplitData();
  }

  Future<void> removeSplitExpense(String expenseId) async {
    final before = _splitExpenses.length;
    _splitExpenses = _splitExpenses.where((e) => e.id != expenseId).toList();
    if (_splitExpenses.length == before) return;
    await _saveSplitData();
  }

  Future<void> clearSplitExpenses() async {
    _splitExpenses = [];
    await _saveSplitData();
  }

  Future<void> addRecurringTemplate({
    required String title,
    required double amount,
    required String paidByPersonId,
    required Map<String, double> participantWeights,
    required SplitRecurringFrequency frequency,
    required DateTime startDate,
  }) async {
    final cleanWeights = _validatedParticipantWeights(participantWeights);
    if (cleanWeights.isEmpty) return;
    if (!_splitPeople.any((p) => p.id == paidByPersonId)) return;
    if (amount <= 0) return;

    final cleanStart = _dateOnly(startDate);
    final now = DateTime.now();
    final template = SplitRecurringTemplate(
      id: _generateId(prefix: 'rsplit', seed: title),
      title: title.trim().isEmpty ? 'Recurring Shared Expense' : title.trim(),
      amount: amount.abs(),
      paidByPersonId: paidByPersonId,
      participantWeights: cleanWeights,
      frequency: frequency,
      startDate: cleanStart,
      nextRunAt: cleanStart,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    _splitRecurringTemplates = [template, ..._splitRecurringTemplates];
    await _saveSplitData();
  }

  Future<void> updateRecurringTemplateThisAndFuture({
    required String templateId,
    required DateTime effectiveFrom,
    String? title,
    double? amount,
    String? paidByPersonId,
    Map<String, double>? participantWeights,
    SplitRecurringFrequency? frequency,
  }) async {
    final index =
        _splitRecurringTemplates.indexWhere((t) => t.id == templateId);
    if (index == -1) return;

    final current = _splitRecurringTemplates[index];
    final now = DateTime.now();
    final effectiveDate = _dateOnly(effectiveFrom);

    final patchedPayer = paidByPersonId ?? current.paidByPersonId;
    if (!_splitPeople.any((p) => p.id == patchedPayer)) return;

    Map<String, double> patchedWeights = current.participantWeights;
    if (participantWeights != null) {
      patchedWeights = _validatedParticipantWeights(participantWeights);
      if (patchedWeights.isEmpty) return;
    }

    final patchedAmount = amount ?? current.amount;
    if (patchedAmount <= 0) return;

    final patchedFrequency = frequency ?? current.frequency;
    final patchedStart = current.startDate.isAfter(effectiveDate)
        ? current.startDate
        : effectiveDate;
    final patchedNext = _firstOccurrenceOnOrAfter(
      from: effectiveDate,
      startDate: patchedStart,
      frequency: patchedFrequency,
    );

    _splitExpenses = _splitExpenses.where((expense) {
      if (expense.sourceTemplateId != templateId) return true;
      final occurrence = expense.occurrenceDate;
      if (occurrence == null) return true;
      return occurrence.isBefore(effectiveDate);
    }).toList();

    _splitRecurringTemplates[index] = current.copyWith(
      title: title?.trim().isEmpty == true ? current.title : title?.trim(),
      amount: patchedAmount.abs(),
      paidByPersonId: patchedPayer,
      participantWeights: patchedWeights,
      frequency: patchedFrequency,
      startDate: patchedStart,
      nextRunAt: patchedNext,
      isActive: true,
      updatedAt: now,
      clearPauseReason: true,
    );

    await _saveSplitData();
  }

  Future<void> pauseRecurringTemplate(String templateId,
      {String? reason}) async {
    final index =
        _splitRecurringTemplates.indexWhere((t) => t.id == templateId);
    if (index == -1) return;
    _splitRecurringTemplates[index] = _splitRecurringTemplates[index].copyWith(
      isActive: false,
      pauseReason: reason,
      updatedAt: DateTime.now(),
    );
    await _saveSplitData();
  }

  Future<void> resumeRecurringTemplate(String templateId) async {
    final index =
        _splitRecurringTemplates.indexWhere((t) => t.id == templateId);
    if (index == -1) return;
    _splitRecurringTemplates[index] = _splitRecurringTemplates[index].copyWith(
      isActive: true,
      updatedAt: DateTime.now(),
      clearPauseReason: true,
    );
    await _saveSplitData();
  }

  Future<void> deleteRecurringTemplate(String templateId) async {
    final before = _splitRecurringTemplates.length;
    _splitRecurringTemplates =
        _splitRecurringTemplates.where((t) => t.id != templateId).toList();
    if (_splitRecurringTemplates.length == before) return;
    await _saveSplitData();
  }

  Future<void> runRecurringCatchUp(DateTime now) async {
    if (_splitRecurringTemplates.isEmpty) return;

    final cappedNow = _dateOnly(now);
    bool didChange = false;
    final updatedTemplates = <SplitRecurringTemplate>[];

    for (final template in _splitRecurringTemplates) {
      var working = template;
      if (!working.isActive) {
        updatedTemplates.add(working);
        continue;
      }

      final validationError = _validateTemplateIntegrity(working);
      if (validationError != null) {
        working = working.copyWith(
          isActive: false,
          pauseReason: validationError,
          updatedAt: DateTime.now(),
        );
        didChange = true;
        updatedTemplates.add(working);
        continue;
      }

      int generated = 0;
      var nextRun = _dateOnly(working.nextRunAt);
      while (!nextRun.isAfter(cappedNow) && generated < 24) {
        if (!_hasOccurrenceForTemplate(working.id, nextRun)) {
          final expense = _buildValidatedSplitExpense(
            title: working.title,
            amount: working.amount,
            paidByPersonId: working.paidByPersonId,
            participantWeights: working.participantWeights,
            sourceTemplateId: working.id,
            occurrenceDate: nextRun,
            isAutoGenerated: true,
            createdAt: nextRun,
          );
          if (expense == null) {
            working = working.copyWith(
              isActive: false,
              pauseReason:
                  'Paused: invalid payer/participants. Update this template.',
              updatedAt: DateTime.now(),
            );
            didChange = true;
            break;
          }
          _splitExpenses = [expense, ..._splitExpenses];
          didChange = true;
        }

        generated++;
        nextRun = _nextOccurrenceDate(
          current: nextRun,
          frequency: working.frequency,
          anchorDay: working.startDate.day,
        );
      }

      if (!isSameDay(nextRun, working.nextRunAt)) {
        working = working.copyWith(
          nextRunAt: nextRun,
          updatedAt: DateTime.now(),
        );
        didChange = true;
      }

      updatedTemplates.add(working);
    }

    if (!didChange) return;
    _splitExpenses = _normalizeSplitExpenses(_splitExpenses, _splitPeople);
    _splitRecurringTemplates = _normalizeSplitRecurringTemplates(
      updatedTemplates,
      _splitPeople,
    );
    await _saveSplitData();
  }

  List<SplitPerson> _normalizeSplitPeople(List<SplitPerson> input) {
    final normalized = <SplitPerson>[];
    final usedIds = <String>{};
    final usedNames = <String>{};

    for (final person in input) {
      final cleanName = person.name.trim();
      if (cleanName.isEmpty) continue;

      final nameKey = cleanName.toLowerCase();
      if (usedNames.contains(nameKey)) continue;

      var id = _sanitizeId(person.id);
      if (id.isEmpty || usedIds.contains(id)) {
        id = _generateId(prefix: 'person', seed: cleanName);
      }

      usedIds.add(id);
      usedNames.add(nameKey);
      normalized.add(SplitPerson(id: id, name: cleanName));
    }

    return normalized;
  }

  List<SplitExpense> _normalizeSplitExpenses(
    List<SplitExpense> input,
    List<SplitPerson> people,
  ) {
    final personIds = people.map((p) => p.id).toSet();
    if (personIds.isEmpty) return [];

    final normalized = <SplitExpense>[];
    final usedIds = <String>{};

    for (final expense in input) {
      if (expense.amount <= 0) continue;
      if (!personIds.contains(expense.paidByPersonId)) continue;

      final cleanWeights = <String, double>{};
      for (final entry in expense.participantWeights.entries) {
        if (!personIds.contains(entry.key)) continue;
        final weight = entry.value;
        if (weight <= 0) continue;
        cleanWeights[entry.key] = weight;
      }
      if (cleanWeights.isEmpty) continue;

      var id = _sanitizeId(expense.id);
      if (id.isEmpty || usedIds.contains(id)) {
        id = _generateId(prefix: 'split', seed: expense.title);
      }
      usedIds.add(id);

      normalized.add(
        expense.copyWith(
          id: id,
          title: expense.title.trim().isEmpty
              ? 'Shared Expense'
              : expense.title.trim(),
          amount: expense.amount.abs(),
          participantWeights: cleanWeights,
          occurrenceDate: expense.occurrenceDate != null
              ? _dateOnly(expense.occurrenceDate!)
              : null,
          sourceTemplateId: _sanitizeId(expense.sourceTemplateId).isEmpty
              ? null
              : _sanitizeId(expense.sourceTemplateId),
        ),
      );
    }

    normalized.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return normalized;
  }

  List<SplitRecurringTemplate> _normalizeSplitRecurringTemplates(
    List<SplitRecurringTemplate> input,
    List<SplitPerson> people,
  ) {
    final normalized = <SplitRecurringTemplate>[];
    final usedIds = <String>{};
    final personIds = people.map((p) => p.id).toSet();

    for (final template in input) {
      if (template.amount <= 0) continue;

      var id = _sanitizeId(template.id);
      if (id.isEmpty || usedIds.contains(id)) {
        id = _generateId(prefix: 'rsplit', seed: template.title);
      }
      usedIds.add(id);

      final cleanWeights = <String, double>{};
      for (final entry in template.participantWeights.entries) {
        if (entry.value <= 0) continue;
        cleanWeights[entry.key] = entry.value;
      }
      if (cleanWeights.isEmpty) continue;

      final hasMissingPayer = !personIds.contains(template.paidByPersonId);
      final hasMissingParticipant =
          cleanWeights.keys.any((personId) => !personIds.contains(personId));
      final pauseReason = hasMissingPayer || hasMissingParticipant
          ? 'Paused: member removed. Update participants to resume.'
          : template.pauseReason;

      normalized.add(
        template.copyWith(
          id: id,
          title: template.title.trim().isEmpty
              ? 'Recurring Shared Expense'
              : template.title.trim(),
          amount: template.amount.abs(),
          participantWeights: cleanWeights,
          startDate: _dateOnly(template.startDate),
          nextRunAt: _dateOnly(template.nextRunAt),
          pauseReason: pauseReason,
          isActive: pauseReason == null ? template.isActive : false,
        ),
      );
    }

    normalized.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return normalized;
  }

  SplitExpense? _buildValidatedSplitExpense({
    required String title,
    required double amount,
    required String paidByPersonId,
    required Map<String, double> participantWeights,
    String? sourceTemplateId,
    DateTime? occurrenceDate,
    required bool isAutoGenerated,
    DateTime? createdAt,
  }) {
    if (amount <= 0) return null;
    if (!_splitPeople.any((p) => p.id == paidByPersonId)) return null;

    final cleanWeights = _validatedParticipantWeights(participantWeights);
    if (cleanWeights.isEmpty) return null;

    final sourceId = _sanitizeId(sourceTemplateId);
    final date = occurrenceDate != null ? _dateOnly(occurrenceDate) : null;
    return SplitExpense(
      id: _generateId(prefix: 'split', seed: title),
      title: title.trim().isEmpty ? 'Shared Expense' : title.trim(),
      amount: amount.abs(),
      paidByPersonId: paidByPersonId,
      participantWeights: cleanWeights,
      createdAt: createdAt ?? DateTime.now(),
      sourceTemplateId: sourceId.isEmpty ? null : sourceId,
      occurrenceDate: date,
      isAutoGenerated: isAutoGenerated,
    );
  }

  Map<String, double> _validatedParticipantWeights(Map<String, double> input) {
    final peopleIds = _splitPeople.map((p) => p.id).toSet();
    final clean = <String, double>{};
    for (final entry in input.entries) {
      if (!peopleIds.contains(entry.key)) continue;
      if (entry.value <= 0) continue;
      clean[entry.key] = entry.value;
    }
    return clean;
  }

  String? _validateTemplateIntegrity(SplitRecurringTemplate template) {
    if (!_splitPeople.any((p) => p.id == template.paidByPersonId)) {
      return 'Paused: payer no longer exists.';
    }
    if (template.participantWeights.isEmpty) {
      return 'Paused: no participants left in template.';
    }
    final peopleIds = _splitPeople.map((p) => p.id).toSet();
    for (final entry in template.participantWeights.entries) {
      if (entry.value <= 0) return 'Paused: invalid participant weight.';
      if (!peopleIds.contains(entry.key)) {
        return 'Paused: one or more participants were removed.';
      }
    }
    return null;
  }

  bool _hasOccurrenceForTemplate(String templateId, DateTime occurrenceDate) {
    for (final expense in _splitExpenses) {
      if (expense.sourceTemplateId != templateId) continue;
      if (expense.occurrenceDate == null) continue;
      if (isSameDay(expense.occurrenceDate!, occurrenceDate)) return true;
    }
    return false;
  }

  DateTime _firstOccurrenceOnOrAfter({
    required DateTime from,
    required DateTime startDate,
    required SplitRecurringFrequency frequency,
  }) {
    var date = _dateOnly(startDate);
    final target = _dateOnly(from);
    if (!date.isBefore(target)) return date;
    while (date.isBefore(target)) {
      date = _nextOccurrenceDate(
        current: date,
        frequency: frequency,
        anchorDay: startDate.day,
      );
    }
    return date;
  }

  DateTime _nextOccurrenceDate({
    required DateTime current,
    required SplitRecurringFrequency frequency,
    required int anchorDay,
  }) {
    final cleanCurrent = _dateOnly(current);
    if (frequency == SplitRecurringFrequency.weekly) {
      return cleanCurrent.add(const Duration(days: 7));
    }

    final monthIndex = cleanCurrent.month + 1;
    final targetYear = cleanCurrent.year + ((monthIndex - 1) ~/ 12);
    final targetMonth = ((monthIndex - 1) % 12) + 1;
    final safeDay = _safeDayInMonth(targetYear, targetMonth, anchorDay);
    return DateTime(targetYear, targetMonth, safeDay);
  }

  int _safeDayInMonth(int year, int month, int desiredDay) {
    final firstDayNextMonth =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final lastDayThisMonth =
        firstDayNextMonth.subtract(const Duration(days: 1));
    return min(max(1, desiredDay), lastDayThisMonth.day);
  }

  DateTime _dateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _saveSplitData() async {
    await StorageService.saveSplitPeople(_splitPeople);
    await StorageService.saveSplitExpenses(_splitExpenses);
    await StorageService.saveSplitRecurringTemplates(_splitRecurringTemplates);
    notifyListeners();
  }

  SplitSettlementSummary _buildSplitSummary() {
    final netByPerson = <String, double>{
      for (final person in _splitPeople) person.id: 0,
    };

    double totalExpense = 0;

    for (final expense in _splitExpenses) {
      if (!netByPerson.containsKey(expense.paidByPersonId)) continue;
      if (expense.amount <= 0) continue;

      final activeWeights = <String, double>{};
      for (final entry in expense.participantWeights.entries) {
        if (!netByPerson.containsKey(entry.key)) continue;
        if (entry.value <= 0) continue;
        activeWeights[entry.key] = entry.value;
      }
      if (activeWeights.isEmpty) continue;

      totalExpense += expense.amount;
      netByPerson[expense.paidByPersonId] =
          (netByPerson[expense.paidByPersonId] ?? 0) + expense.amount;

      final totalWeight =
          activeWeights.values.fold<double>(0, (sum, w) => sum + w);
      if (totalWeight <= 0) continue;

      for (final entry in activeWeights.entries) {
        final share = expense.amount * (entry.value / totalWeight);
        netByPerson[entry.key] = (netByPerson[entry.key] ?? 0) - share;
      }
    }

    final roundedNetByPerson = <String, double>{};
    netByPerson.forEach((personId, amount) {
      final rounded = _roundMoney(amount);
      roundedNetByPerson[personId] = rounded.abs() < 0.01 ? 0 : rounded;
    });

    final creditors = <_SplitBalance>[];
    final debtors = <_SplitBalance>[];

    roundedNetByPerson.forEach((personId, amount) {
      if (amount > 0.009) {
        creditors.add(_SplitBalance(personId: personId, amount: amount));
      } else if (amount < -0.009) {
        debtors.add(_SplitBalance(personId: personId, amount: -amount));
      }
    });

    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final transfers = <SettlementTransfer>[];
    int creditorIndex = 0;
    int debtorIndex = 0;

    while (creditorIndex < creditors.length && debtorIndex < debtors.length) {
      final creditor = creditors[creditorIndex];
      final debtor = debtors[debtorIndex];
      final amount = _roundMoney(min(creditor.amount, debtor.amount));

      if (amount >= 0.01) {
        transfers.add(
          SettlementTransfer(
            fromPersonId: debtor.personId,
            toPersonId: creditor.personId,
            amount: amount,
          ),
        );
      }

      creditor.amount = _roundMoney(creditor.amount - amount);
      debtor.amount = _roundMoney(debtor.amount - amount);

      if (creditor.amount < 0.01) creditorIndex++;
      if (debtor.amount < 0.01) debtorIndex++;
    }

    return SplitSettlementSummary(
      netByPerson: roundedNetByPerson,
      transfers: transfers,
      totalExpense: _roundMoney(totalExpense),
      expenseCount: _splitExpenses.length,
    );
  }

  double _roundMoney(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  Future<void> _saveAndNotify() async {
    _updateStats();
    await StorageService.saveTransactions(_transactions);
    notifyListeners();
    await EngagementNotificationsService.syncFromTransactions(_transactions);
  }

  /// Home / buddy speech: open, resume, or after new transactions land.
  void requestBuddyBubble() {
    _buddyBubbleSignal++;
    notifyListeners();
  }

  /// Returns a human-readable summary of the last scan
  // Diagnostic stats for last scan
  int _lastScanChecked = 0;
  int _lastScanRegex = 0;
  int _lastScanModel = 0;
  int _lastScanSkipped = 0;
  bool _lastScanUsedOpenAi = false;

  String get scanStatus {
    if (_lastScanChecked == 0) return '';
    if (_lastScanUsedOpenAi) {
      return 'Scanned $_lastScanChecked SMS via OpenAI (${OpenAIService.chatModel}). '
          'Extracted $_lastScanModel transactions.';
    }
    return 'Scanned $_lastScanChecked messages. '
        'Found ${_lastScanRegex + _lastScanModel} bank transactions. '
        '$_lastScanSkipped promos filtered.';
  }

  void _updateStats() {
    final range =
        _rangeOption.resolve(customFrom: _customFrom, customTo: _customTo);
    final inRange = _transactions.where((t) {
      return t.date
              .isAfter(range[0].subtract(const Duration(milliseconds: 1))) &&
          t.date.isBefore(range[1].add(const Duration(milliseconds: 1)));
    }).toList();
    _stats = StatsService.compute(inRange);
  }

  String _generateId({required String prefix, String? seed}) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = Random().nextInt(1 << 31);
    final safeSeed =
        (seed ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();
    if (safeSeed.isEmpty) {
      return '${prefix}_${stamp}_$randomPart';
    }
    return '${prefix}_${stamp}_${randomPart}_$safeSeed';
  }

  String _sanitizeId(String? rawId) {
    final clean = (rawId ?? '').trim();
    if (clean.isEmpty || clean == 'null' || clean == '0') {
      return '';
    }
    return clean;
  }

  List<Transaction> _normalizeTransactionIds(List<Transaction> input) {
    final used = <String>{};
    final normalized = <Transaction>[];

    for (final t in input) {
      var id = _sanitizeId(t.id);
      if (id.isEmpty || used.contains(id)) {
        id = _generateId(prefix: 'txn', seed: t.uniqueKey);
      }
      used.add(id);

      normalized.add(Transaction(
        id: id,
        merchant: t.merchant,
        category: t.category,
        bank: t.bank,
        account: t.account,
        amount: t.amount,
        date: t.date,
        type: t.type,
        raw: t.raw,
        categoryNeedsReview: t.categoryNeedsReview,
      ));
    }

    return normalized;
  }

  /// Merges new transactions while skipping duplicates.
  /// Returns count of new items added.
  int _mergeTransactions(List<Transaction> incoming) {
    if (incoming.isEmpty) return 0;

    final existingKeys = _transactions.map((t) => t.uniqueKey).toSet();
    final toAdd = <Transaction>[];
    final existingIds = _transactions.map((t) => t.id).toSet();

    for (final t in incoming) {
      if (!existingKeys.contains(t.uniqueKey)) {
        var id = _sanitizeId(t.id);
        if (id.isEmpty || existingIds.contains(id)) {
          id = _generateId(prefix: 'txn', seed: t.uniqueKey);
        }
        final normalized = Transaction(
          id: id,
          merchant: t.merchant,
          category: t.category,
          bank: t.bank,
          account: t.account,
          amount: t.amount,
          date: t.date,
          type: t.type,
          raw: t.raw,
          categoryNeedsReview: t.categoryNeedsReview,
        );
        toAdd.add(normalized);
        existingIds.add(id);
        existingKeys.add(
            t.uniqueKey); // Prevent duplicates within the incoming batch too
      }
    }

    if (toAdd.isNotEmpty) {
      _transactions = [...toAdd, ..._transactions];
    }
    return toAdd.length;
  }

  // ── Initialization & Persistence ─────────────────────────────
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _userName = await StorageService.getUserName() ?? 'User';
    _selectedCurrency = await StorageService.getCurrency();
    _themeMode = await StorageService.getThemeMode();
    _sectorMonthlyLimits = await StorageService.getSectorMonthlyLimits();
    _budgetBuckets = await StorageService.loadBudgetBuckets();
    _splitPeople = await StorageService.loadSplitPeople();
    _splitExpenses = await StorageService.loadSplitExpenses();
    _splitRecurringTemplates =
        await StorageService.loadSplitRecurringTemplates();
    AppColors.isMonochrome = _themeMode == 'monochrome';

    // Load cached transactions first for instant UI response
    _transactions =
        _normalizeTransactionIds(await StorageService.loadTransactions());
    _budgetBuckets = _budgetBuckets
        .map((bucket) => bucket.copyWith(
              transactionIds: bucket.transactionIds
                  .where((id) => _transactions.any((t) => t.id == id))
                  .toList(),
            ))
        .toList();
    _splitPeople = _normalizeSplitPeople(_splitPeople);
    _splitExpenses = _normalizeSplitExpenses(_splitExpenses, _splitPeople);
    _splitRecurringTemplates = _normalizeSplitRecurringTemplates(
        _splitRecurringTemplates, _splitPeople);
    await runRecurringCatchUp(DateTime.now());
    await StorageService.saveTransactions(_transactions);
    await StorageService.saveBudgetBuckets(_budgetBuckets);
    await StorageService.saveSplitPeople(_splitPeople);
    await StorageService.saveSplitExpenses(_splitExpenses);
    await StorageService.saveSplitRecurringTemplates(_splitRecurringTemplates);
    _updateStats();
    notifyListeners();

    // Trigger full SMS scan in background
    await load();
  }

  void toggleTheme() async {
    _themeMode = _themeMode == 'monochrome' ? 'pastel' : 'monochrome';
    AppColors.isMonochrome = _themeMode == 'monochrome';
    await StorageService.saveThemeMode(_themeMode);
    notifyListeners();
  }

  void setTheme(String mode) async {
    _themeMode = mode;
    AppColors.isMonochrome = mode == 'monochrome';
    await StorageService.saveThemeMode(mode);
    notifyListeners();
  }

  void updateProfile({String? name, String? currency}) async {
    if (name != null) {
      _userName = name;
      await StorageService.saveUserName(name);
    }
    if (currency != null) {
      _selectedCurrency = currency;
      await StorageService.saveCurrency(currency);
    }
    notifyListeners();
  }

  // ── Filter setters ───────────────────────────────────────────
  void setSearch(String v) {
    _searchQuery = v;
    notifyListeners();
  }

  void setType(String? v) {
    _filterType = v ?? '';
    notifyListeners();
  }

  void setSector(String? v) {
    _filterSector = v ?? '';
    notifyListeners();
  }

  void setBank(String? v) {
    _filterBank = v ?? '';
    notifyListeners();
  }

  void clearTransactionFilters() {
    _searchQuery = '';
    _filterType = '';
    _filterSector = '';
    _filterBank = '';
    notifyListeners();
  }

  bool _matchesActiveFilters(Transaction t) {
    if (_filterType.isNotEmpty && t.type != _filterType) return false;
    if (_filterSector.isNotEmpty && t.category != _filterSector) return false;
    if (_filterBank.isNotEmpty && t.bank != _filterBank) return false;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      if (!t.merchant.toLowerCase().contains(q) &&
          !t.bank.toLowerCase().contains(q)) {
        return false;
      }
    }
    return true;
  }

  List<Transaction> _sortedTransactions(Iterable<Transaction> input) {
    final list = input.toList();
    list.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
    return list;
  }

  void addManualTransaction({
    required String merchant,
    required double amount,
    required String type,
    required String category,
    required String bank,
    required DateTime date,
  }) {
    final normalizedType = type == 'credit' ? 'credit' : 'debit';
    final normalizedAmount = amount.abs();

    final txn = Transaction(
      id: _generateId(prefix: 'manual'),
      merchant: merchant.trim().isEmpty ? 'Manual Entry' : merchant.trim(),
      category: category.trim().isEmpty ? 'Other' : category.trim(),
      bank: bank.trim().isEmpty ? 'Manual' : bank.trim(),
      account: null,
      amount: normalizedAmount,
      date: date,
      type: normalizedType,
      raw: 'Manual entry',
      categoryNeedsReview: false,
    );

    _transactions = [txn, ..._transactions];
    _saveAndNotify().then((_) {
      requestBuddyBubble();
    });
    if (_state != LoadState.loading) {
      _state = LoadState.loaded;
      notifyListeners();
    }
  }

  void deleteTransaction(String id) {
    final beforeCount = _transactions.length;
    _transactions.removeWhere((t) => t.id == id);
    if (_transactions.length == beforeCount) return;

    _budgetBuckets = _budgetBuckets
        .map((bucket) => bucket.copyWith(
              transactionIds:
                  bucket.transactionIds.where((txId) => txId != id).toList(),
            ))
        .toList();
    StorageService.saveBudgetBuckets(_budgetBuckets);
    _saveAndNotify();
  }

  void updateTransaction(String id, ManualTransactionDraft draft) {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      final old = _transactions[index];
      _transactions[index] = Transaction(
        id: old.id,
        merchant: draft.merchant.trim(),
        category: draft.category.trim(),
        bank: draft.bank.trim(),
        account: old.account,
        amount: draft.amount,
        date: draft.date,
        type: draft.type,
        raw: old.raw,
        categoryNeedsReview: false,
      );
      _saveAndNotify();
    }
  }

  void setTransactionCategory(String id, String category) {
    final i = _transactions.indexWhere((t) => t.id == id);
    if (i == -1) return;
    final old = _transactions[i];
    final cat = category.trim().isEmpty ? 'Other' : category.trim();
    _transactions[i] = old.copyWith(category: cat, categoryNeedsReview: false);
    _saveAndNotify();
  }

  /// Keeps "Other" but stops prompting (user skipped).
  void skipCategoryReview(String id) {
    final i = _transactions.indexWhere((t) => t.id == id);
    if (i == -1) return;
    final old = _transactions[i];
    _transactions[i] = old.copyWith(categoryNeedsReview: false);
    _saveAndNotify();
  }

  // ── Date range setter ────────────────────────────────────────
  void setRange(DateRangeOption opt, {DateTime? from, DateTime? to}) {
    _rangeOption = opt;
    if (opt == DateRangeOption.custom) {
      _customFrom = from;
      _customTo = to;
    }
    _updateStats();
    notifyListeners();
    // NOTE: We intentionally do NOT call load() here.
    // Transactions are already cached locally; we just re-filter them.
    // Users can explicitly trigger a fresh SMS scan via the "Scan SMS" button.
  }

  // ── Load ─────────────────────────────────────────────────────
  Future<void> load() async {
    _state = LoadState.loading;
    _progressLabel = 'Requesting SMS permission…';
    _progressCurrent = 0;
    _progressTotal = 0;
    _debugInfo = '';
    _error = null;
    notifyListeners();

    // Step 1: Check SMS permission
    final granted = await SmsService.requestPermission();
    if (!granted) {
      _state = LoadState.permissionDenied;
      _debugInfo = '[ERROR] SMS permission denied';
      notifyListeners();
      await EngagementNotificationsService.syncFromTransactions(_transactions);
      return;
    }
    _debugInfo += '[OK] SMS permission granted\n';

    try {
      // Step 2: Read SMS candidates
      _progressLabel = 'Reading SMS inbox…';
      notifyListeners();

      final range =
          _rangeOption.resolve(customFrom: _customFrom, customTo: _customTo);
      _debugInfo +=
          '[RANGE] Range: ${range[0].toString().substring(0, 10)} → ${range[1].toString().substring(0, 10)}\n';
      notifyListeners();

      final candidates =
          await SmsService.readCandidates(from: range[0], to: range[1]);
      _debugInfo += '[SMS] SMS candidates found: ${candidates.length}\n';

      if (candidates.isEmpty) {
        _state = LoadState.loaded;
        _progressLabel = '';
        _debugInfo += '[WARN] No financial SMS found in this period';
        notifyListeners();
        await EngagementNotificationsService.syncFromTransactions(_transactions);
        return;
      }

      // Show first candidate for debug
      if (candidates.isNotEmpty) {
        final first = candidates.first.body;
        _debugInfo +=
            '[PREV] First SMS: ${first.substring(0, first.length > 80 ? 80 : first.length)}…\n';
      }

      // Step 3: Cloud AI when signed in (Vercel proxy + Firebase); otherwise local-only.
      final useCloudAi = OpenAIService.canUseCloudAi;
      List<Transaction> parsedTxns = [];
      LocalParseResult? parseResult;
      _lastScanUsedOpenAi = false;

      if (useCloudAi) {
        _progressLabel =
            'Parsing SMS with OpenAI (${OpenAIService.chatModel})…';
        notifyListeners();
        try {
          parsedTxns = await OpenAIService.classify(
            candidates: candidates,
            onProgress: (done, total) {
              _progressLabel = 'OpenAI SMS… $done / $total';
              notifyListeners();
            },
          );
          _lastScanUsedOpenAi = true;
          _lastScanChecked = candidates.length;
          _lastScanRegex = 0;
          _lastScanModel = parsedTxns.length;
          _lastScanSkipped = 0;
          _debugInfo +=
              '[AI] ${OpenAIService.chatModel}: ${parsedTxns.length} transactions from ${candidates.length} SMS.\n';
        } catch (e) {
          _debugInfo += '[AI] OpenAI failed: $e\n[FALLBACK] Local parser…\n';
          _progressLabel = 'OpenAI failed — parsing locally…';
          notifyListeners();
          final local =
              await compute(LocalParserService.parseCandidates, candidates);
          parseResult = local;
          parsedTxns = local.transactions;
          _lastScanUsedOpenAi = false;
          _lastScanChecked = local.checked;
          _lastScanRegex = local.regexMatched;
          _lastScanModel = local.modelFlagged;
          _lastScanSkipped = local.skipped;
          _debugInfo +=
              '[LOCAL] Fallback found ${parsedTxns.length} transactions.\n';
        }
      } else {
        _debugInfo +=
            '[KEY] Not signed in — cloud AI unavailable; local parser only.\n';
        _progressLabel = 'Parsing transactions locally…';
        notifyListeners();
        final local =
            await compute(LocalParserService.parseCandidates, candidates);
        parseResult = local;
        parsedTxns = local.transactions;
        _lastScanChecked = local.checked;
        _lastScanRegex = local.regexMatched;
        _lastScanModel = local.modelFlagged;
        _lastScanSkipped = local.skipped;
        _debugInfo +=
            '[LOCAL] Local parser found ${parsedTxns.length}.\n';
      }

      final addedCount = _mergeTransactions(parsedTxns);
      _debugInfo += '[MERGE] Added $addedCount new (deduped by merchant+amount+day).\n';

      await _saveAndNotify();
      if (addedCount > 0) {
        requestBuddyBubble();
      }

      final skipped = candidates.length - parsedTxns.length;
      if (!_lastScanUsedOpenAi && skipped > 0) {
        _debugInfo +=
            '[LOCAL] $skipped SMS did not yield a transaction from rules.\n';
      }

      _progressLabel = parsedTxns.isEmpty
          ? 'No transactions parsed (${candidates.length} bank-like SMS in range). Try manual add or adjust range.'
          : 'Imported ${parsedTxns.length} from ${candidates.length} bank-like SMS${skipped > 0 ? ' ($skipped not classified)' : ''}.';
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 900));

      _state = LoadState.loaded;
      _progressLabel = '';
      _debugInfo += '[OK] Done! ${parsedTxns.length} transactions this scan.';
      if (kDebugMode) {
        final rs = parseResult;
        debugPrint(
          '──────── Savyit SMS scan (debug) ────────\n'
          '$_debugInfo\n'
          '${rs != null ? '[STATS] regex=${rs.regexMatched} fallback=${rs.modelFlagged} promoSkipped=${rs.skipped} checked=${rs.checked}' : '[STATS] OpenAI path'}\n'
          '────────────────────────────────────────',
        );
      }
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
      _debugInfo += '[ERROR] Error: $e';
      if (kDebugMode) {
        debugPrint('──────── Savyit SMS scan ERROR ────────\n$_debugInfo');
      }
      await EngagementNotificationsService.syncFromTransactions(_transactions);
    }
    notifyListeners();
  }

  // ── PDF Upload ──────────────────────────────────────────────
  Future<void> processPdf({PdfChunkMode mode = PdfChunkMode.bothHalves}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) return;

      _state = LoadState.loading;
      _error = null;
      _progressLabel = 'Extracting text from PDF…';
      _debugInfo = '[PDF] PDF selected: ${result.files.single.name}\n';
      notifyListeners();

      final file = File(result.files.single.path!);
      final text = await PdfService.extractText(file);

      final cleanedText = text.replaceAll('\u0000', '').trim();
      if (cleanedText.isEmpty) {
        throw Exception('No readable text found in the selected PDF.');
      }

      _debugInfo += '[OK] Text extracted (${cleanedText.length} chars)\n';

      final preview = cleanedText
          .substring(0, cleanedText.length > 200 ? 200 : cleanedText.length)
          .replaceAll('\n', ' ');
      _debugInfo += '[PREV] Preview: $preview…\n\n';

      final segments = _splitPdfText(cleanedText, mode);
      _debugInfo += '[CHUNKS] Processing ${segments.length} chunks\n';
      _progressLabel = 'Preparing AI analysis…';
      _progressCurrent = 0;
      _progressTotal = segments.length;
      notifyListeners();

      if (!OpenAIService.canUseCloudAi) {
        _state = LoadState.error;
        _error =
            'PDF AI import needs you to be signed in (Firebase). Sign in from Profile, then try again — or use Export Data → CSV.';
        _debugInfo += '[ERROR] Not signed in — PDF cloud AI unavailable\n';
        notifyListeners();
        return;
      }

      final parsedFromPdf = <Transaction>[];
      var pdfHadNewTransactions = false;
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        _progressCurrent = i;
        _progressLabel = 'Chunk ${i + 1}/${segments.length}: Sending to AI…';
        notifyListeners();

        try {
          final txns = await OpenAIService.classifyText(
            text: segment.text,
            onStatus: (status) {
              _progressLabel = 'Chunk ${i + 1}/${segments.length}: $status';
              notifyListeners();
            },
          );

          if (txns.isNotEmpty) {
            final added = _mergeTransactions(txns);
            if (added > 0) pdfHadNewTransactions = true;
            parsedFromPdf.addAll(txns);
            await _saveAndNotify();
            _debugInfo +=
                '[AI] Chunk ${i + 1}: ${txns.length} found. $added new.\n';
          } else {
            _debugInfo += '[AI] Chunk ${i + 1}: No transactions found\n';
          }
          notifyListeners();
        } catch (e) {
          _debugInfo += '[WARN] Chunk ${i + 1} failed: $e\n';
          // Continue to next chunk instead of aborting entirely?
          // For now, we continue so at least partial data is kept.
        }
      }

      _state = LoadState.loaded;
      _progressLabel = '';
      _progressCurrent = _progressTotal;
      if (pdfHadNewTransactions) {
        requestBuddyBubble();
      }
      _debugInfo +=
          '[OK] Final: ${parsedFromPdf.length} new transactions parsed total\nDone!';
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
      _debugInfo += '[ERROR] Critical Error: $e\n';
    }
    notifyListeners();
  }

  List<_PdfTextSegment> _splitPdfText(String text, PdfChunkMode mode) {
    const int maxChars = 8000; // Safe chunk size for AI context and response

    if (text.length <= maxChars) {
      return [_PdfTextSegment(label: 'Full statement', text: text)];
    }

    final segments = <_PdfTextSegment>[];

    if (mode == PdfChunkMode.firstHalf) {
      final part = text.substring(0, text.length ~/ 2);
      return [_PdfTextSegment(label: 'First half', text: part)];
    } else if (mode == PdfChunkMode.secondHalf) {
      final part = text.substring(text.length ~/ 2);
      return [_PdfTextSegment(label: 'Second half', text: part)];
    }

    // mode == bothHalves or default: Split into small chunks automatically
    int start = 0;
    int chunkIdx = 1;
    while (start < text.length) {
      int end = start + maxChars;
      if (end > text.length) {
        end = text.length;
      } else {
        // Try to find a newline to split more cleanly
        final lastNewline = text.lastIndexOf('\n', end);
        if (lastNewline > start + (maxChars * 0.7)) {
          end = lastNewline;
        }
      }

      final chunkText = text.substring(start, end).trim();
      if (chunkText.isNotEmpty) {
        segments.add(_PdfTextSegment(
          label: 'Chunk $chunkIdx',
          text: chunkText,
        ));
      }

      start = end;
      chunkIdx++;
    }

    return segments;
  }
}

class _SplitBalance {
  final String personId;
  double amount;

  _SplitBalance({
    required this.personId,
    required this.amount,
  });
}
