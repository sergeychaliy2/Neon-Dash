library;

import 'package:flutter/widgets.dart';
import 'package:playable_core/playable_core.dart';

import '../render/palette.dart';
import '../ui/neon_widgets.dart';
import '../ui/star_row.dart';

class ResultOverlay extends StatefulWidget {
  const ResultOverlay({
    required this.summary,
    required this.level,
    required this.starsAlreadyHeld,
    required this.shardsHeld,
    required this.canContinue,
    required this.onContinue,
    required this.onRetry,
    required this.onMenu,
    required this.onNext,
    super.key,
  });

  final RunSummary summary;
  final LevelDefinition level;

  final int starsAlreadyHeld;

  final int shardsHeld;

  final bool canContinue;

  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  final VoidCallback? onNext;

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  bool get _won => widget.summary.finished;

  bool get _canAfford => widget.shardsHeld >= widget.summary.continuePrice;

  @override
  Widget build(BuildContext context) {
    final accent = _won ? Palette.star : colorFromHsl(14.0, 0.85, 0.62);

    return AnimatedBuilder(
      animation: _entry,
      builder: (context, child) {
        final eased = Curves.easeOutCubic.transform(_entry.value);
        return ColoredBox(
          color: Palette.resultScrim.withValues(
            alpha: Palette.resultScrim.a * eased,
          ),
          child: Opacity(
            opacity: eased,
            child: Transform.translate(
              offset: Offset(0.0, (1.0 - eased) * 26.0),
              child: child,
            ),
          ),
        );
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420.0),
            child: GlassPanel(
              tint: accent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  NeonLabel(
                    _won ? 'STAGE CLEAR' : 'RUN ENDED',
                    size: 24.0,
                    color: accent,
                    weight: FontWeight.w800,
                    tracking: 4.0,
                  ),
                  const SizedBox(height: 6.0),
                  NeonLabel(
                    widget.level.name,
                    size: 12.0,
                    color: Palette.hudDim,
                    glow: 0.0,
                    tracking: 3.0,
                    weight: FontWeight.w500,
                  ),
                  const SizedBox(height: 18.0),
                  _buildStars(),
                  const SizedBox(height: 18.0),
                  _buildStats(),
                  const SizedBox(height: 20.0),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStars() {
    if (_won) {
      return Column(
        children: <Widget>[
          StarRow(
            earned: widget.summary.stars,
            alreadyHeld: widget.starsAlreadyHeld,
          ),
          if (widget.summary.stars > widget.starsAlreadyHeld) ...<Widget>[
            const SizedBox(height: 10.0),
            NeonLabel(
              widget.starsAlreadyHeld == 0 ? 'FIRST CLEAR' : 'NEW BEST',
              size: 11.0,
              color: Palette.star,
              tracking: 3.0,
            ),
          ],
          if (widget.summary.stars < StarRules.maxPerLevel) ...<Widget>[
            const SizedBox(height: 10.0),
            NeonLabel(
              _missingStarHint(),
              size: 10.5,
              color: Palette.hudDim,
              glow: 0.0,
              tracking: 1.6,
              weight: FontWeight.w500,
              maxLines: 2,
            ),
          ],
        ],
      );
    }

    return Column(
      children: <Widget>[
        _ProgressTrack(
          progress: widget.summary.progress,
          checkpointsPassed: widget.summary.checkpointsPassed,
          checkpointCount: widget.level.route.checkpointCount,
          listenable: _entry,
        ),
        const SizedBox(height: 12.0),
        NeonLabel(
          '${widget.summary.progressPercent}% OF THE ROUTE',
          size: 13.0,
          color: Palette.hudPrimary,
          tracking: 2.6,
        ),
        const SizedBox(height: 8.0),
        NeonLabel(
          widget.starsAlreadyHeld > 0
              ? 'BEST ON THIS LEVEL: ${widget.starsAlreadyHeld} OF '
                    '${StarRules.maxPerLevel} STARS'
              : 'STARS ARE AWARDED AT THE FINISH LINE',
          size: 10.5,
          color: Palette.hudDim,
          glow: 0.0,
          tracking: 1.6,
          weight: FontWeight.w500,
          maxLines: 2,
        ),
      ],
    );
  }

  String _missingStarHint() {
    if (widget.summary.orbs < widget.level.stars.orbTarget) {
      return 'COLLECT ${widget.level.stars.orbTarget} ORBS FOR ANOTHER STAR';
    }
    return 'FINISH WITHOUT A SINGLE HIT FOR THE LAST STAR';
  }

  Widget _buildStats() {
    final summary = widget.summary;
    final lines = <Widget>[
      StatLine(label: 'SCORE', value: '${summary.score}'),
      StatLine(
        label: 'ORBS',
        value: '${summary.orbs} / ${widget.level.stars.orbTarget}',
      ),
      StatLine(label: 'NEAR MISSES', value: '${summary.nearMisses}'),
      StatLine(
        label: 'HITS TAKEN',
        value: '${summary.hits}',
        accent: summary.hits == 0 ? Palette.star : null,
      ),
      StatLine(
        label: 'SHARDS EARNED',
        value: '+${summary.shards}',
        accent: colorFromHsl(BonusKind.overdrive.hue, 0.9, 0.66),
      ),
    ];

    return Column(
      children: <Widget>[
        for (var i = 0; i < lines.length; i++)
          RiseIn(index: i, lift: 8.0, child: lines[i]),
      ],
    );
  }

  Widget _buildActions() {
    final price = widget.summary.continuePrice;

    return Column(
      children: <Widget>[
        if (_won && widget.onNext != null)
          _wide(
            NeonButton(
              label: 'NEXT LEVEL',
              emphasis: ButtonEmphasis.primary,
              onPressed: widget.onNext,
            ),
          ),
        if (!_won && widget.canContinue)
          _wide(
            NeonButton(
              label: 'CONTINUE',
              emphasis: ButtonEmphasis.primary,
              hue: BonusKind.shield.hue,
              enabled: _canAfford,
              note: _canAfford
                  ? 'FROM CHECKPOINT · $price SHARDS'
                  : 'NEEDS $price SHARDS · YOU HAVE ${widget.shardsHeld}',
              onPressed: widget.onContinue,
            ),
          ),
        const SizedBox(height: NeonMetrics.rowGap),
        RiseIn(
          index: 6,
          child: Row(
            children: <Widget>[
              Expanded(
                child: NeonButton(
                  label: _won ? 'REPLAY' : 'TRY AGAIN',
                  emphasis: _won
                      ? ButtonEmphasis.normal
                      : ButtonEmphasis.primary,
                  onPressed: widget.onRetry,
                ),
              ),
              const SizedBox(width: NeonMetrics.rowGap),
              Expanded(
                child: NeonButton(
                  label: 'MENU',
                  emphasis: ButtonEmphasis.quiet,
                  onPressed: widget.onMenu,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _wide(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: NeonMetrics.rowGap),
    child: RiseIn(
      index: 5,
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.progress,
    required this.checkpointsPassed,
    required this.checkpointCount,
    required this.listenable,
  });

  final double progress;
  final int checkpointsPassed;
  final int checkpointCount;

  final Animation<double> listenable;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: listenable,
    builder: (context, _) => CustomPaint(
      size: const Size(double.infinity, 16.0),
      painter: _ProgressPainter(
        progress: progress * Curves.easeOutCubic.transform(listenable.value),
        reached: progress,
        checkpointsPassed: checkpointsPassed,
        checkpointCount: checkpointCount,
      ),
    ),
  );
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.progress,
    required this.reached,
    required this.checkpointsPassed,
    required this.checkpointCount,
  });

  final double progress;

  final double reached;

  final int checkpointsPassed;
  final int checkpointCount;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Rect.fromLTWH(0.0, size.height * 0.34, size.width, 5.0);
    final corner = Radius.circular(track.height * 0.5);
    final paint = Paint()..isAntiAlias = true;

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(track, corner),
        paint..color = Palette.routeTrack,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            track.left,
            track.top,
            track.width * progress,
            track.height,
          ),
          corner,
        ),
        paint..color = Palette.routeRunner,
      );

    for (var i = 0; i < checkpointCount; i++) {
      final at = (i + 1) / (checkpointCount + 1);
      canvas.drawCircle(
        Offset(track.left + track.width * at, track.center.dy),
        3.2,
        paint
          ..color = i < checkpointsPassed
              ? Palette.routeCheckpointPassed
              : Palette.routeCheckpointAhead,
      );
    }

    if (progress >= reached - 0.001) {
      canvas.drawCircle(
        Offset(track.left + track.width * reached, track.center.dy),
        5.0,
        paint..color = Palette.crashFlash,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.reached != reached ||
      oldDelegate.checkpointsPassed != checkpointsPassed;
}
