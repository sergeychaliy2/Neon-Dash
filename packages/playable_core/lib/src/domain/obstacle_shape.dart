enum ObstacleShape {
  box(hue: 192.0),

  spike(hue: 14.0),

  mine(hue: 286.0),

  wedge(hue: 36.0),

  saw(hue: 330.0);

  const ObstacleShape({required this.hue});

  final double hue;
}
