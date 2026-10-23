import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';

import 'palette.dart';

class Backdrop {
  Backdrop(LevelTheme theme)
      : _style = theme.backdrop,
        _hue = theme.grid.hue,
        _line = colorOfTheme(theme.grid),
        _moteX = Float32List(_moteCount),
        _moteY = Float32List(_moteCount),
        _moteScale = Float32List(_moteCount),
        _moteDrift = Float32List(_moteCount),
        _starPoints = Float32List(_starCount * 2),
        _starDepth = Float32List(_starCount),
        _tearOffset = Float32List(_tearFrames * _tearLines) {
    final random = DeterministicRandom(_style.index + _seedBase);

    for (var i = 0; i < _moteCount; i++) {
      _moteX[i] = random.nextDouble();
      _moteY[i] = random.nextDouble();
      _moteScale[i] = random.nextRange(0.35, 1.0);
      _moteDrift[i] = random.nextRange(-1.0, 1.0);
    }
    for (var i = 0; i < _starCount; i++) {
      _starPoints[i * 2] = random.nextDouble();
      _starPoints[i * 2 + 1] = random.nextDouble();
      _starDepth[i] = random.nextRange(0.25, 1.0);
    }
    for (var i = 0; i < _tearOffset.length; i++) {
      _tearOffset[i] = random.nextRange(-1.0, 1.0);
    }
  }

  static const int _seedBase = 0x4B1D;

  static const int _circuitTraces = 18;
  static const double _circuitParallax = 0.35;
  static const double _circuitPulseHz = 1.0;

  static const int _auroraRibbons = 4;
  static const double _auroraSwayHz = 1.0;
  static const double _auroraAlpha = 0.07;

  static const int _cascadeStreaks = 48;
  static const int _moteCount = 32;
  static const int _starCount = 72;

  static const int _tearFrames = 16;
  static const int _tearLines = 7;
  static const double _tearRate = 6.0;
  static const double _tearAlpha = 0.07;
  static const double _tearThickness = 0.013;

  static const double _gridSpacingWorld = 11.0;
  static const int _gridColumns = 5;
  static const int _sonarRings = 5;
  static const double _sonarSpacing = 0.26;
  static const int _refractionBands = 14;
  static const double _refractionAlpha = 0.05;
  static const double _tau = 6.283185307179586;

  final BackdropStyle _style;
  final double _hue;
  final Color _line;

  final Float32List _moteX;
  final Float32List _moteY;
  final Float32List _moteScale;
  final Float32List _moteDrift;
  final Float32List _starPoints;
  final Float32List _starDepth;
  final Float32List _tearOffset;

  final Float32List _starScreen = Float32List(_starCount * 2);

  Shader? _flareShader;
  Rect? _flareRect;

  void paint(
    Canvas canvas,
    Rect field,
    double scale,
    double distance,
    double phase,
    Paint fill,
    Paint stroke,
  ) {
    _paintGrid(canvas, field, scale, distance, stroke);

    switch (_style) {
      case BackdropStyle.grid:
        break;
      case BackdropStyle.embers:
        _paintEmbers(canvas, field, scale, distance, phase, fill);
      case BackdropStyle.sonar:
        _paintSonar(canvas, field, scale, distance, stroke);
      case BackdropStyle.refraction:
        _paintRefraction(canvas, field, distance, phase, fill);
      case BackdropStyle.starfield:
        _paintStarfield(canvas, field, scale, distance, stroke);
      case BackdropStyle.flare:
        _paintFlare(canvas, field, scale, distance, phase, fill);
      case BackdropStyle.glitch:
        _paintTears(canvas, field, phase, fill);
      case BackdropStyle.circuit:
        _paintCircuit(canvas, field, scale, distance, phase, fill, stroke);
      case BackdropStyle.aurora:
        _paintAurora(canvas, field, distance, phase, fill);
      case BackdropStyle.cascade:
        _paintCascade(canvas, field, scale, distance, stroke);
    }
  }

  void _paintCircuit(
    Canvas canvas,
    Rect field,
    double scale,
    double distance,
    double phase,
    Paint fill,
    Paint stroke,
  ) {
    stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..strokeWidth = math.max(1.0, 0.08 * scale)
      ..color = Color(packHsl(_hue, 0.75, 0.52, 0.2));
    fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;

    final travel = (distance * _circuitParallax) % field.height;

    for (var i = 0; i < _circuitTraces; i++) {
      final x = field.left + field.width * _moteX[i];
      var y = field.top + field.height * _moteY[i] + travel;
      if (y > field.bottom) y -= field.height;

      final run = field.width * 0.1 * (0.4 + _moteScale[i]);
      final drop = field.height * 0.06 * (0.4 + _moteScale[i]);
      final side = _moteDrift[i] >= 0.0 ? 1.0 : -1.0;

      canvas
        ..drawLine(Offset(x, y), Offset(x + run * side, y), stroke)
        ..drawLine(
          Offset(x + run * side, y),
          Offset(x + run * side, y + drop),
          stroke,
        );

      final pulse = 0.5 +
          0.5 * math.sin((phase + _moteScale[i]) * _tau * _circuitPulseHz);
      fill.color = Color(packHsl(_hue, 0.9, 0.66, 0.1 + 0.26 * pulse));
      canvas.drawCircle(
        Offset(x + run * side, y + drop),
        math.max(1.0, 0.16 * scale * (0.6 + pulse * 0.6)),
        fill,
      );
    }
  }

  void _paintAurora(
    Canvas canvas,
    Rect field,
    double distance,
    double phase,
    Paint fill,
  ) {
    fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;

    const steps = 12;
    for (var ribbon = 0; ribbon < _auroraRibbons; ribbon++) {
      final seat = (ribbon + 0.5) / _auroraRibbons;
      final sway = phase * _tau * _auroraSwayHz + ribbon * 1.7;
      final thickness = field.height * (0.05 + 0.03 * _moteScale[ribbon]);

      final path = Path();
      for (var i = 0; i <= steps; i++) {
        final along = i / steps;
        final y = field.top +
            field.height *
                (seat +
                    0.06 *
                        math.sin(along * _tau * 1.5 + sway) *
                        math.cos(distance * 0.0006 + along * 2.2));
        final x = field.left + field.width * along;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      for (var i = steps; i >= 0; i--) {
        final along = i / steps;
        final y = field.top +
            field.height *
                (seat +
                    0.06 *
                        math.sin(along * _tau * 1.5 + sway) *
                        math.cos(distance * 0.0006 + along * 2.2));
        path.lineTo(field.left + field.width * along, y + thickness);
      }

      fill.color = Color(
        packHsl(_hue + ribbon * 14.0, 0.55, 0.6, _auroraAlpha),
      );
      canvas.drawPath(path..close(), fill);
    }
  }

  void _paintCascade(
    Canvas canvas,
    Rect field,
    double scale,
    double distance,
    Paint stroke,
  ) {
    stroke
      ..shader = null
      ..blendMode = BlendMode.plus;

    for (var i = 0; i < _cascadeStreaks; i++) {
      final depth = _starDepth[i];
      final x = field.left + field.width * _starPoints[i * 2];

      var unit = (_starPoints[i * 2 + 1] + distance * 0.0016 * depth) % 1.0;
      if (unit < 0.0) unit += 1.0;

      final y = field.top + field.height * unit;
      final length = field.height * 0.05 * depth;

      stroke
        ..strokeWidth = math.max(1.0, 0.09 * scale * depth)
        ..color = Color(packHsl(_hue, 0.8, 0.7, 0.05 + 0.13 * depth));
      canvas.drawLine(Offset(x, y), Offset(x, y + length), stroke);
    }

    stroke.blendMode = BlendMode.srcOver;
  }

  void _paintGrid(
    Canvas canvas,
    Rect field,
    double scale,
    double distance,
    Paint stroke,
  ) {
    final spacing = _gridSpacingWorld * scale;
    final offset = (distance * scale) % spacing;

    stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..strokeCap = StrokeCap.butt
      ..color = _line
      ..strokeWidth = 1.0;

    for (var y = field.top + offset; y < field.bottom; y += spacing) {
      canvas.drawLine(Offset(field.left, y), Offset(field.right, y), stroke);
    }

    final step = field.width / _gridColumns;
    for (var column = 1; column < _gridColumns; column++) {
      final x = field.left + step * column;
      canvas.drawLine(Offset(x, field.top), Offset(x, field.bottom), stroke);
    }
  }

  void _paintEmbers(
    Canvas canvas,
    Rect field,
    double scale,
    double distance,
    double phase,
    Paint fill,
  ) {
    fill
      ..shader = null
      ..blendMode = BlendMode.plus;

    for (var i = 0; i < _moteCount; i++) {
      final depth = 0.3 + _moteScale[i] * 0.7;
      var unitY = (_moteY[i] - distance * 0.0016 * depth) % 1.0;
      if (unitY < 0.0) unitY += 1.0;

      final wobble = math.sin((phase + _moteX[i]) * _tau * 2.0) * 0.012;
      final x = field.left + field.width * (_moteX[i] + wobble * _moteDrift[i]);
      final y = field.top + field.height * unitY;

      final fade = math.sin(unitY * math.pi);
      fill.color = Color(packHsl(_hue + depth * 18.0, 0.95, 0.58, fade * 0.30));
      canvas.drawCircle(Offset(x, y), _moteScale[i] * 0.45 * scale, fill);
    }

    fill.blendMode = BlendMode.srcOver;
  }

  void _paintSonar(
    Canvas canvas,
    Rect field,
    double scale,
    double distance,
    Paint stroke,
  ) {
    final origin = Offset(field.center.dx, field.top);
    final maxRadius = field.height * 1.15;

    stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..strokeWidth = math.max(1.0, 0.1 * scale);

    for (var ring = 0; ring < _sonarRings; ring++) {
      var unit = (distance * 0.0012 + ring * _sonarSpacing) % 1.0;
      if (unit < 0.0) unit += 1.0;

      final fade = (1.0 - unit) * (1.0 - unit);
      stroke.color = Color(packHsl(_hue, 0.9, 0.62, fade * 0.26));
      canvas.drawCircle(origin, maxRadius * unit, stroke);
    }
  }

  void _paintRefraction(
    Canvas canvas,
    Rect field,
    double distance,
    double phase,
    Paint fill,
  ) {
    final bandWidth = field.width / _refractionBands;

    fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;

    for (var band = 0; band < _refractionBands; band++) {
      final along = band / _refractionBands;
      final ripple = math.sin(along * _tau * 3.0 + phase * _tau) *
          math.sin(along * _tau + distance * 0.004);
      if (ripple <= 0.0) continue;

      fill.color = Color(
        packHsl(_hue + ripple * 10.0, 0.45, 0.78, ripple * _refractionAlpha),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          field.left + bandWidth * band,
          field.top,
          bandWidth + 1.0,
          field.height,
        ),
        fill,
      );
    }
  }

  void _paintStarfield(
    Canvas canvas,
    Rect field,
    double scale,
    double distance,
    Paint stroke,
  ) {
    for (var i = 0; i < _starCount; i++) {
      final depth = _starDepth[i];
      var unitY = (_starPoints[i * 2 + 1] + distance * 0.0009 * depth) % 1.0;
      if (unitY < 0.0) unitY += 1.0;

      _starScreen[i * 2] = field.left + field.width * _starPoints[i * 2];
      _starScreen[i * 2 + 1] = field.top + field.height * unitY;
    }

    stroke
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, 0.2 * scale)
      ..color = Color(packHsl(_hue, 0.3, 0.9, 0.42));
    canvas.drawRawPoints(PointMode.points, _starScreen, stroke);
    stroke.strokeCap = StrokeCap.butt;
  }

  void _paintFlare(
    Canvas canvas,
    Rect field,
    double scale,
    double distance,
    double phase,
    Paint fill,
  ) {
    if (_flareRect != field) {
      _flareRect = field;
      _flareShader = Gradient.radial(
        Offset(field.center.dx, field.top),
        field.height * 0.9,
        <Color>[
          Color(packHsl(_hue, 0.85, 0.55, 0.18)),
          Color(packHsl(_hue, 0.85, 0.50, 0.0)),
        ],
      );
    }

    fill
      ..shader = _flareShader
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(field, fill);
    fill
      ..shader = null
      ..blendMode = BlendMode.plus;

    for (var i = 0; i < _moteCount; i++) {
      final depth = 0.4 + _moteScale[i] * 0.6;
      var unitY = (_moteY[i] + distance * 0.0011 * depth) % 1.0;
      if (unitY < 0.0) unitY += 1.0;

      final sway = math.sin((phase * 2.0 + _moteX[i]) * _tau) * 0.02;
      final x = field.left + field.width * (_moteX[i] + sway * _moteDrift[i]);
      final y = field.top + field.height * unitY;

      fill.color = Color(packHsl(_hue + 12.0, 0.8, 0.74, depth * 0.18));
      canvas.drawCircle(Offset(x, y), _moteScale[i] * 0.34 * scale, fill);
    }

    fill.blendMode = BlendMode.srcOver;
  }

  void _paintTears(Canvas canvas, Rect field, double phase, Paint fill) {
    final frame = (phase * _tearRate).floor() % _tearFrames;
    final thickness = field.height * _tearThickness;

    fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;

    for (var line = 0; line < _tearLines; line++) {
      final index = frame * _tearLines + line;
      final offset = _tearOffset[index % _tearOffset.length];

      final at = ((line + 1) / (_tearLines + 1) + offset * 0.06) % 1.0;

      fill.color = Color(packHsl(_hue, 0.2, 0.88, _tearAlpha));
      canvas.drawRect(
        Rect.fromLTWH(
          field.left + offset * field.width * 0.03,
          field.top + field.height * at,
          field.width,
          thickness,
        ),
        fill,
      );
    }
  }
}
