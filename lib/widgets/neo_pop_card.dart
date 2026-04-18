// lib/widgets/neo_pop_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// NeoPOP card: flat fill + 2px black border + hard offset shadow.
/// Optionally tappable with press animation.
class NeoPopCard extends StatefulWidget {
  final Widget child;
  final Color fill;
  final double radius;
  final double shadowOffset;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color borderColor;
  final Color shadowColor;

  const NeoPopCard({
    super.key,
    required this.child,
    this.fill = Colors.white,
    this.radius = 14,
    this.shadowOffset = 6,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor = AppNeoColors.tealInk,
    this.shadowColor = AppNeoColors.tealInk,
  });

  @override
  State<NeoPopCard> createState() => _NeoPopCardState();
}

class _NeoPopCardState extends State<NeoPopCard>
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
    if (widget.onTap == null) return _buildCard(0);

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) { _press.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, __) => _buildCard(_press.value),
      ),
    );
  }

  Widget _buildCard(double pressProgress) {
    final offset = widget.shadowOffset * (1 - pressProgress);
    return Transform.translate(
      offset: Offset(pressProgress * widget.shadowOffset,
          pressProgress * widget.shadowOffset),
      child: Container(
        decoration: BoxDecoration(
          color: widget.fill,
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
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}
