import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/transaction_provider.dart';
import '../services/sms_service.dart' show sectors;
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../services/share_service.dart';

class SectorsScreen extends StatefulWidget {
  const SectorsScreen({super.key});
  @override
  State<SectorsScreen> createState() => _SectorsScreenState();
}

class _SectorsScreenState extends State<SectorsScreen> {
  int _touchedIndex = -1;

  Future<void> _showLimitSheet(
    BuildContext context,
    TransactionProvider provider,
    String sectorName,
    double? currentLimit,
  ) async {
    final sym = provider.selectedCurrency;
    final controller = TextEditingController(
      text: currentLimit != null ? currentLimit.toStringAsFixed(0) : '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: AppColors.sheetChrome,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.sheet),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Monthly Limit',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  sectorName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Monthly limit amount',
                    prefixText: '$sym ',
                    hintText: 'e.g. 5000',
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final raw = controller.text
                              .replaceAll(RegExp(r'[^0-9.]'), '');
                          if (raw.isEmpty && currentLimit != null) {
                            await provider.clearSectorMonthlyLimit(sectorName);
                            if (ctx.mounted) Navigator.pop(ctx);
                            return;
                          }
                          final amount = double.tryParse(raw);
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Enter a valid amount greater than 0'),
                              ),
                            );
                            return;
                          }
                          await provider.setSectorMonthlyLimit(
                            sectorName,
                            amount,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Save Limit'),
                      ),
                    ),
                  ],
                ),
                if (currentLimit != null) ...[
                  SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        await provider.clearSectorMonthlyLimit(sectorName);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(
                        'Clear limit',
                        style: GoogleFonts.inter(
                          color: AppColors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final sectors = provider.stats.sectors;

    if (sectors.isEmpty) {
      return _EmptySectors();
    }

    final colors = AppColors.sectorColors;
    final totalSpending = sectors.fold(0.0, (sum, s) => sum + s.amount);
    final monitoredSectors = sectors
        .where((s) => (provider.monthlyLimitForSector(s.name) ?? 0) > 0)
        .toList();

    int overCount = 0;
    int nearCount = 0;
    int onTrackCount = 0;
    for (final sector in monitoredSectors) {
      final limit = provider.monthlyLimitForSector(sector.name)!;
      final monthSpent = provider.currentMonthSpendForSector(sector.name);
      final usage = limit > 0 ? monthSpent / limit : 0;
      if (usage >= 1) {
        overCount++;
      } else if (usage >= 0.85) {
        nearCount++;
      } else {
        onTrackCount++;
      }
    }

    return SingleChildScrollView(
      padding:
          EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xl,
        AppSpacing.screenHorizontal,
        AppSpacing.scrollBottomDockClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Spending Breakdown',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'See where your money goes',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: AppSpacing.xxl),

          // Donut Chart Card
          Container(
            decoration: AppDecorations.cardElevated,
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 60,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    response == null ||
                                    response.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = response
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sections: sectors.asMap().entries.map((e) {
                            final isTouched = e.key == _touchedIndex;
                            return PieChartSectionData(
                              value: e.value.amount,
                              color: colors[e.key % colors.length],
                              radius: isTouched ? 45 : 35,
                              showTitle: false,
                            );
                          }).toList(),
                        ),
                      ),
                      // Center Label
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            provider.formatAmount(totalSpending),
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
                // Legend
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: sectors.take(6).toList().asMap().entries.map((e) {
                    final color = colors[e.key % colors.length];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          e.value.name,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.xxxl),

          if (monitoredSectors.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: AppDecorations.cardElevated,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedAlarmClock,
                          color: AppColors.isMonochrome
                              ? AppColors.primary
                              : AppColors.iconOnLight,
                          size: 18,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Monthly Limit Monitor',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _StatusPill(
                        label: '$onTrackCount on track',
                        color: AppColors.green,
                      ),
                      _StatusPill(
                        label: '$nearCount near limit',
                        color: AppColors.amber,
                      ),
                      _StatusPill(
                        label: '$overCount over limit',
                        color: AppColors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.xxxl),
          ],

          // Category List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${sectors.length} active',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),

          // Category Cards
          ...sectors.asMap().entries.map((e) {
            final sector = e.value;
            final color = colors[e.key % colors.length];
            final monthlyLimit = provider.monthlyLimitForSector(sector.name);
            final monthSpent = provider.currentMonthSpendForSector(sector.name);
            return _CategoryCard(
              sector: sector,
              color: color,
              monthlyLimit: monthlyLimit,
              monthSpent: monthSpent,
              onTap: () {
                final txns = provider.transactions
                    .where((t) => t.category == sector.name)
                    .toList();
                ShareService.shareSectorBreakdown(
                  category: sector.name,
                  amount: sector.amount,
                  totalOutflow: provider.stats.totalDebit,
                  transactions: txns,
                  currencySymbol: provider.selectedCurrency,
                );
              },
              onSetLimit: () =>
                  _showLimitSheet(context, provider, sector.name, monthlyLimit),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptySectors extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final defaultSectorNames = sectors.map((s) => s.name).toList();

    Future<void> showLimitSheet(String sectorName, double? currentLimit) async {
      final sym = provider.selectedCurrency;
      final controller = TextEditingController(
        text: currentLimit != null ? currentLimit.toStringAsFixed(0) : '',
      );

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.sheetChrome,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.sheet),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Monthly Limit',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(sectorName,
                      style: Theme.of(context).textTheme.bodyMedium),
                  SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monthly limit amount',
                      prefixText: '$sym ',
                      hintText: 'e.g. 5000',
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final raw = controller.text
                            .replaceAll(RegExp(r'[^0-9.]'), '');
                        if (raw.isEmpty && currentLimit != null) {
                          await provider.clearSectorMonthlyLimit(sectorName);
                          if (ctx.mounted) Navigator.pop(ctx);
                          return;
                        }
                        final amount = double.tryParse(raw);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Enter a valid amount greater than 0'),
                            ),
                          );
                          return;
                        }
                        await provider.setSectorMonthlyLimit(
                            sectorName, amount);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Limit'),
                    ),
                  ),
                  if (currentLimit != null) ...[
                    SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          await provider.clearSectorMonthlyLimit(sectorName);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(
                          'Clear limit',
                          style: GoogleFonts.inter(
                            color: AppColors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      padding:
          EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xl,
        AppSpacing.screenHorizontal,
        AppSpacing.scrollBottomDockClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedChartRose,
                    size: 32,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                Text(
                  'No spending data',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Set limits now and start tracking from day one',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xxxl),
          Text(
            'Set Monthly Limits',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppSpacing.lg),
          ...defaultSectorNames.map((name) {
            final limit = provider.monthlyLimitForSector(name);
            final categoryColor = AppColors.colorForCategory(name);
            return Container(
              margin: EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: AppDecorations.card,
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: AppColors.iconForCategory(name),
                      color: AppColors.glyphOnPaleAccent(categoryColor),
                      size: 18,
                    ),
                  ),
                ),
                title:
                    Text(name, style: Theme.of(context).textTheme.labelLarge),
                subtitle: Text(
                  limit != null
                      ? 'Limit: ${provider.formatAmount(limit)} / month'
                      : 'No limit set',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: (limit == null
                                ? AppColors.primarySoft
                                : AppColors.primary)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: (limit == null
                                  ? AppColors.border
                                  : AppColors.primary)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: TextButton(
                        onPressed: () => showLimitSheet(name, limit),
                        child: Text(
                          limit == null ? 'Set' : 'Edit',
                          style: GoogleFonts.inter(
                            color: limit == null
                                ? AppColors.textSecondary
                                : AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final SectorStat sector;
  final Color color;
  final double? monthlyLimit;
  final double monthSpent;
  final VoidCallback onTap;
  final VoidCallback onSetLimit;

  const _CategoryCard({
    required this.sector,
    required this.color,
    required this.monthlyLimit,
    required this.monthSpent,
    required this.onTap,
    required this.onSetLimit,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final percentage = (sector.percentage * 100).clamp(0, 100);
    final hasLimit = monthlyLimit != null && monthlyLimit! > 0;
    final double usage = hasLimit
        ? (monthSpent / monthlyLimit!).clamp(0.0, 10.0).toDouble()
        : 0.0;
    final double progress = hasLimit
        ? usage.clamp(0.0, 1.0).toDouble()
        : sector.percentage.toDouble();
    final monitorColor = !hasLimit
        ? color
        : usage >= 1
            ? AppColors.red
            : usage >= 0.85
                ? AppColors.amber
                : AppColors.green;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      decoration: AppDecorations.card,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: AppColors.iconForCategory(sector.name),
                          color: AppColors.glyphOnPaleAccent(color),
                          size: 22,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.lg),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sector.name,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            '${percentage.toStringAsFixed(1)}% of spending',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    // Amount
                    Text(
                      p.formatAmount(sector.amount),
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(monitorColor),
                    minHeight: 6,
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasLimit
                            ? 'This month: ${p.formatAmount(monthSpent)} / ${p.formatAmount(monthlyLimit!)}'
                            : 'No monthly limit set',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  hasLimit ? monitorColor : AppColors.textMuted,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: onSetLimit,
                      child: Text(hasLimit ? 'Edit Limit' : 'Set Limit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.glyphOnPaleAccent(color),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
