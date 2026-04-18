import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'fcl_theme.dart';

/// FCL “plan card” shell: scale entrance + gradient rim around a clipped surface card.
class SleekPlanHeroFrame extends StatelessWidget {
  final Widget child;

  const SleekPlanHeroFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final outerRadius = AppRadius.card + 4;
    final innerRadius = AppRadius.card;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, scale, c) => Transform.scale(scale: scale, child: c),
      child: DecoratedBox(
        decoration: AppColors.isMonochrome
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(outerRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: FclTheme.heroRimGradient,
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  width: 1.5,
                ),
                boxShadow: FclTheme.heroRimShadow(AppColors.primary),
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(outerRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: FclTheme.heroRimGradient,
                ),
                border: Border.all(
                  color: AppNeoColors.strokeBlack,
                  width: 2,
                ),
                boxShadow: NeoPopDecorations.hardShadow(
                  6,
                  color: AppNeoColors.shadowInk,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(innerRadius),
              border: Border.all(
                color: AppColors.isMonochrome
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : AppNeoColors.strokeBlack.withValues(alpha: 0.06),
                width: AppBorders.thin,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
