import 'package:playable_kit/playable_kit.dart';

enum BackdropStyle {
  grid,

  embers,

  sonar,

  refraction,

  starfield,

  flare,

  glitch,

  circuit,

  aurora,

  cascade,
}

enum ObstacleTrim {
  plain,

  leading,

  trailing,

  both,
}

enum WallFace {
  solid,

  ribbed,

  cored,

  banded,
}

class LevelTheme {
  const LevelTheme({
    required this.backdrop,
    required this.craft,
    required this.orb,
    required this.hazard,
    required this.skyFar,
    required this.skyNear,
    required this.surroundFar,
    required this.surroundNear,
    required this.grid,
    required this.horizon,
    required this.rail,
    this.trim = ObstacleTrim.plain,
    this.face = WallFace.solid,
  });

  final BackdropStyle backdrop;

  final ObstacleTrim trim;

  final WallFace face;

  final ThemeColor craft;

  final ThemeColor orb;

  final ThemeColor hazard;

  final ThemeColor skyFar;
  final ThemeColor skyNear;

  final ThemeColor surroundFar;
  final ThemeColor surroundNear;

  final ThemeColor grid;
  final ThemeColor horizon;
  final ThemeColor rail;
}
