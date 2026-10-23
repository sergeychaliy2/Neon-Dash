library;

enum AchievementMetric {
  runs,

  finishes,

  shiftingFinishes,

  perfectRuns,

  levelsCleared,

  stars,

  orbs,

  nearMisses,

  bonusesSpent,

  shardsEarned,

  continuesBought,

  bestScore,

  hullsOwned,

  upgradesOwned,
}

enum Achievement {
  firstFlight(
    title: 'FIRST FLIGHT',
    detail: 'Finish a run, however it ends.',
    metric: AchievementMetric.runs,
    target: 1,
  ),
  gettingTheHang(
    title: 'GETTING THE HANG',
    detail: 'Twenty-five runs.',
    metric: AchievementMetric.runs,
    target: 25,
  ),
  regular(
    title: 'REGULAR',
    detail: 'A hundred runs.',
    metric: AchievementMetric.runs,
    target: 100,
  ),

  madeIt(
    title: 'MADE IT',
    detail: 'Reach a finish line.',
    metric: AchievementMetric.finishes,
    target: 1,
  ),
  tenDown(
    title: 'TEN DOWN',
    detail: 'Ten finishes.',
    metric: AchievementMetric.finishes,
    target: 10,
  ),
  longHaul(
    title: 'LONG HAUL',
    detail: 'Fifty finishes.',
    metric: AchievementMetric.finishes,
    target: 50,
  ),

  wayOpen(
    title: 'WAY OPEN',
    detail: 'Clear your first level.',
    metric: AchievementMetric.levelsCleared,
    target: 1,
  ),
  halfTheMap(
    title: 'HALF THE MAP',
    detail: 'Clear seven levels.',
    metric: AchievementMetric.levelsCleared,
    target: 7,
  ),
  terminus(
    title: 'ALL FOURTEEN',
    detail: 'Clear every level in the catalogue.',
    metric: AchievementMetric.levelsCleared,
    target: 14,
  ),

  firstStars(
    title: 'THREE POINTS',
    detail: 'Hold three stars.',
    metric: AchievementMetric.stars,
    target: 3,
  ),
  constellation(
    title: 'CONSTELLATION',
    detail: 'Hold fifteen stars.',
    metric: AchievementMetric.stars,
    target: 15,
  ),
  starCharted(
    title: 'STAR CHARTED',
    detail: 'Hold thirty stars.',
    metric: AchievementMetric.stars,
    target: 30,
  ),
  everyStar(
    title: 'EVERY LAST STAR',
    detail: 'Hold all forty-two.',
    metric: AchievementMetric.stars,
    target: 42,
  ),

  untouched(
    title: 'UNTOUCHED',
    detail: 'Finish a level with all three stars.',
    metric: AchievementMetric.perfectRuns,
    target: 1,
  ),
  surgical(
    title: 'SURGICAL',
    detail: 'Five perfect runs.',
    metric: AchievementMetric.perfectRuns,
    target: 5,
  ),
  immaculate(
    title: 'IMMACULATE',
    detail: 'Twenty perfect runs.',
    metric: AchievementMetric.perfectRuns,
    target: 20,
  ),

  closeShave(
    title: 'CLOSE SHAVE',
    detail: 'Twenty-five near misses.',
    metric: AchievementMetric.nearMisses,
    target: 25,
  ),
  paintSwap(
    title: 'PAINT SWAP',
    detail: 'Two hundred and fifty near misses.',
    metric: AchievementMetric.nearMisses,
    target: 250,
  ),
  recklessness(
    title: 'STUDIED RECKLESSNESS',
    detail: 'A thousand near misses.',
    metric: AchievementMetric.nearMisses,
    target: 1000,
  ),

  magpie(
    title: 'MAGPIE',
    detail: 'Collect fifty orbs.',
    metric: AchievementMetric.orbs,
    target: 50,
  ),
  hoarder(
    title: 'HOARDER',
    detail: 'Collect five hundred orbs.',
    metric: AchievementMetric.orbs,
    target: 500,
  ),
  vault(
    title: 'THE VAULT',
    detail: 'Collect two and a half thousand orbs.',
    metric: AchievementMetric.orbs,
    target: 2500,
  ),

  fiveFigures(
    title: 'FIVE FIGURES',
    detail: 'Score ten thousand in a single run.',
    metric: AchievementMetric.bestScore,
    target: 10000,
  ),
  recordHolder(
    title: 'RECORD HOLDER',
    detail: 'Score twenty-five thousand in a single run.',
    metric: AchievementMetric.bestScore,
    target: 25000,
  ),

  loadedUp(
    title: 'LOADED UP',
    detail: 'Spend ten power-ups.',
    metric: AchievementMetric.bonusesSpent,
    target: 10,
  ),
  quartermaster(
    title: 'QUARTERMASTER',
    detail: 'Spend a hundred power-ups.',
    metric: AchievementMetric.bonusesSpent,
    target: 100,
  ),

  secondOpinion(
    title: 'SECOND OPINION',
    detail: 'Own three hulls.',
    metric: AchievementMetric.hullsOwned,
    target: 3,
  ),
  collector(
    title: 'COLLECTOR',
    detail: 'Own seven hulls.',
    metric: AchievementMetric.hullsOwned,
    target: 7,
  ),
  fullHangar(
    title: 'FULL HANGAR',
    detail: 'Own every hull.',
    metric: AchievementMetric.hullsOwned,
    target: 12,
  ),
  firstUpgrade(
    title: 'REFIT',
    detail: 'Buy an upgrade rank.',
    metric: AchievementMetric.upgradesOwned,
    target: 1,
  ),
  wellEquipped(
    title: 'WELL EQUIPPED',
    detail: 'Buy every rank of every upgrade.',
    metric: AchievementMetric.upgradesOwned,
    target: 12,
  ),
  wealthy(
    title: 'WEALTHY',
    detail: 'Earn five thousand shards.',
    metric: AchievementMetric.shardsEarned,
    target: 5000,
  ),

  noRehearsal(
    title: 'NO REHEARSAL',
    detail: 'Finish a level in shifting mode.',
    metric: AchievementMetric.shiftingFinishes,
    target: 1,
  ),
  improviser(
    title: 'IMPROVISER',
    detail: 'Ten shifting finishes.',
    metric: AchievementMetric.shiftingFinishes,
    target: 10,
  ),

  secondChance(
    title: 'SECOND CHANCE',
    detail: 'Buy a run back from a checkpoint.',
    metric: AchievementMetric.continuesBought,
    target: 1,
  ),
  persistent(
    title: 'PERSISTENT',
    detail: 'Buy ten runs back.',
    metric: AchievementMetric.continuesBought,
    target: 10,
  );

  const Achievement({
    required this.title,
    required this.detail,
    required this.metric,
    required this.target,
  });

  final String title;
  final String detail;

  final AchievementMetric metric;

  final int target;
}
