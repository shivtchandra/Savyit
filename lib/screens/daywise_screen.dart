// lib/screens/daywise_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../providers/transaction_provider.dart';
import '../widgets/pdf_mode_sheet.dart';
import '../widgets/manual_transaction_sheet.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chart_card.dart';
import '../widgets/ai_insight_card.dart';

class DaywiseScreen extends StatefulWidget {
  const DaywiseScreen({super.key});

  @override
  State<DaywiseScreen> createState() => _DaywiseScreenState();
}

class _DaywiseScreenState extends State<DaywiseScreen> {
  int _viewDays = 7;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final stats = provider.stats;
    final days = stats.days;

    if (days.isEmpty) {
      return _EmptyDaywise(provider: provider);
    }

    // Show last X days based on user selection
    final slice =
        days.length > _viewDays ? days.sublist(days.length - _viewDays) : days;

    final savingsRate = stats.totalCredit > 0
        ? ((stats.totalCredit - stats.totalDebit) / stats.totalCredit * 100)
            .clamp(-100, 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        28,
        AppSpacing.screenHorizontal,
        AppSpacing.scrollBottomDockClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsHeader(stats),
          const SizedBox(height: 24),
          AiInsightCard(
            totalIncome: stats.totalCredit.toDouble(),
            totalExpenses: stats.totalDebit.toDouble(),
            currentBalance: stats.netBalance.toDouble(),
            savingsRate: savingsRate.toDouble(),
            categoryBreakdown: {
              for (final s in stats.sectors) s.name: s.amount,
            },
            period: provider.rangeLabel,
            currencySymbol: provider.selectedCurrency,
          ),
          const SizedBox(height: 32),
          _buildChartSection(slice),
          const SizedBox(height: 32),
          Text(
            'Daily Ledger',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
              boxShadow: AppShadows.md,
            ),
            child: Column(
              children: [
                _tableHeader(),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length > 20 ? 20 : days.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppColors.border.withValues(alpha: 0.5)),
                  itemBuilder: (context, index) =>
                      _tableRow(days.reversed.toList()[index]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(dynamic stats) {
    final p = context.watch<TransactionProvider>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _SummaryPill(
            label: 'Income',
            value: p.formatAmount(stats.totalCredit),
            color: AppColors.primary,
            icon: Icons.south_west_rounded,
          ),
          const SizedBox(width: 12),
          _SummaryPill(
            label: 'Expenses',
            value: p.formatAmount(stats.totalDebit),
            color: AppColors.red,
            icon: Icons.north_east_rounded,
          ),
          const SizedBox(width: 12),
          _SummaryPill(
            label: 'Net Period',
            value: p.formatAmount(stats.netBalance, showSign: true),
            color: stats.netBalance >= 0 ? AppColors.primary : AppColors.red,
            icon: Icons.account_balance_wallet_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(List<DayStat> slice) {
    final p = context.watch<TransactionProvider>();
    // Dynamically adjust bar width so it doesn't clutter on 30D
    final double rodWidth =
        slice.length > 20 ? 8 : (slice.length > 10 ? 12 : 16);

    // Calculate maxY from the maximum of BOTH credit and debit to prevent overflow
    double computeMaxY() {
      if (slice.isEmpty) return 1000.0;
      double maxCredit = 0;
      double maxDebit = 0;
      for (final day in slice) {
        if (day.credit > maxCredit) maxCredit = day.credit;
        if (day.debit > maxDebit) maxDebit = day.debit;
      }
      final maxValue = maxCredit > maxDebit ? maxCredit : maxDebit;
      // Add 20% headroom so bars don't touch the top
      return (maxValue * 1.2).clamp(100.0, double.infinity);
    }

    final chartMaxY = computeMaxY();

    return ChartCard(
      title: 'Daily Cash Flow',
      subtitle: 'Comparing daily inflow vs outflow',
      height: 340,
      action: _buildDaySelector(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _LegendItem(color: AppColors.chartStrokeOnCard, label: 'Inflow'),
              const SizedBox(width: 16),
              _LegendItem(color: AppColors.red, label: 'Outflow'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: chartMaxY,
              barGroups: slice
                  .asMap()
                  .entries
                  .map((e) => BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.credit,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.chartStrokeOnCard,
                                AppColors.chartStrokeOnCard
                                    .withValues(alpha: 0.45),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            width: rodWidth,
                            borderRadius:
                                BorderRadius.all(Radius.circular(rodWidth / 2)),
                          ),
                          BarChartRodData(
                            toY: e.value.debit,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.red,
                                AppColors.red.withValues(alpha: 0.6)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            width: rodWidth,
                            borderRadius:
                                BorderRadius.all(Radius.circular(rodWidth / 2)),
                          ),
                        ],
                        barsSpace: 4,
                      ))
                  .toList(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: null,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.textMain.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= slice.length) {
                      return const SizedBox.shrink();
                    }
                    final d = DateTime.parse(slice[i].dateKey);
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(DateFormat('d MMM').format(d),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700)),
                    );
                  },
                )),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.textMain,
                  tooltipRoundedRadius: 12,
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                      '${ri == 0 ? 'In: ' : 'Out: '}${p.formatAmount(rod.toY)}',
                      TextStyle(
                          color: AppColors.labelOnSolid(AppColors.textMain),
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.3),
          border: Border(
              bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.8), width: 1.5)),
        ),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: Text('DATE',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1))),
          Expanded(
              flex: 2,
              child: Text('IN',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1))),
          Expanded(
              flex: 2,
              child: Text('OUT',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1))),
          Expanded(
              flex: 3,
              child: Text('NET',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1))),
        ]),
      );

  Widget _tableRow(DayStat d) {
    final p = context.watch<TransactionProvider>();
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('d MMM').format(DateTime.parse(d.dateKey)),
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w700)),
                  Text(DateFormat('EEEE').format(DateTime.parse(d.dateKey)),
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500)),
                ],
              )),
          Expanded(
              flex: 2,
              child: Text(p.formatAmount(d.credit),
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.accentTextOnSurface,
                      fontWeight: FontWeight.w800))),
          Expanded(
              flex: 2,
              child: Text(p.formatAmount(d.debit),
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.red,
                      fontWeight: FontWeight.w800))),
          Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (d.net >= 0 ? AppColors.primary : AppColors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${d.net >= 0 ? '+' : ''}${p.formatAmount(d.net)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: d.net >= 0
                            ? AppColors.accentTextOnSurface
                            : AppColors.red,
                        fontWeight: FontWeight.w900)),
              )),
        ]),
      );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [7, 14, 30].map((d) {
          final isSelected = _viewDays == d;
          return GestureDetector(
            onTap: () => setState(() => _viewDays = d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected ? AppShadows.sm : [],
              ),
              child: Text(
                '${d}D',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? AppColors.accentTextOnSurface
                      : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyDaywise extends StatelessWidget {
  final TransactionProvider provider;
  const _EmptyDaywise({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasAnyData = provider.transactions.isNotEmpty;
    final stats = provider.stats;
    final savingsRate = stats.totalCredit > 0
        ? ((stats.totalCredit - stats.totalDebit) / stats.totalCredit * 100)
            .clamp(-100, 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        32,
        AppSpacing.screenHorizontal,
        AppSpacing.scrollBottomDockClearance,
      ),
      child: Column(
        children: [
          if (hasAnyData) ...[
            AiInsightCard(
              totalIncome: stats.totalCredit.toDouble(),
              totalExpenses: stats.totalDebit.toDouble(),
              currentBalance: stats.netBalance.toDouble(),
              savingsRate: savingsRate.toDouble(),
              categoryBreakdown: {
                for (final s in stats.sectors) s.name: s.amount,
              },
              period: provider.rangeLabel,
              currencySymbol: provider.selectedCurrency,
            ),
            SizedBox(height: AppSpacing.xl),
          ],
          Container(
            padding: EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAnalytics01,
              size: 44,
              color: AppColors.isMonochrome
                  ? AppColors.primary
                  : AppColors.iconOnLight,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          Text(
            hasAnyData ? 'No stats in this period' : 'Stats Need Data',
            style: Theme.of(context).textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            hasAnyData
                ? 'Try another date range from the top period selector.'
                : 'Import transactions to unlock daily trends and cashflow analysis.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (!hasAnyData) ...[
            SizedBox(height: AppSpacing.xxxl),
            _EmptyActionOption(
              icon: HugeIcons.strokeRoundedMessage01,
              title: 'Scan SMS',
              subtitle: 'Import from bank messages',
              color: AppColors.primary,
              onTap: provider.load,
            ),
            SizedBox(height: AppSpacing.md),
            _EmptyActionOption(
              icon: HugeIcons.strokeRoundedFileAttachment,
              title: 'Import PDF',
              subtitle: 'Upload bank statements',
              color: AppColors.primary,
              onTap: () => _openPdfFlow(context, provider),
            ),
            SizedBox(height: AppSpacing.md),
            _EmptyActionOption(
              icon: HugeIcons.strokeRoundedPencilEdit01,
              title: 'Add Manually',
              subtitle: 'Enter transactions by hand',
              color: AppColors.primary,
              onTap: () => _openManualEntry(context, provider),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPdfFlow(
      BuildContext context, TransactionProvider provider) async {
    final mode = await showPdfChunkModeSheet(context);
    if (mode == null) return;
    provider.processPdf(mode: mode);
  }

  Future<void> _openManualEntry(
      BuildContext context, TransactionProvider provider) async {
    final draft = await showManualTransactionSheet(context);
    if (draft == null) return;
    provider.addManualTransaction(
      merchant: draft.merchant,
      amount: draft.amount,
      type: draft.type,
      category: draft.category,
      bank: draft.bank,
      date: draft.date,
    );
  }
}

class _EmptyActionOption extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _EmptyActionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: AppDecorations.card,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: AppDecorations.iconContainer(color: color),
                child: HugeIcon(
                  icon: icon,
                  color: AppColors.isMonochrome ? color : AppColors.iconOnLight,
                  size: 22,
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    SizedBox(height: AppSpacing.xs),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryPill(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.border.withValues(alpha: 0.8), width: 1.5),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: AppColors.glyphOnPaleAccent(color),
                ),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMain,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted)),
      ],
    );
  }
}
