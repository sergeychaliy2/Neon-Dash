library;

enum HullSilhouette {
  delta,

  blade,

  chevron,

  ring,

  star,

  heart,
}

enum CraftSkin {
  interceptor(
    price: 0,
    title: 'INTERCEPTOR',
    detail: 'The standard hull. Balanced, and it never gets in the way.',
    silhouette: HullSilhouette.delta,
    noseLength: 1.18,
    shoulder: 0.28,
    tipReach: 0.98,
    tipDrop: 0.52,
    waist: 0.33,
    tailLength: 0.74,
    exhausts: 2,
    trailWidthScale: 1.0,
  ),

  lance(
    price: 140,
    title: 'LANCE',
    detail: 'A needle with three thrusters. Quick, precise, and it flies '
        'past most of the money.',
    silhouette: HullSilhouette.blade,
    noseLength: 1.52,
    shoulder: 0.18,
    tipReach: 0.62,
    tipDrop: 0.66,
    waist: 0.20,
    tailLength: 0.62,
    exhausts: 3,
    trailWidthScale: 0.72,
    speedScale: 1.16,
    gripScale: 1.10,
    radiusScale: 0.88,
    shardScale: 0.70,
  ),

  kite(
    price: 180,
    title: 'KITE',
    detail: 'All wing. Slow and broad, with the second-best haul in the '
        'hangar.',
    silhouette: HullSilhouette.delta,
    noseLength: 0.86,
    shoulder: 0.40,
    tipReach: 1.26,
    tipDrop: 0.36,
    waist: 0.44,
    tailLength: 0.52,
    exhausts: 1,
    trailWidthScale: 1.55,
    speedScale: 0.86,
    gripScale: 1.06,
    radiusScale: 1.16,
    shardScale: 1.26,
  ),

  dart(
    price: 200,
    title: 'DART',
    detail: 'The fastest thing in the hangar, and it turns like a thrown '
        'knife.',
    silhouette: HullSilhouette.chevron,
    noseLength: 1.30,
    shoulder: 0.34,
    tipReach: 1.04,
    tipDrop: 0.82,
    waist: 0.26,
    tailLength: 0.34,
    exhausts: 2,
    trailWidthScale: 0.9,
    speedScale: 1.22,
    gripScale: 0.82,
    radiusScale: 0.94,
    shardScale: 0.98,
  ),

  anvil(
    price: 220,
    title: 'ANVIL',
    detail: 'Heavy and wide, and it stops the instant you stop asking.',
    silhouette: HullSilhouette.delta,
    noseLength: 0.78,
    shoulder: 0.52,
    tipReach: 0.92,
    tipDrop: 0.18,
    waist: 0.50,
    tailLength: 0.60,
    exhausts: 3,
    trailWidthScale: 1.3,
    speedScale: 1.04,
    gripScale: 1.24,
    radiusScale: 1.18,
    shardScale: 0.94,
  ),

  halo(
    price: 240,
    title: 'HALO',
    detail: 'Violet, whatever the level says. A small target that drifts '
        'into its turns.',
    silhouette: HullSilhouette.ring,
    noseLength: 1.00,
    shoulder: 0.46,
    tipReach: 0.86,
    tipDrop: 0.10,
    waist: 0.52,
    tailLength: 0.92,
    exhausts: 2,
    trailWidthScale: 1.2,
    hueOverride: 292.0,
    speedScale: 0.94,
    gripScale: 0.84,
    radiusScale: 0.82,
    shardScale: 1.08,
  ),

  sweetheart(
    price: 260,
    title: 'SWEETHEART',
    detail: 'Pink, and absurd, and the sharpest handling in the game. Big, '
        'though.',
    silhouette: HullSilhouette.heart,
    noseLength: 1.02,
    shoulder: 0.56,
    tipReach: 1.00,
    tipDrop: 0.20,
    waist: 0.42,
    tailLength: 1.04,
    exhausts: 1,
    trailWidthScale: 1.25,
    hueOverride: 338.0,
    speedScale: 0.84,
    gripScale: 1.30,
    radiusScale: 1.10,
    shardScale: 1.04,
  ),

  trident(
    price: 280,
    title: 'TRIDENT',
    detail: 'Three prongs, three thrusters, no weaknesses worth the name — '
        'and no strengths either.',
    silhouette: HullSilhouette.chevron,
    noseLength: 1.22,
    shoulder: 0.24,
    tipReach: 1.14,
    tipDrop: 0.58,
    waist: 0.34,
    tailLength: 0.70,
    exhausts: 3,
    trailWidthScale: 1.0,
    speedScale: 1.06,
    gripScale: 1.08,
    radiusScale: 0.96,
    shardScale: 0.90,
  ),

  wisp(
    price: 300,
    title: 'WISP',
    detail: 'The smallest target in the game. You will miss things you '
        'meant to collect.',
    silhouette: HullSilhouette.ring,
    noseLength: 0.72,
    shoulder: 0.34,
    tipReach: 0.58,
    tipDrop: 0.14,
    waist: 0.34,
    tailLength: 0.66,
    exhausts: 1,
    trailWidthScale: 0.6,
    speedScale: 0.88,
    gripScale: 0.96,
    radiusScale: 0.80,
    shardScale: 0.96,
  ),

  prism(
    price: 320,
    title: 'PRISM',
    detail: 'Gold, angular, swept back. The best haul in the hangar, and '
        'the patience to use it.',
    silhouette: HullSilhouette.star,
    noseLength: 1.34,
    shoulder: 0.14,
    tipReach: 1.10,
    tipDrop: 0.74,
    waist: 0.16,
    tailLength: 0.44,
    exhausts: 3,
    trailWidthScale: 0.9,
    hueOverride: 46.0,
    speedScale: 0.90,
    gripScale: 0.92,
    radiusScale: 1.04,
    shardScale: 1.30,
  ),

  comet(
    price: 360,
    title: 'COMET',
    detail: 'Fast, broad and well paid. It hears you, then thinks about it.',
    silhouette: HullSilhouette.blade,
    noseLength: 1.44,
    shoulder: 0.30,
    tipReach: 0.74,
    tipDrop: 0.88,
    waist: 0.30,
    tailLength: 0.80,
    exhausts: 2,
    trailWidthScale: 1.45,
    hueOverride: 18.0,
    speedScale: 1.20,
    gripScale: 0.80,
    radiusScale: 1.06,
    shardScale: 1.14,
  ),

  oracle(
    price: 400,
    title: 'ORACLE',
    detail: 'Five points of nothing much, and it goes exactly where you '
        'look.',
    silhouette: HullSilhouette.star,
    noseLength: 1.10,
    shoulder: 0.20,
    tipReach: 0.90,
    tipDrop: 0.44,
    waist: 0.24,
    tailLength: 0.88,
    exhausts: 2,
    trailWidthScale: 0.85,
    hueOverride: 168.0,
    speedScale: 0.98,
    gripScale: 1.06,
    radiusScale: 0.90,
    shardScale: 0.96,
  );

  const CraftSkin({
    required this.price,
    required this.title,
    required this.detail,
    required this.silhouette,
    required this.noseLength,
    required this.shoulder,
    required this.tipReach,
    required this.tipDrop,
    required this.waist,
    required this.tailLength,
    required this.exhausts,
    required this.trailWidthScale,
    this.hueOverride,
    this.speedScale = 1.0,
    this.gripScale = 1.0,
    this.radiusScale = 1.0,
    this.shardScale = 1.0,
  });

  final int price;

  final String title;

  final String detail;

  final HullSilhouette silhouette;

  final double noseLength;

  final double shoulder;

  final double tipReach;
  final double tipDrop;

  final double waist;

  final double tailLength;

  final int exhausts;

  final double trailWidthScale;

  final double? hueOverride;

  final double speedScale;

  final double gripScale;

  final double radiusScale;

  final double shardScale;

  bool get isPurchasable => price > 0;

  double get rating =>
      speedScale + gripScale + (2.0 - radiusScale) + shardScale;

  bool dominates(CraftSkin other) =>
      this != other &&
      speedScale >= other.speedScale &&
      gripScale >= other.gripScale &&
      radiusScale <= other.radiusScale &&
      shardScale >= other.shardScale &&
      (speedScale > other.speedScale ||
          gripScale > other.gripScale ||
          radiusScale < other.radiusScale ||
          shardScale > other.shardScale);

  static const CraftSkin standard = CraftSkin.interceptor;
}
