library;

import 'package:playable_core/playable_core.dart';

const double _phoneAspect = 0.45;

const double _step = 1.0 / 120.0;

void main() {
  final game = Game(seed: 2026)
    ..resizeToScreenAspect(_phoneAspect)
    ..startRun();

  var events = 0;
  final steps = (45.0 / _step).round();
  for (var i = 0; i < steps; i++) {
    game
      ..moveTargetTo((i % 140) * 0.3)
      ..advance(_step);

    final world = game.world;
    events += world.eventCount;
    game.consumeEvents();

    if (world.phase == GamePhase.over) {
      game
        ..restart()
        ..startRun();
    }
  }

  final bank = SoundBank.render();

  final world = game.world;
  print(
    'score=${world.score.floor()} '
    'close=${world.nearMissCount} '
    'orbs=${world.orbsCollected} '
    'events=$events '
    'audioBytes=${bank.totalBytes}',
  );
}
