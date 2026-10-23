library;

import 'dart:ui';

import 'package:playable_kit/playable_kit.dart';

int packHsl(
  double hueDegrees,
  double saturation,
  double lightness,
  double alpha,
) {
  var hue = hueDegrees % 360.0;
  if (hue < 0.0) hue += 360.0;
  final sector = hue / 60.0;

  final chroma = (1.0 - (2.0 * lightness - 1.0).abs()) * saturation;
  final second = chroma * (1.0 - ((sector % 2.0) - 1.0).abs());
  final offset = lightness - chroma * 0.5;

  final double red;
  final double green;
  final double blue;
  if (sector < 1.0) {
    red = chroma;
    green = second;
    blue = 0.0;
  } else if (sector < 2.0) {
    red = second;
    green = chroma;
    blue = 0.0;
  } else if (sector < 3.0) {
    red = 0.0;
    green = chroma;
    blue = second;
  } else if (sector < 4.0) {
    red = 0.0;
    green = second;
    blue = chroma;
  } else if (sector < 5.0) {
    red = second;
    green = 0.0;
    blue = chroma;
  } else {
    red = chroma;
    green = 0.0;
    blue = second;
  }

  return _byte(alpha) << 24 |
      _byte(red + offset) << 16 |
      _byte(green + offset) << 8 |
      _byte(blue + offset);
}

Color colorOfTheme(ThemeColor color) => colorFromHsl(
      color.hue,
      color.saturation,
      color.lightness,
      color.alpha,
    );

Color colorFromHsl(
  double hueDegrees,
  double saturation,
  double lightness, [
  double alpha = 1.0,
]) =>
    Color(packHsl(hueDegrees, saturation, lightness, alpha));

int _byte(double unit) {
  final scaled = (unit * 255.0).round();
  if (scaled < 0) return 0;
  if (scaled > 255) return 255;
  return scaled;
}

class NeonInk {
  NeonInk.fromHue(double hue)
      : halo = colorFromHsl(hue, 0.95, 0.55, 0.14),
        aura = colorFromHsl(hue, 0.95, 0.58, 0.34),
        body = colorFromHsl(hue, 0.90, 0.46, 0.85),
        core = colorFromHsl(hue, 0.75, 0.86, 0.95),
        edge = colorFromHsl(hue, 1.00, 0.72, 1.00);

  final Color halo;

  final Color aura;

  final Color body;

  final Color core;

  final Color edge;
}

abstract final class Palette {
  static const Color skyFar = Color(0xFF05070F);

  static const Color skyNear = Color(0xFF0C1226);

  static const Color surroundFar = Color(0xFF02030A);
  static const Color surroundNear = Color(0xFF060814);

  static const Color gridLine = Color(0x2240E0FF);
  static const Color gridHorizon = Color(0x3360F0FF);

  static const Color railGlow = Color(0x3300E5FF);
  static const Color railCore = Color(0xCC7DF9FF);

  static const double craftHue = 186.0;

  static const double orbHue = 52.0;

  static const Color crashFlash = Color(0xFFFF4D2E);

  static const Color hudPrimary = Color(0xF2E8FBFF);
  static const Color hudDim = Color(0x99A8C8E0);

  static const Color routeTrack = Color(0x66060B16);
  static const Color routeTrackEdge = Color(0x3360F0FF);
  static const Color routeDense = Color(0x99FF3B4E);
  static const Color routeCalm = Color(0x8633C7FF);
  static const Color routeCheckpointAhead = Color(0x66A8C8E0);
  static const Color routeCheckpointPassed = Color(0xFF7DF9FF);
  static const Color routeFinish = Color(0xFFFFE27A);
  static const Color routeRunner = Color(0xFFE8FBFF);

  static const Color glassFill = Color(0x16BFF4FF);

  static const Color resultScrim = Color(0xBF02040C);

  static const Color panelFloor = Color(0xB3030610);

  static const Color star = Color(0xFFFFE27A);
  static const Color starEmpty = Color(0x3DFFE27A);

  static const Color slotEmptyEdge = Color(0x3DBFF4FF);
  static const Color slotEmptyMark = Color(0x4FA8C8E0);
  static const Color glassSheen = Color(0x1FE2FCFF);
  static const Color glassEdge = Color(0x7ABFF4FF);
}
