// lib/screens/financial_plan_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../ui/savyit/index.dart';
import '../widgets/grid_background.dart';
import 'home_screen.dart';

// ── Plan screen tokens (same language as rest of app: neo + AppColors) ──
abstract final class _PlanColors {
  static Color get card => AppColors.surface;
  /// “Needs” / primary metric emphasis.
  static Color get accent =>
      AppColors.isMonochrome ? AppColors.textMain : AppNeoColors.royal;
  static Color get success =>
      AppColors.isMonochrome ? const Color(0xFF2A2A2A) : AppNeoColors.mint;
  static Color get gold =>
      AppColors.isMonochrome ? const Color(0xFF555555) : AppNeoColors.amber;
  static Color get danger => AppColors.red;
  static Color get sand => AppColors.sand;
  static Color get textDark => AppColors.textMain;
  static Color get textMid => AppColors.textSecondary;
  static Color get textLight => AppColors.textMuted;
  static Color get heroFill =>
      AppColors.isMonochrome ? AppColors.surface2 : AppNeoColors.lime;
  /// Icon wells / soft fills on white cards.
  static Color get wellWash => AppColors.isMonochrome
      ? AppColors.surface2
      : AppNeoColors.lime.withValues(alpha: 0.22);
}

class FinancialPlanScreen extends StatefulWidget {
  final bool fromOnboarding;
  const FinancialPlanScreen({super.key, this.fromOnboarding = false});

  @override
  State<FinancialPlanScreen> createState() => _FinancialPlanScreenState();
}

class _FinancialPlanScreenState extends State<FinancialPlanScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  double _monthlyIncome = 0;
  double _recommendedSavingsRate = 0;
  double _monthlySavings = 0;
  double _monthlyInvestment = 0;
  double _monthlyNeeds = 0;
  double _monthlyWants = 0;
  String _ruleLabel = '';
  List<_Projection> _projections = [];
  List<_GoalAdvice> _goalAdvice = [];

  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadAndCompute();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _loadAndCompute() async {
    try {
      final profile = await StorageService.getUserProfile();
      final income = _parseIncome(profile['monthlyIncome'] ?? '');
      final age = _parseAge(profile['ageRange'] ?? '');
      final occupation = profile['occupation'] ?? '';
      final goals = List<String>.from(profile['goals'] ?? []);

      double savingsRate;
      if (age < 25) {
        savingsRate = occupation == 'Student' ? 15 : 30;
      } else if (age < 35) {
        savingsRate = 30;
      } else if (age < 45) {
        savingsRate = 35;
      } else if (age < 55) {
        savingsRate = 40;
      } else {
        savingsRate = 25;
      }

      final needs = income * 0.50;
      final wantsPercent = (1.0 - savingsRate / 100 - 0.50).clamp(0.10, 0.40);
      final wants = income * wantsPercent;
      final savings = income * (savingsRate / 100);
      final investable = savings * 0.70;

      _ruleLabel = '50-${(wantsPercent * 100).toInt()}-${savingsRate.toInt()}';
      _recommendedSavingsRate = savingsRate;

      final projections = <_Projection>[];
      for (final years in [5, 10, 20, 30]) {
        projections.add(_Projection(
          years: years,
          invested: investable * 12 * years,
          at8: _futureValue(investable, 0.08, years),
          at10: _futureValue(investable, 0.10, years),
          at12: _futureValue(investable, 0.12, years),
        ));
      }

      final advice = <_GoalAdvice>[];
      for (final goal in goals) {
        advice.add(_getGoalAdvice(goal, income, age, investable));
      }

      StorageService.saveFinancialPlan({
        'monthlyIncome': income,
        'savingsRate': savingsRate,
        'monthlySavings': savings,
        'monthlyInvestment': investable,
        'goals': goals,
        'generatedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _profile = profile;
          _monthlyIncome = income;
          _monthlySavings = savings;
          _monthlyInvestment = investable;
          _monthlyNeeds = needs;
          _monthlyWants = wants;
          _projections = projections;
          _goalAdvice = advice;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Plan error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  double _parseIncome(String range) {
    if (range.contains('< ₹15K')) return 12000;
    if (range.contains('15K – 30K')) return 22500;
    if (range.contains('30K – 50K')) return 40000;
    if (range.contains('50K – 1L')) return 75000;
    if (range.contains('1L – 3L')) return 200000;
    if (range.contains('3L+')) return 450000;
    return 25000;
  }

  int _parseAge(String range) {
    if (range.contains('18')) return 20;
    if (range.contains('23')) return 25;
    if (range.contains('28')) return 31;
    if (range.contains('36')) return 40;
    if (range.contains('46')) return 50;
    if (range.contains('55')) return 58;
    return 28;
  }

  double _futureValue(double monthlySIP, double annualRate, int years) {
    final r = annualRate / 12;
    final n = years * 12;
    return monthlySIP * ((math.pow(1 + r, n) - 1) / r) * (1 + r);
  }

  _GoalAdvice _getGoalAdvice(
      String goal, double income, int age, double investable) {
    switch (goal) {
      case 'Save More':
        return _GoalAdvice(
          icon: HugeIcons.strokeRoundedMoney03,
          title: 'Save More',
          color: _PlanColors.success,
          advice:
              'Automate ₹${_fmt(investable * 0.3)}/mo into a savings account. In 5 years at 7%, this becomes ₹${_fmt(_futureValue(investable * 0.3, 0.07, 5))}.',
        );
      case 'Pay Off Debt':
        return _GoalAdvice(
          icon: HugeIcons.strokeRoundedMoney03,
          title: 'Pay Off Debt',
          color: _PlanColors.danger,
          advice:
              'Use the avalanche method — put extra ₹${_fmt(investable * 0.5)}/mo toward your highest-interest debt first.',
        );
      case 'Emergency Fund':
        final target = income * 6;
        final months =
            investable > 0 ? (target / (investable * 0.4)).ceil() : 36;
        return _GoalAdvice(
          icon: HugeIcons.strokeRoundedShield01,
          title: 'Emergency Fund',
          color: _PlanColors.sand,
          advice:
              'Target: ₹${_fmt(target)} (6 months). At ₹${_fmt(investable * 0.4)}/mo, build this in ~$months months. Park in a liquid fund.',
        );
      case 'Invest Wisely':
        return _GoalAdvice(
          icon: HugeIcons.strokeRoundedChartIncrease,
          title: 'Invest Wisely',
          color: _PlanColors.accent,
          advice: age < 35
              ? 'Go 70% equity (index funds) + 30% debt. ₹${_fmt(investable)} SIP for 20y at 12% = ₹${_fmt(_futureValue(investable, 0.12, 20))}!'
              : 'Balance 50-50 equity-debt. ₹${_fmt(investable)} SIP at 10% for 15y = ₹${_fmt(_futureValue(investable, 0.10, 15))}.',
        );
      case 'Track Everything':
        final parts = _ruleLabel.split('-');
        final wantsPercent = parts.length > 1 ? parts[1] : '20';
        return _GoalAdvice(
          icon: HugeIcons.strokeRoundedAnalytics01,
          title: 'Track Everything',
          color: _PlanColors.gold,
          advice:
              'You\'re here! Review weekly. Budgets: Needs ≤50%, Wants ≤$wantsPercent%, Savings ≥${_recommendedSavingsRate.toInt()}%.',
        );
      case 'Live Freely':
        final fireNumber = income * 12 * 25;
        return _GoalAdvice(
          icon: HugeIcons.strokeRoundedTree01,
          title: 'Financial Freedom',
          color: _PlanColors.success,
          advice:
              'FIRE number: ₹${_fmt(fireNumber)}. Investing ₹${_fmt(investable)}/mo at 12%, reach in ~${_yearsToFire(investable, 0.12, fireNumber)}y.',
        );
      default:
        return _GoalAdvice(
            icon: HugeIcons.strokeRoundedTarget02,
            title: goal,
            color: _PlanColors.accent,
            advice: 'Keep tracking your progress!');
    }
  }

  int _yearsToFire(double monthly, double rate, double target) {
    if (monthly <= 0) return 60;
    for (int y = 1; y <= 60; y++) {
      if (_futureValue(monthly, rate, y) >= target) return y;
    }
    return 60;
  }

  String _fmt(double val) {
    if (val >= 10000000) return '${(val / 10000000).toStringAsFixed(1)}Cr';
    if (val >= 100000) return '${(val / 100000).toStringAsFixed(1)}L';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }

  void _onDone() {
    if (widget.fromOnboarding) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        patternColor: AppColors.isMonochrome
            ? null
            : AppNeoColors.shadowInk.withValues(alpha: 0.12),
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            _buildHero(context),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildBudgetCard()),
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildInvestmentCard()),
            if (_goalAdvice.isNotEmpty) ...[
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(child: _buildGoalPlaybook()),
            ],
            SliverToBoxAdapter(child: const SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildFooter()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        patternColor: AppColors.isMonochrome
            ? null
            : AppNeoColors.shadowInk.withValues(alpha: 0.12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (_, __) => Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.isMonochrome
                        ? AppColors.textMain
                        : AppNeoColors.lime,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.isMonochrome
                          ? AppColors.border
                          : AppNeoColors.strokeBlack,
                      width: 2,
                    ),
                    boxShadow: AppColors.isMonochrome
                        ? AppShadows.sm
                        : NeoPopDecorations.hardShadow(4),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAnalytics01,
                      color: AppColors.isMonochrome
                          ? AppColors.surface
                          : AppNeoColors.ink,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Crunching numbers...',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _PlanColors.textMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────
  Widget _buildHero(BuildContext context) {
    final firstName = _profile['name']?.toString().split(' ').first ?? 'Your';
    final ink = AppColors.isMonochrome ? AppColors.textMain : AppNeoColors.ink;
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, MediaQuery.of(context).padding.top + 16, 24, 32),
        decoration: BoxDecoration(
          color: _PlanColors.heroFill,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          border: Border.all(
            color: AppColors.border,
            width: AppBorders.normal,
          ),
          boxShadow: AppColors.isMonochrome
              ? AppShadows.sm
              : NeoPopDecorations.hardShadow(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Row(
              children: [
                if (!widget.fromOnboarding)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          width: AppBorders.normal,
                        ),
                        boxShadow: AppColors.isMonochrome
                            ? null
                            : NeoPopDecorations.hardShadow(3),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: ink, size: 20),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.isMonochrome
                        ? AppColors.surface2
                        : AppNeoColors.pink,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 2),
                    boxShadow: AppColors.isMonochrome
                        ? null
                        : NeoPopDecorations.hardShadow(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: ink, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'AI PLAN',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ink,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "$firstName's",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ink.withValues(alpha: 0.72),
              ),
            ),
            Text(
              'Financial Plan',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    height: 1.1,
                  ) ??
                  GoogleFonts.fraunces(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    height: 1.1,
                  ),
            ),
            const SizedBox(height: 20),
            // Income + SIP summary row
            Row(
              children: [
                _HeroPill(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Income',
                  value: '₹${_fmt(_monthlyIncome)}/mo',
                ),
                const SizedBox(width: 10),
                _HeroPill(
                  icon: Icons.trending_up_rounded,
                  label: 'SIP',
                  value: '₹${_fmt(_monthlyInvestment)}/mo',
                ),
                const SizedBox(width: 10),
                _HeroPill(
                  icon: Icons.savings_outlined,
                  label: 'Save',
                  value: '${_recommendedSavingsRate.toInt()}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Budget Card ──────────────────────────────────────────────
  Widget _buildBudgetCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _PlanColors.wellWash,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: HugeIcon(
                    icon: HugeIcons.strokeRoundedAnalytics01,
                    color: AppColors.iconOnLight,
                    size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Budget Rule',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _PlanColors.textDark,
                      )),
                  Text(_ruleLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentTextOnSurface,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Animated budget bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  Expanded(
                    flex: 50,
                    child: Container(color: _PlanColors.accent),
                  ),
                  Expanded(
                    flex: ((1.0 - _recommendedSavingsRate / 100 - 0.50)
                                .clamp(0.10, 0.40) *
                            100)
                        .toInt(),
                    child: Container(color: _PlanColors.gold),
                  ),
                  Expanded(
                    flex: _recommendedSavingsRate.toInt(),
                    child: Container(color: _PlanColors.success),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _BudgetTile(
                  label: 'Needs',
                  amount: _fmt(_monthlyNeeds),
                  color: _PlanColors.accent,
                  icon: HugeIcons.strokeRoundedHome01),
              const SizedBox(width: 8),
              _BudgetTile(
                  label: 'Wants',
                  amount: _fmt(_monthlyWants),
                  color: _PlanColors.gold,
                  icon: HugeIcons.strokeRoundedPizza01),
              const SizedBox(width: 8),
              _BudgetTile(
                  label: 'Savings',
                  amount: _fmt(_monthlySavings),
                  color: _PlanColors.success,
                  icon: HugeIcons.strokeRoundedMoney03),
            ],
          ),
        ],
      ),
    );
  }

  // ── Investment Card ──────────────────────────────────────────
  Widget _buildInvestmentCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _PlanColors.wellWash,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: HugeIcon(
                    icon: HugeIcons.strokeRoundedRocket,
                    color: AppColors.iconOnLight,
                    size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Growth Projections',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _PlanColors.textDark,
                      )),
                  Text('₹${_fmt(_monthlyInvestment)}/mo SIP',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentTextOnSurface,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Projection cards row
          ..._projections.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final isHighlight = p.years == 20;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 400 + i * 100),
              curve: Curves.easeOutCubic,
              builder: (_, val, child) => Opacity(
                opacity: val,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - val)),
                  child: child,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isHighlight
                      ? AppNeoColors.lime.withValues(alpha: 0.35)
                      : AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isHighlight
                        ? AppNeoColors.strokeBlack
                        : AppColors.border,
                    width: 2,
                  ),
                  boxShadow: isHighlight && !AppColors.isMonochrome
                      ? NeoPopDecorations.hardShadow(4)
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isHighlight
                            ? (AppColors.isMonochrome
                                ? AppColors.textMain
                                : AppNeoColors.pink)
                            : AppColors.sandLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${p.years}y',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isHighlight
                                ? AppColors.labelOnSolid(
                                    AppColors.isMonochrome
                                        ? AppColors.textMain
                                        : AppNeoColors.pink)
                                : AppColors.textMain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Invested ₹${_fmt(p.invested)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _PlanColors.textLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isHighlight)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.isMonochrome
                                        ? AppColors.surface2
                                        : AppNeoColors.pink,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedStar,
                                        color: AppColors.iconOnLight,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'BEST',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.iconOnLight,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _RateChip('8%', _fmt(p.at8), _PlanColors.textMid),
                              _RateChip(
                                  '10%', _fmt(p.at10), AppNeoColors.royal),
                              _RateChip(
                                  '12%', _fmt(p.at12), _PlanColors.success),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          // Highlight banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppNeoColors.mint.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border, width: 2),
              boxShadow: AppColors.isMonochrome
                  ? null
                  : NeoPopDecorations.hardShadow(3),
            ),
            child: Row(
              children: [
                HugeIcon(
                    icon: HugeIcons.strokeRoundedMagicWand01,
                    color: AppColors.iconOnLight,
                    size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '₹${_fmt(_monthlyInvestment)}/mo at 12% for 20y = ₹${_fmt(_projections.length > 2 ? _projections[2].at12 : 0)}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Goal Playbook ────────────────────────────────────────────
  Widget _buildGoalPlaybook() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _PlanColors.wellWash,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: HugeIcon(
                    icon: HugeIcons.strokeRoundedTarget02,
                    color: AppColors.iconOnLight,
                    size: 18),
              ),
              const SizedBox(width: 12),
              Text('Your Goal Playbook',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _PlanColors.textDark,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          ..._goalAdvice.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + i * 150),
              curve: Curves.easeOutCubic,
              builder: (_, val, child) => Opacity(
                opacity: val,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - val)),
                  child: child,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border, width: 2),
                  boxShadow: AppColors.isMonochrome
                      ? AppShadows.sm
                      : NeoPopDecorations.hardShadow(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      child: Center(
                          child: HugeIcon(
                              icon: a.icon,
                              color: AppColors.glyphOnPaleAccent(a.color),
                              size: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _PlanColors.textDark,
                              )),
                          const SizedBox(height: 4),
                          Text(a.advice,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _PlanColors.textMid,
                                height: 1.5,
                              )),
                        ],
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

  // ── Footer ───────────────────────────────────────────────────
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        children: [
          Text(
            '⚠️ General guidance only — not professional financial advice.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 11, color: _PlanColors.textLight, height: 1.4),
          ),
          const SizedBox(height: 20),
          SavyitTheme(
            data: SavyitThemeData.defaults(),
            child: SavyitButton(
              label: widget.fromOnboarding ? 'Start tracking' : 'Got it!',
              onTap: _onDone,
              variant: AppColors.isMonochrome
                  ? SavyitButtonVariant.primary
                  : SavyitButtonVariant.cta,
              width: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ───────────────────────────────────────────────

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeroPill(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.isMonochrome ? AppColors.textMain : AppNeoColors.ink;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 2),
          boxShadow: AppColors.isMonochrome
              ? AppShadows.sm
              : NeoPopDecorations.hardShadow(4),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: ink.withValues(alpha: 0.65)),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ink.withValues(alpha: 0.72),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppColors.isMonochrome
            ? BoxDecoration(
                color: _PlanColors.card,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border, width: 1.2),
                boxShadow: AppShadows.sm,
              )
            : NeoPopDecorations.card(
                fill: _PlanColors.card,
                radius: AppRadius.xl,
                shadowOffset: 5,
              ),
        child: child,
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final dynamic icon;
  const _BudgetTile(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 2),
          boxShadow: AppColors.isMonochrome ? null : NeoPopDecorations.hardShadow(3),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: icon,
              color: AppColors.glyphOnPaleAccent(color),
              size: 18,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _PlanColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₹$amount',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _PlanColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  final String rate;
  final String value;
  final Color color;
  const _RateChip(this.rate, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: AppBorders.normal),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rate,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _PlanColors.textMid,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '₹$value',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _PlanColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data Models ──────────────────────────────────────────────────
class _Projection {
  final int years;
  final double invested;
  final double at8;
  final double at10;
  final double at12;
  const _Projection(
      {required this.years,
      required this.invested,
      required this.at8,
      required this.at10,
      required this.at12});
}

class _GoalAdvice {
  final dynamic icon;
  final String title;
  final String advice;
  final Color color;
  const _GoalAdvice(
      {required this.icon,
      required this.title,
      required this.advice,
      required this.color});
}
