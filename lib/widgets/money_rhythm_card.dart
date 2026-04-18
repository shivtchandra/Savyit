// lib/widgets/money_rhythm_card.dart
// Spending Pulse — local, history-based insights (no network).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../services/money_rhythm_service.dart';
import '../theme/app_theme.dart';

class MoneyRhythmCard extends StatelessWidget {
  const MoneyRhythmCard({super.key});

  IconData _iconFor(RhythmInsightKind k) {
    switch (k) {
      case RhythmInsightKind.cap:
        return Icons.shield_outlined;
      case RhythmInsightKind.pace:
        return Icons.trending_up_rounded;
      case RhythmInsightKind.recurring:
        return Icons.repeat_rounded;
      case RhythmInsightKind.weekendRhythm:
        return Icons.weekend_rounded;
      case RhythmInsightKind.needMoreData:
        return Icons.insights_outlined;
    }
  }

  Color _accentFor(RhythmInsightKind k, BuildContext context) {
    switch (k) {
      case RhythmInsightKind.cap:
        return AppColors.red;
      case RhythmInsightKind.pace:
        return AppColors.primary;
      case RhythmInsightKind.recurring:
        return AppColors.textSecondary;
      case RhythmInsightKind.weekendRhythm:
        return const Color(0xFF7C6F9B);
      case RhythmInsightKind.needMoreData:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransactionProvider>();
    final report = MoneyRhythmService.build(
      allTxns: p.transactions,
      sectorMonthlyLimits: p.sectorMonthlyLimits,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: AppColors.isMonochrome
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primarySoft.withValues(alpha: 0.35),
                  AppColors.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            )
          : NeoPopDecorations.card(
              fill: Color.lerp(
                AppColors.surface,
                AppColors.primarySoft,
                0.5,
              )!,
              radius: AppRadius.lg,
              shadowOffset: 5,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: AppDecorations.iconContainer(color: AppColors.primary),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAnalyticsUp,
                  color: AppColors.iconOnLight,
                  size: 22,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spending pulse',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      'From your own history — not generic tips',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          ...report.insights.map((i) {
            final accent = _accentFor(i.kind, context);
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconFor(i.kind), size: 20, color: accent),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.headline,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          i.detail,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
