library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:playable_core/playable_core.dart';

import '../render/palette.dart';
import '../ui/neon_widgets.dart';
import '../ui/skin_preview.dart';
import 'menu_screen.dart' show MenuBackdrop;

const String kBuildStamp = String.fromEnvironment(
  'BUILD_STAMP',
  defaultValue: 'LOCAL',
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.progression,
    required this.onFly,
    required this.onOpenMenu,
    super.key,
  });

  final Progression progression;

  final ValueChanged<LevelDefinition> onFly;

  final VoidCallback onOpenMenu;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _cycle = Duration(seconds: 20);

  static const double _bob = 7.0;

  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  LevelDefinition get _next {
    var last = LevelCatalogue.byIndex(0);

    for (final level in LevelCatalogue.levels) {
      if (!widget.progression.isUnlocked(level)) break;
      last = level;
      if (!widget.progression.isCleared(level.index)) return level;
    }

    return last;
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.progression;
    final next = _next;

    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: MenuBackdrop(phase: _clock.value)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Spacer(),
                      _buildTitle(),
                      const Spacer(),
                      _buildCraft(profile.selectedSkin),
                      const Spacer(),
                      _buildStanding(profile),
                      const SizedBox(height: 20.0),
                      _buildWayIn(next),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() => const Column(
    children: <Widget>[
      RiseIn(
        child: NeonLabel(
          'NEON',
          size: 46.0,
          tracking: 14.0,
          weight: FontWeight.w200,
        ),
      ),
      RiseIn(
        index: 1,
        child: NeonLabel(
          'DASH',
          size: 46.0,
          tracking: 14.0,
          weight: FontWeight.w700,
        ),
      ),
      SizedBox(height: 10.0),
      RiseIn(
        index: 2,
        child: NeonLabel(
          'FOURTEEN WAYS DOWN',
          size: 10.0,
          color: Palette.hudDim,
          glow: 0.0,
          tracking: 4.0,
          weight: FontWeight.w500,
        ),
      ),
      if (kBuildStamp != 'LOCAL') ...<Widget>[
        SizedBox(height: 6.0),
        RiseIn(
          index: 3,
          child: NeonLabel(
            kBuildStamp,
            size: 8.0,
            color: Palette.hudDim,
            glow: 0.0,
            tracking: 2.0,
            weight: FontWeight.w400,
          ),
        ),
      ],
    ],
  );

  Widget _buildCraft(CraftSkin skin) {
    final lift = math.sin(_clock.value * 2.0 * math.pi) * _bob;

    return RiseIn(
      index: 4,
      lift: 26.0,
      child: Transform.translate(
        offset: Offset(0.0, lift),
        child: SkinPreview(skin: skin, size: 132.0),
      ),
    );
  }

  Widget _buildStanding(Progression profile) => RiseIn(
    index: 5,
    child: GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _Figure(
            value: '${profile.totalStars}',
            label: 'STARS',
            hue: Palette.orbHue,
          ),
          _Figure(
            value: '${profile.clearedCount}/${LevelCatalogue.count}',
            label: 'CLEARED',
            hue: Palette.craftHue,
          ),
          _Figure(
            value: '${profile.shards}',
            label: 'SHARDS',
            hue: BonusKind.overdrive.hue,
          ),
        ],
      ),
    ),
  );

  Widget _buildWayIn(LevelDefinition next) => Column(
    children: <Widget>[
      RiseIn(
        index: 6,
        child: NeonButton(
          label: 'FLY',
          emphasis: ButtonEmphasis.primary,
          note: next.name,
          onPressed: () => widget.onFly(next),
        ),
      ),
      const SizedBox(height: 12.0),
      RiseIn(
        index: 7,
        child: NeonButton(
          label: 'HANGAR',
          emphasis: ButtonEmphasis.quiet,
          onPressed: widget.onOpenMenu,
        ),
      ),
    ],
  );
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    required this.hue,
  });

  final String value;
  final String label;
  final double hue;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      NeonLabel(
        value,
        size: 20.0,
        color: colorFromHsl(hue, 0.85, 0.66),
        tracking: 1.4,
        weight: FontWeight.w600,
      ),
      const SizedBox(height: 3.0),
      NeonLabel(
        label,
        size: 9.0,
        color: Palette.hudDim,
        glow: 0.0,
        tracking: 2.2,
        weight: FontWeight.w500,
      ),
    ],
  );
}
