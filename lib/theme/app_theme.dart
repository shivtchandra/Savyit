// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class AppColors {
  static bool isMonochrome = false;

  // ── Core Colors ──────────────────────────────────────────────
  /// Page chrome behind gradients; solid fallback when no gradient is drawn.
  /// Color mode matches [AppGradients.pageVertical] top stop so the app bar does
  /// not show a different purple band above the body gradient / greeting card.
  /// Align with [AppGradients.monoPageVertical] top stop so chrome matches the canvas.
  static Color get bg =>
      isMonochrome ? const Color(0xFFE4E4E4) : const Color(0xFFEDE7FF);
  static Color get surface => const Color(0xFFFFFFFF);
  static Color get surfaceVariant =>
      isMonochrome ? const Color(0xFFE0E0E0) : const Color(0xFFFFF5F0);
  static Color get surface2 =>
      isMonochrome ? const Color(0xFFF2F2F2) : const Color(0xFFF8FAFF);

  /// Bottom sheet backdrop behind inner white [controlSurface] / neo cards.
  /// Avoids white-on-white between the sheet plane and row tiles.
  static Color get sheetChrome => surface2;

  /// UI outlines (neo: near-black like reference screens).
  static Color get border =>
      isMonochrome ? const Color(0xFFC6C6C6) : AppNeoColors.strokeBlack;
  static Color get borderLight =>
      isMonochrome ? const Color(0xFFD8D8D8) : const Color(0xFFE8E4F0);

  /// Greeting strip on overview — lavender that blends with [AppGradients.pageVertical].
  static Color get greetingLavender =>
      isMonochrome ? surface2 : const Color(0xFFEDE7FF);

  // ── Text ─────────────────────────────────────────────────────
  static Color get textMain =>
      isMonochrome ? const Color(0xFF141414) : const Color(0xFF221E20);
  static Color get textSecondary =>
      isMonochrome ? const Color(0xFF4A4A4A) : const Color(0xFF3A3336);
  static Color get textMuted =>
      isMonochrome ? const Color(0xFF8A8A8A) : const Color(0xFF595155);
  static Color get textHint =>
      isMonochrome ? const Color(0xFFC0C0C0) : const Color(0xFF7D7378);

  /// Text/icons on an opaque colored fill (chips, pills). Avoids light-on-light
  /// (e.g. white on lime) and dark-on-dark; aligns with [ColorScheme.onPrimary] for [primary].
  static Color labelOnSolid(Color background) {
    final lum = background.computeLuminance();
    if (lum > 0.5) {
      return isMonochrome ? textMain : AppNeoColors.ink;
    }
    return Colors.white;
  }

  /// Icons, logos, wordmarks, and strokes on [surface], sheets, and pale brand chips.
  /// In color mode use near-black ink — never [primary] (lime) there; it fails on white.
  /// ([shadowInk] on pale lime reads as “dark on dark” to many users.)
  static Color get iconOnLight =>
      isMonochrome ? textMain : AppNeoColors.ink;

  /// Alias for [iconOnLight] — use at call sites for “logo / mark on card”.
  static Color get logoOnSurface => iconOnLight;

  /// Links and small accent labels on white / card (avoid lime body text).
  static Color get accentTextOnSurface =>
      isMonochrome ? primary : primaryDark;

  /// Chart lines and dots on light card backgrounds.
  static Color get chartStrokeOnCard =>
      isMonochrome ? primary : primaryDark;

  /// Icon / glyph color when the parent uses [accent] only as a pale wash (alpha chip).
  /// Avoids lime-on-lime; keeps saturated accents (red, etc.) as-is.
  static Color glyphOnPaleAccent(Color accent) {
    if (isMonochrome) return accent;
    if (accent.computeLuminance() > 0.55) return iconOnLight;
    return accent;
  }

  // ── Brand ────────────────────────────────────────────────────
  /// Pastel storage mode is visually the Soft Neobrutalist branch (lime + ink).
  static Color get primary =>
      isMonochrome ? const Color(0xFF0A0A0A) : AppNeoColors.lime;
  static Color get primaryDark =>
      isMonochrome ? const Color(0xFF000000) : AppNeoColors.shadowInk;
  static Color get primaryLight =>
      isMonochrome ? const Color(0xFF333333) : const Color(0xFFE8FFB3);
  static Color get primarySoft =>
      isMonochrome ? const Color(0xFFF5F5F5) : AppNeoColors.lime.withValues(alpha: 0.22);

  /// Decorative accent — same hue family as [primary] for a calm, minimal shell.
  static Color get accent =>
      isMonochrome ? const Color(0xFF636363) : primaryDark;
  static Color get accentLight =>
      isMonochrome ? const Color(0xFFE0E0E0) : primarySoft;

  // ── Functional ───────────────────────────────────────────────
  static Color get sand =>
      isMonochrome ? const Color(0xFF7A7A7A) : const Color(0xFFC39B64);
  static Color get sandLight =>
      isMonochrome ? const Color(0xFFF0F0F0) : const Color(0xFFF4EBDE);

  static Color get green =>
      isMonochrome ? const Color(0xFF222222) : const Color(0xFF2D6A4E);
  static Color get greenLight =>
      isMonochrome ? const Color(0xFFF5F5F5) : const Color(0xFFE8F5EE);
  static Color get red =>
      isMonochrome ? const Color(0xFF444444) : const Color(0xFFD46586);
  static Color get redLight =>
      isMonochrome ? const Color(0xFFF8F8F8) : const Color(0xFFFBEAF0);
  static Color get amber =>
      isMonochrome ? const Color(0xFF555555) : const Color(0xFFBC8D4B);
  static Color get amberLight =>
      isMonochrome ? const Color(0xFFF9F9F9) : const Color(0xFFF7F0E4);

  // ── Hero ─────────────────────────────────────────────────────
  static Color get heroDark =>
      isMonochrome ? const Color(0xFF000000) : AppNeoColors.shadowInk;
  static Color get heroMid =>
      isMonochrome ? const Color(0xFF333333) : AppNeoColors.lime;
  static Color get heroAccent =>
      isMonochrome ? const Color(0xFF666666) : primaryLight;
  static Color get heroBg =>
      isMonochrome ? const Color(0xFFF9F9F9) : const Color(0xFFFFF8F4);

  static List<Color> get sectorColors => isMonochrome
      ? [
          const Color(0xFF0A0A0A),
          const Color(0xFF2C2C2C),
          const Color(0xFF4D4D4D),
          const Color(0xFF6E6E6E),
          const Color(0xFF909090),
          const Color(0xFFB1B1B1),
          const Color(0xFFD3D3D3),
          const Color(0xFFF5F5F5),
        ]
      : [
          AppNeoColors.lime,
          AppNeoColors.pink,
          AppNeoColors.amber,
          AppNeoColors.royal,
          AppNeoColors.mint,
          AppNeoColors.violet,
          AppNeoColors.shadowInk,
          const Color(0xFF736A6E),
        ];

  static Color colorForCategory(String category) {
    if (isMonochrome) {
      final colors = {
        'Food & Dining': const Color(0xFF2C2C2C),
        'Transport': const Color(0xFF4D4D4D),
        'Shopping': const Color(0xFF0A0A0A),
        'Health': const Color(0xFF6E6E6E),
        'Entertainment': const Color(0xFF909090),
        'Utilities & Bills': const Color(0xFFB1B1B1),
        'Transfer': const Color(0xFF333333),
        'Transfer & Finance': const Color(0xFF333333),
        'Other': const Color(0xFF888888),
      };
      return colors[category] ?? const Color(0xFF888888);
    }

    final colors = {
      'Food & Dining': AppNeoColors.amber,
      'Transport': AppNeoColors.royal,
      'Shopping': AppNeoColors.pink,
      'Health': AppNeoColors.mint,
      'Entertainment': AppNeoColors.violet,
      'Utilities & Bills': const Color(0xFFC39B64),
      'Transfer': AppNeoColors.shadowInk,
      'Transfer & Finance': AppNeoColors.shadowInk,
      'Other': const Color(0xFF736A6E),
    };
    return colors[category] ?? const Color(0xFF736A6E);
  }

  static dynamic iconForCategory(String category) {
    final icons = {
      'Food & Dining': HugeIcons.strokeRoundedPizza01,
      'Transport': HugeIcons.strokeRoundedCar02,
      'Shopping': HugeIcons.strokeRoundedShoppingBag01,
      'Health': HugeIcons.strokeRoundedShield01,
      'Entertainment': HugeIcons.strokeRoundedTicket01,
      'Utilities & Bills': HugeIcons.strokeRoundedInvoice01,
      'Transfer': HugeIcons.strokeRoundedExchange01,
      'Transfer & Finance': HugeIcons.strokeRoundedExchange01,
      'Other': HugeIcons.strokeRoundedWallet01,
    };
    return icons[category] ?? HugeIcons.strokeRoundedWallet01;
  }
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Main horizontal gutter for tab content (slightly roomier than [xl]).
  static const double screenHorizontal = 22;

  /// Space above the dock + FAB so scroll content clears the bar comfortably.
  static const double scrollBottomDockClearance = 172;
}

class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;
  /// Hero / list cards — slightly rounder to match soft-neo reference.
  static const double card = 20;
  static const double sheet = 28;
  static const double full = 999;
}

class AppBorders {
  static const double thin = 1;
  static double get normal => AppColors.isMonochrome ? 1.2 : 2.0;
  static const double thick = 2.5;
}

/// Soft vertical canvas used behind [GridBackground] (non-monochrome).
class AppGradients {
  /// Page wash — lavender into white into warm peach (ties to greeting + cards).
  static const LinearGradient pageVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFEDE7FF),
      Color(0xFFFAFAFF),
      Color(0xFFFFF7F3),
    ],
    stops: [0.0, 0.48, 1.0],
  );

  /// Minimal mode — cool gray depth so white cards read as layers, not one flat slab.
  static const LinearGradient monoPageVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE4E4E4),
      Color(0xFFEFEFEF),
      Color(0xFFF7F7F7),
    ],
    stops: [0.0, 0.42, 1.0],
  );

  /// Balance hero interior — same vertical story as [pageVertical] so the card
  /// reads as part of the canvas (not a separate lime panel).
  static const LinearGradient balanceHeroFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF5F2FF),
      Color(0xFFFFFFFF),
      Color(0xFFFFF5F0),
    ],
    stops: [0.0, 0.42, 1.0],
  );

  /// Monochrome hero — soft “silver” panel so the main balance isn’t flat white.
  static const LinearGradient monoBalanceHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE8E8E8),
      Color(0xFFFFFFFF),
      Color(0xFFF0F0F0),
    ],
    stops: [0.0, 0.52, 1.0],
  );
}

/// Minimum tap target aligned with iOS HIG-style comfort.
class AppHitTarget {
  static const double min = 44;
}

class AppShadows {
  static List<BoxShadow> get none => [];

  static List<BoxShadow> get sm => [
        BoxShadow(
          color: AppColors.isMonochrome
              ? const Color(0x18000000)
              : const Color(0x12000000),
          blurRadius: AppColors.isMonochrome ? 18 : 24,
          offset: Offset(0, AppColors.isMonochrome ? 5 : 8),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: AppColors.isMonochrome
              ? const Color(0x20000000)
              : const Color(0x1A000000),
          blurRadius: AppColors.isMonochrome ? 28 : 46,
          offset: Offset(0, AppColors.isMonochrome ? 10 : 16),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: AppColors.isMonochrome
              ? const Color(0x24000000)
              : const Color(0x1E000000),
          blurRadius: AppColors.isMonochrome ? 36 : 58,
          offset: Offset(0, AppColors.isMonochrome ? 12 : 16),
        ),
      ];

  static List<BoxShadow> get xl => [
        BoxShadow(
          color: AppColors.isMonochrome
              ? const Color(0x16000000)
              : const Color(0x22000000),
          blurRadius: 82,
          offset: const Offset(0, 24),
        ),
      ];

  static List<BoxShadow> colored(Color color, {double opacity = 0.15}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 32,
          offset: const Offset(0, 10),
        ),
      ];
}

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      error: AppColors.red,
      onSurface: AppColors.textMain,
    ).copyWith(
      onPrimary: AppColors.isMonochrome ? Colors.white : AppNeoColors.ink,
      outline: AppColors.border,
    );

    final interBase = GoogleFonts.interTextTheme();
    // Serif (Fraunces) for marketing / section headlines; Inter for UI chrome & body.
    final textTheme = interBase.copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
        fontSize: 34,
        letterSpacing: -0.7,
        height: 1.08,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
        fontSize: 28,
        letterSpacing: -0.5,
        height: 1.1,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
        fontSize: 26,
        letterSpacing: -0.45,
        height: 1.12,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
        fontSize: 24,
        letterSpacing: -0.4,
        height: 1.12,
      ),
      headlineSmall: GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
        fontSize: 20,
        letterSpacing: -0.35,
        height: 1.15,
      ),
      titleLarge: GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
        fontSize: 22,
        letterSpacing: -0.35,
        height: 1.15,
      ),
      titleMedium: GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
        fontSize: 17,
        letterSpacing: -0.25,
        height: 1.2,
      ),
      bodyLarge: GoogleFonts.inter(
        color: AppColors.textMain,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: GoogleFonts.inter(
        color: AppColors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: AppColors.textMain,
        fontSize: 14,
        letterSpacing: 0.15,
      ),
      labelMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        fontSize: 12,
        letterSpacing: 0.35,
      ),
      labelSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        fontSize: 11,
        letterSpacing: 0.55,
      ),
    );

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: colorScheme,
      textTheme: textTheme,
      iconTheme: IconThemeData(
        color: AppColors.isMonochrome ? AppColors.textMain : AppColors.iconOnLight,
        size: 22,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textMain, size: 22),
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textMain,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: AppColors.border,
            width: AppBorders.normal,
          ),
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor:
              AppColors.isMonochrome ? Colors.white : AppNeoColors.ink,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: AppColors.isMonochrome
                  ? Colors.transparent
                  : AppNeoColors.strokeBlack,
              width: AppColors.isMonochrome ? 0 : 2,
            ),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textMain,
          side: BorderSide(color: AppColors.border, width: AppBorders.normal),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor:
              AppColors.isMonochrome ? Colors.white : AppNeoColors.ink,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: AppColors.isMonochrome
                  ? Colors.transparent
                  : AppNeoColors.strokeBlack,
              width: AppColors.isMonochrome ? 0 : 2,
            ),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.surface;
        }),
        checkColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.labelOnSolid(AppColors.primary);
          }
          return AppColors.textMain;
        }),
        side: BorderSide(color: AppColors.border, width: 1.6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.labelOnSolid(AppColors.primary);
          }
          return AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.borderLight;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return AppColors.border;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: AppColors.border, width: AppBorders.normal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: AppColors.border, width: AppBorders.normal),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: AppNeoColors.lime,
            width: AppColors.isMonochrome ? AppBorders.normal : 2.5,
          ),
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.textHint,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border.withValues(alpha: 0.35),
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.sheetChrome,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        // Defaults use [ColorScheme.primary] for “today” when unselected → lime on white.
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.labelOnSolid(AppColors.primary);
          }
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textMain.withValues(alpha: 0.38);
          }
          return AppColors.textMain;
        }),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.textMain,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.textMain,
        ),
      ),
    );
  }
}

// ── Soft Neobrutalist tokens (stroke + solid offset shadow) ───────
class AppNeoColors {
  static const lime = Color(0xFFD1FF4E);
  static const pink = Color(0xFFFF4D8F);
  static const royal = Color(0xFF3D5BFF);
  static const amber = Color(0xFFFFB347);
  static const mint = Color(0xFF4DFFB8);
  static const violet = Color(0xFFB794FF);
  static const ink = Color(0xFF0A0A0F);
  /// Near-black outlines (matches reference UI chrome).
  static const strokeBlack = Color(0xFF0D0D0D);
  /// Forest — hard shadow only (depth under lime / white surfaces).
  static const shadowInk = Color(0xFF1B3D2F);
  /// Legacy name used in savyit / onboarding (same as [shadowInk]).
  static const tealInk = shadowInk;
}

class NeoPopDecorations {
  static List<BoxShadow> hardShadow(
    double offset, {
    Color color = AppNeoColors.shadowInk,
  }) =>
      [
        BoxShadow(
          color: color,
          offset: Offset(offset, offset),
          blurRadius: 0,
        ),
      ];

  static BoxDecoration card({
    Color? fill,
    double? radius,
    double shadowOffset = 5,
    Color shadowColor = AppNeoColors.shadowInk,
    Color borderColor = AppNeoColors.strokeBlack,
  }) =>
      BoxDecoration(
        color: fill ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius ?? AppRadius.card),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: hardShadow(shadowOffset, color: shadowColor),
      );

  static BoxDecoration kpiCard(
    Color accent, {
    double radius = 14,
    double shadowOffset = 5,
    Color shadowColor = AppNeoColors.shadowInk,
    Color borderColor = AppNeoColors.strokeBlack,
  }) =>
      BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: hardShadow(shadowOffset, color: shadowColor),
      );

  static BoxDecoration chip({
    Color? color,
    Color borderColor = AppNeoColors.strokeBlack,
    Color shadowColor = AppNeoColors.shadowInk,
    double shadowOffset = 3,
  }) =>
      BoxDecoration(
        color: color ?? AppNeoColors.lime,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: hardShadow(shadowOffset, color: shadowColor),
      );
}

class AppDecorations {
  static BoxDecoration get card => AppColors.isMonochrome
      ? BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface,
              Color.lerp(AppColors.surface, AppColors.surface2, 0.55)!,
            ],
          ),
          border: Border.all(
            color: AppColors.border,
            width: 1.2,
          ),
          boxShadow: AppShadows.sm,
        )
      : NeoPopDecorations.card(
          fill: AppColors.surface,
          radius: AppRadius.card,
          shadowOffset: 5,
        );

  static BoxDecoration get cardElevated => AppColors.isMonochrome
      ? BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              Color.lerp(AppColors.surface, AppColors.surfaceVariant, 0.22)!,
            ],
          ),
          border: Border.all(color: AppColors.border, width: 1.35),
          boxShadow: AppShadows.md,
        )
      : NeoPopDecorations.card(
          fill: AppColors.surface,
          radius: AppRadius.card,
          shadowOffset: 6,
        );

  static BoxDecoration get cardHero => AppColors.isMonochrome
      ? BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface,
              Color.lerp(AppColors.surface, AppColors.surface2, 0.4)!,
            ],
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.22),
            width: AppBorders.thick,
          ),
          boxShadow: AppShadows.lg,
        )
      : NeoPopDecorations.card(
          fill: AppColors.surface,
          radius: AppRadius.card,
          shadowOffset: 7,
        );

  /// Greeting strip in minimal mode — reads as its own plane vs the page + hero.
  static BoxDecoration get greetingMono => BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surface2,
          ],
        ),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: AppShadows.sm,
      );

  static BoxDecoration chip({bool selected = false, Color? color}) {
    if (AppColors.isMonochrome) {
      return BoxDecoration(
        color: selected ? (color ?? AppColors.primary) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: selected ? (color ?? AppColors.primary) : AppColors.border,
          width: AppBorders.normal,
        ),
      );
    }
    if (selected) {
      return NeoPopDecorations.chip(
        color: color ?? AppNeoColors.lime,
        borderColor: AppNeoColors.strokeBlack,
        shadowColor: AppNeoColors.shadowInk,
        shadowOffset: 3,
      );
    }
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.full),
      border: Border.all(color: AppNeoColors.strokeBlack, width: 2),
      boxShadow: NeoPopDecorations.hardShadow(3, color: AppNeoColors.shadowInk),
    );
  }

  static BoxDecoration iconContainer({Color? color}) {
    final c = color ?? AppNeoColors.lime;
    if (AppColors.isMonochrome) {
      return BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.45),
          width: 1,
        ),
      );
    }
    return NeoPopDecorations.card(
      fill: c.withValues(alpha: 0.2),
      radius: AppRadius.md,
      shadowOffset: 3,
    );
  }

  /// Filled control chrome (hairline + soft shadow in mono; neo card in color).
  static BoxDecoration controlSurface({double? radius}) {
    final r = radius ?? AppRadius.md;
    if (AppColors.isMonochrome) {
      final bottom = Color.lerp(
        AppColors.surface,
        AppColors.surfaceVariant,
        0.25,
      )!;
      return BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface, bottom],
        ),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.88),
          width: AppBorders.normal,
        ),
        boxShadow: AppShadows.sm,
      );
    }
    return NeoPopDecorations.card(
      fill: AppColors.surface,
      radius: r,
      shadowOffset: 4,
    );
  }
}
