library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:playable_core/playable_core.dart';

import 'palette.dart';
import 'viewport_layout.dart';

class BonusHud {
  BonusHud({required bool showKeyHints})
      // ignore: prefer_initializing_formals
      : _showKeyHints = showKeyHints,
        _inks = <NeonInk>[
          for (final kind in BonusKind.values) NeonInk.fromHue(kind.hue),
        ];

  static const double _cornerFraction = 0.26;

  static const double _edgeFraction = 0.022;
  static const double _glyphStrokeFraction = 0.075;

  static const double _glyphFraction = 0.46;

  static const double _breathHz = 1.0;
  static const double _breathDepth = 0.045;

  static const double _popSeconds = 0.34;
  static const double _popDepth = 0.3;

  static const double _pressInset = 0.055;

  static const double _pillHeightFraction = 0.34;
  static const double _pillGapFraction = 0.12;
  static const double _pillGapAbove = 0.22;

  static const double _tau = 6.283185307179586;

  final bool _showKeyHints;
  final List<NeonInk> _inks;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final List<TextPainter> _hintPainters = <TextPainter>[];
  double _hintSide = -1.0;

  final List<BonusKind?> _lastKind = <BonusKind?>[];
  final List<double> _filledAtPhase = <double>[];

  void paint(
    Canvas canvas,
    WorldView world,
    ViewportLayout layout, {
    required double animationPhase,
    required int pressedSlot,
    required double prominence,
  }) {
    if (prominence <= 0.0) return;

    final breath =
        1.0 + math.sin(animationPhase * _tau * _breathHz) * _breathDepth;

    _noticeFills(world, animationPhase);

    for (var i = 0; i < layout.slotCount; i++) {
      final rect = layout.slotRect(i);
      if (rect.isEmpty) continue;
      _paintSlot(
        canvas,
        rect,
        world.slotAt(i),
        breath: breath * _popAt(i, animationPhase),
        pressed: pressedSlot == i,
        prominence: prominence,
      );
    }

    _paintActiveStrip(canvas, world, layout, prominence);
  }

  void _noticeFills(WorldView world, double phase) {
    while (_lastKind.length < world.slotCount) {
      _lastKind.add(null);
      _filledAtPhase.add(-1.0);
    }

    for (var i = 0; i < world.slotCount; i++) {
      final kind = world.slotAt(i);
      if (kind != null && _lastKind[i] == null) _filledAtPhase[i] = phase;
      _lastKind[i] = kind;
    }
  }

  double _popAt(int index, double phase) {
    if (index >= _filledAtPhase.length) return 1.0;

    final startedAt = _filledAtPhase[index];
    if (startedAt < 0.0) return 1.0;

    var elapsed = phase - startedAt;
    if (elapsed < 0.0) elapsed += 1.0;
    if (elapsed >= _popSeconds) return 1.0;

    final along = elapsed / _popSeconds;
    return 1.0 + _popDepth * (1.0 - along) * math.sin(along * math.pi * 1.5);
  }

  void _paintSlot(
    Canvas canvas,
    Rect rect,
    BonusKind? kind, {
    required double breath,
    required bool pressed,
    required double prominence,
  }) {
    final side = rect.width;
    final corner = Radius.circular(side * _cornerFraction);

    final scale = kind == null ? 1.0 : breath;
    final inset = pressed ? side * _pressInset : 0.0;
    final plate = Rect.fromCenter(
      center: rect.center,
      width: side * scale - inset * 2.0,
      height: side * scale - inset * 2.0,
    );
    final rounded = RRect.fromRectAndRadius(plate, corner);

    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;
    _stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver;

    if (kind == null) {
      _paintEmptyPlate(canvas, rounded, plate, side, prominence);
      return;
    }

    final ink = _inks[kind.index];
    final lift = pressed ? 1.35 : 1.0;

    _fill.color = _scaled(ink.halo, prominence * lift);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        plate.inflate(side * 0.1),
        Radius.circular(side * (_cornerFraction + 0.1)),
      ),
      _fill,
    );

    _fill.color = _scaled(ink.halo, prominence * 1.8 * lift);
    canvas.drawRRect(rounded, _fill);

    _paintSheen(canvas, plate, corner, _scaled(ink.aura, prominence * lift));

    _stroke
      ..color = _scaled(ink.edge, prominence * lift)
      ..strokeWidth = math.max(1.0, side * _edgeFraction);
    canvas.drawRRect(rounded, _stroke);

    _paintGlyph(
      canvas,
      kind,
      plate.center,
      side * _glyphFraction * 0.5,
      _scaled(ink.core, prominence),
      side,
    );
  }

  void _paintEmptyPlate(
    Canvas canvas,
    RRect rounded,
    Rect plate,
    double side,
    double prominence,
  ) {
    _fill.color = _scaled(Palette.glassFill, prominence * 0.8);
    canvas.drawRRect(rounded, _fill);

    _stroke
      ..color = _scaled(Palette.slotEmptyEdge, prominence)
      ..strokeWidth = math.max(1.0, side * _edgeFraction);
    canvas.drawRRect(rounded, _stroke);

    final reach = side * 0.17;
    _stroke
      ..color = _scaled(Palette.slotEmptyMark, prominence)
      ..strokeWidth = math.max(1.0, side * _glyphStrokeFraction * 0.8);
    canvas.drawLine(
      plate.center.translate(-reach, 0.0),
      plate.center.translate(reach, 0.0),
      _stroke,
    );
  }

  void _paintSheen(Canvas canvas, Rect plate, Radius corner, Color color) {
    final sheen = Rect.fromLTWH(
      plate.left,
      plate.top,
      plate.width,
      plate.height * 0.34,
    );
    _fill.color = color;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        sheen,
        topLeft: corner,
        topRight: corner,
      ),
      _fill,
    );
  }

  void _paintKeyHint(Canvas canvas, Rect plate, int index) {
    if (index >= _hintPainters.length) return;

    final painter = _hintPainters[index];
    painter.paint(
      canvas,
      Offset(
        plate.left + plate.width * 0.1,
        plate.top + plate.height * 0.06,
      ),
    );
  }

  void _ensureHints(double side, int count) {
    if (_hintSide == side && _hintPainters.length == count) return;
    _hintSide = side;

    final style = TextStyle(
      color: Palette.hudDim,
      fontSize: side * 0.19,
      fontWeight: FontWeight.w600,
      letterSpacing: side * 0.01,
    );

    _hintPainters.clear();
    for (var i = 0; i < count; i++) {
      _hintPainters.add(
        TextPainter(
          text: TextSpan(text: '${i + 1}', style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
    }
  }

  void _paintActiveStrip(
    Canvas canvas,
    WorldView world,
    ViewportLayout layout,
    double prominence,
  ) {
    final row = layout.slotRow;
    if (row.isEmpty) return;

    final side = row.height;
    final height = side * _pillHeightFraction;
    final gap = side * _pillGapFraction;

    var width = 0.0;
    var shown = 0;
    for (final kind in BonusKind.values) {
      if (!_isShownAsActive(world, kind)) continue;
      width += _pillWidth(world, kind, height) + (shown > 0 ? gap : 0.0);
      shown++;
    }
    if (shown == 0) return;

    var left = row.center.dx - width * 0.5;
    final top = row.top - side * _pillGapAbove - height;

    for (final kind in BonusKind.values) {
      if (!_isShownAsActive(world, kind)) continue;
      final pillWidth = _pillWidth(world, kind, height);
      _paintPill(
        canvas,
        Rect.fromLTWH(left, top, pillWidth, height),
        kind,
        world,
        prominence,
      );
      left += pillWidth + gap;
    }
  }

  bool _isShownAsActive(WorldView world, BonusKind kind) =>
      kind.isCharge ? world.shieldCharges > 0 : world.remainingFor(kind) > 0.0;

  double _pillWidth(WorldView world, BonusKind kind, double height) {
    if (!kind.isCharge) return height * 2.9;
    return height * (1.0 + world.shieldCharges * 0.62);
  }

  void _paintPill(
    Canvas canvas,
    Rect rect,
    BonusKind kind,
    WorldView world,
    double prominence,
  ) {
    final ink = _inks[kind.index];
    final corner = Radius.circular(rect.height * 0.5);
    final rounded = RRect.fromRectAndRadius(rect, corner);

    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = _scaled(ink.halo, prominence * 2.0);
    canvas.drawRRect(rounded, _fill);

    if (kind.isCharge) {
      _paintChargePips(canvas, rect, world.shieldCharges, ink, prominence);
    } else {
      _paintDrain(canvas, rect, kind, world, ink, prominence);
    }

    _stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = _scaled(ink.edge, prominence * 0.8)
      ..strokeWidth = math.max(1.0, rect.height * 0.055);
    canvas.drawRRect(rounded, _stroke);

    _paintGlyph(
      canvas,
      kind,
      Offset(rect.left + rect.height * 0.5, rect.center.dy),
      rect.height * 0.3,
      _scaled(ink.core, prominence),
      rect.height,
    );
  }

  void _paintDrain(
    Canvas canvas,
    Rect rect,
    BonusKind kind,
    WorldView world,
    NeonInk ink,
    double prominence,
  ) {
    final total = kind.seconds;
    if (total <= 0.0) return;

    var fraction = world.remainingFor(kind) / total;
    if (fraction > 1.0) fraction = 1.0;

    final track = Rect.fromLTRB(
      rect.left + rect.height * 0.95,
      rect.center.dy - rect.height * 0.14,
      rect.right - rect.height * 0.28,
      rect.center.dy + rect.height * 0.14,
    );
    if (track.width <= 0.0) return;

    final corner = Radius.circular(track.height * 0.5);
    _fill.color = _scaled(Palette.routeTrack, prominence);
    canvas.drawRRect(RRect.fromRectAndRadius(track, corner), _fill);

    _fill.color = _scaled(ink.edge, prominence);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          track.left,
          track.top,
          track.width * fraction,
          track.height,
        ),
        corner,
      ),
      _fill,
    );
  }

  void _paintChargePips(
    Canvas canvas,
    Rect rect,
    int charges,
    NeonInk ink,
    double prominence,
  ) {
    final radius = rect.height * 0.13;
    final step = radius * 2.8;
    var centre = Offset(rect.left + rect.height * 1.05 + radius, rect.center.dy);

    _fill.color = _scaled(ink.edge, prominence);
    for (var i = 0; i < charges; i++) {
      canvas.drawCircle(centre, radius, _fill);
      centre = centre.translate(step, 0.0);
    }
  }

  void paintFieldGlyph(
    Canvas canvas,
    BonusKind kind,
    Offset centre,
    double radius,
    Color color,
    double strokeBasis,
  ) =>
      _paintGlyph(canvas, kind, centre, radius, color, strokeBasis);

  void _paintGlyph(
    Canvas canvas,
    BonusKind kind,
    Offset centre,
    double radius,
    Color color,
    double side,
  ) {
    _stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = color
      ..strokeWidth = math.max(1.2, side * _glyphStrokeFraction);
    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = color;

    switch (kind) {
      case BonusKind.chrono:
        _paintClock(canvas, centre, radius);
      case BonusKind.overdrive:
        _paintChevrons(canvas, centre, radius);
      case BonusKind.shield:
        _paintShield(canvas, centre, radius);
      case BonusKind.magnet:
        _paintMagnet(canvas, centre, radius);
    }
  }

  void _paintClock(Canvas canvas, Offset centre, double radius) {
    canvas.drawCircle(centre, radius * 0.92, _stroke);
    canvas.drawLine(
      centre,
      centre.translate(0.0, -radius * 0.58),
      _stroke,
    );
    canvas.drawLine(
      centre,
      centre.translate(radius * 0.46, radius * 0.18),
      _stroke,
    );
  }

  void _paintChevrons(Canvas canvas, Offset centre, double radius) {
    final reach = radius * 0.82;
    for (final offset in <double>[radius * 0.42, -radius * 0.38]) {
      final path = Path()
        ..moveTo(centre.dx - reach, centre.dy + offset + reach * 0.52)
        ..lineTo(centre.dx, centre.dy + offset - reach * 0.3)
        ..lineTo(centre.dx + reach, centre.dy + offset + reach * 0.52);
      canvas.drawPath(path, _stroke);
    }
  }

  void _paintShield(Canvas canvas, Offset centre, double radius) {
    final path = Path()
      ..moveTo(centre.dx - radius * 0.78, centre.dy - radius * 0.76)
      ..lineTo(centre.dx + radius * 0.78, centre.dy - radius * 0.76)
      ..lineTo(centre.dx + radius * 0.66, centre.dy + radius * 0.2)
      ..quadraticBezierTo(
        centre.dx + radius * 0.52,
        centre.dy + radius * 0.76,
        centre.dx,
        centre.dy + radius * 0.96,
      )
      ..quadraticBezierTo(
        centre.dx - radius * 0.52,
        centre.dy + radius * 0.76,
        centre.dx - radius * 0.66,
        centre.dy + radius * 0.2,
      )
      ..close();
    canvas.drawPath(path, _stroke);
  }

  void _paintMagnet(Canvas canvas, Offset centre, double radius) {
    final box = Rect.fromCircle(
      center: centre.translate(0.0, radius * 0.16),
      radius: radius * 0.74,
    );
    canvas.drawArc(box, math.pi, math.pi, false, _stroke);

    final tipY = box.center.dy;
    final span = radius * 0.3;
    for (final sign in <double>[-1.0, 1.0]) {
      canvas.drawLine(
        Offset(box.center.dx + sign * box.width * 0.5, tipY),
        Offset(box.center.dx + sign * box.width * 0.5, tipY + span),
        _stroke,
      );
    }
  }

  Color _scaled(Color color, double factor) {
    final alpha = color.a * factor;
    return color.withValues(alpha: alpha > 1.0 ? 1.0 : alpha);
  }

  void paintKeyHints(Canvas canvas, ViewportLayout layout) {
    if (!_showKeyHints) return;

    final first = layout.slotRect(0);
    if (first.isEmpty) return;
    _ensureHints(first.width, layout.slotCount);

    for (var i = 0; i < layout.slotCount; i++) {
      final rect = layout.slotRect(i);
      if (rect.isEmpty) continue;
      _paintKeyHint(canvas, rect, i);
    }
  }
}
