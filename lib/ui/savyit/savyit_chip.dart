// lib/ui/savyit/savyit_chip.dart
// Unified chip component — filter toggles, multi-select, mood labels, badge counts.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'savyit_theme.dart';

enum SavyitChipVariant { filter, select, mood, badge }

class SavyitChip extends StatelessWidget {
  final String label;
  final SavyitChipVariant variant;
  final bool selected;
  final VoidCallback? onTap;
  final Color? moodColor;
  final Widget? leading;

  const SavyitChip({
    super.key,
    required this.label,
    this.variant = SavyitChipVariant.filter,
    this.selected = false,
    this.onTap,
    this.moodColor,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final t = SavyitTheme.of(context);
    final c = t.colors;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: selected ? 1 : 0),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      builder: (_, pct, __) {
        final decoration = _decoration(c, pct);
        final textColor  = _textColor(c, pct);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: decoration,
            padding: _padding(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 5)],
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize:   _fontSize(),
                    fontWeight: FontWeight.w600,
                    color:      textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _decoration(SavyitColorTokens c, double pct) {
    switch (variant) {
      case SavyitChipVariant.filter:
        return BoxDecoration(
          color: Color.lerp(c.surface, c.primary, pct),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Color.lerp(c.border, c.primary, pct)!,
            width: 1.2,
          ),
        );

      case SavyitChipVariant.select:
        return BoxDecoration(
          color: Color.lerp(c.surface, c.primarySoft, pct),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Color.lerp(c.border, c.primary, pct)!,
            width: 1.5,
          ),
        );

      case SavyitChipVariant.mood:
        final base = moodColor ?? c.primary;
        return BoxDecoration(
          color: base.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: base.withValues(alpha: 0.35),
            width: 1,
          ),
        );

      case SavyitChipVariant.badge:
        return BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(999),
        );
    }
  }

  Color _textColor(SavyitColorTokens c, double pct) {
    switch (variant) {
      case SavyitChipVariant.filter:
        // Color mode: lime fill needs ink/body type — white washes out. Mono: black fill keeps white label.
        if (AppColors.isMonochrome) {
          return Color.lerp(c.textMuted, Colors.white, pct)!;
        }
        return Color.lerp(c.textMuted, AppNeoColors.ink, pct)!;
      case SavyitChipVariant.select:
        final end = AppColors.isMonochrome ? c.primary : AppNeoColors.ink;
        return Color.lerp(c.textMuted, end, pct)!;
      case SavyitChipVariant.mood:
        // Wash is very light; mood tint is often pastel — use body ink, not the tint as text.
        return c.textMain;
      case SavyitChipVariant.badge:
        return AppColors.labelOnSolid(c.primary);
    }
  }

  EdgeInsetsGeometry _padding() {
    switch (variant) {
      case SavyitChipVariant.badge:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
      case SavyitChipVariant.select:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 9);
      default:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 7);
    }
  }

  double _fontSize() {
    switch (variant) {
      case SavyitChipVariant.badge: return 11;
      default:                      return 13;
    }
  }
}
