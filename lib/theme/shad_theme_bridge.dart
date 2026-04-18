import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app_theme.dart';

/// [shadcn_ui](https://pub.dev/packages/shadcn_ui) theme aligned with MoneyLens [AppColors].
ShadThemeData moneyLensShadThemeData() {
  final onPrimary =
      AppColors.isMonochrome ? AppColors.surface : AppNeoColors.ink;

  final scheme = ShadColorScheme(
    background: AppColors.bg,
    foreground: AppColors.textMain,
    card: AppColors.surface,
    cardForeground: AppColors.textMain,
    popover: AppColors.surface,
    popoverForeground: AppColors.textMain,
    primary: AppColors.primary,
    primaryForeground: onPrimary,
    secondary: AppColors.surfaceVariant,
    secondaryForeground: AppColors.textMain,
    muted: AppColors.surface2,
    mutedForeground: AppColors.textMuted,
    accent: AppColors.primarySoft,
    accentForeground: AppColors.primaryDark,
    destructive: AppColors.red,
    destructiveForeground: AppColors.surface,
    border: AppColors.border,
    input: AppColors.border,
    ring: AppNeoColors.lime,
    selection: AppNeoColors.lime.withValues(alpha: 0.28),
  );

  return ShadThemeData(
    brightness: Brightness.light,
    colorScheme: scheme,
    radius: BorderRadius.circular(AppRadius.md),
  );
}
