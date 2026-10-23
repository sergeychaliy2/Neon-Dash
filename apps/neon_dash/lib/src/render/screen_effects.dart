import 'dart:math' as math;

import 'package:playable_core/playable_core.dart';

class ScreenEffects {
  static const double _shakeDecayRate = 7.5;

  static const double _flashDecayRate = 4.0;

  static const double _pulseDecayRate = 5.0;

  static const double _zoneFadeRate = 7.0;

  static const double _shakeFrequencyX = 23.0;
  static const double _shakeFrequencyY = 17.0;

  static const double _shakePhaseX = 0.37;
  static const double _shakePhaseY = 1.91;

  static const double _crashShake = 2.6;
  static const double _nearMissShake = 0.45;
  static const double _orbShake = 0.22;

  static const double _crashFlash = 0.72;

  static const double _shieldFlash = 0.34;
  static const double _orbPulse = 1.0;
  static const double _bonusPickupPulse = 0.85;
  static const double _bonusSpendPulse = 1.0;
  static const double _shieldShake = 1.1;

  static const double _portalSweep = 1.0;
  static const double _portalDecayRate = 2.2;
  static const double _speedPulse = 0.45;
  static const double _checkpointPulse = 0.7;

  static const double _tau = 6.283185307179586;

  double _shakeAmplitude = 0.0;
  double _flashAlpha = 0.0;
  double _pulse = 0.0;
  double _phase = 0.0;
  double _zoneProminence = 1.0;
  double _zoneTarget = 1.0;
  bool _flashIsShield = false;
  double _portal = 0.0;

  double get shakeX => _shakeAmplitude *
      math.sin(_phase * _tau * _shakeFrequencyX + _shakePhaseX);

  double get shakeY => _shakeAmplitude *
      math.sin(_phase * _tau * _shakeFrequencyY + _shakePhaseY);

  double get flashAlpha => _flashAlpha;

  bool get flashIsShield => _flashIsShield;

  double get portalSweep => _portal;

  int pressedSlot = -1;

  double get pulse => _pulse;

  double get animationPhase => _phase;

  double get zoneProminence => _zoneProminence;

  void setZonesVisible({required bool visible}) {
    _zoneTarget = visible ? 1.0 : 0.0;
  }

  void onEvent(GameEvent event) {
    switch (event) {
      case GameEvent.crashed:
        _addShake(_crashShake);
        _flashAlpha = _crashFlash;
        _flashIsShield = false;
      case GameEvent.shieldAbsorbed:
        _addShake(_shieldShake);
        _flashAlpha = _shieldFlash;
        _flashIsShield = true;
      case GameEvent.portalEntered:
        _portal = _portalSweep;
        _addPulse(1.0);
      case GameEvent.portalEnded:
        _portal = _portalSweep * 0.5;
      case GameEvent.bonusCollected:
        _addPulse(_bonusPickupPulse);
      case GameEvent.bonusSpent:
        _addPulse(_bonusSpendPulse);
      case GameEvent.nearMiss:
        _addShake(_nearMissShake);
      case GameEvent.orbCollected:
        _addShake(_orbShake);
        _addPulse(_orbPulse);
      case GameEvent.speedTierUp:
        _addPulse(_speedPulse);
      case GameEvent.runStarted:
        _addPulse(_speedPulse);
      case GameEvent.checkpointPassed:
        _addPulse(_checkpointPulse);
      case GameEvent.stageCleared:
        _addPulse(1.0);
    }
  }

  void advance(double dt) {
    _phase = (_phase + dt) % 1.0;
    _shakeAmplitude *= math.exp(-_shakeDecayRate * dt);
    _flashAlpha *= math.exp(-_flashDecayRate * dt);
    _pulse *= math.exp(-_pulseDecayRate * dt);
    _portal *= math.exp(-_portalDecayRate * dt);

    _zoneProminence += (_zoneTarget - _zoneProminence) *
        (1.0 - math.exp(-_zoneFadeRate * dt));
    if ((_zoneTarget - _zoneProminence).abs() < 0.002) {
      _zoneProminence = _zoneTarget;
    }
  }

  void reset() {
    _shakeAmplitude = 0.0;
    _flashAlpha = 0.0;
    _pulse = 0.0;
    _flashIsShield = false;
    _portal = 0.0;
    pressedSlot = -1;
  }

  void _addShake(double amount) {
    final total = _shakeAmplitude + amount;
    _shakeAmplitude = total > _crashShake ? _crashShake : total;
  }

  void _addPulse(double amount) {
    final total = _pulse + amount;
    _pulse = total > 1.0 ? 1.0 : total;
  }
}
