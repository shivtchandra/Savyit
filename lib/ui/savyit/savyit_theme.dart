// lib/ui/savyit/savyit_theme.dart
// Design token foundation — all components read from SavyitTheme.of(context).
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ── Color tokens ──────────────────────────────────────────────────────────────
class SavyitColorTokens {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primarySoft;
  final Color surface;
  final Color border;
  final Color borderLight;
  final Color error;
  final Color textMain;
  final Color textMuted;
  final Color textHint;
  // Neons — blob/mascot/CTA only
  final Color lime;
  final Color tealInk;

  const SavyitColorTokens({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primarySoft,
    required this.surface,
    required this.border,
    required this.borderLight,
    required this.error,
    required this.textMain,
    required this.textMuted,
    required this.textHint,
    required this.lime,
    required this.tealInk,
  });

  factory SavyitColorTokens.defaults() => SavyitColorTokens(
    primary:      AppColors.primary,
    primaryDark:  AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    primarySoft:  AppColors.primarySoft,
    surface:      AppColors.surface,
    border:       AppColors.border,
    borderLight:  AppColors.borderLight,
    error:        AppColors.red,
    textMain:     AppColors.textMain,
    textMuted:    AppColors.textMuted,
    textHint:     AppColors.textHint,
    lime:         AppNeoColors.lime,
    tealInk:      AppNeoColors.tealInk,
  );
}

// ── Shape tokens ──────────────────────────────────────────────────────────────
class SavyitShapeTokens {
  final double tight;
  final double compact;
  final double card;
  final double large;
  final double full;

  const SavyitShapeTokens({
    this.tight   = 8,
    this.compact = 12,
    this.card    = 16,
    this.large   = 20,
    this.full    = 999,
  });
}

// ── Motion tokens ─────────────────────────────────────────────────────────────
class SavyitMotionTokens {
  final Duration fast;    // press snap
  final Duration normal;  // chip select
  final Duration slow;    // card hover lift
  final Curve easeOut;
  final Curve spring;

  const SavyitMotionTokens({
    this.fast   = const Duration(milliseconds: 80),
    this.normal = const Duration(milliseconds: 180),
    this.slow   = const Duration(milliseconds: 300),
    this.easeOut = Curves.easeOut,
    this.spring  = Curves.elasticOut,
  });
}

// ── Shadow tokens ─────────────────────────────────────────────────────────────
class SavyitShadowTokens {
  const SavyitShadowTokens();

  List<BoxShadow> sm(Color base) {
    if (AppColors.isMonochrome) {
      return [
        BoxShadow(
          color: base.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];
    }
    return NeoPopDecorations.hardShadow(4);
  }

  List<BoxShadow> md(Color base) {
    if (AppColors.isMonochrome) {
      return [
        BoxShadow(
          color: base.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
    }
    return NeoPopDecorations.hardShadow(6);
  }

  List<BoxShadow> pop(Color base, {double offset = 5}) => [
    BoxShadow(
      color: base,
      offset: Offset(offset, offset),
      blurRadius: 0,
    ),
  ];
}

// ── Theme data ────────────────────────────────────────────────────────────────
class SavyitThemeData {
  final SavyitColorTokens colors;
  final SavyitShapeTokens shapes;
  final SavyitMotionTokens motion;
  final SavyitShadowTokens shadows;

  const SavyitThemeData({
    required this.colors,
    required this.shapes,
    required this.motion,
    required this.shadows,
  });

  factory SavyitThemeData.defaults() => SavyitThemeData(
    colors:  SavyitColorTokens.defaults(),
    shapes:  const SavyitShapeTokens(),
    motion:  const SavyitMotionTokens(),
    shadows: const SavyitShadowTokens(),
  );
}

// ── InheritedWidget ───────────────────────────────────────────────────────────
class SavyitTheme extends InheritedWidget {
  final SavyitThemeData data;

  const SavyitTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static SavyitThemeData of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<SavyitTheme>();
    return result?.data ?? SavyitThemeData.defaults();
  }

  @override
  bool updateShouldNotify(SavyitTheme old) => data != old.data;
}
