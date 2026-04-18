// lib/widgets/grid_background.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GridBackground extends StatelessWidget {
  final Widget child;
  final bool showPattern;
  /// When set, drawn behind the dot pattern instead of a flat [backgroundColor].
  final Gradient? backgroundGradient;
  /// Used when [backgroundGradient] is null.
  final Color? backgroundColor;
  /// Dot colour for the grid (defaults to a soft border tone).
  final Color? patternColor;

  const GridBackground({
    super.key,
    required this.child,
    this.showPattern = false,
    this.backgroundGradient,
    this.backgroundColor,
    this.patternColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasSolidOnly =
        backgroundGradient == null && backgroundColor != null;
    final gradient = backgroundGradient ??
        (AppColors.isMonochrome
            ? AppGradients.monoPageVertical
            : AppGradients.pageVertical);

    return Stack(
      children: [
        Positioned.fill(
          child: hasSolidOnly
              ? ColoredBox(color: backgroundColor!)
              : DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient),
                ),
        ),
        
        // Striped pattern
        if (showPattern)
          Positioned.fill(
            child: CustomPaint(
              painter: _StripesPainter(patternColorOverride: patternColor),
            ),
          ),
          
        child,
      ],
    );
  }
}

class _StripesPainter extends CustomPainter {
  _StripesPainter({this.patternColorOverride});

  /// When null, uses a soft default so dots always paint after hot reload.
  final Color? patternColorOverride;

  Color get _effectiveDotColor =>
      patternColorOverride ?? AppColors.border.withValues(alpha: 0.35);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _effectiveDotColor
      ..style = PaintingStyle.fill;

    const double spacing = 40;
    const double dotSize = 1.5;

    for (double i = 0; i < size.width; i += spacing) {
      for (double j = 0; j < size.height; j += spacing) {
        canvas.drawCircle(Offset(i, j), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! _StripesPainter) return true;
    return oldDelegate.patternColorOverride != patternColorOverride;
  }
}
