enum BonusKind {
  chrono(
    hue: 196.0,
    seconds: 4.0,
    worldSpeedScale: 0.45,
    scoreScale: 1.0,
    graceSeconds: 0.0,
  ),

  overdrive(
    hue: 32.0,
    seconds: 3.0,
    worldSpeedScale: 1.6,
    scoreScale: 2.0,
    graceSeconds: 1.0,
  ),

  shield(
    hue: 150.0,
    seconds: 0.0,
    worldSpeedScale: 1.0,
    scoreScale: 1.0,
    graceSeconds: 0.0,
  ),

  magnet(
    hue: 286.0,
    seconds: 6.0,
    worldSpeedScale: 1.0,
    scoreScale: 1.0,
    graceSeconds: 0.0,
  );

  const BonusKind({
    required this.hue,
    required this.seconds,
    required this.worldSpeedScale,
    required this.scoreScale,
    required this.graceSeconds,
  });

  final double hue;

  final double seconds;

  final double worldSpeedScale;

  final double scoreScale;

  final double graceSeconds;

  bool get isCharge => seconds <= 0.0;
}
