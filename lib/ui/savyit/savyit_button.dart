// lib/ui/savyit/savyit_button.dart
// Unified button component — replaces ElevatedButton, OutlinedButton, NeoPopButton.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'savyit_theme.dart';

enum SavyitButtonVariant { primary, secondary, ghost, cta, danger }

class SavyitButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final SavyitButtonVariant variant;
  final Widget? icon;
  final bool small;
  final double? width;

  const SavyitButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = SavyitButtonVariant.primary,
    this.icon,
    this.small = false,
    this.width,
  });

  @override
  State<SavyitButton> createState() => _SavyitButtonState();
}

class _SavyitButtonState extends State<SavyitButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _press;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _press = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
    final s = t.shapes;
    final disabled = widget.onTap == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) {
        HapticFeedback.lightImpact();
        _ctrl.forward();
      },
      onTapUp: disabled ? null : (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: disabled ? null : () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, __) {
          final pv = _press.value;
          return _buildVisual(context, c, s, disabled, pv);
        },
      ),
    );
  }

  Widget _buildVisual(
    BuildContext context,
    SavyitColorTokens c,
    SavyitShapeTokens s,
    bool disabled,
    double pv,
  ) {
    final v = widget.variant;
    final isCta = v == SavyitButtonVariant.cta;
    final shadowOffset = isCta ? 5.0 * (1 - pv) : 0.0;
    final radius = isCta ? s.compact : s.card;

    Color fill;
    Color textColor;
    Border border;
    List<BoxShadow> shadow;

    switch (v) {
      case SavyitButtonVariant.primary:
        fill = c.primary;
        textColor =
            AppColors.isMonochrome ? Colors.white : AppNeoColors.ink;
        border = Border.all(
          color: AppColors.isMonochrome
              ? Colors.transparent
              : AppNeoColors.strokeBlack,
          width: AppColors.isMonochrome ? 0 : 2,
        );
        shadow = AppColors.isMonochrome
            ? []
            : NeoPopDecorations.hardShadow(4, color: AppNeoColors.shadowInk);
        break;
      case SavyitButtonVariant.secondary:
        fill      = Colors.transparent;
        textColor = c.textMain;
        border    = Border.all(color: c.border, width: 1.5);
        shadow    = [];
        break;
      case SavyitButtonVariant.ghost:
        fill      = Colors.transparent;
        textColor = c.primary;
        border    = Border.all(color: Colors.transparent);
        shadow    = [];
        break;
      case SavyitButtonVariant.cta:
        fill = c.lime;
        textColor = c.tealInk;
        border = Border.all(color: AppNeoColors.strokeBlack, width: 2);
        shadow = [
          BoxShadow(
            color: AppNeoColors.shadowInk,
            offset: Offset(shadowOffset, shadowOffset),
            blurRadius: 0,
          ),
        ];
        break;
      case SavyitButtonVariant.danger:
        fill      = c.error.withValues(alpha: 0.10);
        textColor = c.error;
        border    = Border.all(color: c.error, width: 1);
        shadow    = [];
        break;
    }

    if (disabled) {
      fill      = fill.withValues(alpha: 0.5);
      textColor = textColor.withValues(alpha: 0.5);
    }

    final translate = isCta ? Offset(pv * 5, pv * 5) : Offset.zero;

    return Transform.translate(
      offset: translate,
      child: Container(
        width: widget.width,
        constraints: BoxConstraints(
          minHeight: widget.small ? 38 : 50,
          minWidth: widget.small ? 72 : 110,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
          border: border,
          boxShadow: shadow,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.small ? 14 : 22,
            vertical:   widget.small ? 8  : 14,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                widget.icon!,
                const SizedBox(width: 8),
              ],
              Text(
                isCta
                    ? widget.label.toUpperCase()
                    : widget.label,
                style: GoogleFonts.inter(
                  fontWeight: isCta ? FontWeight.w800 : FontWeight.w600,
                  fontSize:   widget.small ? 12 : 14,
                  color:      textColor,
                  letterSpacing: isCta ? 0.5 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
