import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' hide TextStyle;

import 'package:flutter/rendering.dart' hide Gradient;
import 'package:playable_core/playable_core.dart';

import 'backdrop.dart';
import 'bonus_hud.dart';
import 'craft_shape.dart';
import 'palette.dart';
import 'screen_effects.dart';
import 'viewport_layout.dart';

class NeonPainter extends CustomPainter {
  NeonPainter({
    required WorldView world,
    required ScreenEffects effects,
    required LevelTheme theme,
    required super.repaint,
    CraftSkin skin = CraftSkin.standard,
    bool showKeyHints = false,
  })  : _backdrop = Backdrop(theme),
        _trim = theme.trim,
        _face = theme.face,
        _skin = skin,
        _hullPaths = buildHullPaths(skin),
        _exhaustOffsets = exhaustOffsets(skin),
        _exhaustWidth = exhaustWidthScale(skin),
        _exhaustSeat = exhaustSeat(skin),
        _bonusHud = BonusHud(showKeyHints: showKeyHints),
        _pickupInks = <NeonInk>[
          for (final kind in BonusKind.values) NeonInk.fromHue(kind.hue),
        ],
        _craftHue = skin.hueOverride ?? theme.craft.hue,
        _skyFar = colorOfTheme(theme.skyFar),
        _skyNear = colorOfTheme(theme.skyNear),
        _surroundFar = colorOfTheme(theme.surroundFar),
        _surroundNear = colorOfTheme(theme.surroundNear),
        _gridHorizon = colorOfTheme(theme.horizon),
        _horizonFade = colorFromHsl(
          theme.horizon.hue,
          theme.horizon.saturation,
          theme.horizon.lightness,
          0.0,
        ),
        _railCore = colorOfTheme(theme.rail),
        _railGlow = colorFromHsl(
          theme.rail.hue,
          theme.rail.saturation,
          theme.rail.lightness,
          theme.rail.alpha * 0.25,
        ),
        _world = world,
        // ignore: prefer_initializing_formals
        _effects = effects,
        _craftInk = NeonInk.fromHue(skin.hueOverride ?? theme.craft.hue),
        _finishInk = NeonInk.fromHue(theme.orb.hue),
        _orbInk = NeonInk.fromHue(theme.orb.hue),
        _obstacleInkByShape = List<NeonInk>.generate(
          ObstacleShape.values.length,
          (index) => NeonInk.fromHue(
            theme.hazard.hue + _shapeHueOffsets[index],
          ),
          growable: false,
        ),
        _particlePositions =
            Float32List(world.config.pools.maxParticles * _floatsPerQuad),
        _particleColors =
            Int32List(world.config.pools.maxParticles * _verticesPerQuad),
        _trailColors = _buildTrailColors(
          world.config.trailCapacity,
          skin.hueOverride ?? theme.craft.hue,
        ),
        _trailWidths = _buildTrailWidths(world.config.trailCapacity);

  static const int _verticesPerQuad = 6;
  static const int _floatsPerQuad = _verticesPerQuad * 2;

  static const double _horizonDepth = 0.22;

  static const double _railGlowWidth = 2.4;
  static const double _railCoreWidth = 0.4;

  static const double _haloFraction = 0.35;
  static const double _haloMaxWorld = 1.4;
  static const double _cornerFraction = 0.26;
  static const double _cornerMaxWorld = 1.2;
  static const double _coreInsetFraction = 0.28;
  static const double _coreInsetMaxWorld = 1.0;

  static const List<double> _shapeHueOffsets = <double>[
    0.0,
    170.0,
    86.0,
    40.0,
    250.0,
  ];

  static const double _particleRadius = 0.5;
  static const double _glowPassSize = 2.6;
  static const double _glowPassAlpha = 0.3;
  static const double _corePassSize = 1.0;
  static const double _corePassAlpha = 0.95;

  static const double _craftRadius = 2.6;

  static const double _guardRadius = 1.9;
  static const double _guardHz = 3.0;
  static const double _craftBankRadians = 0.42;

  static const double _bankFlatten = 0.3;

  static const double _trailWingOffset = 0.62;
  static const double _trailRibbonWidth = 0.72;

  static const double _coreBaseHz = 2.0;

  static const double _orbBreathHz = 1.0;

  static const double _sawSpinHz = 1.0;

  static const double _portalHeightWorld = 3.2;
  static const double _portalChevronWorld = 7.0;
  static const double _portalFrameWorld = 0.9;
  static const double _portalPulseHz = 2.0;

  static const double _pickupSpinHz = 1.0;

  static const double _flameSlowHz = 3.0;
  static const double _flameFastHz = 5.0;
  static const double _flameSlowDepth = 0.085;
  static const double _flameFastDepth = 0.05;

  static const double _flameLengthAtRest = 1.15;
  static const double _flameLengthGain = 0.85;

  static const double _tau = 6.283185307179586;

  static const double _hudInset = 4.0;

  static const double _stripTopWorld = 2.2;
  static const double _stripHeightWorld = 1.7;
  static const double _stripInsetWorld = 3.0;
  static const double _stripEdgeWorld = 0.12;

  static const double _hudTopWorld = 6.2;

  static const double _zoneCornerWorld = 2.6;
  static const double _zoneEdgeWorld = 0.16;
  static const double _sheenFraction = 0.32;
  static const double _arrowRadiusWorld = 5.0;
  static const double _arrowPulseHz = 1.0;

  final WorldView _world;
  final ScreenEffects _effects;

  final Backdrop _backdrop;
  final BonusHud _bonusHud;

  final List<NeonInk> _pickupInks;

  static final List<NeonInk> _portalInks = <NeonInk>[
    for (final kind in PortalKind.values) NeonInk.fromHue(kind.hue),
  ];

  static final Color _shieldFlashColor =
      colorFromHsl(BonusKind.shield.hue, 0.85, 0.62);

  static final NeonInk _guardInk = NeonInk.fromHue(BonusKind.shield.hue);

  final double _craftHue;
  final Color _skyFar;
  final Color _skyNear;
  final Color _surroundFar;
  final Color _surroundNear;
  final Color _gridHorizon;

  final Color _horizonFade;

  final Color _railCore;
  final Color _railGlow;

  final NeonInk _craftInk;

  final NeonInk _finishInk;
  final NeonInk _orbInk;
  final List<NeonInk> _obstacleInkByShape;

  final Float32List _particlePositions;
  final Int32List _particleColors;

  final List<Color> _trailColors;
  final Float32List _trailWidths;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  final Paint _particlePaint = Paint()..blendMode = BlendMode.plus;

  final CraftSkin _skin;
  final List<Path> _hullPaths;
  final List<double> _exhaustOffsets;
  final double _exhaustWidth;
  final double _exhaustSeat;
  final Path _exhaustPath = buildExhaustPath();
  final Path _corePath = _buildCorePath();
  final Path _spikePath = _buildSpikePath();
  final Path _minePath = _buildMinePath();

  Size? _shaderSize;
  double? _shaderFieldWidth;
  Shader? _surroundShader;
  Shader? _fieldShader;
  Shader? _horizonShader;

  final TextPainter _scorePainter =
      TextPainter(textDirection: TextDirection.ltr);
  final TextPainter _tallyPainter =
      TextPainter(textDirection: TextDirection.ltr);
  final TextPainter _promptPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  final TextPainter _finishPainter =
      TextPainter(textDirection: TextDirection.ltr);

  int _scoreShown = -1;
  int _nearMissShown = -1;
  int _orbsShown = -1;
  double _hudScale = -1.0;
  GamePhase? _promptPhase;
  double _promptWidth = -1.0;
  double _finishScale = -1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final world = _world;
    final layout = ViewportLayout.fit(
      size,
      world.fieldWidth,
      world.fieldHeight,
      slotCount: world.slotCount,
    );
    final fieldRect = layout.fieldRect;
    final scale = layout.scale;

    _ensureShaders(size, fieldRect, world.fieldWidth);

    _paintSurround(canvas, size, fieldRect);

    canvas.save();
    canvas.clipRect(fieldRect);
    canvas.translate(_effects.shakeX * scale, _effects.shakeY * scale);

    _paintField(canvas, fieldRect);
    _backdrop.paint(
      canvas,
      fieldRect,
      scale,
      world.distance,
      _effects.animationPhase,
      _fill,
      _stroke,
    );
    _paintRails(canvas, fieldRect, scale);
    _paintFinish(canvas, fieldRect, scale);
    _paintTrail(canvas, fieldRect, scale);
    _paintObstacles(canvas, fieldRect, scale);
    _paintOrbs(canvas, fieldRect, scale);
    _paintPickups(canvas, fieldRect, scale);
    _paintPortals(canvas, fieldRect, scale);
    _paintStretch(canvas, fieldRect, scale);
    _paintParticles(canvas, fieldRect, scale);
    _paintCraft(canvas, fieldRect, scale);

    canvas.restore();

    _paintFlash(canvas, size);
    _paintPortalSweep(canvas, size);
    _paintControlZones(canvas, layout);
    _paintRouteStrip(canvas, fieldRect, scale);
    _paintHud(canvas, fieldRect, scale);
    _bonusHud.paint(
      canvas,
      world,
      layout,
      animationPhase: _effects.animationPhase,
      pressedSlot: _effects.pressedSlot,
      prominence: 1.0,
    );
    _bonusHud.paintKeyHints(canvas, layout);
  }

  void _paintPortals(Canvas canvas, Rect fieldRect, double scale) {
    final world = _world;
    if (world.portalCount == 0) return;

    final height = _portalHeightWorld * scale;
    final pulse =
        0.5 + 0.5 * math.sin(_effects.animationPhase * _tau * _portalPulseHz);

    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;
    _stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver;

    for (var i = 0; i < world.portalCount; i++) {
      final kind = world.portalKindAt(i);
      final ink = _portalInks[kind.index];
      final centreY = fieldRect.top + world.portalY[i] * scale;

      final band = Rect.fromLTRB(
        fieldRect.left,
        centreY - height * 0.5,
        fieldRect.right,
        centreY + height * 0.5,
      );

      _fill.color = ink.halo;
      canvas.drawRect(band.inflate(height * 0.6), _fill);
      _fill.color = ink.aura;
      canvas.drawRect(band, _fill);

      _stroke
        ..color = ink.edge
        ..strokeWidth = math.max(1.0, 0.2 * scale);
      canvas
        ..drawLine(
          Offset(band.left, band.top),
          Offset(band.right, band.top),
          _stroke,
        )
        ..drawLine(
          Offset(band.left, band.bottom),
          Offset(band.right, band.bottom),
          _stroke,
        );

      _paintPortalChevrons(canvas, band, ink, pulse, scale);
    }
  }

  void _paintPortalChevrons(
    Canvas canvas,
    Rect band,
    NeonInk ink,
    double pulse,
    double scale,
  ) {
    final step = _portalChevronWorld * scale;
    if (step <= 0.0) return;

    final reach = band.height * 0.3;
    _stroke
      ..color = ink.core.withValues(alpha: 0.35 + 0.4 * pulse)
      ..strokeWidth = math.max(1.0, 0.14 * scale);

    for (var x = band.left + step * 0.5; x < band.right; x += step) {
      canvas
        ..drawLine(
          Offset(x - reach, band.center.dy - reach * 0.6),
          Offset(x, band.center.dy + reach * 0.6),
          _stroke,
        )
        ..drawLine(
          Offset(x, band.center.dy + reach * 0.6),
          Offset(x + reach, band.center.dy - reach * 0.6),
          _stroke,
        );
    }
  }

  void _paintStretch(Canvas canvas, Rect fieldRect, double scale) {
    final kind = _world.portal;
    if (kind == null) return;

    final ink = _portalInks[kind.index];
    final strength = _world.portalRemaining < 1.0
        ? _world.portalRemaining
        : 1.0;

    if (kind.scrollScale > 1.0) {
      _paintSpeedStreaks(canvas, fieldRect, scale, ink, strength);
    }

    _stroke
      ..shader = null
      ..blendMode = BlendMode.plus
      ..color = ink.edge.withValues(alpha: 0.5 * strength)
      ..strokeWidth = math.max(2.0, _portalFrameWorld * scale);
    canvas.drawRect(fieldRect.deflate(_portalFrameWorld * scale * 0.5), _stroke);
    _stroke.blendMode = BlendMode.srcOver;
  }

  void _paintSpeedStreaks(
    Canvas canvas,
    Rect fieldRect,
    double scale,
    NeonInk ink,
    double strength,
  ) {
    const streaks = 14;
    final travel = (_world.distance * 0.05) % 1.0;

    _stroke
      ..shader = null
      ..blendMode = BlendMode.plus
      ..strokeWidth = math.max(1.0, 0.1 * scale);

    for (var i = 0; i < streaks; i++) {
      final across = (i * 0.618) % 1.0;
      var along = (i / streaks + travel) % 1.0;
      if (along < 0.0) along += 1.0;

      final x = fieldRect.left + fieldRect.width * across;
      final y = fieldRect.top + fieldRect.height * along;
      final length = fieldRect.height * 0.09;

      _stroke.color = ink.edge.withValues(alpha: 0.28 * strength);
      canvas.drawLine(Offset(x, y), Offset(x, y + length), _stroke);
    }

    _stroke.blendMode = BlendMode.srcOver;
  }

  void _paintPortalSweep(Canvas canvas, Size size) {
    final sweep = _effects.portalSweep;
    if (sweep <= 0.01) return;

    final kind = _world.portal;
    final ink = _portalInks[(kind ?? PortalKind.rush).index];

    _fill
      ..shader = null
      ..blendMode = BlendMode.plus
      ..color = ink.body.withValues(alpha: sweep * 0.3);
    canvas.drawRect(Offset.zero & size, _fill);
    _fill.blendMode = BlendMode.srcOver;
  }

  void _paintPickups(Canvas canvas, Rect fieldRect, double scale) {
    final world = _world;
    if (world.pickupCount == 0) return;

    final radius = world.config.bonus.pickupRadius * scale;
    final spin = _effects.animationPhase * _tau * _pickupSpinHz;
    final breath =
        0.5 + 0.5 * math.sin(_effects.animationPhase * _tau * _orbBreathHz);

    _fill.shader = null;
    _stroke.shader = null;

    for (var i = 0; i < world.pickupCount; i++) {
      final kind = world.pickupKindAt(i);
      final ink = _pickupInks[kind.index];
      final centre = Offset(
        fieldRect.left + world.pickupX[i] * scale,
        fieldRect.top + world.pickupY[i] * scale,
      );

      _fill.color = ink.halo;
      canvas.drawCircle(centre, radius * (2.5 + breath * 0.8), _fill);

      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(spin);

      _fill.color = ink.body;
      canvas.drawPath(_scaledDiamond(radius * 1.15), _fill);
      _stroke
        ..color = ink.edge
        ..strokeWidth = math.max(1.0, 0.22 * scale);
      canvas.drawPath(_scaledDiamond(radius * 1.5), _stroke);

      canvas.restore();

      _bonusHud.paintFieldGlyph(canvas, kind, centre, radius * 0.72, ink.core,
          radius * 2.0);
    }
  }

  Path _scaledDiamond(double reach) {
    _scratch.reset();
    return _scratch
      ..moveTo(0.0, -reach)
      ..lineTo(reach, 0.0)
      ..lineTo(0.0, reach)
      ..lineTo(-reach, 0.0)
      ..close();
  }

  void _paintRouteStrip(Canvas canvas, Rect fieldRect, double scale) {
    final route = _world.route;
    if (route.length <= 0.0) return;

    final inset = _stripInsetWorld * scale;
    final track = Rect.fromLTWH(
      fieldRect.left + inset,
      fieldRect.top + _stripTopWorld * scale,
      fieldRect.width - inset * 2.0,
      _stripHeightWorld * scale,
    );
    if (track.width <= 0.0) return;

    final corner = Radius.circular(track.height * 0.5);
    final rounded = RRect.fromRectAndRadius(track, corner);

    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = Palette.routeTrack;
    canvas.drawRRect(rounded, _fill);

    _paintRouteSegments(canvas, track, route);
    _paintRouteCheckpoints(canvas, track, route, scale);

    _stroke
      ..shader = null
      ..color = Palette.routeTrackEdge
      ..strokeWidth = math.max(1.0, _stripEdgeWorld * scale);
    canvas.drawRRect(rounded, _stroke);

    _paintRouteMarkers(canvas, track, scale);
  }

  void _paintRouteSegments(Canvas canvas, Rect track, Route route) {
    for (var i = 0; i < route.segmentCount; i++) {
      final hazard = route.classOfSegment(i);
      if (hazard == HazardClass.moderate) continue;

      final from = route.progressAt(route.segmentStart[i]);
      final to = route.progressAt(route.segmentEnd(i));

      _fill.color = hazard == HazardClass.dense
          ? Palette.routeDense
          : Palette.routeCalm;
      canvas.drawRect(
        Rect.fromLTRB(
          track.left + track.width * from,
          track.top,
          track.left + track.width * to,
          track.bottom,
        ),
        _fill,
      );
    }
  }

  void _paintRouteCheckpoints(
    Canvas canvas,
    Rect track,
    Route route,
    double scale,
  ) {
    final radius = track.height * 0.42;
    final passed = _world.checkpointsPassed;

    for (var i = 0; i < route.checkpointCount; i++) {
      final at = route.progressAt(route.checkpointDistance[i]);
      final centre = Offset(
        track.left + track.width * at,
        track.center.dy,
      );

      final banked = i < passed;
      _fill.color = banked
          ? Palette.routeCheckpointPassed
          : Palette.routeCheckpointAhead;
      canvas.drawCircle(centre, banked ? radius : radius * 0.62, _fill);
    }
  }

  void _paintRouteMarkers(Canvas canvas, Rect track, double scale) {
    final finish = Offset(track.right, track.center.dy);
    canvas.save();
    canvas.translate(finish.dx, finish.dy);
    canvas.rotate(math.pi * 0.25);
    _fill.color = Palette.routeFinish;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: track.height * 0.74,
        height: track.height * 0.74,
      ),
      _fill,
    );
    canvas.restore();

    final at = _world.routeProgress;
    final runner = Offset(track.left + track.width * at, track.center.dy);

    _fill.color = Palette.routeFinish;
    canvas.drawCircle(runner, track.height * 0.62, _fill);
    _fill.color = Palette.routeRunner;
    canvas.drawCircle(runner, track.height * 0.36, _fill);
  }

  void _paintControlZones(Canvas canvas, ViewportLayout layout) {
    final prominence = _effects.zoneProminence;
    if (prominence <= 0.01) return;

    final corner = Radius.circular(_zoneCornerWorld * layout.scale);

    _paintGlassPanel(canvas, layout.leftZone, corner, layout.scale, prominence);
    _paintGlassPanel(
      canvas,
      layout.rightZone,
      corner,
      layout.scale,
      prominence,
    );

    final pulse = 0.82 +
        0.18 * math.sin(_effects.animationPhase * _tau * _arrowPulseHz);
    final arrowRadius = _arrowRadiusWorld * layout.scale;

    _paintZoneArrow(
      canvas,
      layout.leftZone.center,
      arrowRadius,
      -1.0,
      prominence * pulse,
    );
    _paintZoneArrow(
      canvas,
      layout.rightZone.center,
      arrowRadius,
      1.0,
      prominence * pulse,
    );
  }

  void _paintGlassPanel(
    Canvas canvas,
    Rect zone,
    Radius corner,
    double scale,
    double prominence,
  ) {
    final panel = RRect.fromRectAndRadius(zone, corner);

    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = _scaleAlpha(Palette.glassFill, prominence);
    canvas.drawRRect(panel, _fill);

    _fill.color = _scaleAlpha(Palette.glassSheen, prominence);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          zone.left,
          zone.top,
          zone.right,
          zone.top + zone.height * _sheenFraction,
        ),
        corner,
      ),
      _fill,
    );

    _stroke
      ..shader = null
      ..color = _scaleAlpha(Palette.glassEdge, prominence)
      ..strokeWidth = math.max(1.0, _zoneEdgeWorld * scale);
    canvas.drawRRect(panel, _stroke);
  }

  void _paintZoneArrow(
    Canvas canvas,
    Offset centre,
    double radius,
    double direction,
    double prominence,
  ) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(direction * math.pi * 0.5);

    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = _scaleAlpha(_craftInk.halo, prominence);
    _paintUnitPath(canvas, _hullPaths.first, radius * 1.45);
    _fill.color = _scaleAlpha(_craftInk.body, prominence);
    _paintUnitPath(canvas, _hullPaths.first, radius);
    _fill.color = _scaleAlpha(_craftInk.core, prominence);
    _paintUnitPath(canvas, _hullPaths.first, radius * 0.5);

    canvas.restore();
  }

  static Color _scaleAlpha(Color color, double factor) =>
      factor >= 1.0 ? color : color.withValues(alpha: color.a * factor);

  void _ensureShaders(Size size, Rect fieldRect, double fieldWidth) {
    if (_shaderSize == size && _shaderFieldWidth == fieldWidth) return;
    _shaderSize = size;
    _shaderFieldWidth = fieldWidth;

    _surroundShader = Gradient.linear(
      Offset.zero,
      Offset(0.0, size.height),
      <Color>[_surroundFar, _surroundNear],
    );
    _fieldShader = Gradient.linear(
      fieldRect.topCenter,
      fieldRect.bottomCenter,
      <Color>[_skyFar, _skyNear],
    );
    _horizonShader = Gradient.linear(
      fieldRect.topCenter,
      Offset(
        fieldRect.center.dx,
        fieldRect.top + fieldRect.height * _horizonDepth,
      ),
      <Color>[_gridHorizon, _horizonFade],
    );
  }

  void _paintSurround(Canvas canvas, Size size, Rect fieldRect) {
    final coversWindow = fieldRect.left <= 0.0 &&
        fieldRect.top <= 0.0 &&
        fieldRect.right >= size.width &&
        fieldRect.bottom >= size.height;
    if (coversWindow) return;

    _fill
      ..shader = _surroundShader
      ..blendMode = BlendMode.srcOver;

    const seam = 1.0;

    if (fieldRect.left > 0.0) {
      canvas.drawRect(
        Rect.fromLTRB(0.0, 0.0, fieldRect.left + seam, size.height),
        _fill,
      );
    }
    if (fieldRect.right < size.width) {
      canvas.drawRect(
        Rect.fromLTRB(fieldRect.right - seam, 0.0, size.width, size.height),
        _fill,
      );
    }
    if (fieldRect.top > 0.0) {
      canvas.drawRect(
        Rect.fromLTRB(
          fieldRect.left,
          0.0,
          fieldRect.right,
          fieldRect.top + seam,
        ),
        _fill,
      );
    }
    if (fieldRect.bottom < size.height) {
      canvas.drawRect(
        Rect.fromLTRB(
          fieldRect.left,
          fieldRect.bottom - seam,
          fieldRect.right,
          size.height,
        ),
        _fill,
      );
    }

    _fill.shader = null;
  }

  void _paintField(Canvas canvas, Rect fieldRect) {
    _fill.shader = _fieldShader;
    canvas.drawRect(fieldRect, _fill);

    _fill.shader = _horizonShader;
    canvas.drawRect(
      Rect.fromLTWH(
        fieldRect.left,
        fieldRect.top,
        fieldRect.width,
        fieldRect.height * _horizonDepth,
      ),
      _fill,
    );
    _fill.shader = null;
  }

  void _paintRails(Canvas canvas, Rect fieldRect, double scale) {
    final glowWidth = _railGlowWidth * scale;
    final coreWidth = _railCoreWidth * scale;

    _fill
      ..shader = null
      ..color = _railGlow;
    canvas.drawRect(
      Rect.fromLTWH(fieldRect.left, fieldRect.top, glowWidth, fieldRect.height),
      _fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        fieldRect.right - glowWidth,
        fieldRect.top,
        glowWidth,
        fieldRect.height,
      ),
      _fill,
    );

    _fill.color = _railCore;
    canvas.drawRect(
      Rect.fromLTWH(fieldRect.left, fieldRect.top, coreWidth, fieldRect.height),
      _fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        fieldRect.right - coreWidth,
        fieldRect.top,
        coreWidth,
        fieldRect.height,
      ),
      _fill,
    );
  }

  void _paintTrail(Canvas canvas, Rect fieldRect, double scale) {
    if (_world.trailCount < 2) return;

    _stroke.shader = null;

    final offset = _trailWingOffset * _craftRadius * scale;
    _paintTrailRibbon(canvas, fieldRect, scale, -offset);
    _paintTrailRibbon(canvas, fieldRect, scale, offset);
  }

  void _paintTrailRibbon(
    Canvas canvas,
    Rect fieldRect,
    double scale,
    double offsetX,
  ) {
    final world = _world;
    final count = world.trailCount;
    final capacity = world.trailCapacity;
    final head = world.trailHead;

    var previousX = fieldRect.left + world.trailX[head] * scale + offsetX;
    var previousY = fieldRect.top + world.trailY[head] * scale;

    for (var age = 1; age < count; age++) {
      final index = (head - age + capacity) % capacity;
      final x = fieldRect.left + world.trailX[index] * scale + offsetX;
      final y = fieldRect.top + world.trailY[index] * scale;

      _stroke
        ..color = _trailColors[age]
        ..strokeWidth = _trailWidths[age] *
            scale *
            _trailRibbonWidth *
            _skin.trailWidthScale;
      canvas.drawLine(Offset(previousX, previousY), Offset(x, y), _stroke);

      previousX = x;
      previousY = y;
    }
  }

  final ObstacleTrim _trim;

  final WallFace _face;

  static const double _ribWorld = 1.5;
  static const double _ribPitchWorld = 4.2;

  static const double _coreLineWorld = 0.6;

  static const double _bandWorld = 0.9;

  final Path _teeth = Path();
  final Path _scratch = Path();

  static const double _toothDepthWorld = 0.8;

  static const double _toothWidthWorld = 2.6;

  static const double _toothDepthLimit = 0.42;

  static const double _finishHaloWorld = 3.4;

  static const double _finishCoreWorld = 0.5;

  static const double _finishTickWorld = 3.6;

  void _paintFinish(Canvas canvas, Rect fieldRect, double scale) {
    final world = _world;
    final remaining = world.routeRemaining;
    final depth = world.playerY - remaining;
    if (depth < -_finishHaloWorld || depth > world.fieldHeight) return;

    final centreY = fieldRect.top + depth * scale;
    final halo = _finishHaloWorld * scale;
    final core = _finishCoreWorld * scale;

    _fill.color = _finishInk.halo;
    canvas.drawRect(
      Rect.fromLTRB(
        fieldRect.left,
        centreY - halo,
        fieldRect.right,
        centreY + halo,
      ),
      _fill,
    );

    final tick = _finishTickWorld * scale;
    final chequer = core * 2.4;
    _fill.color = _finishInk.aura;
    for (var x = fieldRect.left; x < fieldRect.right; x += tick * 2.0) {
      final to = x + tick;
      canvas.drawRect(
        Rect.fromLTRB(
          x,
          centreY - chequer,
          to > fieldRect.right ? fieldRect.right : to,
          centreY + chequer,
        ),
        _fill,
      );
    }

    _fill.color = _finishInk.edge;
    canvas.drawRect(
      Rect.fromLTRB(
        fieldRect.left,
        centreY - core,
        fieldRect.right,
        centreY + core,
      ),
      _fill,
    );

    if (remaining <= 0.0) return;

    _layOutFinish(scale);
    _finishPainter.paint(
      canvas,
      Offset(
        fieldRect.center.dx - _finishPainter.width * 0.5,
        centreY + halo + 1.6 * scale,
      ),
    );
  }

  void _layOutFinish(double scale) {
    if (_finishScale == scale) return;

    _finishScale = scale;
    _finishPainter
      ..text = TextSpan(
        text: 'FINISH',
        style: TextStyle(
          color: _finishInk.core,
          fontSize: 4.4 * scale,
          fontWeight: FontWeight.w300,
          letterSpacing: 2.6 * scale,
          height: 1.0,
        ),
      )
      ..layout();
  }

  void _paintObstacles(Canvas canvas, Rect fieldRect, double scale) {
    final world = _world;

    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;

    for (var i = 0; i < world.obstacleCount; i++) {
      final shape = world.obstacleShapeAt(i);
      final ink = _obstacleInkByShape[shape.index];
      final centreX = fieldRect.left + world.obstacleX[i] * scale;
      final centreY = fieldRect.top + world.obstacleY[i] * scale;
      final halfWidth = world.obstacleHalfWidth[i] * scale;
      final halfHeight = world.obstacleHalfHeight[i] * scale;

      switch (shape) {
        case ObstacleShape.box:
          _paintBoxObstacle(
            canvas,
            ink,
            centreX,
            centreY,
            halfWidth,
            halfHeight,
            scale,
            toothed: _trim != ObstacleTrim.plain &&
                (((world.obstacleHalfWidth[i] * 8.0).floor() ^
                            (world.obstacleHalfHeight[i] * 8.0).floor()) &
                        1) ==
                    0,
          );
        case ObstacleShape.spike:
          _paintSpikeObstacle(
            canvas,
            ink,
            centreX,
            centreY,
            halfWidth,
            halfHeight,
            scale,
          );
        case ObstacleShape.mine:
          _paintMineObstacle(canvas, ink, centreX, centreY, halfWidth);
        case ObstacleShape.wedge:
          _paintWedgeObstacle(
            canvas,
            ink,
            centreX,
            centreY,
            halfWidth,
            halfHeight,
            scale,
            leansLeft: world.obstacleX[i] < world.fieldWidth * 0.5,
          );
        case ObstacleShape.saw:
          _paintSawObstacle(canvas, ink, centreX, centreY, halfWidth, i);
      }
    }
  }

  void _paintBoxObstacle(
    Canvas canvas,
    NeonInk ink,
    double centreX,
    double centreY,
    double halfWidth,
    double halfHeight,
    double scale, {
    bool toothed = false,
  }) {
    final thinner = math.min(halfWidth, halfHeight);
    final halo = math.min(thinner * _haloFraction, _haloMaxWorld * scale);
    final corner = Radius.circular(
      math.min(thinner * _cornerFraction, _cornerMaxWorld * scale),
    );

    _fill.color = ink.halo;
    canvas.drawRRect(
      RRect.fromLTRBR(
        centreX - halfWidth - halo,
        centreY - halfHeight - halo,
        centreX + halfWidth + halo,
        centreY + halfHeight + halo,
        corner,
      ),
      _fill,
    );

    final depth = toothed
        ? math.min(_toothDepthWorld * scale, halfHeight * _toothDepthLimit)
        : 0.0;
    final leading = _trim == ObstacleTrim.leading || _trim == ObstacleTrim.both
        ? depth
        : 0.0;
    final trailing =
        _trim == ObstacleTrim.trailing || _trim == ObstacleTrim.both
            ? depth
            : 0.0;

    final bodyTop = centreY - halfHeight + trailing;
    final bodyBottom = centreY + halfHeight - leading;

    _fill.color = ink.body;
    canvas.drawRRect(
      RRect.fromLTRBR(
        centreX - halfWidth,
        bodyTop,
        centreX + halfWidth,
        bodyBottom,
        corner,
      ),
      _fill,
    );

    if (leading > 0.0) {
      _paintEdgeTeeth(
        canvas,
        ink.body,
        centreX - halfWidth,
        centreX + halfWidth,
        bodyBottom,
        centreY + halfHeight,
        scale,
      );
    }
    if (trailing > 0.0) {
      _paintEdgeTeeth(
        canvas,
        ink.body,
        centreX - halfWidth,
        centreX + halfWidth,
        bodyTop,
        centreY - halfHeight,
        scale,
      );
    }

    final inset = math.min(
      thinner * _coreInsetFraction,
      _coreInsetMaxWorld * scale,
    );
    final coreTop = bodyTop + inset;
    final coreBottom = bodyBottom - inset;
    if (coreBottom <= coreTop) return;

    final coreLeft = centreX - halfWidth + inset;
    final coreRight = centreX + halfWidth - inset;
    if (coreRight <= coreLeft) return;

    _fill.color = ink.core;

    switch (_face) {
      case WallFace.solid:
        canvas.drawRRect(
          RRect.fromLTRBR(coreLeft, coreTop, coreRight, coreBottom, corner),
          _fill,
        );

      case WallFace.ribbed:
        final rib = _ribWorld * scale;
        final pitch = _ribPitchWorld * scale;
        final span = coreRight - coreLeft;
        final count = (span / pitch).floor() + 1;
        final first = coreLeft + (span - (count - 1) * pitch - rib) * 0.5;
        for (var i = 0; i < count; i++) {
          var from = first + i * pitch;
          var to = from + rib;
          if (to <= coreLeft || from >= coreRight) continue;
          if (from < coreLeft) from = coreLeft;
          if (to > coreRight) to = coreRight;
          canvas.drawRect(Rect.fromLTRB(from, coreTop, to, coreBottom), _fill);
        }

      case WallFace.cored:
        final middle = (coreTop + coreBottom) * 0.5;
        final half = math.min(_coreLineWorld * scale, (coreBottom - coreTop) * 0.5);
        canvas.drawRect(
          Rect.fromLTRB(coreLeft, middle - half, coreRight, middle + half),
          _fill,
        );

      case WallFace.banded:
        final band = math.min(_bandWorld * scale, (coreBottom - coreTop) * 0.4);
        canvas
          ..drawRect(
            Rect.fromLTRB(coreLeft, coreTop, coreRight, coreTop + band),
            _fill,
          )
          ..drawRect(
            Rect.fromLTRB(coreLeft, coreBottom - band, coreRight, coreBottom),
            _fill,
          );
    }
  }

  void _paintEdgeTeeth(
    Canvas canvas,
    Color colour,
    double left,
    double right,
    double baseY,
    double tipY,
    double scale,
  ) {
    final span = right - left;
    if (span <= 0.0) return;

    var count = (span / (_toothWidthWorld * scale)).round();
    if (count < 1) count = 1;
    final step = span / count;

    _teeth.reset();
    _teeth.moveTo(left, baseY);
    for (var i = 0; i < count; i++) {
      _teeth.lineTo(left + step * (i + 0.5), tipY);
      _teeth.lineTo(left + step * (i + 1), baseY);
    }
    _teeth.close();

    _fill.color = colour;
    canvas.drawPath(_teeth, _fill);
  }

  void _paintSpikeObstacle(
    Canvas canvas,
    NeonInk ink,
    double centreX,
    double centreY,
    double halfWidth,
    double halfHeight,
    double scale,
  ) {
    final halo = math.min(
      math.min(halfWidth, halfHeight) * _haloFraction,
      _haloMaxWorld * scale,
    );

    canvas.save();
    canvas.translate(centreX, centreY);

    _fill.color = ink.halo;
    _paintScaledPath(canvas, _spikePath, halfWidth + halo, halfHeight + halo);
    _fill.color = ink.body;
    _paintScaledPath(canvas, _spikePath, halfWidth, halfHeight);
    _fill.color = ink.core;
    _paintScaledPath(
      canvas,
      _spikePath,
      halfWidth * 0.46,
      halfHeight * 0.58,
    );

    canvas.restore();
  }

  void _paintWedgeObstacle(
    Canvas canvas,
    NeonInk ink,
    double centreX,
    double centreY,
    double halfWidth,
    double halfHeight,
    double scale, {
    required bool leansLeft,
  }) {
    final foot = leansLeft ? centreX - halfWidth : centreX + halfWidth;

    Path rampAt(double grow) {
      _scratch.reset();
      return _scratch
        ..moveTo(centreX - halfWidth - grow, centreY - halfHeight - grow)
        ..lineTo(centreX + halfWidth + grow, centreY - halfHeight - grow)
        ..lineTo(
          foot + (leansLeft ? -grow : grow),
          centreY + halfHeight + grow,
        )
        ..close();
    }

    final halo = math.min(halfWidth * _haloFraction, _haloMaxWorld * scale);

    _fill.color = ink.halo;
    canvas.drawPath(rampAt(halo), _fill);
    _fill.color = ink.body;
    canvas.drawPath(rampAt(0.0), _fill);

    _stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..color = ink.edge
      ..strokeWidth = math.max(1.0, 0.18 * scale);
    canvas.drawLine(
      Offset(leansLeft ? centreX + halfWidth : centreX - halfWidth,
          centreY - halfHeight),
      Offset(foot, centreY + halfHeight),
      _stroke,
    );
  }

  void _paintSawObstacle(
    Canvas canvas,
    NeonInk ink,
    double centreX,
    double centreY,
    double radius,
    int index,
  ) {
    const teeth = 8;

    _fill.color = ink.halo;
    canvas.drawCircle(Offset(centreX, centreY), radius * 1.5, _fill);
    _fill.color = ink.body;
    canvas.drawCircle(Offset(centreX, centreY), radius * 0.72, _fill);

    canvas
      ..save()
      ..translate(centreX, centreY)
      ..rotate(
        _effects.animationPhase *
            _tau *
            _sawSpinHz *
            (index.isEven ? 1.0 : -1.0),
      );

    _fill.color = ink.aura;
    for (var tooth = 0; tooth < teeth; tooth++) {
      final angle = tooth * _tau / teeth;
      final reach = radius * 0.98;
      const spread = _tau / teeth * 0.32;

      _scratch.reset();
      canvas.drawPath(
        _scratch
          ..moveTo(
            math.cos(angle - spread) * radius * 0.62,
            math.sin(angle - spread) * radius * 0.62,
          )
          ..lineTo(math.cos(angle) * reach, math.sin(angle) * reach)
          ..lineTo(
            math.cos(angle + spread) * radius * 0.62,
            math.sin(angle + spread) * radius * 0.62,
          )
          ..close(),
        _fill,
      );
    }

    _fill.color = ink.core;
    canvas
      ..drawCircle(Offset.zero, radius * 0.26, _fill)
      ..restore();
  }

  void _paintMineObstacle(
    Canvas canvas,
    NeonInk ink,
    double centreX,
    double centreY,
    double radius,
  ) {
    final centre = Offset(centreX, centreY);

    _fill.color = ink.halo;
    canvas.drawCircle(centre, radius * 2.0, _fill);

    canvas.save();
    canvas.translate(centreX, centreY);
    _fill.color = ink.aura;
    _paintScaledPath(canvas, _minePath, radius * 1.34, radius * 1.34);
    canvas.restore();

    _fill.color = ink.body;
    canvas.drawCircle(centre, radius, _fill);
    _fill.color = ink.core;
    canvas.drawCircle(centre, radius * 0.42, _fill);
  }

  void _paintScaledPath(
    Canvas canvas,
    Path path,
    double scaleX,
    double scaleY,
  ) {
    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.drawPath(path, _fill);
    canvas.restore();
  }

  void _paintOrbs(Canvas canvas, Rect fieldRect, double scale) {
    final world = _world;
    if (world.orbCount == 0) return;

    final radius = world.config.orbRadius * scale;
    final breath = 0.5 +
        0.5 * math.sin(_effects.animationPhase * _tau * _orbBreathHz);

    _fill.shader = null;
    _stroke.shader = null;

    for (var i = 0; i < world.orbCount; i++) {
      final centre = Offset(
        fieldRect.left + world.orbX[i] * scale,
        fieldRect.top + world.orbY[i] * scale,
      );

      _fill.color = _orbInk.halo;
      canvas.drawCircle(centre, radius * (2.4 + breath * 0.9), _fill);
      _fill.color = _orbInk.body;
      canvas.drawCircle(centre, radius * (0.95 + breath * 0.14), _fill);
      _fill.color = _orbInk.core;
      canvas.drawCircle(centre, radius * 0.42, _fill);

      _stroke
        ..color = _orbInk.edge
        ..strokeWidth = 0.2 * scale;
      canvas.drawCircle(centre, radius * (1.5 + breath * 0.45), _stroke);
    }
  }

  void _paintParticles(Canvas canvas, Rect fieldRect, double scale) {
    final count = _world.particleCount;
    if (count == 0) return;

    _particlePaint.shader = null;
    _paintParticlePass(
      canvas,
      fieldRect,
      scale,
      count,
      _glowPassSize,
      _glowPassAlpha,
    );
    _paintParticlePass(
      canvas,
      fieldRect,
      scale,
      count,
      _corePassSize,
      _corePassAlpha,
    );
  }

  void _paintParticlePass(
    Canvas canvas,
    Rect fieldRect,
    double scale,
    int count,
    double sizeFactor,
    double alphaFactor,
  ) {
    final world = _world;
    final lifetime = world.config.particleLifetime;
    final positions = _particlePositions;
    final colors = _particleColors;

    var position = 0;
    var colour = 0;

    for (var i = 0; i < count; i++) {
      var fade = world.particleLife[i] / lifetime;
      if (fade < 0.0) {
        fade = 0.0;
      } else if (fade > 1.0) {
        fade = 1.0;
      }

      final half =
          _particleRadius * sizeFactor * (0.35 + 0.65 * fade) * scale;
      final x = fieldRect.left + world.particleX[i] * scale;
      final y = fieldRect.top + world.particleY[i] * scale;
      final left = x - half;
      final right = x + half;
      final top = y - half;
      final bottom = y + half;

      positions[position++] = left;
      positions[position++] = top;
      positions[position++] = right;
      positions[position++] = top;
      positions[position++] = right;
      positions[position++] = bottom;
      positions[position++] = left;
      positions[position++] = top;
      positions[position++] = right;
      positions[position++] = bottom;
      positions[position++] = left;
      positions[position++] = bottom;

      final packed = packHsl(
        world.particleHue[i],
        0.95,
        0.62,
        fade * alphaFactor,
      );
      for (var vertex = 0; vertex < _verticesPerQuad; vertex++) {
        colors[colour++] = packed;
      }
    }

    final vertices = Vertices.raw(
      VertexMode.triangles,
      Float32List.view(positions.buffer, 0, position),
      colors: Int32List.view(colors.buffer, 0, colour),
    );

    canvas.drawVertices(vertices, BlendMode.dst, _particlePaint);
  }

  void _paintCraft(Canvas canvas, Rect fieldRect, double scale) {
    final world = _world;
    if (world.phase == GamePhase.over) return;

    final radius = _craftRadius * scale;
    final tilt = world.playerTilt;
    final speed = _speedFraction(world);
    final tier = _hullTierFor(speed);

    canvas.save();
    canvas.translate(
      fieldRect.left + world.playerX * scale,
      fieldRect.top + world.playerY * scale,
    );
    canvas.rotate(tilt * _craftBankRadians);
    canvas.scale(1.0 - tilt.abs() * _bankFlatten, 1.0);

    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;

    _paintExhausts(canvas, radius, speed);

    final hull = _hullPaths[tier];
    _fill.color = _craftInk.halo;
    _paintUnitPath(canvas, hull, radius * 1.75);
    _fill.color = _craftInk.body;
    _paintUnitPath(canvas, hull, radius);
    _fill.color = _craftInk.edge;
    _paintUnitPath(canvas, hull, radius * 0.6);

    _paintEnergyCore(canvas, radius, tier);
    _paintGuard(canvas, radius);

    final pulse = _effects.pulse;
    if (pulse > 0.01) {
      _fill.color = Color(packHsl(_craftHue, 0.4, 0.95, pulse * 0.8));
      _paintUnitPath(canvas, hull, radius * 1.22);
    }

    canvas.restore();
  }

  void _paintGuard(Canvas canvas, double radius) {
    final world = _world;
    if (!world.isImmune) return;

    final pulse =
        0.5 + 0.5 * math.sin(_effects.animationPhase * _tau * _guardHz);
    final reach = radius * (_guardRadius + 0.12 * pulse);

    _fill
      ..shader = null
      ..blendMode = BlendMode.plus
      ..color = _guardInk.halo;
    canvas.drawCircle(Offset.zero, reach, _fill);

    _stroke
      ..shader = null
      ..blendMode = BlendMode.plus
      ..color = _guardInk.edge
      ..strokeWidth = math.max(1.0, radius * 0.09);
    canvas.drawCircle(Offset.zero, reach, _stroke);

    _fill.blendMode = BlendMode.srcOver;
    _stroke.blendMode = BlendMode.srcOver;
  }

  void _paintExhausts(Canvas canvas, double radius, double speed) {
    final phase = _effects.animationPhase;
    final gutter = 1.0 +
        _flameSlowDepth * math.sin(phase * _tau * _flameSlowHz) +
        _flameFastDepth * math.sin(phase * _tau * _flameFastHz);
    final plume =
        radius * gutter * (_flameLengthAtRest + _flameLengthGain * speed);

    for (final offset in _exhaustOffsets) {
      canvas.save();
      canvas.translate(offset * radius, _exhaustSeat * radius);

      _fill.color = _craftInk.halo;
      _paintScaledPath(canvas, _exhaustPath, plume * _exhaustWidth, plume);
      _fill.color = _craftInk.body;
      _paintScaledPath(
        canvas,
        _exhaustPath,
        plume * _exhaustWidth * 0.52,
        plume * 0.62,
      );

      canvas.restore();
    }
  }

  void _paintEnergyCore(Canvas canvas, double radius, int tier) {
    final beat = 0.74 +
        0.26 *
            math.sin(_effects.animationPhase * _tau * (_coreBaseHz + tier));

    _fill.color = _craftInk.core;
    _paintUnitPath(canvas, _corePath, radius * beat * 0.9);
  }

  int _hullTierFor(double speedFraction) {
    final tier = (speedFraction * _hullPaths.length).floor();
    if (tier < 0) return 0;
    if (tier >= _hullPaths.length) return _hullPaths.length - 1;
    return tier;
  }

  double _speedFraction(WorldView world) {
    final difficulty = world.config.difficulty;
    final span = difficulty.maxScrollSpeed - difficulty.startScrollSpeed;
    if (span <= 0.0) return 0.0;

    final fraction = (world.scrollSpeed - difficulty.startScrollSpeed) / span;
    if (fraction < 0.0) return 0.0;
    if (fraction > 1.0) return 1.0;
    return fraction;
  }

  void _paintUnitPath(Canvas canvas, Path path, double radius) {
    canvas.save();
    canvas.scale(radius);
    canvas.drawPath(path, _fill);
    canvas.restore();
  }

  void _paintFlash(Canvas canvas, Size size) {
    final alpha = _effects.flashAlpha;
    if (alpha <= 0.01) return;

    final tint =
        _effects.flashIsShield ? _shieldFlashColor : Palette.crashFlash;

    _fill
      ..shader = null
      ..blendMode = BlendMode.plus
      ..color = tint.withValues(alpha: alpha * 0.55);
    canvas.drawRect(Offset.zero & size, _fill);
    _fill.blendMode = BlendMode.srcOver;
  }

  void _paintHud(Canvas canvas, Rect fieldRect, double scale) {
    final world = _world;
    final inset = _hudInset * scale;

    if (_hudScale != scale) {
      _hudScale = scale;
      _scoreShown = -1;
      _nearMissShown = -1;
      _promptWidth = -1.0;
    }

    final score = world.score.floor();
    if (score != _scoreShown) {
      _scoreShown = score;
      _scorePainter
        ..text = TextSpan(text: '$score', style: _scoreStyle(scale))
        ..layout();
    }
    final hudTop = fieldRect.top + _hudTopWorld * scale;

    _scorePainter.paint(canvas, Offset(fieldRect.left + inset, hudTop));

    if (world.nearMissCount != _nearMissShown ||
        world.orbsCollected != _orbsShown) {
      _nearMissShown = world.nearMissCount;
      _orbsShown = world.orbsCollected;
      _tallyPainter
        ..text = TextSpan(
          text: 'CLOSE $_nearMissShown   ORBS $_orbsShown',
          style: _tallyStyle(scale),
        )
        ..layout();
    }
    _tallyPainter.paint(
      canvas,
      Offset(fieldRect.right - inset - _tallyPainter.width, hudTop),
    );

    final phase = world.phase;
    if (phase != GamePhase.ready) return;

    final maxWidth = fieldRect.width - inset * 2.0;
    if (_promptPhase != phase || _promptWidth != maxWidth) {
      _promptPhase = phase;
      _promptWidth = maxWidth;
      _promptPainter
        ..text = TextSpan(
          text: 'PRESS TO START',
          style: _promptStyle(scale),
        )
        ..layout(maxWidth: maxWidth);
    }
    _promptPainter.paint(
      canvas,
      Offset(
        fieldRect.center.dx - _promptPainter.width * 0.5,
        fieldRect.center.dy - _promptPainter.height * 0.5,
      ),
    );
  }

  TextStyle _scoreStyle(double scale) => TextStyle(
        color: Palette.hudPrimary,
        fontSize: 5.6 * scale,
        fontWeight: FontWeight.w200,
        letterSpacing: 1.2 * scale,
        height: 1.0,
      );

  TextStyle _tallyStyle(double scale) => TextStyle(
        color: Palette.hudDim,
        fontSize: 1.9 * scale,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.35 * scale,
        height: 1.0,
      );

  TextStyle _promptStyle(double scale) => TextStyle(
        color: Palette.hudPrimary,
        fontSize: 3.0 * scale,
        fontWeight: FontWeight.w300,
        letterSpacing: 0.5 * scale,
        height: 1.45,
      );

  @override
  bool shouldRepaint(NeonPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(NeonPainter oldDelegate) => false;

  static List<Color> _buildTrailColors(int capacity, double hue) =>
      List<Color>.generate(
        capacity,
        (age) {
          final fade = 1.0 - age / capacity;
          return Color(
            packHsl(
              hue + age * 1.6,
              0.95,
              0.58,
              fade * fade * 0.55,
            ),
          );
        },
        growable: false,
      );

  static Float32List _buildTrailWidths(int capacity) {
    final widths = Float32List(capacity);
    for (var age = 0; age < capacity; age++) {
      final fade = 1.0 - age / capacity;
      widths[age] = 0.25 + 1.45 * fade;
    }
    return widths;
  }

  static Path _buildCorePath() => Path()
    ..moveTo(0.0, -0.52)
    ..lineTo(0.24, -0.08)
    ..lineTo(0.0, 0.36)
    ..lineTo(-0.24, -0.08)
    ..close();

  static Path _buildSpikePath() => Path()
    ..moveTo(-1.0, -1.0)
    ..lineTo(1.0, -1.0)
    ..lineTo(0.0, 1.0)
    ..close();

  static Path _buildMinePath() {
    const prongs = 6;
    const bodyRadius = 0.74;
    const halfAngle = 0.2;

    final path = Path();
    for (var i = 0; i < prongs; i++) {
      final angle = i * _tau / prongs;
      path
        ..moveTo(
          math.cos(angle - halfAngle) * bodyRadius,
          math.sin(angle - halfAngle) * bodyRadius,
        )
        ..lineTo(math.cos(angle), math.sin(angle))
        ..lineTo(
          math.cos(angle + halfAngle) * bodyRadius,
          math.sin(angle + halfAngle) * bodyRadius,
        )
        ..close();
    }
    return path;
  }
}
