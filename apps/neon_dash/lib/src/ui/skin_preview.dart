library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:playable_core/playable_core.dart';

import '../render/craft_shape.dart';
import '../render/palette.dart';

class SkinPreview extends StatefulWidget {
  const SkinPreview({
    required this.skin,
    this.hue = Palette.craftHue,
    this.size = 92.0,
    this.lit = true,
    super.key,
  });

  final CraftSkin skin;

  final double hue;

  final double size;

  final bool lit;

  @override
  State<SkinPreview> createState() => _SkinPreviewState();
}

class _SkinPreviewState extends State<SkinPreview>
    with SingleTickerProviderStateMixin {
  static const Duration _cycle = Duration(seconds: 4);

  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _SkinPainter(
              skin: widget.skin,
              hue: widget.skin.hueOverride ?? widget.hue,
              phase: _clock.value,
              lit: widget.lit,
            ),
          ),
        ),
      );
}

class _SkinPainter extends CustomPainter {
  _SkinPainter({
    required this.skin,
    required this.hue,
    required this.phase,
    required this.lit,
  })  : _hull = buildHullPath(skin, 0.35),
        _exhaust = buildExhaustPath(),
        _offsets = exhaustOffsets(skin),
        _exhaustWidth = exhaustWidthScale(skin),
        _seat = exhaustSeat(skin);

  final CraftSkin skin;
  final double hue;
  final double phase;
  final bool lit;

  final Path _hull;
  final Path _exhaust;
  final List<double> _offsets;
  final double _exhaustWidth;
  final double _seat;

  static const double _tau = 6.283185307179586;

  static const double _bankRadians = 0.34;
  static const double _bankHz = 1.0;

  static const double _flameSlowHz = 3.0;
  static const double _flameFastHz = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = NeonInk.fromHue(hue);
    final dim = lit ? 1.0 : 0.3;
    final paint = Paint()..isAntiAlias = true;

    final centre = size.center(Offset.zero);
    final radius = size.shortestSide * 0.26;
    final bank = math.sin(phase * _tau * _bankHz);

    _paintTrail(canvas, paint, centre, radius, bank, ink, dim);

    canvas
      ..save()
      ..translate(centre.dx + bank * radius * 0.5, centre.dy)
      ..rotate(bank * _bankRadians)
      ..scale(1.0 - bank.abs() * 0.3, 1.0);

    _paintExhausts(canvas, paint, radius, ink, dim);

    for (final (scale, color) in <(double, Color)>[
      (1.75, ink.halo),
      (1.0, ink.body),
      (0.6, ink.edge),
    ]) {
      paint.color = _fade(color, dim);
      _paintHull(canvas, paint, radius * scale);
    }

    canvas.restore();
  }

  void _paintHull(Canvas canvas, Paint paint, double radius) {
    canvas
      ..save()
      ..scale(radius, radius)
      ..drawPath(_hull, paint)
      ..restore();
  }

  void _paintExhausts(
    Canvas canvas,
    Paint paint,
    double radius,
    NeonInk ink,
    double dim,
  ) {
    final gutter = 1.0 +
        0.085 * math.sin(phase * _tau * _flameSlowHz) +
        0.05 * math.sin(phase * _tau * _flameFastHz);
    final plume = radius * gutter * 1.5;

    for (final offset in _offsets) {
      canvas
        ..save()
        ..translate(offset * radius, _seat * radius);

      paint.color = _fade(ink.halo, dim);
      _paintScaled(canvas, paint, plume * _exhaustWidth, plume);
      paint.color = _fade(ink.body, dim);
      _paintScaled(canvas, paint, plume * _exhaustWidth * 0.52, plume * 0.62);

      canvas.restore();
    }
  }

  void _paintScaled(Canvas canvas, Paint paint, double width, double length) {
    canvas
      ..save()
      ..scale(width, length)
      ..drawPath(_exhaust, paint)
      ..restore();
  }

  void _paintTrail(
    Canvas canvas,
    Paint paint,
    Offset centre,
    double radius,
    double bank,
    NeonInk ink,
    double dim,
  ) {
    const samples = 14;
    for (var i = samples; i > 0; i--) {
      final back = i / samples;
      final at = phase - back * 0.12;
      final x = centre.dx + math.sin(at * _tau * _bankHz) * radius * 0.5;
      final y = centre.dy + radius * (0.8 + back * 1.6);

      paint.color = _fade(ink.aura, dim * (1.0 - back) * 0.5);
      canvas.drawCircle(
        Offset(x, y),
        radius * 0.17 * skin.trailWidthScale * (1.0 - back * 0.65),
        paint,
      );
    }
  }

  Color _fade(Color color, double factor) =>
      color.withValues(alpha: color.a * factor);

  @override
  bool shouldRepaint(_SkinPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.skin != skin ||
      oldDelegate.hue != hue ||
      oldDelegate.lit != lit;
}
