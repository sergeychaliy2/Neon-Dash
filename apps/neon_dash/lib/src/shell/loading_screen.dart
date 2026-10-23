library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:playable_core/playable_core.dart';

import '../render/craft_shape.dart';
import '../render/palette.dart';
import '../ui/neon_widgets.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    required this.title,
    required this.caption,
    required this.progress,
    this.theme,
    super.key,
  });

  final String title;

  final String caption;

  final double progress;

  final LevelTheme? theme;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _cycle = Duration(seconds: 4);

  static const Duration _settle = Duration(milliseconds: 420);

  final List<TextPainter> _glyphWarmUp = <TextPainter>[];
  double _warmedFor = -1.0;

  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  void _ensureGlyphs(Size size) {
    final scale = size.height / GameConfig.neonDash.viewport.worldHeight;
    if (_warmedFor == scale) return;
    _warmedFor = scale;

    const text = '0123456789 CLOSEORBSPRETAU';
    _glyphWarmUp
      ..clear()
      ..addAll(<double>[5.6, 3.0, 1.9].map(
        (multiple) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: Palette.hudPrimary,
              fontSize: multiple * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      ));
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final accent = theme == null
        ? colorFromHsl(Palette.craftHue, 0.9, 0.62)
        : colorOfTheme(theme.craft);

    _ensureGlyphs(MediaQuery.sizeOf(context));

    final hazard = theme == null
        ? colorFromHsl(196.0, 0.9, 0.6)
        : colorOfTheme(theme.hazard);
    final skyFar = theme == null ? Palette.skyFar : colorOfTheme(theme.skyFar);
    final skyNear =
        theme == null ? Palette.skyNear : colorOfTheme(theme.skyNear);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.progress),
      duration: _settle,
      curve: Curves.easeOut,
      builder: (context, eased, child) => AnimatedBuilder(
        animation: _clock,
        builder: (context, inner) => CustomPaint(
          painter: _LoaderPainter(
            phase: _clock.value,
            progress: eased,
            accent: accent,
            hazard: hazard,
            skyFar: skyFar,
            skyNear: skyNear,
            glyphWarmUp: _glyphWarmUp,
          ),
          child: inner,
        ),
        child: child,
      ),
      child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                NeonLabel(
                  widget.title,
                  size: 34.0,
                  color: accent,
                  weight: FontWeight.w800,
                  tracking: 9.0,
                  maxLines: 2,
                ),
                const SizedBox(height: 120.0),
                NeonLabel(
                  widget.caption,
                  size: 11.0,
                  color: Palette.hudDim,
                  glow: 0.0,
                  tracking: 3.0,
                  weight: FontWeight.w500,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter({
    required this.phase,
    required this.progress,
    required this.accent,
    required this.hazard,
    required this.skyFar,
    required this.skyNear,
    required this.glyphWarmUp,
  });

  final double phase;
  final double progress;
  final Color accent;
  final Color hazard;
  final Color skyFar;
  final Color skyNear;

  final List<TextPainter> glyphWarmUp;

  static const double _tau = 6.283185307179586;

  static const int _rungs = 14;
  static const double _rungsPerCycle = 2.0;

  static const double _sweep = 0.62;

  static final Path _warmHull = buildHullPath(CraftSkin.standard, 0.5);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final rect = Offset.zero & size;

    _paintSky(canvas, rect, paint);
    _paintCorridor(canvas, rect, paint);
    _paintCraft(canvas, rect, paint);
    _paintBar(canvas, rect, paint);
    _warmUpPipelines(canvas, rect);
  }

  void _warmUpPipelines(Canvas canvas, Rect rect) {
    final corner = Rect.fromLTWH(rect.left, rect.top, 2.0, 2.0);
    canvas
      ..save()
      ..clipRect(corner);

    final paint = Paint()..isAntiAlias = true;

    paint
      ..blendMode = BlendMode.plus
      ..color = accent;
    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.fromList(<double>[
          corner.left, corner.top,
          corner.right, corner.top,
          corner.left, corner.bottom,
        ]),
        colors: Int32List.fromList(<int>[
          0x40FFFFFF, 0x40FFFFFF, 0x40FFFFFF,
        ]),
      ),
      BlendMode.dst,
      paint,
    );

    paint
      ..blendMode = BlendMode.srcOver
      ..shader = ui.Gradient.linear(
        corner.topCenter,
        corner.bottomCenter,
        <Color>[accent, skyFar],
      );
    canvas.drawRect(corner, paint);
    paint.shader = null;

    paint.color = accent;
    canvas
      ..save()
      ..translate(corner.left, corner.top)
      ..scale(1.2)
      ..drawPath(_warmHull, paint)
      ..restore();

    final rounded = RRect.fromRectAndRadius(corner, const Radius.circular(0.5));
    canvas.drawRRect(rounded, paint);

    canvas
      ..drawCircle(corner.center, 0.8, paint)
      ..drawPath(
        Path()
          ..moveTo(corner.left, corner.top)
          ..lineTo(corner.right, corner.top)
          ..lineTo(corner.center.dx, corner.bottom)
          ..close(),
        paint,
      );

    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(corner)
        ..addOval(Rect.fromCenter(center: corner.center, width: 1.0, height: 1.0)),
      paint,
    );

    paint.blendMode = BlendMode.plus;
    canvas.drawCircle(corner.center, 0.9, paint);

    paint
      ..blendMode = BlendMode.srcOver
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rounded, paint);
    canvas.drawCircle(corner.center, 0.7, paint);

    paint.blendMode = BlendMode.plus;
    canvas.drawLine(corner.topLeft, corner.bottomRight, paint);
    paint.blendMode = BlendMode.srcOver;

    for (final painter in glyphWarmUp) {
      painter.paint(canvas, corner.topLeft);
    }

    canvas.restore();
  }

  void _paintSky(Canvas canvas, Rect rect, Paint paint) {
    paint
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        <Color>[skyFar, skyNear],
      )
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(rect, paint);
    paint.shader = null;
  }

  void _paintCorridor(Canvas canvas, Rect rect, Paint paint) {
    final centre = rect.center.dx;
    final horizon = rect.top + rect.height * 0.3;
    final travel = (phase * _rungsPerCycle) % 1.0;

    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _rungs; i++) {
      final step = (i + travel) / _rungs;
      final depth = step * step;
      final y = horizon + (rect.bottom - horizon) * depth;
      final halfWidth = rect.width * 0.08 + rect.width * 0.52 * depth;
      final fade = depth * (1.0 - depth * 0.25);

      paint
        ..color = hazard.withValues(alpha: 0.5 * fade)
        ..strokeWidth = 1.0 + 2.6 * depth;
      canvas.drawLine(
        Offset(centre - halfWidth, y),
        Offset(centre + halfWidth, y),
        paint,
      );
    }

    paint
      ..color = accent.withValues(alpha: 0.5)
      ..strokeWidth = 2.0;
    for (final side in <double>[-1.0, 1.0]) {
      canvas.drawLine(
        Offset(centre + side * rect.width * 0.08, horizon),
        Offset(centre + side * rect.width * 0.6, rect.bottom),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
  }

  void _paintCraft(Canvas canvas, Rect rect, Paint paint) {
    final centre = rect.center.dx;
    final y = rect.top + rect.height * 0.72;
    final reach = rect.width * 0.34 * _sweep;

    const samples = 16;
    for (var i = samples; i > 0; i--) {
      final back = i / samples;
      final at = phase - back * 0.11;
      final x = centre + math.sin(at * _tau) * reach;
      final ribbonY = y + back * rect.height * 0.14;

      paint.color = accent.withValues(alpha: 0.3 * (1.0 - back));
      canvas.drawCircle(
        Offset(x, ribbonY),
        rect.width * 0.012 * (1.0 - back * 0.7),
        paint,
      );
    }

    final x = centre + math.sin(phase * _tau) * reach;
    final nose = Offset(x, y);
    final radius = rect.width * 0.035;

    paint.color = accent.withValues(alpha: 0.16);
    canvas.drawCircle(nose, radius * 2.6, paint);

    final bank = math.cos(phase * _tau) * 0.4;
    canvas
      ..save()
      ..translate(nose.dx, nose.dy)
      ..rotate(bank);

    final hull = Path()
      ..moveTo(0.0, -radius)
      ..lineTo(radius * 0.82, radius * 0.86)
      ..lineTo(0.0, radius * 0.46)
      ..lineTo(-radius * 0.82, radius * 0.86)
      ..close();

    paint.color = accent;
    canvas
      ..drawPath(hull, paint)
      ..restore();
  }

  void _paintBar(Canvas canvas, Rect rect, Paint paint) {
    final width = math.min(rect.width * 0.62, 320.0);
    final track = Rect.fromLTWH(
      rect.center.dx - width * 0.5,
      rect.center.dy + 34.0,
      width,
      4.0,
    );
    final corner = Radius.circular(track.height * 0.5);

    paint.color = Palette.routeTrack;
    canvas.drawRRect(RRect.fromRectAndRadius(track, corner), paint);

    final filled = track.width * progress.clamp(0.0, 1.0);
    if (filled <= 0.0) return;

    paint.color = accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(track.left, track.top, filled, track.height),
        corner,
      ),
      paint,
    );

    paint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.85);
    canvas.drawCircle(
      Offset(track.left + filled, track.center.dy),
      3.4,
      paint,
    );
  }

  @override
  bool shouldRepaint(_LoaderPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent;
}
