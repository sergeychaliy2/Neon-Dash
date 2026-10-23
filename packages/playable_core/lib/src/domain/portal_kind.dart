library;

enum PortalKind {
  rush(
    hue: 20.0,
    title: 'RUSH',
    seconds: 7.0,
    scrollScale: 1.35,
    radiusScale: 1.0,
    scoreScale: 1.5,
    mirrors: false,
  ),

  crawl(
    hue: 196.0,
    title: 'CRAWL',
    seconds: 7.0,
    scrollScale: 0.72,
    radiusScale: 1.0,
    scoreScale: 0.75,
    mirrors: false,
  ),

  mirror(
    hue: 300.0,
    title: 'MIRROR',
    seconds: 6.0,
    scrollScale: 1.0,
    radiusScale: 1.0,
    scoreScale: 1.4,
    mirrors: true,
  ),

  shrink(
    hue: 150.0,
    title: 'SHRINK',
    seconds: 8.0,
    scrollScale: 1.0,
    radiusScale: 0.62,
    scoreScale: 1.0,
    mirrors: false,
  );

  const PortalKind({
    required this.hue,
    required this.title,
    required this.seconds,
    required this.scrollScale,
    required this.radiusScale,
    required this.scoreScale,
    required this.mirrors,
  });

  final double hue;

  final String title;

  final double seconds;

  final double scrollScale;

  final double radiusScale;

  final double scoreScale;

  final bool mirrors;
}
