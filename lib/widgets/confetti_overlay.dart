// lib/widgets/confetti_overlay.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Call `ConfettiOverlay.burst(context)` to show a one-shot celebration burst.
class ConfettiOverlay {
  static OverlayEntry? _entry;

  static void burst(BuildContext context) {
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (_) => _ConfettiWidget(onDone: () {
        _entry?.remove();
        _entry = null;
      }),
    );
    Overlay.of(context).insert(_entry!);
  }
}

class _ConfettiWidget extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiWidget({required this.onDone});

  @override
  State<_ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<_ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Piece> _pieces;

  static const _colors = [
    AppNeoColors.lime,
    AppNeoColors.pink,
    AppNeoColors.royal,
    AppNeoColors.amber,
    AppNeoColors.mint,
    AppNeoColors.violet,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward().then((_) => widget.onDone());

    final rng = math.Random();
    _pieces = List.generate(48, (i) {
      final angle = (math.pi * 2 * i / 48) + rng.nextDouble() * 0.6;
      final dist = 100 + rng.nextDouble() * 180;
      return _Piece(
        color: _colors[i % _colors.length],
        dx: math.cos(angle) * dist,
        dy: math.sin(angle) * dist - 60,
        rot: rng.nextDouble() * math.pi * 4 - math.pi * 2,
        width: 6 + rng.nextDouble() * 6,
        height: 10 + rng.nextDouble() * 8,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height * 0.35;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return CustomPaint(
            size: size,
            painter: _ConfettiPainter(
              pieces: _pieces,
              progress: _ctrl.value,
              origin: Offset(cx, cy),
            ),
          );
        },
      ),
    );
  }
}

class _Piece {
  final Color color;
  final double dx, dy, rot, width, height;
  const _Piece({
    required this.color,
    required this.dx,
    required this.dy,
    required this.rot,
    required this.width,
    required this.height,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double progress;
  final Offset origin;

  const _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.origin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ease-out curve
    final t = 1.0 - math.pow(1.0 - progress, 3).toDouble();
    final opacity = progress < 0.7 ? 1.0 : (1.0 - (progress - 0.7) / 0.3);

    for (final p in pieces) {
      final x = origin.dx + p.dx * t;
      final y = origin.dy + p.dy * t + 80 * t * t; // gravity
      final rot = p.rot * t;
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = AppNeoColors.ink.withValues(alpha: opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.width,
        height: p.height,
      );
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
