enum MusicLayer {
  drums(joinsAtIntensity: 0, mixGain: 0.95),

  bass(joinsAtIntensity: 1, mixGain: 0.85),

  arp(joinsAtIntensity: 2, mixGain: 0.62),

  lead(joinsAtIntensity: 3, mixGain: 0.5);

  const MusicLayer({required this.joinsAtIntensity, required this.mixGain});

  final int joinsAtIntensity;

  final double mixGain;

  double volumeAt(int intensity) =>
      intensity >= joinsAtIntensity ? mixGain : 0.0;
}
