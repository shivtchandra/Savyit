// lib/services/stats_service.dart
import '../models/transaction.dart';

class DayStat {
  final String dateKey; // 'YYYY-MM-DD'
  final double credit;
  final double debit;
  final int count;
  DayStat(this.dateKey, this.credit, this.debit, this.count);
  double get net => credit - debit;
}

class WeekStat {
  final String weekStart; // Monday ISO date
  final double credit;
  final double debit;
  final int count;
  WeekStat(this.weekStart, this.credit, this.debit, this.count);
  double get net => credit - debit;
}

class SectorStat {
  final String name;
  final String icon;
  final double amount;
  final double percentage;
  SectorStat(this.name, this.icon, this.amount, this.percentage);
}

class CumulativePoint {
  final String dateKey;
  final double balance;
  CumulativePoint(this.dateKey, this.balance);
}

class Stats {
  final double totalCredit;
  final double totalDebit;
  final double netBalance;
  final int totalCount;
  final List<DayStat> days;
  final List<WeekStat> weeks;
  final List<SectorStat> sectors;
  final List<MapEntry<String, double>> topMerchants;
  final List<CumulativePoint> cumulative;

  Stats({
    required this.totalCredit,
    required this.totalDebit,
    required this.netBalance,
    required this.totalCount,
    required this.days,
    required this.weeks,
    required this.sectors,
    required this.topMerchants,
    required this.cumulative,
  });
}

class StatsService {
  static Stats compute(List<Transaction> txns) {
    if (txns.isEmpty) {
      return Stats(
        totalCredit: 0, totalDebit: 0, netBalance: 0, totalCount: 0,
        days: [], weeks: [], sectors: [], topMerchants: [], cumulative: [],
      );
    }

    double totalCredit = 0, totalDebit = 0;
    for (final t in txns) {
      if (t.isCredit) {
        totalCredit += t.amount;
      } else {
        totalDebit += t.amount;
      }
    }

    // ── Day-wise ──────────────────────────────────────────────
    final dayMap = <String, (double, double, int)>{};
    for (final t in txns) {
      final k = '${t.date.year.toString().padLeft(4,'0')}-${t.date.month.toString().padLeft(2,'0')}-${t.date.day.toString().padLeft(2,'0')}';
      final prev = dayMap[k] ?? (0.0, 0.0, 0);
      dayMap[k] = (
        prev.$1 + (t.isCredit ? t.amount : 0),
        prev.$2 + (t.isDebit  ? t.amount : 0),
        prev.$3 + 1,
      );
    }
    final days = dayMap.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
    final dayStat = days.map((e) => DayStat(e.key, e.value.$1, e.value.$2, e.value.$3)).toList();

    // ── Week-wise (Mon–Sun) ───────────────────────────────────
    final weekMap = <String, (double, double, int)>{};
    for (final t in txns) {
      final d   = t.date;
      final dow = d.weekday; // 1=Mon … 7=Sun
      final mon = d.subtract(Duration(days: dow - 1));
      final k   = '${mon.year.toString().padLeft(4,'0')}-${mon.month.toString().padLeft(2,'0')}-${mon.day.toString().padLeft(2,'0')}';
      final prev = weekMap[k] ?? (0.0, 0.0, 0);
      weekMap[k] = (
        prev.$1 + (t.isCredit ? t.amount : 0),
        prev.$2 + (t.isDebit  ? t.amount : 0),
        prev.$3 + 1,
      );
    }
    final weeks = weekMap.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
    final weekStat = weeks.map((e) => WeekStat(e.key, e.value.$1, e.value.$2, e.value.$3)).toList();

    // ── Sectors (debits only) ─────────────────────────────────
    final sectorMap = <String, double>{};
    for (final t in txns.where((x) => x.isDebit)) {
      sectorMap[t.category] = (sectorMap[t.category] ?? 0) + t.amount;
    }
    final sectorTotal = sectorMap.values.fold<double>(0, (a, b) => a + b);
    final sectorEntries = sectorMap.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    final sectorStat = sectorEntries.map((e) {
      // icon looked up by name – we replicate the small icon map here
      const icons = {
        'Food & Dining':'','Transport':'','Shopping':'',
        'Health':'','Entertainment':'','Utilities & Bills':'',
        'Transfer':'','Other':'',
      };
      return SectorStat(e.key, icons[e.key] ?? '', e.value, sectorTotal > 0 ? e.value/sectorTotal : 0);
    }).toList();

    // ── Top merchants ─────────────────────────────────────────
    final merchantMap = <String, double>{};
    for (final t in txns.where((x) => x.isDebit)) {
      final key = t.merchant.length > 20 ? t.merchant.substring(0,20) : t.merchant;
      merchantMap[key] = (merchantMap[key] ?? 0) + t.amount;
    }
    final topMerchants = (merchantMap.entries.toList()..sort((a,b)=>b.value.compareTo(a.value))).take(10).toList();

    // ── Cumulative balance ────────────────────────────────────
    double running = 0;
    final cumulative = dayStat.map((d) {
      running += d.credit - d.debit;
      return CumulativePoint(d.dateKey, running);
    }).toList();

    return Stats(
      totalCredit:  totalCredit,
      totalDebit:   totalDebit,
      netBalance:   totalCredit - totalDebit,
      totalCount:   txns.length,
      days:         dayStat,
      weeks:        weekStat,
      sectors:      sectorStat,
      topMerchants: topMerchants,
      cumulative:   cumulative,
    );
  }
}
