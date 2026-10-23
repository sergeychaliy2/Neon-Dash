library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:playable_core/playable_core.dart';

const int kHullTiers = 3;

const double _sweepPull = 0.14;

List<Path> buildHullPaths(CraftSkin skin) => List<Path>.unmodifiable(<Path>[
      for (var tier = 0; tier < kHullTiers; tier++)
        buildHullPath(skin, tier / (kHullTiers - 1)),
    ]);

Path buildHullPath(CraftSkin skin, double sweep) {
  final pull = 1.0 - _sweepPull * sweep;

  return switch (skin.silhouette) {
    HullSilhouette.delta => _delta(skin, sweep, pull),
    HullSilhouette.blade => _blade(skin, pull),
    HullSilhouette.chevron => _chevron(skin, pull),
    HullSilhouette.ring => _ring(skin, pull),
    HullSilhouette.star => _star(skin, pull),
    HullSilhouette.heart => _heart(skin, pull),
  };
}

Path _delta(CraftSkin skin, double sweep, double pull) {
  final tipX = skin.tipReach * pull;
  final tipY = skin.tipDrop + 0.26 * sweep;

  return Path()
    ..moveTo(0.0, -skin.noseLength)
    ..lineTo(skin.shoulder * pull, -0.22)
    ..lineTo(tipX, tipY)
    ..lineTo(skin.waist * pull, 0.40)
    ..lineTo(0.0, skin.tailLength)
    ..lineTo(-skin.waist * pull, 0.40)
    ..lineTo(-tipX, tipY)
    ..lineTo(-skin.shoulder * pull, -0.22)
    ..close();
}

Path _blade(CraftSkin skin, double pull) {
  final shoulder = skin.shoulder * pull;
  final waist = skin.waist * pull;
  final fin = skin.tipReach * 0.38 * pull;

  return Path()
    ..moveTo(0.0, -skin.noseLength)
    ..lineTo(shoulder, -skin.noseLength * 0.34)
    ..lineTo(waist, skin.tipDrop * 0.5)
    ..lineTo(fin, skin.tailLength)
    ..lineTo(0.0, skin.tailLength * 0.78)
    ..lineTo(-fin, skin.tailLength)
    ..lineTo(-waist, skin.tipDrop * 0.5)
    ..lineTo(-shoulder, -skin.noseLength * 0.34)
    ..close();
}

Path _chevron(CraftSkin skin, double pull) {
  final tipX = skin.tipReach * pull;
  final waist = skin.waist * pull;

  return Path()
    ..moveTo(0.0, -skin.noseLength)
    ..lineTo(tipX, skin.tipDrop)
    ..lineTo(waist, skin.tipDrop * 0.42)
    ..lineTo(0.0, skin.tailLength)
    ..lineTo(-waist, skin.tipDrop * 0.42)
    ..lineTo(-tipX, skin.tipDrop)
    ..close();
}

Path _ring(CraftSkin skin, double pull) {
  final outer = Rect.fromCenter(
    center: Offset(0.0, (skin.tailLength - skin.noseLength) * 0.5),
    width: skin.tipReach * 2.0 * pull,
    height: skin.noseLength + skin.tailLength,
  );

  return Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(outer)
    ..addOval(Rect.fromCenter(
      center: outer.center,
      width: outer.width * skin.waist,
      height: outer.height * skin.waist,
    ));
}

Path _star(CraftSkin skin, double pull) {
  const points = 5;
  final inner = skin.waist * 2.0 + 0.2;
  final squash = skin.tipReach / skin.noseLength * pull;

  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final angle = -math.pi * 0.5 + i * math.pi / points;
    final reach = i.isEven ? skin.noseLength : inner;
    final x = math.cos(angle) * reach * squash;
    final y = math.sin(angle) * reach;
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  return path..close();
}

Path _heart(CraftSkin skin, double pull) {
  final crest = -skin.noseLength;
  final point = skin.tailLength;
  final half = skin.tipReach * pull;
  final notch = crest * 0.28;

  return Path()
    ..moveTo(0.0, notch)
    ..cubicTo(-half * 0.55, crest * 1.25, -half, crest * 0.35, -half * 0.62,
        0.05)
    ..cubicTo(-half * 0.40, 0.45, -half * 0.18, point * 0.72, 0.0, point)
    ..cubicTo(half * 0.18, point * 0.72, half * 0.40, 0.45, half * 0.62, 0.05)
    ..cubicTo(half, crest * 0.35, half * 0.55, crest * 1.25, 0.0, notch)
    ..close();
}

Path buildExhaustPath() => Path()
  ..moveTo(-0.5, 0.0)
  ..lineTo(0.5, 0.0)
  ..lineTo(0.0, 1.0)
  ..close();

List<double> exhaustOffsets(CraftSkin skin) => switch (skin.exhausts) {
      1 => const <double>[0.0],
      3 => const <double>[-0.42, 0.0, 0.42],
      _ => const <double>[-0.33, 0.33],
    };

double exhaustWidthScale(CraftSkin skin) => switch (skin.exhausts) {
      1 => 0.72,
      3 => 0.34,
      _ => 0.46,
    };

double exhaustSeat(CraftSkin skin) => switch (skin.silhouette) {
      HullSilhouette.heart => skin.tailLength * 0.92,
      HullSilhouette.ring => skin.tailLength * 0.86,
      HullSilhouette.star => skin.noseLength * 0.44,
      _ => 0.42,
    };
