import '../domain/game_event.dart';

enum SoundCue {
  runStart,

  nearMiss,

  orbPickup,

  speedUp,

  bonusPickup,

  bonusSpend,

  shieldHit,

  portalEnter,

  portalLeave,

  checkpoint,

  stageClear,

  crash,
}

SoundCue cueForEvent(GameEvent event) => switch (event) {
      GameEvent.runStarted => SoundCue.runStart,
      GameEvent.nearMiss => SoundCue.nearMiss,
      GameEvent.orbCollected => SoundCue.orbPickup,
      GameEvent.speedTierUp => SoundCue.speedUp,
      GameEvent.bonusCollected => SoundCue.bonusPickup,
      GameEvent.bonusSpent => SoundCue.bonusSpend,
      GameEvent.shieldAbsorbed => SoundCue.shieldHit,
      GameEvent.portalEntered => SoundCue.portalEnter,
      GameEvent.portalEnded => SoundCue.portalLeave,
      GameEvent.checkpointPassed => SoundCue.checkpoint,
      GameEvent.stageCleared => SoundCue.stageClear,
      GameEvent.crashed => SoundCue.crash,
    };
