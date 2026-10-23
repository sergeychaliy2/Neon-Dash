library;

import 'package:flutter/services.dart';
import 'package:playable_core/playable_core.dart';

class Haptics {
  Haptics({required this.enabled});

  bool enabled;

  void onEvent(GameEvent event) {
    if (!enabled) return;

    switch (event) {
      case GameEvent.crashed:
      case GameEvent.stageCleared:
        HapticFeedback.heavyImpact();

      case GameEvent.shieldAbsorbed:
      case GameEvent.portalEntered:
        HapticFeedback.mediumImpact();

      case GameEvent.checkpointPassed:
      case GameEvent.speedTierUp:
        HapticFeedback.lightImpact();

      case GameEvent.bonusCollected:
      case GameEvent.bonusSpent:
        HapticFeedback.selectionClick();

      case GameEvent.nearMiss:
      case GameEvent.orbCollected:
      case GameEvent.runStarted:
      case GameEvent.portalEnded:
        break;
    }
  }

  void tap() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }
}
