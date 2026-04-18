// lib/ui/savyit/savyit_card.dart
// Unified card component — replaces AppDecorations.card, NeoPopCard, KpiCard shell.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'savyit_theme.dart';

enum SavyitCardVariant { flat, standard, elevated, featured, kpi, pop }

class SavyitCard extends StatefulWidget {
  final Widget child;
  final SavyitCardVariant variant;
  final VoidCallback? onTap;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const SavyitCard({
    super.key,
    required this.child,
    this.variant = SavyitCardVariant.standard,
    this.onTap,
    this.accentColor,
    this.padding,
    this.borderRadius,
  });

  @override
  State<SavyitCard> createState() => _SavyitCardState();
}

class _SavyitCardState extends State<SavyitCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SavyitTheme.of(context);
    final c = t.colors;
    final sh = t.shadows;
    final tappable = widget.onTap != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: tappable ? (_) {
          HapticFeedback.selectionClick();
          _ctrl.forward();
        } : null,
        onTapUp: tappable ? (_) {
          _ctrl.reverse();
          widget.onTap?.call();
        } : null,
        onTapCancel: tappable ? () => _ctrl.reverse() : null,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final pv = _ctrl.value;
            return Transform.scale(
              scale: tappable ? 1.0 - (pv * 0.02) : 1.0,
              child: child,
            );
          },
          child: _buildCard(c, sh),
        ),
      ),
    );
  }

  Widget _buildCard(SavyitColorTokens c, SavyitShadowTokens sh) {
    final v       = widget.variant;
    final radius  = widget.borderRadius ?? _radius(v);
    final accent  = widget.accentColor ?? c.primary;

    BoxDecoration decoration;

    switch (v) {
      case SavyitCardVariant.flat:
        decoration = BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: c.border,
            width: AppColors.isMonochrome ? 1 : 2,
          ),
        );
        break;

      case SavyitCardVariant.standard:
        decoration = BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: c.border,
            width: AppColors.isMonochrome ? 1.5 : 2,
          ),
          boxShadow: _hovered ? sh.md(Colors.black) : sh.sm(Colors.black),
        );
        break;

      case SavyitCardVariant.elevated:
        decoration = BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: c.border,
            width: AppColors.isMonochrome ? 1 : 2,
          ),
          boxShadow: _hovered ? sh.md(Colors.black) : sh.sm(Colors.black),
        );
        break;

      case SavyitCardVariant.featured:
        decoration = BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border(
            top:    BorderSide(color: accent, width: 3),
            left:   BorderSide(color: c.border),
            right:  BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
          ),
          boxShadow: sh.sm(accent),
        );
        break;

      case SavyitCardVariant.kpi:
        decoration = BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: c.border, width: 1),
          boxShadow: sh.sm(accent),
        );
        break;

      case SavyitCardVariant.pop:
        decoration = BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppNeoColors.strokeBlack, width: 2),
          boxShadow: sh.pop(AppNeoColors.shadowInk),
        );
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: decoration,
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.all(16),
        child: widget.child,
      ),
    );
  }

  double _radius(SavyitCardVariant v) {
    switch (v) {
      case SavyitCardVariant.flat:     return 12;
      case SavyitCardVariant.pop:      return 14;
      default:                         return 16;
    }
  }
}
