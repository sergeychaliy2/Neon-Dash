library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:playable_core/playable_core.dart';

import '../render/palette.dart';
import '../ui/neon_widgets.dart';
import '../ui/skin_preview.dart';
import '../ui/star_row.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({
    required this.progression,
    required this.onPlay,
    required this.onProfileChanged,
    required this.settings,
    required this.onSettingsChanged,
    this.onTabChanged,
    this.initialTab = 0,
    super.key,
  });

  final Progression progression;

  final void Function(LevelDefinition level, RunMode mode) onPlay;

  final VoidCallback onProfileChanged;

  final Settings settings;

  final VoidCallback onSettingsChanged;

  final int initialTab;

  final ValueChanged<int>? onTabChanged;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _tabs = <String>[
    'LEVELS',
    'HULLS',
    'UPGRADES',
    'AWARDS',
    'RECORD',
    'SETTINGS',
  ];

  static const Duration _cycle = Duration(seconds: 20);

  static const double _swipeVelocity = 220.0;

  late final AnimationController _clock;
  final ScrollController _strip = ScrollController();
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: _cycle)..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealTab(_tab));
  }

  @override
  void dispose() {
    _clock.dispose();
    _strip.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _tab) return;

    setState(() => _tab = index);
    widget.onTabChanged?.call(index);
    _revealTab(index);
  }

  void _revealTab(int index) {
    if (!_strip.hasClients) return;

    final travel = _strip.position.maxScrollExtent;
    if (travel <= 0.0) return;

    _strip.animateTo(
      travel * index / (_tabs.length - 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _swipeTab(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity.abs() < _swipeVelocity) return;

    _selectTab(velocity > 0.0 ? _tab - 1 : _tab + 1);
  }

  void _buy(Upgrade upgrade) {
    if (!widget.progression.buy(upgrade)) return;
    setState(widget.onProfileChanged);
  }

  void _chooseSkin(CraftSkin skin) {
    final profile = widget.progression;
    final acted = profile.ownsSkin(skin)
        ? profile.selectSkin(skin)
        : profile.buySkin(skin);
    if (!acted) return;
    setState(widget.onProfileChanged);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) =>
              CustomPaint(painter: MenuBackdrop(phase: _clock.value)),
        ),
      ),
      SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(),
            SingleChildScrollView(
              controller: _strip,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: NeonTabBar(
                labels: _tabs,
                selected: _tab,
                onSelected: _selectTab,
              ),
            ),
            const SizedBox(height: 14.0),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: _swipeTab,
                child: ScreenSwitch(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_tab),
                    child: _buildBody(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20.0, 22.0, 20.0, 16.0),
    child: Column(
      children: <Widget>[
        const NeonLabel(
          'NEON DASH',
          size: 30.0,
          weight: FontWeight.w800,
          tracking: 8.0,
        ),
        const SizedBox(height: 12.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _Counter(
              icon: _CounterIcon.star,
              value: '${widget.progression.totalStars}',
              color: Palette.star,
            ),
            const SizedBox(width: 22.0),
            _Counter(
              icon: _CounterIcon.shard,
              value: '${widget.progression.shards}',
              color: colorFromHsl(BonusKind.overdrive.hue, 0.9, 0.66),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildBody() => switch (_tab) {
    1 => _buildSkins(),
    2 => _buildUpgrades(),
    3 => _buildAwards(),
    4 => _buildRecord(),
    5 => _buildSettings(),
    _ => _buildLevels(),
  };

  Widget _buildSettings() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440.0),
        child: Column(
          children: <Widget>[
            RiseIn(
              child: GlassPanel(
                child: Column(
                  children: <Widget>[
                    SettingRow(
                      label: 'MUSIC',
                      detail: 'The level soundtrack.',
                      control: NeonSlider(
                        value: widget.settings.musicVolume,
                        onChanged: (value) => _setSetting(
                          () => widget.settings.musicVolume = value,
                        ),
                      ),
                    ),
                    SettingRow(
                      label: 'EFFECTS',
                      detail: 'Impacts, pickups, gates and near misses.',
                      control: NeonSlider(
                        value: widget.settings.effectsVolume,
                        hue: BonusKind.overdrive.hue,
                        onChanged: (value) => _setSetting(
                          () => widget.settings.effectsVolume = value,
                        ),
                      ),
                    ),
                    SettingRow(
                      label: 'VIBRATION',
                      detail:
                          'Buzzes on impacts, shields and gates. Handsets '
                          'only — there is nothing to buzz on a desktop.',
                      control: NeonToggle(
                        value: widget.settings.vibration,
                        hue: BonusKind.shield.hue,
                        onChanged: (value) => _setSetting(
                          () => widget.settings.vibration = value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14.0),
            RiseIn(
              index: 1,
              child: NeonLabel(
                widget.settings.isSilent
                    ? 'SOUND IS OFF'
                    : 'SETTINGS ARE SAVED AS YOU CHANGE THEM',
                size: 10.0,
                color: widget.settings.isSilent
                    ? Palette.crashFlash
                    : Palette.hudDim,
                glow: 0.0,
                tracking: 1.6,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _setSetting(VoidCallback change) {
    setState(change);
    widget.onSettingsChanged();
  }

  Widget _buildAwards() => LayoutBuilder(
    builder: (context, constraints) {
      const target = 330.0;
      final columns = math
          .max(1, (constraints.maxWidth - 24.0) ~/ target)
          .clamp(1, 2);
      final width =
          (constraints.maxWidth - 24.0 - (columns - 1) * 12.0) / columns;

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 24.0),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: NeonLabel(
                '${widget.progression.earnedAchievementCount} OF '
                '${Achievement.values.length} EARNED',
                size: 11.0,
                color: Palette.star,
                tracking: 2.4,
              ),
            ),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: <Widget>[
                for (var i = 0; i < Achievement.values.length; i++)
                  SizedBox(
                    width: width,
                    child: RiseIn(
                      index: i,
                      child: _AwardCard(
                        achievement: Achievement.values[i],
                        progress: widget.progression.progressOf(
                          Achievement.values[i],
                        ),
                        earned: widget.progression.hasEarned(
                          Achievement.values[i],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _buildSkins() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 24.0),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560.0),
        child: Column(
          children: <Widget>[
            for (final skin in CraftSkin.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: RiseIn(
                  index: skin.index,
                  child: _SkinCard(
                    skin: skin,
                    owned: widget.progression.ownsSkin(skin),
                    worn: widget.progression.selectedSkin == skin,
                    affordable: widget.progression.canAffordSkin(skin),
                    onChoose: () => _chooseSkin(skin),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _buildLevels() => LayoutBuilder(
    builder: (context, constraints) {
      const target = 280.0;
      final columns = math
          .max(1, (constraints.maxWidth - 24.0) ~/ target)
          .clamp(1, 3);
      final width =
          (constraints.maxWidth - 24.0 - (columns - 1) * 12.0) / columns;

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 24.0),
        child: Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: <Widget>[
            for (final level in LevelCatalogue.levels)
              SizedBox(
                width: width,
                child: RiseIn(
                  index: level.index,
                  child: _LevelCard(
                    level: level,
                    stars: widget.progression.starsFor(level.index),
                    best: widget.progression.bestScoreFor(level.index),
                    unlocked: widget.progression.isUnlocked(level),
                    shiftingOpen: widget.progression.isShiftingUnlocked(
                      level.index,
                    ),
                    shiftingBest: widget.progression.bestScoreFor(
                      level.index,
                      mode: RunMode.shifting,
                    ),
                    requirement: _requirementFor(level),
                    onPlay: (mode) => widget.onPlay(level, mode),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  String _requirementFor(LevelDefinition level) {
    if (widget.progression.isUnlocked(level)) return '';

    return switch (level.unlock) {
      AlwaysOpen() => '',
      AfterLevel(:final levelIndex) =>
        'CLEAR ${LevelCatalogue.byIndex(levelIndex).name}',
      StarsRequired() =>
        '${widget.progression.starsStillNeeded(level)} MORE STARS',
    };
  }

  Widget _buildUpgrades() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460.0),
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(bottom: 14.0),
              child: NeonLabel(
                'SHARDS COME FROM ORBS AND FINISHED RUNS',
                size: 10.5,
                color: Palette.hudDim,
                glow: 0.0,
                tracking: 2.0,
                weight: FontWeight.w500,
                maxLines: 2,
              ),
            ),
            for (final upgrade in Upgrade.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: RiseIn(
                  index: upgrade.index,
                  child: _UpgradeCard(
                    upgrade: upgrade,
                    rank: widget.progression.rankOf(upgrade),
                    price: widget.progression.priceOf(upgrade),
                    maxed: widget.progression.isMaxed(upgrade),
                    affordable: widget.progression.canAfford(upgrade),
                    onBuy: () => _buy(upgrade),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _buildRecord() {
    final profile = widget.progression;
    final maxStars = LevelCatalogue.count * StarRules.maxPerLevel;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420.0),
          child: GlassPanel(
            child: Column(
              children: <Widget>[
                StatLine(
                  label: 'STARS',
                  value: '${profile.totalStars} / $maxStars',
                  accent: Palette.star,
                ),
                StatLine(
                  label: 'LEVELS CLEARED',
                  value: '${profile.clearedCount} / ${LevelCatalogue.count}',
                ),
                StatLine(
                  label: 'LEVELS UNLOCKED',
                  value: '${profile.unlockedCount} / ${LevelCatalogue.count}',
                ),
                StatLine(label: 'BEST SCORE', value: '${profile.bestScore}'),
                StatLine(label: 'RUNS', value: '${profile.runsPlayed}'),
                StatLine(
                  label: 'ORBS COLLECTED',
                  value: '${profile.orbsCollected}',
                ),
                StatLine(
                  label: 'SHARDS',
                  value: '${profile.shards}',
                  accent: colorFromHsl(BonusKind.overdrive.hue, 0.9, 0.66),
                ),
                StatLine(
                  label: 'AWARDS',
                  value:
                      '${profile.earnedAchievementCount} / '
                      '${Achievement.values.length}',
                  accent: Palette.star,
                ),
                StatLine(
                  label: 'FINISHES',
                  value: '${profile.metric(AchievementMetric.finishes)}',
                ),
                StatLine(
                  label: 'PERFECT RUNS',
                  value: '${profile.metric(AchievementMetric.perfectRuns)}',
                ),
                StatLine(
                  label: 'NEAR MISSES',
                  value: '${profile.metric(AchievementMetric.nearMisses)}',
                ),
                StatLine(
                  label: 'HULLS',
                  value:
                      '${profile.skins.length} / '
                      '${CraftSkin.values.length}',
                ),
                StatLine(
                  label: 'UPGRADES',
                  value:
                      '${profile.loadout.owned.length} / '
                      '${Upgrade.values.length}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatefulWidget {
  const _LevelCard({
    required this.level,
    required this.stars,
    required this.best,
    required this.unlocked,
    required this.shiftingOpen,
    required this.shiftingBest,
    required this.requirement,
    required this.onPlay,
  });

  final LevelDefinition level;
  final int stars;
  final int best;
  final bool unlocked;

  final bool shiftingOpen;
  final int shiftingBest;

  final String requirement;
  final ValueChanged<RunMode> onPlay;

  @override
  State<_LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<_LevelCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    final accent = colorOfTheme(level.theme.craft);
    final open = widget.unlocked;
    final lift = open ? (_hovered ? 1.0 : 0.55) : 0.0;

    return MouseRegion(
      cursor: open ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NeonMetrics.corner),
          border: Border.all(
            color: open
                ? accent.withValues(alpha: 0.25 + 0.6 * lift)
                : Palette.hudDim.withValues(alpha: 0.2),
            width: NeonMetrics.hairline,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colorOfTheme(level.theme.skyNear),
              colorOfTheme(level.theme.skyFar),
            ],
          ),
          boxShadow: lift > 0.6
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2 * lift),
                    blurRadius: 22.0,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: open ? () => widget.onPlay(RunMode.fixed) : null,
              child: open ? _buildOpen(accent) : _buildLocked(),
            ),
            if (open && widget.shiftingOpen) ...<Widget>[
              const SizedBox(height: 12.0),
              _ModeChip(
                best: widget.shiftingBest,
                onTap: () => widget.onPlay(RunMode.shifting),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOpen(Color accent) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        children: <Widget>[
          _LevelNumber(index: widget.level.index, color: accent),
          const SizedBox(width: 10.0),
          Expanded(
            child: NeonLabel(
              widget.level.name,
              size: 15.0,
              color: accent,
              weight: FontWeight.w700,
              tracking: 2.6,
              align: TextAlign.left,
              maxLines: 1,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8.0),
      NeonLabel(
        widget.level.tagline,
        size: 10.5,
        color: Palette.hudDim,
        glow: 0.0,
        tracking: 1.2,
        weight: FontWeight.w500,
        align: TextAlign.left,
        maxLines: 2,
      ),
      const SizedBox(height: 14.0),
      Row(
        children: <Widget>[
          StarRow(
            earned: widget.stars,
            alreadyHeld: widget.stars,
            size: 18.0,
            animate: false,
          ),
          const Spacer(),
          if (widget.best > 0)
            NeonLabel(
              '${widget.best}',
              size: 12.0,
              color: Palette.hudDim,
              glow: 0.0,
              tracking: 1.0,
            ),
        ],
      ),
    ],
  );

  Widget _buildLocked() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      const Row(
        children: <Widget>[
          _PadlockIcon(),
          SizedBox(width: 10.0),
          Expanded(
            child: NeonLabel(
              'LOCKED',
              size: 15.0,
              color: Palette.hudDim,
              glow: 0.0,
              weight: FontWeight.w700,
              tracking: 3.0,
              align: TextAlign.left,
              maxLines: 1,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8.0),
      NeonLabel(
        widget.requirement,
        size: 11.0,
        color: Palette.star.withValues(alpha: 0.8),
        glow: 0.0,
        tracking: 1.6,
        weight: FontWeight.w600,
        align: TextAlign.left,
        maxLines: 2,
      ),
      const SizedBox(height: 14.0),
      const StarRow(earned: 0, alreadyHeld: 0, size: 18.0, animate: false),
    ],
  );
}

class _ModeChip extends StatefulWidget {
  const _ModeChip({required this.best, required this.onTap});

  final int best;
  final VoidCallback onTap;

  @override
  State<_ModeChip> createState() => _ModeChipState();
}

class _ModeChipState extends State<_ModeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = colorFromHsl(BonusKind.overdrive.hue, 0.9, 0.66);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NeonMetrics.buttonCorner),
            color: accent.withValues(alpha: _hovered ? 0.16 : 0.07),
            border: Border.all(
              color: accent.withValues(alpha: _hovered ? 0.8 : 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              NeonLabel(
                RunMode.shifting.title,
                size: 11.0,
                color: accent,
                glow: _hovered ? 0.8 : 0.3,
                tracking: 2.0,
                weight: FontWeight.w700,
              ),
              NeonLabel(
                widget.best > 0 ? '${widget.best}' : 'x1.5 SHARDS',
                size: 10.0,
                color: Palette.hudDim,
                glow: 0.0,
                tracking: 1.0,
                weight: FontWeight.w500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.owned,
    required this.worn,
    required this.affordable,
    required this.onChoose,
  });

  final CraftSkin skin;
  final bool owned;
  final bool worn;
  final bool affordable;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final hue = skin.hueOverride ?? Palette.craftHue;
    final accent = colorFromHsl(hue, 0.9, 0.64);

    return GlassPanel(
      padding: const EdgeInsets.all(14.0),
      tint: worn ? Palette.star : accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkinPreview(skin: skin, hue: hue, size: 104.0, lit: owned),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                NeonLabel(
                  skin.title,
                  size: 14.0,
                  color: worn ? Palette.star : Palette.hudPrimary,
                  weight: FontWeight.w700,
                  tracking: 2.4,
                  align: TextAlign.left,
                  maxLines: 1,
                ),
                const SizedBox(height: 6.0),
                NeonLabel(
                  skin.detail,
                  size: 10.5,
                  color: Palette.hudDim,
                  glow: 0.0,
                  tracking: 1.0,
                  weight: FontWeight.w500,
                  align: TextAlign.left,
                  maxLines: 3,
                ),
                const SizedBox(height: 10.0),
                _HullStats(skin: skin, accent: accent),
                const SizedBox(height: 12.0),
                SizedBox(width: 136.0, child: _buildAction(hue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(double hue) {
    if (worn) {
      return const NeonLabel(
        'IN USE',
        size: 12.0,
        color: Palette.star,
        weight: FontWeight.w700,
        tracking: 2.0,
      );
    }
    if (owned) {
      return NeonButton(label: 'WEAR', hue: hue, onPressed: onChoose);
    }
    return NeonButton(
      label: '${skin.price}',
      note: 'SHARDS',
      hue: hue,
      enabled: affordable,
      emphasis: ButtonEmphasis.primary,
      onPressed: onChoose,
    );
  }
}

class _HullStats extends StatelessWidget {
  const _HullStats({required this.skin, required this.accent});

  final CraftSkin skin;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      _HullStatBar(label: 'SPEED', value: skin.speedScale, accent: accent),
      _HullStatBar(label: 'GRIP', value: skin.gripScale, accent: accent),
      _HullStatBar(
        label: 'LOW PROFILE',
        value: 2.0 - skin.radiusScale,
        accent: accent,
      ),
      _HullStatBar(label: 'HAUL', value: skin.shardScale, accent: accent),
    ],
  );
}

class _HullStatBar extends StatelessWidget {
  const _HullStatBar({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;

  final double value;

  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.0),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 86.0,
          child: NeonLabel(
            label,
            size: 9.0,
            color: Palette.hudDim,
            glow: 0.0,
            tracking: 1.2,
            weight: FontWeight.w600,
            align: TextAlign.left,
            maxLines: 1,
          ),
        ),
        Expanded(
          child: CustomPaint(
            size: const Size(double.infinity, 6.0),
            painter: _HullStatPainter(value: value, accent: accent),
          ),
        ),
      ],
    ),
  );
}

class _HullStatPainter extends CustomPainter {
  _HullStatPainter({required this.value, required this.accent});

  final double value;
  final Color accent;

  static const double _span = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final middle = size.width * 0.5;
    final track = Rect.fromLTWH(0.0, 1.0, size.width, size.height - 2.0);
    final corner = Radius.circular(track.height * 0.5);

    canvas.drawRRect(
      RRect.fromRectAndRadius(track, corner),
      paint..color = Palette.routeTrack,
    );

    final offset = ((value - 1.0) / _span).clamp(-1.0, 1.0);
    if (offset.abs() > 0.02) {
      final reach = middle * offset;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            offset < 0 ? middle + reach : middle,
            track.top,
            offset < 0 ? middle : middle + reach,
            track.bottom,
          ),
          corner,
        ),
        paint..color = offset > 0 ? accent : Palette.crashFlash,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(middle - 0.5, 0.0, 1.0, size.height),
      paint..color = Palette.hudDim.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_HullStatPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.accent != accent;
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({
    required this.achievement,
    required this.progress,
    required this.earned,
  });

  final Achievement achievement;
  final int progress;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final accent = earned ? Palette.star : Palette.hudDim;

    return GlassPanel(
      padding: const EdgeInsets.all(13.0),
      tint: earned ? Palette.star : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              CustomPaint(
                size: const Size.square(14.0),
                painter: _AwardMarkPainter(earned: earned),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: NeonLabel(
                  achievement.title,
                  size: 12.0,
                  color: accent,
                  glow: earned ? 0.7 : 0.0,
                  weight: FontWeight.w700,
                  tracking: 1.8,
                  align: TextAlign.left,
                  maxLines: 1,
                ),
              ),
              NeonLabel(
                '$progress/${achievement.target}',
                size: 10.0,
                color: Palette.hudDim,
                glow: 0.0,
                tracking: 0.8,
                weight: FontWeight.w600,
              ),
            ],
          ),
          const SizedBox(height: 7.0),
          NeonLabel(
            achievement.detail,
            size: 10.0,
            color: Palette.hudDim,
            glow: 0.0,
            tracking: 0.9,
            weight: FontWeight.w500,
            align: TextAlign.left,
            maxLines: 2,
          ),
          const SizedBox(height: 9.0),
          CustomPaint(
            size: const Size(double.infinity, 4.0),
            painter: _AwardProgressPainter(
              fraction: achievement.target == 0
                  ? 1.0
                  : progress / achievement.target,
              earned: earned,
            ),
          ),
        ],
      ),
    );
  }
}

class _AwardMarkPainter extends CustomPainter {
  _AwardMarkPainter({required this.earned});

  final bool earned;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = earned ? Palette.star : Palette.starEmpty;
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide * 0.5;

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.32;
    canvas.drawCircle(centre, radius * 0.72, paint);

    if (!earned) return;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(centre, radius * 0.3, paint);
  }

  @override
  bool shouldRepaint(_AwardMarkPainter oldDelegate) =>
      oldDelegate.earned != earned;
}

class _AwardProgressPainter extends CustomPainter {
  _AwardProgressPainter({required this.fraction, required this.earned});

  final double fraction;
  final bool earned;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final track = Offset.zero & size;
    final corner = Radius.circular(size.height * 0.5);

    canvas.drawRRect(
      RRect.fromRectAndRadius(track, corner),
      paint..color = Palette.routeTrack,
    );

    final filled = size.width * fraction.clamp(0.0, 1.0);
    if (filled <= 0.0) return;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.0, 0.0, filled, size.height),
        corner,
      ),
      paint..color = earned ? Palette.star : Palette.routeCalm,
    );
  }

  @override
  bool shouldRepaint(_AwardProgressPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.earned != earned;
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.upgrade,
    required this.rank,
    required this.price,
    required this.maxed,
    required this.affordable,
    required this.onBuy,
  });

  final Upgrade upgrade;

  final int rank;

  final int price;

  final bool maxed;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final accent = colorFromHsl(BonusKind.overdrive.hue, 0.9, 0.66);
    final owned = rank > 0;

    return GlassPanel(
      padding: const EdgeInsets.all(16.0),
      tint: maxed ? Palette.star : accent,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: NeonLabel(
                        upgrade.title,
                        size: 14.0,
                        color: owned ? Palette.star : Palette.hudPrimary,
                        weight: FontWeight.w700,
                        tracking: 2.4,
                        align: TextAlign.left,
                        maxLines: 1,
                      ),
                    ),
                    NeonLabel(
                      '$rank/${upgrade.maxRank}',
                      size: 11.0,
                      color: owned ? Palette.star : Palette.hudDim,
                      glow: 0.0,
                      tracking: 1.0,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                NeonLabel(
                  upgrade.detail,
                  size: 10.5,
                  color: Palette.hudDim,
                  glow: 0.0,
                  tracking: 1.0,
                  weight: FontWeight.w500,
                  align: TextAlign.left,
                  maxLines: 3,
                ),
                const SizedBox(height: 9.0),
                _RankPips(rank: rank, of: upgrade.maxRank, accent: accent),
              ],
            ),
          ),
          const SizedBox(width: 14.0),
          SizedBox(
            width: 104.0,
            child: maxed
                ? const NeonLabel(
                    'MAXED',
                    size: 12.0,
                    color: Palette.star,
                    weight: FontWeight.w700,
                    tracking: 2.0,
                  )
                : NeonButton(
                    label: '$price',
                    note: owned ? 'RANK ${rank + 1}' : 'SHARDS',
                    hue: BonusKind.overdrive.hue,
                    enabled: affordable,
                    emphasis: ButtonEmphasis.primary,
                    onPressed: onBuy,
                  ),
          ),
        ],
      ),
    );
  }
}

class _RankPips extends StatelessWidget {
  const _RankPips({required this.rank, required this.of, required this.accent});

  final int rank;
  final int of;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (var i = 0; i < of; i++)
        Padding(
          padding: const EdgeInsets.only(right: 5.0),
          child: Container(
            width: 22.0,
            height: 5.0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2.5),
              color: i < rank ? accent : accent.withValues(alpha: 0.18),
            ),
          ),
        ),
    ],
  );
}

class _LevelNumber extends StatelessWidget {
  const _LevelNumber({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 26.0,
    height: 26.0,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: NeonLabel(
      '${index + 1}',
      size: 11.0,
      color: color,
      glow: 0.0,
      tracking: 0.0,
      weight: FontWeight.w700,
    ),
  );
}

enum _CounterIcon { star, shard }

class _Counter extends StatelessWidget {
  const _Counter({
    required this.icon,
    required this.value,
    required this.color,
  });

  final _CounterIcon icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      CustomPaint(
        size: const Size.square(15.0),
        painter: _CounterIconPainter(icon: icon, color: color),
      ),
      const SizedBox(width: 7.0),
      NeonLabel(
        value,
        size: 15.0,
        color: color,
        weight: FontWeight.w700,
        tracking: 1.2,
      ),
    ],
  );
}

class _CounterIconPainter extends CustomPainter {
  _CounterIconPainter({required this.icon, required this.color});

  final _CounterIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide * 0.5;

    final path = Path();
    switch (icon) {
      case _CounterIcon.star:
        const points = 5;
        for (var i = 0; i < points * 2; i++) {
          final angle = -math.pi * 0.5 + i * math.pi / points;
          final reach = i.isEven ? radius : radius * 0.44;
          final point = Offset(
            centre.dx + math.cos(angle) * reach,
            centre.dy + math.sin(angle) * reach,
          );
          i == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
      case _CounterIcon.shard:
        path
          ..moveTo(centre.dx, centre.dy - radius)
          ..lineTo(centre.dx + radius * 0.62, centre.dy)
          ..lineTo(centre.dx, centre.dy + radius)
          ..lineTo(centre.dx - radius * 0.62, centre.dy);
    }

    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_CounterIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}

class _PadlockIcon extends StatelessWidget {
  const _PadlockIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.square(22.0), painter: _PadlockPainter());
}

class _PadlockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.hudDim
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.1;

    final body = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.45,
      size.width * 0.64,
      size.height * 0.42,
    );

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(size.width * 0.1)),
        paint,
      )
      ..drawArc(
        Rect.fromLTWH(
          size.width * 0.3,
          size.height * 0.14,
          size.width * 0.4,
          size.height * 0.42,
        ),
        math.pi,
        math.pi,
        false,
        paint,
      );
  }

  @override
  bool shouldRepaint(_PadlockPainter oldDelegate) => false;
}

class MenuBackdrop extends CustomPainter {
  MenuBackdrop({required this.phase});

  final double phase;

  static const int _rows = 12;
  static const double _horizonFraction = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, <Color>[
        Palette.skyFar,
        Palette.skyNear,
      ]);
    canvas.drawRect(rect, paint);

    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final horizon = rect.top + rect.height * _horizonFraction;
    final travel = phase % 1.0;

    for (var i = 0; i < _rows; i++) {
      final step = (i + travel) / _rows;
      final depth = step * step;
      final y = horizon + (rect.bottom - horizon) * depth;

      paint.color = Palette.gridLine.withValues(
        alpha: Palette.gridLine.a * (1.0 - depth * 0.6),
      );
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }

    const columns = 9;
    for (var i = 0; i <= columns; i++) {
      final at = i / columns;
      paint.color = Palette.gridLine.withValues(
        alpha: Palette.gridLine.a * 0.5,
      );
      canvas.drawLine(
        Offset(rect.center.dx + (at - 0.5) * rect.width * 0.1, horizon),
        Offset(
          rect.left + rect.width * at * 2.0 - rect.width * 0.5,
          rect.bottom,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(MenuBackdrop oldDelegate) => oldDelegate.phase != phase;
}
