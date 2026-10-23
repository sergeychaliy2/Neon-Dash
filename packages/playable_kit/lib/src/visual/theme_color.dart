class ThemeColor {
  const ThemeColor(
    this.hue,
    this.saturation,
    this.lightness, [
    this.alpha = 1.0,
  ]);

  final double hue;
  final double saturation;
  final double lightness;
  final double alpha;
}
