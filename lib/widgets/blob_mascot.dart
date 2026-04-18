// lib/widgets/blob_mascot.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/mascot_dna.dart';
import '../theme/app_theme.dart';

class BlobMascot extends StatefulWidget {
  final MascotDna dna;
  final MascotMood mood;
  final double size;
  final bool interactive;
  /// Off-white circular mat + stroke so the pastel body separates from
  /// lavender / pink page tints (color + mono).
  final bool contrastPlate;

  const BlobMascot({
    super.key,
    required this.dna,
    required this.mood,
    this.size = 140,
    this.interactive = true,
    this.contrastPlate = false,
  });

  @override
  State<BlobMascot> createState() => _BlobMascotState();
}

class _BlobMascotState extends State<BlobMascot>
    with TickerProviderStateMixin {
  late AnimationController _breathe;
  late AnimationController _blink;
  late AnimationController _shake;
  late AnimationController _bounce;
  late AnimationController _wiggle;

  Timer? _blinkTimer;
  bool _isBlinking = false;
  bool _isWiggling = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _scheduleNextBlink();
  }

  void _initControllers() {
    final tempo = widget.mood.breatheTempo;

    _breathe = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (tempo * 1000).toInt()),
    )..repeat(reverse: true);

    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );

    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    if (widget.mood == MascotMood.overspent) {
      _scheduleShake();
    }
    if (widget.mood == MascotMood.thriving) {
      _scheduleBounce();
    }
    if (widget.mood == MascotMood.celebrating) {
      _breathe.duration = const Duration(milliseconds: 500);
      _breathe.repeat(reverse: true);
    }
  }

  void _scheduleNextBlink() {
    final delay = Duration(
      milliseconds: 4000 + math.Random().nextInt(3000),
    );
    _blinkTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _isBlinking = true);
      _blink.forward().then((_) {
        _blink.reverse().then((_) {
          if (mounted) setState(() => _isBlinking = false);
          _scheduleNextBlink();
        });
      });
    });
  }

  void _scheduleShake() {
    Timer(const Duration(seconds: 7), () {
      if (!mounted || widget.mood != MascotMood.overspent) return;
      _shake.forward().then((_) => _shake.reverse()).then((_) {
        if (mounted) _scheduleShake();
      });
    });
  }

  void _scheduleBounce() {
    Timer(const Duration(seconds: 4), () {
      if (!mounted || widget.mood != MascotMood.thriving) return;
      _bounce.forward().then((_) => _bounce.reverse()).then((_) {
        if (mounted) _scheduleBounce();
      });
    });
  }

  void _handleTap() {
    if (!widget.interactive || _isWiggling) return;
    setState(() => _isWiggling = true);
    _wiggle.forward().then((_) => _wiggle.reverse()).then((_) {
      if (mounted) setState(() => _isWiggling = false);
    });
  }

  @override
  void didUpdateWidget(BlobMascot old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood || old.dna.color != widget.dna.color) {
      _breathe.stop();
      _breathe.duration =
          Duration(milliseconds: (widget.mood.breatheTempo * 1000).toInt());
      _breathe.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathe.dispose();
    _blink.dispose();
    _shake.dispose();
    _bounce.dispose();
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathe, _blink, _shake, _bounce, _wiggle]),
        builder: (_, __) {
          final breatheScale = 1.0 + _breathe.value * 0.055;
          final bounceOffset = -_bounce.value * 12.0;
          final shakeOffset = math.sin(_shake.value * math.pi * 4) * 5.0;
          final wiggleAngle = math.sin(_wiggle.value * math.pi * 2) * 0.12;
          final blinkScale = _isBlinking ? (1.0 - _blink.value * 0.9) : 1.0;

          final plate = widget.contrastPlate ? widget.size * 0.075 : 0.0;
          final paintSize = (widget.size - 2 * plate).clamp(1.0, widget.size);

          Widget blob = CustomPaint(
            size: Size(paintSize, paintSize),
            painter: _BlobPainter(
              dna: widget.dna,
              mood: widget.mood,
              blinkScale: blinkScale,
            ),
          );

          if (plate > 0) {
            blob = Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              padding: EdgeInsets.all(plate),
              decoration: AppColors.isMonochrome
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(
                        color: AppColors.border,
                        width: 1.35,
                      ),
                      boxShadow: AppShadows.sm,
                    )
                  : BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(
                        color: AppNeoColors.strokeBlack,
                        width: 2,
                      ),
                      boxShadow: NeoPopDecorations.hardShadow(3),
                    ),
              child: blob,
            );
          }

          return Transform.translate(
            offset: Offset(shakeOffset, bounceOffset),
            child: Transform.rotate(
              angle: wiggleAngle,
              child: Transform.scale(
                scale: breatheScale,
                child: blob,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final MascotDna dna;
  final MascotMood mood;
  final double blinkScale;

  const _BlobPainter({
    required this.dna,
    required this.mood,
    required this.blinkScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Round “mochi” body — reads clearly at small sizes; matches soft mascot refs.
    final bodyColor = dna.colorValue;
    final bodyR = math.min(w, h) * 0.405;
    final bodyCx = cx;
    final bodyCy = cy + h * 0.035;
    final faceY = bodyCy + h * 0.018;

    final strokeW = w * (AppColors.isMonochrome ? 0.026 : 0.032);
    final bodyStroke = Paint()
      ..color = AppNeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: AppColors.isMonochrome ? 0.14 : 0.2)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        AppColors.isMonochrome ? 12 : 16,
      );

    canvas.save();
    canvas.translate(3, 5);
    canvas.drawCircle(Offset(bodyCx, bodyCy), bodyR, shadowPaint);
    canvas.restore();

    final bodyBounds =
        Rect.fromCircle(center: Offset(bodyCx, bodyCy), radius: bodyR);
    // Flatter fill (sticker / neubrutalist blob) — still a hint of depth.
    final light = Color.lerp(bodyColor, Colors.white, 0.055)!;
    final mid = bodyColor;
    final dark = Color.lerp(bodyColor, Colors.black, 0.11)!;
    final bodyFill = Paint()
      ..shader = RadialGradient(
        colors: [light, mid, dark],
        stops: const [0.0, 0.48, 1.0],
        center: const Alignment(-0.4, -0.36),
        radius: 1.05,
      ).createShader(bodyBounds);
    canvas.drawCircle(Offset(bodyCx, bodyCy), bodyR, bodyFill);
    canvas.drawCircle(Offset(bodyCx, bodyCy), bodyR, bodyStroke);

    final gloss = Paint()..color = Colors.white.withValues(alpha: 0.11);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyCx - bodyR * 0.32, bodyCy - bodyR * 0.36),
        width: bodyR * 0.55,
        height: bodyR * 0.32,
      ),
      gloss,
    );

    // Soft pale blush ovals just under the eyes (settings / kawaii ref).
    final blush = Paint()
      ..color = const Color(0xFFFFA8CC).withValues(alpha: 0.36);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - w * 0.22, faceY + h * 0.042),
        width: w * 0.15,
        height: h * 0.052,
      ),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + w * 0.22, faceY + h * 0.042),
        width: w * 0.15,
        height: h * 0.052,
      ),
      blush,
    );

    _drawEyes(canvas, cx, faceY, w, h);
    _drawMouth(canvas, cx, faceY, w, h);
    _drawAccessory(canvas, cx, faceY, w, h, bodyCy, bodyR);
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double w, double h) {
    final ink = Paint()..color = AppNeoColors.ink;
    final white = Paint()..color = Colors.white;
    final eyeY = cy - h * 0.058;
    final eyeLX = cx - w * 0.202;
    final eyeRX = cx + w * 0.202;

    switch (_eyeVariant) {
      case 'closed':
        final p = Paint()
          ..color = AppNeoColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.025
          ..strokeCap = StrokeCap.round;
        final closedR = w * 0.088;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(eyeLX, eyeY), width: closedR * 2, height: closedR),
          0, math.pi, false, p,
        );
        canvas.drawArc(
          Rect.fromCenter(center: Offset(eyeRX, eyeY), width: closedR * 2, height: closedR),
          0, math.pi, false, p,
        );
        break;

      case 'wide':
        canvas.save();
        canvas.scale(1, blinkScale);
        final wy = eyeY / blinkScale;
        final stroke = Paint()
          ..color = AppNeoColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.019;
        final eyeR = w * 0.098;
        final outer = eyeR * 1.22;
        canvas.drawCircle(Offset(eyeLX, wy), outer, white);
        canvas.drawCircle(Offset(eyeRX, wy), outer, white);
        canvas.drawCircle(Offset(eyeLX, wy), outer, stroke);
        canvas.drawCircle(Offset(eyeRX, wy), outer, stroke);
        canvas.drawCircle(Offset(eyeLX, wy), eyeR * 0.48, ink);
        canvas.drawCircle(Offset(eyeRX, wy), eyeR * 0.48, ink);
        canvas.drawCircle(Offset(eyeLX + eyeR * 0.35, wy - eyeR * 0.38), eyeR * 0.22, white);
        canvas.drawCircle(Offset(eyeRX + eyeR * 0.35, wy - eyeR * 0.38), eyeR * 0.22, white);
        canvas.restore();
        break;

      case 'dots':
        canvas.save();
        canvas.scale(1, blinkScale);
        final y = eyeY / blinkScale;
        final er = w * 0.108;
        canvas.drawCircle(Offset(eyeLX, y), er, ink);
        canvas.drawCircle(Offset(eyeRX, y), er, ink);
        // Large + small white sparkles (matches settings preview ref).
        canvas.drawCircle(
            Offset(eyeLX + er * 0.30, y - er * 0.28), er * 0.40, white);
        canvas.drawCircle(
            Offset(eyeRX + er * 0.30, y - er * 0.28), er * 0.40, white);
        canvas.drawCircle(
            Offset(eyeLX - er * 0.26, y + er * 0.20), er * 0.17, white);
        canvas.drawCircle(
            Offset(eyeRX - er * 0.26, y + er * 0.20), er * 0.17, white);
        canvas.restore();
        break;
    }
  }

  void _drawMouth(Canvas canvas, double cx, double cy, double w, double h) {
    final mouthY = cy + h * 0.168;
    final p = Paint()
      ..color = AppNeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.015
      ..strokeCap = StrokeCap.round;

    switch (_mouthVariant) {
      case 'smile':
        final path = Path();
        path.moveTo(cx - w * 0.145, mouthY - h * 0.018);
        path.quadraticBezierTo(cx, mouthY + h * 0.065, cx + w * 0.145, mouthY - h * 0.018);
        canvas.drawPath(path, p);
        break;
      case 'frown':
        final path = Path();
        path.moveTo(cx - w * 0.14, mouthY + h * 0.04);
        path.quadraticBezierTo(cx, mouthY - h * 0.06, cx + w * 0.14, mouthY + h * 0.04);
        canvas.drawPath(path, p);
        break;
      case 'flat':
        canvas.drawLine(
          Offset(cx - w * 0.12, mouthY),
          Offset(cx + w * 0.12, mouthY),
          p,
        );
        break;
      case 'open':
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, mouthY), width: w * 0.22, height: h * 0.14),
          Paint()..color = AppNeoColors.ink,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, mouthY + h * 0.025), width: w * 0.1, height: h * 0.055),
          Paint()..color = const Color(0xFFFFB3D0),
        );
        break;
    }
  }

  void _drawAccessory(Canvas canvas, double cx, double cy, double w, double h,
      double bodyCy, double bodyR) {
    final stroke = Paint()
      ..color = AppNeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014
      ..strokeJoin = StrokeJoin.round;
    final topY = bodyCy - bodyR + h * 0.04;
    final acc = normalizeBlobAccessoryId(dna.accessory);

    switch (acc) {
      case 'bow':
        final left = Paint()..color = const Color(0xFFFFD6EC);
        final right = Paint()..color = const Color(0xFFFFC8E6);
        final knot = Paint()..color = const Color(0xFFFFB3DA);
        final rL = Rect.fromCenter(
            center: Offset(cx - w * 0.15, topY + h * 0.07),
            width: w * 0.24,
            height: h * 0.13);
        final rR = Rect.fromCenter(
            center: Offset(cx + w * 0.15, topY + h * 0.07),
            width: w * 0.24,
            height: h * 0.13);
        final rK = Rect.fromCenter(
            center: Offset(cx, topY + h * 0.08),
            width: w * 0.14,
            height: h * 0.11);
        canvas.drawOval(rL, left);
        canvas.drawOval(rL, stroke);
        canvas.drawOval(rR, right);
        canvas.drawOval(rR, stroke);
        canvas.drawOval(rK, knot);
        canvas.drawOval(rK, stroke);
        break;

      case 'clip':
        final starFill = Paint()..color = const Color(0xFFFFF2B8);
        final sx = cx - w * 0.26;
        final sy = topY + h * 0.05;
        canvas.save();
        canvas.translate(sx, sy);
        canvas.rotate(-0.35);
        final star = Path();
        for (int i = 0; i < 5; i++) {
          final ang = (i * 4 * math.pi / 5) - math.pi / 2;
          final rad = i.isEven ? w * 0.055 : w * 0.026;
          final x = rad * math.cos(ang);
          final y = rad * math.sin(ang);
          if (i == 0) {
            star.moveTo(x, y);
          } else {
            star.lineTo(x, y);
          }
        }
        star.close();
        canvas.drawPath(star, starFill);
        canvas.drawPath(star, stroke);
        canvas.restore();
        break;

      case 'petals':
        final petalFill = Paint()..color = const Color(0xFFFFD0EA);
        final pr = w * 0.065;
        final centers = [
          Offset(cx - w * 0.11, topY + h * 0.03),
          Offset(cx, topY - h * 0.02),
          Offset(cx + w * 0.11, topY + h * 0.03),
        ];
        for (final c in centers) {
          canvas.drawCircle(c, pr, petalFill);
          canvas.drawCircle(c, pr, stroke);
        }
        break;

      case 'hearts':
        final hi = Paint()..color = const Color(0xFFFFA8CC);
        void miniHeart(Offset o) {
          final bump = w * 0.028;
          canvas.drawCircle(Offset(o.dx - bump, o.dy), bump * 1.1, hi);
          canvas.drawCircle(Offset(o.dx + bump, o.dy), bump * 1.1, hi);
          final tip = Path();
          tip.moveTo(o.dx - bump * 2.1, o.dy + bump * 0.2);
          tip.lineTo(o.dx + bump * 2.1, o.dy + bump * 0.2);
          tip.lineTo(o.dx, o.dy + bump * 2.6);
          tip.close();
          canvas.drawPath(tip, hi);
          canvas.drawCircle(Offset(o.dx - bump, o.dy), bump * 1.1, stroke);
          canvas.drawCircle(Offset(o.dx + bump, o.dy), bump * 1.1, stroke);
          canvas.drawPath(tip, stroke);
        }
        miniHeart(Offset(cx - w * 0.30, cy - h * 0.02));
        miniHeart(Offset(cx + w * 0.30, cy - h * 0.02));
        break;

      case 'ribbon':
        final fill = Paint()..color = const Color(0xFFE4E9FF);
        final scarfY = bodyCy + bodyR * 0.66;
        final scarfPath = Path();
        scarfPath.moveTo(cx - w * 0.34, scarfY);
        scarfPath.quadraticBezierTo(cx, scarfY + h * 0.07, cx + w * 0.34, scarfY);
        scarfPath.lineTo(cx + w * 0.36, scarfY + h * 0.10);
        scarfPath.quadraticBezierTo(cx, scarfY + h * 0.17, cx - w * 0.36, scarfY + h * 0.10);
        scarfPath.close();
        canvas.drawPath(scarfPath, fill);
        canvas.drawPath(scarfPath, stroke);
        break;

      case 'none':
      default:
        break;
    }
  }

  String get _eyeVariant {
    switch (mood) {
      case MascotMood.sleeping:
        return 'closed';
      case MascotMood.stressed:
      case MascotMood.overspent:
        return 'wide';
      case MascotMood.chill:
      case MascotMood.thriving:
      case MascotMood.celebrating:
      case MascotMood.curious:
        return 'dots';
    }
  }

  String get _mouthVariant {
    switch (mood) {
      case MascotMood.overspent:   return 'frown';
      case MascotMood.stressed:
      case MascotMood.sleeping:    return 'flat';
      case MascotMood.celebrating: return 'open';
      default:                     return 'smile';
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.dna != dna || old.mood != mood || old.blinkScale != blinkScale;
}
