import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Maps FCL-inspired styling to MoneyLens tokens so vendored UI does not fork a second palette.
abstract final class FclTheme {
  static double get navDockRadius => AppRadius.card + 4;

  static List<Color> get heroRimGradient => AppColors.isMonochrome
      ? [
          const Color(0xFF5C5C5C),
          const Color(0xFFADADAD),
        ]
      : [
          const Color(0xFFEAE4FF),
          const Color(0xFFFFFFFF),
          const Color(0xFFFFF2EC),
        ];

  static List<BoxShadow> heroRimShadow(Color base) {
    if (AppColors.isMonochrome) {
      return AppShadows.colored(base, opacity: 0.08);
    }
    return NeoPopDecorations.hardShadow(5, color: AppNeoColors.shadowInk);
  }

  static BorderSide get hairlineBorder => BorderSide(
        color: AppColors.border.withValues(alpha: 0.7),
        width: AppBorders.normal,
      );
}
