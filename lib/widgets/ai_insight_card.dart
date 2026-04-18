// lib/widgets/ai_insight_card.dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';

class AiInsightCard extends StatefulWidget {
  final double totalIncome;
  final double totalExpenses;
  final double currentBalance;
  final double savingsRate;
  final Map<String, double> categoryBreakdown;
  final String period;
  final String currencySymbol;

  const AiInsightCard({
    super.key,
    required this.totalIncome,
    required this.totalExpenses,
    required this.currentBalance,
    required this.savingsRate,
    required this.categoryBreakdown,
    required this.period,
    this.currencySymbol = '₹',
  });

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  Map<String, dynamic>? _insight;
  bool _loading = false;
  bool _hasProfile = false;
  String _userName = 'You';
  List<String> _goals = const [];

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  void _checkProfile() async {
    final done = await StorageService.isProfileComplete();
    if (mounted) setState(() => _hasProfile = done);
  }

  void _generateInsight() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final profile = await StorageService.getUserProfile();
      final name = (profile['name'] as String?)?.trim();
      _userName = (name == null || name.isEmpty) ? 'You' : name;
      _goals = (profile['goals'] as List?)?.whereType<String>().toList() ?? [];
      final financialPlan = await StorageService.getFinancialPlan();
      final result = await OpenAIService.generateFinancialInsight(
        userProfile: profile,
        totalIncome: widget.totalIncome,
        totalExpenses: widget.totalExpenses,
        currentBalance: widget.currentBalance,
        savingsRate: widget.savingsRate,
        categoryBreakdown: widget.categoryBreakdown,
        period: widget.period,
        financialPlan: financialPlan,
      );
      if (mounted) setState(() => _insight = result);
    } catch (e) {
      if (mounted) {
        setState(() => _insight = {
              'verdict': 'Error',
              'emoji': '⚠️',
              'summary': 'Something went wrong. Please try again.',
              'tips': <String>[],
            });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _primaryGoal => _goals.isNotEmpty ? _goals.first : 'your goals';

  MapEntry<String, double>? _topCategoryEntry() {
    if (widget.categoryBreakdown.isEmpty) return null;
    MapEntry<String, double>? top;
    widget.categoryBreakdown.forEach((category, amount) {
      if (amount <= 0) return;
      if (top == null || amount > top!.value) {
        top = MapEntry(category, amount);
      }
    });
    return top;
  }

  String _resolveMood() {
    final rawMood = (_insight?['mood'] as String?)?.toLowerCase();
    if (rawMood == 'happy' || rawMood == 'neutral' || rawMood == 'concerned') {
      return rawMood!;
    }

    final netFlow = widget.totalIncome - widget.totalExpenses;
    if (netFlow < 0 || widget.savingsRate < 0) return 'concerned';
    if (netFlow > 0 && widget.savingsRate >= 20) return 'happy';
    return 'neutral';
  }

  String _moodEmoji(String mood) {
    if (AppColors.isMonochrome) return '';
    switch (mood) {
      case 'happy':
        return '😄';
      case 'concerned':
        return '😟';
      default:
        return '🙂';
    }
  }

  String _moodLine(String mood) {
    final netFlow = widget.totalIncome - widget.totalExpenses;
    if (netFlow >= 0) {
      return 'You received more than you spent in ${widget.period.toLowerCase()}.';
    }
    return 'Spending is currently ahead of incoming money in ${widget.period.toLowerCase()}.';
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<dynamic>()
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Show nothing if no profile yet — the prompt banner handles that
    if (!_hasProfile && _insight == null && !_loading) {
      return const SizedBox.shrink();
    }

    // Pre-generation state: show the button
    if (_insight == null && !_loading) {
      return _buildGenerateButton();
    }

    // Loading state
    if (_loading) {
      return _buildLoadingState();
    }

    // Result state
    return _buildResultCard();
  }

  Widget _buildGenerateButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: GestureDetector(
        onTap: _generateInsight,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.heroBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedIdea01,
                  color: AppColors.isMonochrome
                      ? AppColors.primary
                      : AppColors.iconOnLight,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Deep Financial Check-up',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Detailed + personalized money analysis',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMain.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMain.withValues(alpha: 0.4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.card,
      child: Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.chartStrokeOnCard,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Analyzing your finances...',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Our AI is reviewing your profile, goals, and spending patterns',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final insight = _insight!;
    final verdict = insight['verdict'] ?? '';
    final statusIcon = insight['status_icon'] ?? 'success';
    final summary = insight['summary'] ?? '';
    final tips = _stringList(insight['tips']);
    final wins = _stringList(insight['wins']);
    final watchouts = _stringList(insight['watchouts']);
    final nextStep = (insight['next_step'] as String?)?.trim() ?? '';
    final mood = _resolveMood();
    final moodEmoji = _moodEmoji(mood);
    final moodLine =
        (insight['mood_line'] as String?)?.trim().isNotEmpty == true
            ? (insight['mood_line'] as String).trim()
            : _moodLine(mood);
    final topCategory = _topCategoryEntry();
    final netFlow = widget.totalIncome - widget.totalExpenses;
    final spendRatio = widget.totalIncome > 0
        ? (widget.totalExpenses / widget.totalIncome) * 100
        : 0.0;

    final verdictColor = verdict == 'On Track'
        ? (AppColors.isMonochrome ? AppColors.primary : AppColors.primaryDark)
        : verdict == 'Needs Attention'
            ? AppColors.accent
            : AppColors.red;

    final statusIconData = statusIcon == 'success'
        ? HugeIcons.strokeRoundedCheckmarkCircle02
        : statusIcon == 'warning'
            ? HugeIcons.strokeRoundedAlertCircle
            : HugeIcons.strokeRoundedAlert01;

    return Container(
      width: double.infinity,
      decoration: AppDecorations.cardElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: verdictColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                      icon: statusIconData, color: verdictColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI SUMMARY',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        verdict,
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: verdictColor,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _generateInsight,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.refresh_rounded,
                        size: 20, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              summary.isNotEmpty
                  ? summary
                  : '$_userName, you are focusing on $_primaryGoal. Keep this period disciplined and action-oriented.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: mood == 'happy'
                    ? [
                        AppColors.greenLight.withValues(alpha: 0.9),
                        AppColors.primarySoft.withValues(alpha: 0.9),
                      ]
                    : mood == 'concerned'
                        ? [
                            AppColors.redLight.withValues(alpha: 0.9),
                            AppColors.accentLight.withValues(alpha: 0.7),
                          ]
                        : [
                            AppColors.surfaceVariant.withValues(alpha: 0.9),
                            AppColors.surface.withValues(alpha: 0.95),
                          ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: mood == 'concerned'
                    ? AppColors.red.withValues(alpha: 0.25)
                    : AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (moodEmoji.isNotEmpty) ...[
                  Text(
                    moodEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Money Buddy Mood',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        moodLine,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  label: 'Net Flow',
                  value: netFlow >= 0
                      ? '+${widget.currencySymbol}${netFlow.toStringAsFixed(0)}'
                      : '-${widget.currencySymbol}${netFlow.abs().toStringAsFixed(0)}',
                  color: netFlow >= 0 ? AppColors.primary : AppColors.red,
                ),
                _MetricPill(
                  label: 'Spend Ratio',
                  value: '${spendRatio.toStringAsFixed(0)}%',
                  color:
                      spendRatio <= 70 ? AppColors.primary : AppColors.accent,
                ),
                if (topCategory != null)
                  _MetricPill(
                    label: 'Top Spend',
                    value:
                        '${topCategory.key} • ${widget.currencySymbol}${topCategory.value.toStringAsFixed(0)}',
                    color: AppColors.sand,
                  ),
              ],
            ),
          ),
          if (wins.isNotEmpty) ...[
            const SizedBox(height: 14),
            _InsightListBlock(
              title: 'WHAT IS GOING WELL',
              icon: HugeIcons.strokeRoundedCheckmarkBadge01,
              iconColor: AppColors.isMonochrome
                  ? AppColors.primary
                  : AppColors.iconOnLight,
              items: wins,
            ),
          ],
          if (watchouts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InsightListBlock(
              title: 'WATCH OUT',
              icon: HugeIcons.strokeRoundedAlertCircle,
              iconColor: AppColors.red,
              items: watchouts,
            ),
          ],
          // Tips
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedTree01,
                        color: AppColors.isMonochrome
                            ? AppColors.primary
                            : AppColors.iconOnLight,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ADVICE FOR YOU',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AppColors.chartStrokeOnCard
                                    .withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tip,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            if (nextStep.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 16,
                      color: AppColors.isMonochrome
                          ? AppColors.primary
                          : AppColors.iconOnLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nextStep,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightListBlock extends StatelessWidget {
  final String title;
  final dynamic icon;
  final Color iconColor;
  final List<String> items;

  const _InsightListBlock({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.take(2).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.inter(
                            fontSize: 12.8,
                            height: 1.4,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
