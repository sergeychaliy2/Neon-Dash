library;

import 'bonus_kind.dart';

enum Upgrade {
  extraSlot(
    title: 'FOURTH SLOT',
    detail: 'Carry one more power-up into every run.',
    prices: <int>[180],
  ),

  startingShield(
    title: 'REINFORCED HULL',
    detail: 'Begin each run with a shield charge already banked, per rank.',
    prices: <int>[260, 620],
  ),

  potency(
    title: 'OVERCHARGED CORE',
    detail: 'Timed power-ups last 15% longer and the magnet reaches 22% '
        'further, per rank.',
    prices: <int>[300, 560, 900],
  ),

  salvage(
    title: 'SALVAGE RIG',
    detail: 'Every run pays 18% more shards, per rank.',
    prices: <int>[200, 380, 640],
  ),

  fortune(
    title: 'SCAVENGER ARRAY',
    detail: 'Power-ups appear 25% more often, per rank.',
    prices: <int>[240, 450, 760],
  );

  const Upgrade({
    required this.title,
    required this.detail,
    required this.prices,
  });

  final String title;

  final String detail;

  final List<int> prices;

  int get maxRank => prices.length;

  int priceFrom(int rank) => rank < 0
      ? prices.first
      : (rank >= maxRank ? 0 : prices[rank]);

  static int get totalRanks {
    var total = 0;
    for (final upgrade in values) {
      total += upgrade.maxRank;
    }
    return total;
  }
}

class UpgradeLoadout {
  const UpgradeLoadout(this.ranks);

  static const UpgradeLoadout none = UpgradeLoadout(<Upgrade, int>{});

  final Map<Upgrade, int> ranks;

  int rankOf(Upgrade upgrade) {
    final rank = ranks[upgrade] ?? 0;
    if (rank < 0) return 0;
    return rank > upgrade.maxRank ? upgrade.maxRank : rank;
  }

  bool has(Upgrade upgrade) => rankOf(upgrade) > 0;

  Iterable<Upgrade> get owned => Upgrade.values.where(has);

  int get totalRanks {
    var total = 0;
    for (final upgrade in Upgrade.values) {
      total += rankOf(upgrade);
    }
    return total;
  }

  int get extraSlots {
    final asked = rankOf(Upgrade.extraSlot);
    return asked > BonusKind.values.length ? BonusKind.values.length : asked;
  }

  int get startingShields => rankOf(Upgrade.startingShield);

  double get bonusDurationScale => 1.0 + 0.15 * rankOf(Upgrade.potency);

  double get magnetRadiusScale => 1.0 + 0.22 * rankOf(Upgrade.potency);

  double get pickupChanceScale => 1.0 + 0.25 * rankOf(Upgrade.fortune);

  double get payoutScale => 1.0 + 0.18 * rankOf(Upgrade.salvage);
}
