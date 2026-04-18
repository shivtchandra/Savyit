// lib/screens/weekly_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chart_card.dart';

class WeeklyScreen extends StatelessWidget {
  const WeeklyScreen({super.key});

  String _weekLabel(WeekStat w) {
    final start = DateTime.parse(w.weekStart);
    final end   = start.add(const Duration(days: 6));
    return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final weeks = p.stats.weeks;
    if (weeks.isEmpty) {
      return Center(child: Text('Insufficient data for weekly analysis.', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      child: Column(children: [
        ChartCard(
          title: 'Weekly Performance',
          subtitle: 'Net progression over weeks',
          height: 300,
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: BarChart(BarChartData(
              barGroups: weeks.asMap().entries.map((e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(toY: e.value.credit, color: AppColors.green, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  BarChartRodData(toY: e.value.debit,  color: AppColors.red,   width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                ],
                barsSpace: 6,
              )).toList(),
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [5, 5])),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= weeks.length) return const SizedBox.shrink();
                    final d = DateTime.parse(weeks[i].weekStart);
                    return Padding(padding: const EdgeInsets.only(top:10),
                      child: Text(DateFormat('d MMM').format(d), style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700)));
                  },
                )),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.textMain,
                  getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                      p.formatAmount(rod.toY),
                      TextStyle(
                        color: AppColors.labelOnSolid(AppColors.textMain),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ),
            )),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(children: [
            _header(),
            ...weeks.reversed.map((w) => _row(p, w)),
          ]),
        ),
      ]),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1.2))),
    child: Row(children: [
      Expanded(flex: 4, child: Text('WEEK', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 1))),
      Expanded(flex: 2, child: Text('IN',   style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 1))),
      Expanded(flex: 2, child: Text('OUT',  style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 1))),
      Expanded(flex: 3, child: Text('NET',  textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: AppColors.textMain, fontWeight: FontWeight.w800, letterSpacing: 1))),
    ]),
  );

  Widget _row(TransactionProvider p, WeekStat w) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
    child: Row(children: [
      Expanded(flex: 4, child: Text(_weekLabel(w), style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600))),
      Expanded(flex: 2, child: Text(p.formatAmount(w.credit), style: TextStyle(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w700))),
      Expanded(flex: 2, child: Text(p.formatAmount(w.debit),  style: TextStyle(fontSize: 13, color: AppColors.red, fontWeight: FontWeight.w700))),
      Expanded(flex: 3, child: Text('${w.net >= 0 ? '+' : ''}${p.formatAmount(w.net)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: w.net >= 0 ? AppColors.green : AppColors.red, fontWeight: FontWeight.w900))),
    ]),
  );
}
