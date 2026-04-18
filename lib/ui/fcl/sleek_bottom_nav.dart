import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../theme/app_theme.dart';
import 'fcl_theme.dart';

class SleekNavItem {
  final dynamic icon;
  final String label;

  const SleekNavItem({required this.icon, required this.label});
}

/// FCL-style docked nav: rounded bar + FAB notch via [BottomAppBar]; selection via icon/label only.
class SleekDockedBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<SleekNavItem> items;
  final ValueChanged<int> onTap;
  final double fabGapWidth;

  const SleekDockedBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.fabGapWidth = 56,
  }) : assert(items.length == 4);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 88,
      padding: EdgeInsets.zero,
      color: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: DecoratedBox(
          decoration: AppColors.isMonochrome
              ? BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(FclTheme.navDockRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(AppColors.surface, Colors.white, 0.08)!,
                      AppColors.surface,
                    ],
                  ),
                  border: Border.all(
                    color: FclTheme.hairlineBorder.color,
                    width: FclTheme.hairlineBorder.width,
                  ),
                  boxShadow: AppShadows.md,
                )
              : NeoPopDecorations.card(
                  fill: AppColors.surface,
                  radius: FclTheme.navDockRadius,
                  shadowOffset: 5,
                ),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                Expanded(child: _slot(context, 0)),
                Expanded(child: _slot(context, 1)),
                SizedBox(width: fabGapWidth),
                Expanded(child: _slot(context, 2)),
                Expanded(child: _slot(context, 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, int i) {
    final item = items[i];
    final selected = currentIndex == i;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(i),
        borderRadius: BorderRadius.circular(12),
        splashColor:
            AppColors.primarySoft.withValues(alpha: AppColors.isMonochrome ? 0.35 : 0.5),
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: AppHitTarget.min,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    begin: AppColors.textMuted,
                    end: selected
                        ? (AppColors.isMonochrome
                            ? AppColors.primary
                            : AppNeoColors.strokeBlack)
                        : AppColors.textMuted,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  builder: (context, color, child) => HugeIcon(
                    icon: item.icon,
                    color: color ?? AppColors.textMuted,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? (AppColors.isMonochrome
                          ? AppColors.primary
                          : AppNeoColors.strokeBlack)
                      : AppColors.textMuted,
                  letterSpacing: -0.1,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
