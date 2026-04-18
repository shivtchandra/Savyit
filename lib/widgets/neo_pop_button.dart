// lib/widgets/neo_pop_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Chunky NeoPOP button: saturated fill + 2px black border + hard press animation.
class NeoPopButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color fill;
  final Color textColor;
  final double shadowOffset;
  final double radius;
  final double? width;
  final Widget? icon;
  final bool small;
  final Color borderColor;
  final Color shadowColor;

  const NeoPopButton({
    super.key,
    required this.label,
    required this.onTap,
    this.fill = AppNeoColors.lime,
    this.textColor = AppNeoColors.ink,
    this.shadowOffset = 5,
    this.radius = 12,
    this.width,
    this.icon,
    this.small = false,
    this.borderColor = AppNeoColors.tealInk,
    this.shadowColor = AppNeoColors.tealInk,
  });

  @override
  State<NeoPopButton> createState() => _NeoPopButtonState();
}

class _NeoPopButtonState extends State<NeoPopButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _press.forward();
      },
      onTapUp: (_) { _press.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, __) {
          final offset = widget.shadowOffset * (1 - _press.value);
          return Transform.translate(
            offset: Offset(
              _press.value * widget.shadowOffset,
              _press.value * widget.shadowOffset,
            ),
            child: Container(
              width: widget.width,
              constraints: BoxConstraints(
                minHeight: widget.small ? 40 : 52,
                minWidth: widget.small ? 80 : 120,
              ),
              decoration: BoxDecoration(
                color: widget.onTap == null
                    ? widget.fill.withValues(alpha: 0.5)
                    : widget.fill,
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(color: widget.borderColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.shadowColor,
                    offset: Offset(offset, offset),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.small ? 14 : 22,
                  vertical: widget.small ? 8 : 14,
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
                      widget.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: widget.small ? 12 : 14,
                        color: widget.onTap == null
                            ? widget.textColor.withValues(alpha: 0.5)
                            : widget.textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
