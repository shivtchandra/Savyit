// lib/services/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget_bucket.dart';
import '../models/mascot_dna.dart';
import '../models/split_expense.dart';
import '../models/split_person.dart';
import '../models/split_recurring_template.dart';
import '../models/transaction.dart';

class StorageService {
  static const _keyTransactions = 'ml_transactions';
  static const _keyUserName = 'ml_user_name';
  static const _keyOnboardingDone = 'ml_onboarding_done';
  static const _keyCurrency = 'ml_currency';
  static const _keyOccupation = 'ml_occupation';
  static const _keyMonthlyIncome = 'ml_monthly_income';
  static const _keyAgeRange = 'ml_age_range';
  static const _keyFinancialGoals = 'ml_financial_goals';
  static const _keyProfileComplete = 'ml_profile_complete';
  static const _keyThemeMode = 'ml_theme_mode'; // 'pastel' or 'monochrome'
  static const _keySectorMonthlyLimits = 'ml_sector_monthly_limits';
  static const _keyAuthSkipped = 'ml_auth_skipped';
  static const _keyMascotDna = 'ml_mascot_dna';
  static const _keyBuddyLineHistory = 'ml_buddy_line_history';
  static const _keyMilestones = 'ml_milestones';
  static const _keyBudgetBuckets = 'ml_budget_buckets';
  static const _keySplitPeople = 'ml_split_people';
  static const _keySplitExpenses = 'ml_split_expenses';
  static const _keySplitRecurringTemplates = 'ml_split_recurring_templates';
  static const _keyEngagementNotifs = 'ml_engagement_notifs';
  /// Last calendar day (inclusive) fully covered by an SMS inbox scan (`yyyy-MM-dd`).
  static const _keySmsScanCursor = 'ml_sms_scan_cursor';
  /// When true (default), `load()` only reads SMS from the day after this cursor through the UI range end.
  static const _keyIncrementalSmsScan = 'ml_incremental_sms_scan';

  // ── Transactions ──────────────────────────────────────────────
  static Future<void> saveTransactions(List<Transaction> txns) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = txns.map((t) => t.toJson()).toList();
    await prefs.setString(_keyTransactions, json.encode(jsonList));
  }

  static Future<List<Transaction>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyTransactions);
    if (data == null) return [];

    try {
      final List<dynamic> decoded = json.decode(data);
      return decoded.map((item) => Transaction.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveBudgetBuckets(List<BudgetBucket> buckets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = buckets.map((b) => b.toJson()).toList();
    await prefs.setString(_keyBudgetBuckets, json.encode(jsonList));
  }

  static Future<List<BudgetBucket>> loadBudgetBuckets() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyBudgetBuckets);
    if (data == null) return [];

    try {
      final List<dynamic> decoded = json.decode(data);
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(BudgetBucket.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSplitPeople(List<SplitPerson> people) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = people.map((p) => p.toJson()).toList();
    await prefs.setString(_keySplitPeople, json.encode(jsonList));
  }

  static Future<List<SplitPerson>> loadSplitPeople() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keySplitPeople);
    if (data == null) return [];

    try {
      final List<dynamic> decoded = json.decode(data);
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SplitPerson.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSplitExpenses(List<SplitExpense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = expenses.map((e) => e.toJson()).toList();
    await prefs.setString(_keySplitExpenses, json.encode(jsonList));
  }

  static Future<List<SplitExpense>> loadSplitExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keySplitExpenses);
    if (data == null) return [];

    try {
      final List<dynamic> decoded = json.decode(data);
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SplitExpense.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSplitRecurringTemplates(
      List<SplitRecurringTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = templates.map((t) => t.toJson()).toList();
    await prefs.setString(_keySplitRecurringTemplates, json.encode(jsonList));
  }

  static Future<List<SplitRecurringTemplate>>
      loadSplitRecurringTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keySplitRecurringTemplates);
    if (data == null) return [];

    try {
      final List<dynamic> decoded = json.decode(data);
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SplitRecurringTemplate.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── User / Onboarding ─────────────────────────────────────────
  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<void> setOnboardingDone(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingDone, done);
  }

  static Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingDone) ?? false;
  }

  static Future<void> setAuthSkipped(bool skipped) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAuthSkipped, skipped);
  }

  static Future<bool> isAuthSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAuthSkipped) ?? false;
  }

  static Future<void> saveCurrency(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, symbol);
  }

  static Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrency) ?? '₹';
  }

  // ── Extended Profile ──────────────────────────────────────────
  static Future<void> saveOccupation(String occupation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOccupation, occupation);
  }

  static Future<String?> getOccupation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOccupation);
  }

  static Future<void> saveMonthlyIncome(String range) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMonthlyIncome, range);
  }

  static Future<String?> getMonthlyIncome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMonthlyIncome);
  }

  static Future<void> saveAgeRange(String range) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAgeRange, range);
  }

  static Future<String?> getAgeRange() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAgeRange);
  }

  static Future<void> saveFinancialGoals(List<String> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFinancialGoals, json.encode(goals));
  }

  static Future<List<String>> getFinancialGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyFinancialGoals);
    if (data == null) return [];
    try {
      return List<String>.from(json.decode(data));
    } catch (_) {
      return [];
    }
  }

  static Future<void> setProfileComplete(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyProfileComplete, done);
  }

  static Future<bool> isProfileComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyProfileComplete) ?? false;
  }

  /// Get full user profile as a Map for AI context
  static Future<Map<String, dynamic>> getUserProfile() async {
    return {
      'name': await getUserName() ?? 'User',
      'occupation': await getOccupation() ?? '',
      'monthlyIncome': await getMonthlyIncome() ?? '',
      'ageRange': await getAgeRange() ?? '',
      'goals': await getFinancialGoals(),
      'currency': await getCurrency(),
    };
  }

  // ── Financial Plan ──────────────────────────────────────────────
  static const _keyFinancialPlan = 'ml_financial_plan';

  static Future<void> saveFinancialPlan(Map<String, dynamic> plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFinancialPlan, json.encode(plan));
  }

  static Future<Map<String, dynamic>?> getFinancialPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyFinancialPlan);
    if (data == null) return null;
    try {
      return Map<String, dynamic>.from(json.decode(data));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'pastel';
  }

  // ── Sector Monthly Limits ───────────────────────────────────────
  static Future<void> saveSectorMonthlyLimits(
      Map<String, double> limits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySectorMonthlyLimits, json.encode(limits));
  }

  static Future<Map<String, double>> getSectorMonthlyLimits() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keySectorMonthlyLimits);
    if (data == null) return {};

    try {
      final decoded = Map<String, dynamic>.from(json.decode(data));
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ── SMS scan cursor (incremental inbox reads) ─────────────────
  static Future<DateTime?> getSmsScanCursorEndInclusive() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keySmsScanCursor);
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  /// Persists the last calendar day included in the completed scan window.
  static Future<void> setSmsScanCursorEndInclusive(DateTime date) async {
    final d = DateTime(date.year, date.month, date.day);
    final s =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySmsScanCursor, s);
  }

  static Future<void> clearSmsScanCursor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySmsScanCursor);
  }

  static Future<bool> getIncrementalSmsScanEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIncrementalSmsScan) ?? true;
  }

  static Future<void> setIncrementalSmsScanEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIncrementalSmsScan, enabled);
  }

  // ── Mascot DNA ──────────────────────────────────────────────────
  static Future<void> saveMascotDna(MascotDna dna) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMascotDna, dna.toJsonString());
  }

  static Future<MascotDna> loadMascotDna() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyMascotDna);
    if (raw == null) return MascotDna.defaults();
    try {
      return MascotDna.fromJsonString(raw);
    } catch (_) {
      return MascotDna.defaults();
    }
  }

  /// Recent buddy speech lines (newest first) so Home can avoid repeats.
  static const int _buddyLineHistoryMax = 36;

  static Future<List<String>> getBuddyLineHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyBuddyLineHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> recordBuddyLineShown(String line) async {
    final t = line.trim();
    if (t.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    var prev = await getBuddyLineHistory();
    prev = prev.where((e) => e.trim().toLowerCase() != t.toLowerCase()).toList();
    prev.insert(0, t);
    if (prev.length > _buddyLineHistoryMax) {
      prev = prev.sublist(0, _buddyLineHistoryMax);
    }
    await prefs.setString(_keyBuddyLineHistory, json.encode(prev));
  }

  // ── Milestones ─────────────────────────────────────────────────
  static Future<void> markMilestone(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyMilestones);
    final Map<String, dynamic> map =
        raw != null ? Map<String, dynamic>.from(json.decode(raw)) : {};
    map[key] = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_keyMilestones, json.encode(map));
  }

  static Future<bool> isMilestoneFired(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyMilestones);
    if (raw == null) return false;
    try {
      final map = Map<String, dynamic>.from(json.decode(raw));
      return map.containsKey(key);
    } catch (_) {
      return false;
    }
  }

  /// Local evening nudges when the day has no logged transactions (default on).
  static Future<bool> getEngagementNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEngagementNotifs) ?? true;
  }

  static Future<void> setEngagementNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEngagementNotifs, value);
  }
}
