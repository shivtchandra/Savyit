// lib/services/money_rhythm_service.dart
// "Spending Pulse" — insights derived only from this device's transaction history
// (pace vs your own baselines, caps, rhythm, recurring-like merchants).

import 'dart:math' as math;

import '../models/transaction.dart';

enum RhythmInsightKind { pace, cap, recurring, weekendRhythm, needMoreData }

class RhythmInsight {
  final String headline;
  final String detail;
  final RhythmInsightKind kind;
  /// Lower sorts first.
  final int priority;

  const RhythmInsight({
    required this.headline,
    required this.detail,
    required this.kind,
    required this.priority,
  });
}

class MoneyRhythmReport {
  final List<RhythmInsight> insights;
  final bool hasEnoughHistory;

  const MoneyRhythmReport({
    required this.insights,
    required this.hasEnoughHistory,
  });
}

class MoneyRhythmService {
  MoneyRhythmService._();

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final v = List<double>.from(values)..sort();
    final mid = v.length ~/ 2;
    if (v.length.isOdd) return v[mid];
    return (v[mid - 1] + v[mid]) / 2;
  }

  static bool _merchantMeaningful(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.length < 4) return false;
    if (s == 'unknown' || s.contains('unknown merchant')) return false;
    if (s == 'upi' || s == 'paid' || s == 'purchase') return false;
    return true;
  }

  static String _normMerchant(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    if (s.length > 28) s = s.substring(0, 28);
    return s;
  }

  /// Prior completed calendar months' total debit per sector (newest first).
  static List<double> _priorMonthlySectorTotals({
    required List<Transaction> txns,
    required String sector,
    required DateTime now,
  }) {
    final current = _monthKey(now);
    final bucket = <String, double>{};
    for (final t in txns) {
      if (!t.isDebit || t.category != sector) continue;
      final k = _monthKey(t.date);
      if (k == current) continue;
      bucket[k] = (bucket[k] ?? 0) + t.amount;
    }
    final keys = bucket.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) => bucket[k]!).toList();
  }

  static MoneyRhythmReport build({
    required List<Transaction> allTxns,
    required Map<String, double> sectorMonthlyLimits,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final insights = <RhythmInsight>[];
    var hasEnoughHistory = false;

    if (allTxns.length < 5) {
      return MoneyRhythmReport(
        insights: const [
          RhythmInsight(
            headline: 'Spending pulse warms up with more history',
            detail:
                'After a few dozen transactions from SMS or manual entry, we compare this month’s pace to your own past months — not generic benchmarks.',
            kind: RhythmInsightKind.needMoreData,
            priority: 50,
          ),
        ],
        hasEnoughHistory: false,
      );
    }

    final debits =
        allTxns.where((t) => t.isDebit).toList(growable: false);
    if (debits.length >= 8) hasEnoughHistory = true;

    final daysInMonth = DateTime(clock.year, clock.month + 1, 0).day;
    final elapsed = math.max(1, clock.day.clamp(1, daysInMonth));
    final currentMonthKey = _monthKey(clock);

    // ── Pace & cap per sector (current calendar month) ─────────────
    final mtdBySector = <String, double>{};
    for (final t in debits) {
      if (_monthKey(t.date) != currentMonthKey) continue;
      mtdBySector[t.category] = (mtdBySector[t.category] ?? 0) + t.amount;
    }

    for (final entry in mtdBySector.entries) {
      final sector = entry.key;
      final mtd = entry.value;
      if (mtd < 200) continue;

      final projected = mtd / elapsed * daysInMonth;

      final limit = sectorMonthlyLimits[sector];
      if (limit != null && limit > 0 && projected > limit * 1.02) {
        final over = projected - limit;
        insights.add(RhythmInsight(
          headline: '$sector may breach your monthly cap',
          detail:
              'At today’s pace you’d land near ₹${projected.toStringAsFixed(0)} vs your ₹${limit.toStringAsFixed(0)} limit (~₹${over.toStringAsFixed(0)} over).',
          kind: RhythmInsightKind.cap,
          priority: 1,
        ));
      }

      final history = _priorMonthlySectorTotals(
        txns: allTxns,
        sector: sector,
        now: clock,
      );
      if (history.length >= 2) {
        hasEnoughHistory = true;
        final baseline = _median(history.take(3).toList());
        if (baseline >= 300 && projected > baseline * 1.18) {
          final pct = ((projected / baseline - 1) * 100).round();
          insights.add(RhythmInsight(
            headline: '$sector is running hotter than your usual',
            detail:
                'Pace this month projects ~$pct% above your typical recent months (median ~₹${baseline.toStringAsFixed(0)}).',
            kind: RhythmInsightKind.pace,
            priority: 2,
          ));
        } else if (baseline >= 300 && projected < baseline * 0.72) {
          final pct = ((1 - projected / baseline) * 100).round();
          insights.add(RhythmInsight(
            headline: '$sector is lighter than usual',
            detail:
                'You’re tracking ~$pct% below your recent typical (~₹${baseline.toStringAsFixed(0)}/mo). Nice discipline if intentional.',
            kind: RhythmInsightKind.pace,
            priority: 5,
          ));
        }
      }
    }

    // ── Weekend vs weekday rhythm (last 8 weeks) ────────────────────
    final rhythmCutoff = clock.subtract(const Duration(days: 56));
    final recentDebits =
        debits.where((t) => !t.date.isBefore(rhythmCutoff)).toList();
    if (recentDebits.length >= 10) {
      double weekend = 0, total = 0;
      for (final t in recentDebits) {
        if (t.category == 'Transfer') continue;
        total += t.amount;
        final w = t.date.weekday;
        if (w == DateTime.saturday || w == DateTime.sunday) {
          weekend += t.amount;
        }
      }
      if (total > 500 && weekend / total >= 0.54) {
        insights.add(RhythmInsight(
          headline: 'Weekend-heavy spending pattern',
          detail:
              '${(weekend / total * 100).round()}% of recent outflows (excl. transfers) landed on Sat–Sun. Useful if you want to smooth cashflow across the week.',
          kind: RhythmInsightKind.weekendRhythm,
          priority: 6,
        ));
      }
    }

    // ── Recurring-like merchants (SMS/UPI: same counterparty, stable amount) ──
    final recurCut = clock.subtract(const Duration(days: 92));
    final recurCandidates = <String, List<Transaction>>{};
    for (final t in debits) {
      if (t.date.isBefore(recurCut)) continue;
      if (!_merchantMeaningful(t.merchant)) continue;
      final key = _normMerchant(t.merchant);
      recurCandidates.putIfAbsent(key, () => []).add(t);
    }

    for (final entry in recurCandidates.entries) {
      final list = entry.value;
      if (list.length < 2) continue;
      final amounts = list.map((t) => t.amount).toList();
      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      if (mean < 99) continue;
      final mn = amounts.reduce(math.min);
      final mx = amounts.reduce(math.max);
      if (mean <= 0 || (mx - mn) / mean > 0.17) continue;

      final merchantLabel = list.first.merchant.trim();
      final shortLabel = merchantLabel.length > 32
          ? '${merchantLabel.substring(0, 29)}…'
          : merchantLabel;
      insights.add(RhythmInsight(
        headline: 'Stable repeats: $shortLabel',
        detail:
            '${list.length} similar debits (~₹${mean.toStringAsFixed(0)} avg) in the last ~3 months — often subscriptions, SIPs, or rent. Worth tagging if you want a renewal ledger.',
        kind: RhythmInsightKind.recurring,
        priority: 4,
      ));
    }

    // Dedupe by kind+headline, sort, cap at 4
    final seen = <String>{};
    final deduped = <RhythmInsight>[];
    insights.sort((a, b) => a.priority.compareTo(b.priority));
    for (final i in insights) {
      final k = '${i.kind.name}:${i.headline}';
      if (seen.contains(k)) continue;
      seen.add(k);
      deduped.add(i);
      if (deduped.length >= 4) break;
    }

    if (deduped.isEmpty) {
      deduped.add(RhythmInsight(
        headline: 'Steady rhythm this month',
        detail:
            hasEnoughHistory
                ? 'No strong pace anomalies vs your own history yet. Check back after more debits land.'
                : 'Keep logging — we’ll contrast this month to your past months automatically.',
        kind: RhythmInsightKind.needMoreData,
        priority: 10,
      ));
    }

    return MoneyRhythmReport(
      insights: deduped,
      hasEnoughHistory: hasEnoughHistory || deduped.isNotEmpty,
    );
  }
}
