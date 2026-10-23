import 'dart:typed_data';

import '../config/game_config.dart';
import '../domain/bonus_kind.dart';
import 'package:playable_kit/playable_kit.dart';
import '../domain/obstacle_shape.dart';
import '../domain/portal_kind.dart';
import 'difficulty_curve.dart';
import 'world.dart';

class Spawner {
  Spawner({required GameConfig config, required DeterministicRandom random})
      : _config = config,
        // ignore: prefer_initializing_formals
        _random = random,
        _curve = DifficultyCurve(config.difficulty),
        _blockFrom = Float32List(config.pools.maxObstacles),
        _blockTo = Float32List(config.pools.maxObstacles),
        _rowDepth = Float32List(config.pools.maxObstacles),
        _standFrom = Float32List(config.pools.maxObstacles + 2),
        _standTo = Float32List(config.pools.maxObstacles + 2),
        _prevStandFrom = Float32List(config.pools.maxObstacles + 2),
        _prevStandTo = Float32List(config.pools.maxObstacles + 2);

  static const double _minHalfWidth = 0.7;

  static const double _pylonHalfWidth = 2.2;

  static const double _combFill = 0.78;

  final GameConfig _config;
  final DeterministicRandom _random;
  final DifficultyCurve _curve;

  final Float32List _blockFrom;
  final Float32List _blockTo;

  final Float32List _rowDepth;

  static const double _sameRow = 1e-6;

  final Float32List _standFrom;
  final Float32List _standTo;
  int _standCount = 0;

  final Float32List _prevStandFrom;
  final Float32List _prevStandTo;
  int _prevStandCount = 0;

  double _countdown = 0.0;

  double _extraDelay = 0.0;

  bool _haveRow = false;

  double _lastExitArrival = 0.0;

  double _portalCountdown = 0.0;
  PortalKind? _lastPortal;

  BonusKind? _lastBonus;

  void reset() {
    _countdown = _config.difficulty.startSpawnInterval;
    _extraDelay = 0.0;
    _lastBonus = null;
    _haveRow = false;
    _prevStandCount = 0;
    _lastExitArrival = 0.0;
    _portalCountdown = _config.portal.intervalSeconds;
    _lastPortal = null;
  }

  void update(World world, double dt) {
    if (world.routeRemaining <= _config.route.finishRunIn) return;

    _updatePortals(world, dt);

    _countdown -= dt;
    if (_countdown > 0.0) return;

    _countdown += alignToBeat(
      _curve.spawnIntervalAt(world.elapsed) * world.hazard.spawnIntervalScale,
      _config.wave.beatSeconds,
    );
    if (_countdown <= 0.0) _countdown = _config.wave.beatSeconds;

    final obstaclesBefore = world.obstacleCount;
    final orbsBefore = world.orbCount;
    final pickupsBefore = world.pickupCount;

    _spawnWave(world);
    _requireCrossing(world, obstaclesBefore, orbsBefore, pickupsBefore);

    _countdown += _extraDelay;
    _extraDelay = 0.0;
  }

  void _updatePortals(World world, double dt) {
    final portal = _config.portal;
    if (portal.available.isEmpty) return;

    _portalCountdown -= dt;
    if (_portalCountdown > 0.0) return;

    _portalCountdown += alignToBeat(
      portal.intervalSeconds,
      _config.wave.beatSeconds,
    );
    if (_portalCountdown <= 0.0) {
      _portalCountdown = portal.intervalSeconds;
    }

    final kind = _rollPortal(portal.available);
    _lastPortal = kind;
    world.addPortal(y: -portal.leadDistance, kind: kind);
  }

  PortalKind _rollPortal(Set<PortalKind> available) {
    final skip = available.length > 1 && available.contains(_lastPortal)
        ? _lastPortal
        : null;
    final count = skip == null ? available.length : available.length - 1;

    var choice = _random.nextInt(count);
    for (final kind in available) {
      if (kind == skip) continue;
      if (choice == 0) return kind;
      choice--;
    }
    return available.first;
  }

  void _requireCrossing(World world, int from, int orbsFrom, int pickupsFrom) {
    if (world.obstacleCount <= from) return;

    final rows = _collectRows(world, from);
    final scroll = _curve.scrollSpeedAt(world.elapsed);

    for (var r = 0; r < rows; r++) {
      var depth = _rowDepth[r];
      _collectStands(world, from, depth);
      if (_standCount == 0) continue;

      var leading = depth;
      var trailing = depth;
      for (var i = from; i < world.obstacleCount; i++) {
        final halfHeight = world.obstacleHalfHeight[i];
        if ((world.obstacleY[i] - depth).abs() > halfHeight) continue;
        final low = world.obstacleY[i] + halfHeight;
        final high = world.obstacleY[i] - halfHeight;
        if (low > leading) leading = low;
        if (high < trailing) trailing = high;
      }

      if (_haveRow && scroll > 0.0) {
        final available = _arrivalOf(world, leading) - _lastExitArrival;
        if (available > 0.0) {
          var needed = _crossingSeconds(world, _worstTravelToStands()) *
              scroll *
              _worstScroll;
          if (needed < _config.wave.minRowGap) needed = _config.wave.minRowGap;

          final shortfall = needed - available;

          if (shortfall > 0.0) {
            _liftFrom(world, from, orbsFrom, pickupsFrom, depth, shortfall);
            _countdown += shortfall / scroll;
            depth -= shortfall;
            leading -= shortfall;
            trailing -= shortfall;
            for (var j = r; j < rows; j++) {
              _rowDepth[j] -= shortfall;
            }
          }
        }
      }

      _rememberStands();
      _haveRow = true;
      _lastExitArrival = _arrivalOf(world, trailing);
    }
  }

  void _collectStands(World world, int from, double depth) {
    var blocks = 0;

    for (var i = from; i < world.obstacleCount; i++) {
      final halfHeight = world.obstacleHalfHeight[i];
      if ((world.obstacleY[i] - depth).abs() > halfHeight) continue;

      final reach = world.obstacleHalfWidth[i] + world.obstacleDriftAmplitude[i];
      var low = world.obstacleX[i] - reach;
      var high = world.obstacleX[i] + reach;
      if (high <= 0.0 || low >= world.fieldWidth) continue;
      if (low < 0.0) low = 0.0;
      if (high > world.fieldWidth) high = world.fieldWidth;

      var at = blocks;
      while (at > 0 && _blockFrom[at - 1] > low) {
        _blockFrom[at] = _blockFrom[at - 1];
        _blockTo[at] = _blockTo[at - 1];
        at--;
      }
      _blockFrom[at] = low;
      _blockTo[at] = high;
      blocks++;
      if (blocks == _blockFrom.length) break;
    }

    final radius = _config.player.radius;
    _standCount = 0;
    var cursor = 0.0;

    for (var i = 0; i < blocks; i++) {
      if (_blockFrom[i] > cursor) _addStand(cursor, _blockFrom[i], radius);
      if (_blockTo[i] > cursor) cursor = _blockTo[i];
    }
    _addStand(cursor, world.fieldWidth, radius);
  }

  void _addStand(double spanFrom, double spanTo, double radius) {
    final standFrom = spanFrom + radius;
    final standTo = spanTo - radius;
    if (standTo < standFrom) return;
    if (_standCount == _standFrom.length) return;

    _standFrom[_standCount] = standFrom;
    _standTo[_standCount] = standTo;
    _standCount++;
  }

  double _worstTravelToStands() {
    if (_prevStandCount == 0 || _standCount == 0) return 0.0;

    var worst = 0.0;
    for (var p = 0; p < _prevStandCount; p++) {
      final hereFrom = _nearestStandGap(_prevStandFrom[p]);
      if (hereFrom > worst) worst = hereFrom;
      final hereTo = _nearestStandGap(_prevStandTo[p]);
      if (hereTo > worst) worst = hereTo;

      for (var t = 1; t < _standCount; t++) {
        final mid = (_standTo[t - 1] + _standFrom[t]) * 0.5;
        if (mid < _prevStandFrom[p] || mid > _prevStandTo[p]) continue;
        final here = _nearestStandGap(mid);
        if (here > worst) worst = here;
      }
    }

    return worst;
  }

  double _nearestStandGap(double x) {
    var best = double.infinity;

    for (var t = 0; t < _standCount; t++) {
      final gap = _standFrom[t] > x
          ? _standFrom[t] - x
          : _standTo[t] < x
              ? x - _standTo[t]
              : 0.0;
      if (gap < best) best = gap;
      if (best <= 0.0) return 0.0;
    }

    return best.isFinite ? best : 0.0;
  }

  void _rememberStands() {
    _prevStandCount = _standCount;
    for (var i = 0; i < _standCount; i++) {
      _prevStandFrom[i] = _standFrom[i];
      _prevStandTo[i] = _standTo[i];
    }
  }

  int _collectRows(World world, int from) {
    var rows = 0;

    for (var i = from; i < world.obstacleCount; i++) {
      final y = world.obstacleY[i];

      var seen = false;
      for (var j = 0; j < rows; j++) {
        if ((_rowDepth[j] - y).abs() <= _sameRow) {
          seen = true;
          break;
        }
      }
      if (seen) continue;

      var at = rows;
      while (at > 0 && _rowDepth[at - 1] < y) {
        _rowDepth[at] = _rowDepth[at - 1];
        at--;
      }
      _rowDepth[at] = y;
      rows++;
      if (rows == _rowDepth.length) break;
    }

    return rows;
  }

  double _arrivalOf(World world, double depth) =>
      world.distance + (world.playerY - depth);

  void _liftFrom(
    World world,
    int from,
    int orbsFrom,
    int pickupsFrom,
    double depth,
    double lift,
  ) {
    if (lift <= 0.0) return;
    final limit = depth + _sameRow;

    for (var i = from; i < world.obstacleCount; i++) {
      if (world.obstacleY[i] <= limit) world.obstacleY[i] -= lift;
    }
    for (var i = orbsFrom; i < world.orbCount; i++) {
      if (world.orbY[i] <= limit) world.orbY[i] -= lift;
    }
    for (var i = pickupsFrom; i < world.pickupCount; i++) {
      if (world.pickupY[i] <= limit) world.pickupY[i] -= lift;
    }
  }

  double _crossingSeconds(World world, double crossing) {
    final wave = _config.wave;
    final floor = wave.minRowSeconds;
    if (crossing <= 0.0) return floor;

    final craftSpeed = _config.player.speedInWidths * world.fieldWidth;
    if (craftSpeed <= 0.0) return wave.reactionSeconds + floor;

    final needed = wave.reactionSeconds +
        crossing / craftSpeed * wave.weaveSafetyFactor;
    return needed > floor ? needed : floor;
  }

  double get _worstScroll => _config.portal.worstScrollScale;

  static double alignToBeat(double seconds, double beatSeconds) {
    if (beatSeconds <= 0.0) return seconds;

    var beats = (seconds / beatSeconds).round();
    if (beats < 1) beats = 1;
    return beats * beatSeconds;
  }

  void _spawnWave(World world) {
    switch (_pickPattern(world.elapsed)) {
      case WavePattern.sides:
        _spawnSides(world, spiked: false);
      case WavePattern.spikeRow:
        _spawnSides(world, spiked: true);
      case WavePattern.island:
        _spawnIsland(world);
      case WavePattern.comb:
        _spawnComb(world);
      case WavePattern.mines:
        _spawnMines(world);
      case WavePattern.gate:
        _spawnGate(world);
      case WavePattern.weave:
        _spawnWeave(world);
      case WavePattern.corridor:
        _spawnCorridor(world);
      case WavePattern.funnel:
        _spawnFunnel(world);
      case WavePattern.staircase:
        _spawnStaircase(world);
      case WavePattern.ramps:
        _spawnRamps(world);
      case WavePattern.sawRow:
        _spawnSawRow(world);
      case WavePattern.zipper:
        _spawnZipper(world);
    }
  }

  WavePattern _pickPattern(double elapsed) {
    const patterns = WavePattern.values;
    final wave = _config.wave;

    var total = 0.0;
    for (var i = 0; i < patterns.length; i++) {
      if (patterns[i].unlocksAtSeconds > elapsed) continue;
      total += wave.weightOf(patterns[i]);
    }
    if (total <= 0.0) return WavePattern.sides;

    var roll = _random.nextDouble() * total;
    for (var i = 0; i < patterns.length; i++) {
      if (patterns[i].unlocksAtSeconds > elapsed) continue;
      final weight = wave.weightOf(patterns[i]);
      if (weight <= 0.0) continue;
      roll -= weight;
      if (roll <= 0.0) return patterns[i];
    }
    return WavePattern.sides;
  }

  void _requestDepth(World world, double depth) {
    final scrollSpeed = _curve.scrollSpeedAt(world.elapsed) * _worstScroll;
    if (scrollSpeed <= 0.0) return;
    _extraDelay = alignToBeat(depth / scrollSpeed, _config.wave.beatSeconds);
  }

  double _minGap(World world) =>
      world.playerRadius * 2.0 + _config.wave.gapMargin;

  double _driftAmplitude(World world) =>
      world.elapsed >= _config.wave.driftUnlocksAtSeconds
          ? world.fieldWidth * _config.wave.driftAmplitudeFraction
          : 0.0;

  void _spawnSides(World world, {required bool spiked}) {
    final width = world.fieldWidth;
    final gapHalfWidth = width * _gapFraction(world) * 0.5;
    final gapCentre = _random.nextRange(gapHalfWidth, width - gapHalfWidth);
    final drift = _driftAmplitude(world);

    _fillSide(
      world,
      from: 0.0,
      to: gapCentre - gapHalfWidth,
      spiked: spiked,
      gapIsToTheRight: true,
      drift: drift,
    );
    _fillSide(
      world,
      from: gapCentre + gapHalfWidth,
      to: width,
      spiked: spiked,
      gapIsToTheRight: false,
      drift: drift,
    );

    _maybeAddOrb(world, gapCentre);
  }

  void _spawnIsland(World world) {
    final width = world.fieldWidth;
    final minGap = _minGap(world);
    final drift = _driftAmplitude(world);

    final maxHalfWidth = (width - 2.0 * minGap) * 0.5 - drift;
    if (maxHalfWidth <= _minHalfWidth) {
      _spawnSides(world, spiked: false);
      return;
    }

    final halfWidth = _random.nextRange(maxHalfWidth * 0.45, maxHalfWidth);
    final margin = minGap + halfWidth + drift;
    final centre = _random.nextRange(margin, width - margin);

    _addWall(world, centre: centre, halfWidth: halfWidth, drift: drift);

    final leftRoom = centre - halfWidth;
    final rightRoom = width - (centre + halfWidth);
    _maybeAddOrb(
      world,
      leftRoom > rightRoom ? leftRoom * 0.5 : centre + halfWidth + rightRoom * 0.5,
    );
  }

  void _spawnComb(World world) {
    final width = world.fieldWidth;
    final slots = _config.wave.combSlots;
    final slotWidth = width / slots;

    if (slotWidth < _minGap(world)) {
      _spawnSides(world, spiked: false);
      return;
    }

    final drift = _driftAmplitude(world);
    final halfWidth = slotWidth * _combFill * 0.5 - drift;
    if (halfWidth <= _minHalfWidth) {
      _spawnSides(world, spiked: false);
      return;
    }

    final openSlot = _random.nextInt(slots);
    final phase = _random.nextDouble();

    for (var slot = 0; slot < slots; slot++) {
      if (slot == openSlot) continue;
      _addWall(
        world,
        centre: slotWidth * (slot + 0.5),
        halfWidth: halfWidth,
        drift: drift,
        phase: phase,
      );
    }

    _maybeAddOrb(world, slotWidth * (openSlot + 0.5));
  }

  void _spawnMines(World world) {
    final width = world.fieldWidth;
    final radius = _config.wave.mineRadius;
    final minGap = _minGap(world);
    final drift = _driftAmplitude(world) + radius;

    final corridorHalfWidth = minGap * 0.5;
    final corridorCentre = _random.nextRange(
      corridorHalfWidth,
      width - corridorHalfWidth,
    );
    final exclusion = corridorHalfWidth + radius + drift;

    final leftLimit = corridorCentre - exclusion;
    final rightStart = corridorCentre + exclusion;

    for (var i = 0; i < _config.wave.minesPerWave; i++) {
      final leftFits = leftLimit - radius > 0.0;
      final rightFits = width - radius - rightStart > 0.0;
      if (!leftFits && !rightFits) break;

      final useLeft = leftFits && (!rightFits || _random.chance(0.5));
      final x = useLeft
          ? _random.nextRange(radius, leftLimit)
          : _random.nextRange(rightStart, width - radius);

      world.addObstacle(
        x: x,
        y: -radius - i * radius * 2.6,
        halfWidth: radius,
        halfHeight: radius,
        shape: ObstacleShape.mine,
        driftAmplitude: drift,
        driftRate: _config.wave.driftRateHz,
        driftPhase: _random.nextDouble(),
      );
    }

    _maybeAddOrb(world, corridorCentre);
  }

  void _spawnGate(World world) {
    final width = world.fieldWidth;
    final swing = width * _config.wave.gateSwingFraction;
    final openHalfWidth = _minGap(world) * 0.5 + swing;

    if (openHalfWidth * 2.0 + _minHalfWidth * 4.0 >= width) {
      _spawnSides(world, spiked: false);
      return;
    }

    final centre = _random.nextRange(openHalfWidth, width - openHalfWidth);
    final phase = _random.nextDouble();

    _addGatePanel(
      world,
      from: 0.0,
      to: centre - openHalfWidth,
      swing: swing,
      phase: phase,
    );
    _addGatePanel(
      world,
      from: centre + openHalfWidth,
      to: width,
      swing: swing,
      phase: phase + 0.5,
    );

    _maybeAddOrb(world, centre);
  }

  void _addGatePanel(
    World world, {
    required double from,
    required double to,
    required double swing,
    required double phase,
  }) {
    final halfWidth = (to - from) * 0.5;
    if (halfWidth < _minHalfWidth) return;

    final halfHeight = _config.wave.boxHalfHeight;
    world.addObstacle(
      x: from + halfWidth,
      y: -halfHeight,
      halfWidth: halfWidth,
      halfHeight: halfHeight,
      shape: ObstacleShape.box,
      driftAmplitude: swing,
      driftRate: _config.wave.gateRateHz,
      driftPhase: phase % 1.0,
    );
  }

  void _spawnWeave(World world) {
    final width = world.fieldWidth;
    final gapHalfWidth = width * _gapFraction(world) * 0.5;

    final leftCentre = _random.nextRange(gapHalfWidth, width * 0.5);
    final rightCentre = _random.nextRange(width * 0.5, width - gapHalfWidth);

    final leftFirst = _random.chance(0.5);
    final leading = leftFirst ? leftCentre : rightCentre;
    final trailing = leftFirst ? rightCentre : leftCentre;

    final spacing = _weaveSpacing(world, (trailing - leading).abs());

    _addWeaveWall(world, centre: leading, gapHalfWidth: gapHalfWidth, depth: 0.0);
    _addWeaveWall(
      world,
      centre: trailing,
      gapHalfWidth: gapHalfWidth,
      depth: spacing,
    );

    _requestDepth(world, spacing);
    _maybeAddOrb(world, leading);
  }

  void _spawnRamps(World world) {
    final width = world.fieldWidth;
    final wave = _config.wave;
    final gapHalfWidth = width * _gapFraction(world) * 0.5;
    final gapCentre = _random.nextRange(gapHalfWidth, width - gapHalfWidth);
    final drift = _driftAmplitude(world);

    for (final (from, to, towardsGapOnTheRight) in <(double, double, bool)>[
      (0.0, gapCentre - gapHalfWidth, true),
      (gapCentre + gapHalfWidth, width, false),
    ]) {
      final left = towardsGapOnTheRight ? from : from + drift;
      final right = towardsGapOnTheRight ? to - drift : to;
      final halfWidth = (right - left) * 0.5;
      if (halfWidth < _minHalfWidth) continue;

      world.addObstacle(
        x: left + halfWidth,
        y: -wave.boxHalfHeight,
        halfWidth: halfWidth,
        halfHeight: wave.boxHalfHeight,
        shape: ObstacleShape.wedge,
        driftAmplitude: drift,
      );
    }

    _maybeAddOrb(world, gapCentre);
  }

  void _spawnSawRow(World world) {
    final width = world.fieldWidth;
    final wave = _config.wave;
    final radius = wave.sawRadius;
    final minGap = _minGap(world);

    final count = wave.sawsPerWave < 1 ? 1 : wave.sawsPerWave;
    final slots = count + 1;
    final slotWidth = width / slots;
    if (slotWidth <= minGap * 0.5) {
      _spawnSides(world, spiked: false);
      return;
    }

    final open = _random.nextInt(slots);
    for (var slot = 0; slot < slots; slot++) {
      if (slot == open) continue;

      world.addObstacle(
        x: slotWidth * (slot + 0.5),
        y: -radius,
        halfWidth: radius,
        halfHeight: radius,
        shape: ObstacleShape.saw,
      );
    }

    _maybeAddOrb(world, slotWidth * (open + 0.5));
  }

  void _spawnStaircase(World world) {
    final width = world.fieldWidth;
    final wave = _config.wave;
    final gapHalfWidth = width * _gapFraction(world) * 0.5;

    final low = gapHalfWidth;
    final high = width - gapHalfWidth;
    if (high - low < _minHalfWidth) {
      _spawnSides(world, spiked: false);
      return;
    }

    final steps = wave.staircaseSteps < 2 ? 2 : wave.staircaseSteps;
    final travel = (high - low) * wave.staircaseTravelFraction;
    final stride = travel / (steps - 1);
    final spacing = _weaveSpacing(world, stride);

    final rightward = _random.chance(0.5);
    final start = rightward ? low : high;
    final direction = rightward ? 1.0 : -1.0;

    for (var i = 0; i < steps; i++) {
      _addWeaveWall(
        world,
        centre: start + direction * stride * i,
        gapHalfWidth: gapHalfWidth,
        depth: spacing * i,
      );
    }

    _requestDepth(world, spacing * (steps - 1));
    _maybeAddOrb(world, start + direction * travel * 0.5);
  }

  void _spawnCorridor(World world) {
    final width = world.fieldWidth;
    final wave = _config.wave;
    final minGap = _minGap(world);
    final drift = _driftAmplitude(world);

    var channelHalf = width * wave.corridorWidthFraction * 0.5;
    if (channelHalf * 2.0 < minGap) channelHalf = minGap * 0.5;

    final margin = channelHalf + drift;
    if (margin * 2.0 >= width) {
      _spawnSides(world, spiked: false);
      return;
    }

    final centre = _random.nextRange(margin, width - margin);
    final halfHeight = wave.corridorDepth * 0.5;
    final phase = _random.nextDouble();

    _addCorridorWall(
      world,
      from: 0.0,
      to: centre - margin,
      halfHeight: halfHeight,
      drift: drift,
      phase: phase,
    );
    _addCorridorWall(
      world,
      from: centre + margin,
      to: width,
      halfHeight: halfHeight,
      drift: drift,
      phase: phase,
    );

    _requestDepth(world, wave.corridorDepth);
    _maybeAddOrb(world, centre);
  }

  void _addCorridorWall(
    World world, {
    required double from,
    required double to,
    required double halfHeight,
    required double drift,
    required double phase,
  }) {
    final halfWidth = (to - from) * 0.5;
    if (halfWidth < _minHalfWidth) return;

    world.addObstacle(
      x: from + halfWidth,
      y: -halfHeight,
      halfWidth: halfWidth,
      halfHeight: halfHeight,
      shape: ObstacleShape.box,
      driftAmplitude: drift,
      driftRate: _config.wave.driftRateHz,
      driftPhase: phase,
    );
  }

  void _spawnFunnel(World world) {
    final width = world.fieldWidth;
    final wave = _config.wave;
    final layers = wave.funnelLayers < 2 ? 2 : wave.funnelLayers;

    final mouth = width * _gapFraction(world);
    final throat = _minGap(world);
    final centre = _random.nextRange(
      throat * 0.5 + _minHalfWidth,
      width - throat * 0.5 - _minHalfWidth,
    );

    for (var layer = 0; layer < layers; layer++) {
      final towardThroat = layer / (layers - 1);
      final gapHalfWidth = (mouth + (throat - mouth) * towardThroat) * 0.5;
      final y = -wave.boxHalfHeight - layer * wave.funnelLayerSpacing;

      _addStaticSpan(
        world,
        0.0,
        centre - gapHalfWidth,
        wave.boxHalfHeight,
        y,
      );
      _addStaticSpan(
        world,
        centre + gapHalfWidth,
        width,
        wave.boxHalfHeight,
        y,
      );
    }

    _requestDepth(world, (layers - 1) * wave.funnelLayerSpacing);
    _maybeAddOrb(world, centre);
  }

  void _spawnZipper(World world) {
    final width = world.fieldWidth;
    final wave = _config.wave;
    final minGap = _minGap(world);

    var reach = width * wave.zipperToothFraction;
    final maxReach = width - minGap;
    if (reach > maxReach) reach = maxReach;
    if (reach < _minHalfWidth * 2.0) {
      _spawnSides(world, spiked: false);
      return;
    }

    var crossing = 2.0 * (reach + _config.player.radius) - width;
    if (crossing < 0.0) crossing = 0.0;

    final spacing = weaveSpacing(
      crossing: crossing,
      craftSpeed: _config.player.speedInWidths * width,
      scrollSpeed: _curve.scrollSpeedAt(world.elapsed) * _worstScroll,
      safetyFactor: wave.weaveSafetyFactor,
      minimum: wave.weaveMinSpacing,
      blockedDepth: 2.0 * wave.boxHalfHeight,
      reactionSeconds: wave.reactionSeconds,
    );

    final teeth = wave.zipperTeeth < 2 ? 2 : wave.zipperTeeth;
    for (var tooth = 0; tooth < teeth; tooth++) {
      final y = -wave.boxHalfHeight - tooth * spacing;
      if (tooth.isEven) {
        _addStaticSpan(world, 0.0, reach, wave.boxHalfHeight, y);
      } else {
        _addStaticSpan(world, width - reach, width, wave.boxHalfHeight, y);
      }
    }

    _requestDepth(world, (teeth - 1) * spacing);
    _maybeAddOrb(world, width * 0.5);
  }

  double _weaveSpacing(World world, double crossing) => weaveSpacing(
        crossing: crossing,
        craftSpeed: _config.player.speedInWidths * world.fieldWidth,
        scrollSpeed: _curve.scrollSpeedAt(world.elapsed) * _worstScroll,
        safetyFactor: _config.wave.weaveSafetyFactor,
        minimum: _config.wave.weaveMinSpacing,
        blockedDepth: 2.0 * _config.wave.boxHalfHeight,
        reactionSeconds: _config.wave.reactionSeconds,
      );

  static double weaveSpacing({
    required double crossing,
    required double craftSpeed,
    required double scrollSpeed,
    required double safetyFactor,
    required double minimum,
    required double blockedDepth,
    required double reactionSeconds,
  }) {
    if (craftSpeed <= 0.0) return minimum;

    final needed = blockedDepth +
        scrollSpeed * (reactionSeconds + (crossing / craftSpeed) * safetyFactor);
    return needed > minimum ? needed : minimum;
  }

  void _addWeaveWall(
    World world, {
    required double centre,
    required double gapHalfWidth,
    required double depth,
  }) {
    final halfHeight = _config.wave.boxHalfHeight;
    final y = -halfHeight - depth;

    _addStaticSpan(world, 0.0, centre - gapHalfWidth, halfHeight, y);
    _addStaticSpan(
      world,
      centre + gapHalfWidth,
      world.fieldWidth,
      halfHeight,
      y,
    );
  }

  void _addStaticSpan(
    World world,
    double from,
    double to,
    double halfHeight,
    double y,
  ) {
    final halfWidth = (to - from) * 0.5;
    if (halfWidth < _minHalfWidth) return;

    world.addObstacle(
      x: from + halfWidth,
      y: y,
      halfWidth: halfWidth,
      halfHeight: halfHeight,
      shape: ObstacleShape.box,
    );
  }

  void _fillSide(
    World world, {
    required double from,
    required double to,
    required bool spiked,
    required bool gapIsToTheRight,
    required double drift,
  }) {
    final left = gapIsToTheRight ? from : from + drift;
    final right = gapIsToTheRight ? to - drift : to;
    if (right - left <= 0.0) return;

    if (spiked) {
      _addSpikes(world, left, right, drift);
    } else {
      final halfWidth = (right - left) * 0.5;
      _addWall(world, centre: left + halfWidth, halfWidth: halfWidth, drift: drift);
    }
  }

  void _addWall(
    World world, {
    required double centre,
    required double halfWidth,
    required double drift,
    double? phase,
  }) {
    if (halfWidth < _minHalfWidth) return;

    final halfHeight = halfWidth < _pylonHalfWidth
        ? _config.wave.pylonHalfHeight
        : _config.wave.boxHalfHeight;

    world.addObstacle(
      x: centre,
      y: -halfHeight,
      halfWidth: halfWidth,
      halfHeight: halfHeight,
      shape: ObstacleShape.box,
      driftAmplitude: drift,
      driftRate: _config.wave.driftRateHz,
      driftPhase: phase ?? _random.nextDouble(),
    );
  }

  void _addSpikes(World world, double left, double right, double drift) {
    final span = right - left;
    final spikeWidth = _config.wave.spikeHalfWidth * 2.0;
    final count = (span / spikeWidth).floor();
    if (count <= 0) return;

    final phase = _random.nextDouble();
    final step = span / count;
    final halfWidth = step * 0.5;

    for (var i = 0; i < count; i++) {
      world.addObstacle(
        x: left + step * (i + 0.5),
        y: -_config.wave.spikeHalfHeight,
        halfWidth: halfWidth,
        halfHeight: _config.wave.spikeHalfHeight,
        shape: ObstacleShape.spike,
        driftAmplitude: drift,
        driftRate: _config.wave.driftRateHz,
        driftPhase: phase,
      );
    }
  }

  void _maybeAddOrb(World world, double x) {
    final chance = _config.orbChance * world.hazard.orbChanceScale;
    if (_random.chance(chance > 1.0 ? 1.0 : chance)) {
      world.addOrb(x: x, y: -_config.orbRadius);
    }
    _maybeAddPickup(world, x);
  }

  void _maybeAddPickup(World world, double x) {
    final available = _config.bonus.available;
    if (available.isEmpty) return;
    if (!_random.chance(_config.bonus.pickupChance)) return;

    final kind = _rollBonus(available);
    _lastBonus = kind;

    if (world.holdsBonus(kind)) return;

    world.addPickup(x: x, y: -_config.bonus.pickupRadius, kind: kind);
  }

  BonusKind _rollBonus(Set<BonusKind> available) {
    final skip = available.length > 1 && available.contains(_lastBonus)
        ? _lastBonus
        : null;
    final count = skip == null ? available.length : available.length - 1;

    var choice = _random.nextInt(count);
    for (final kind in available) {
      if (kind == skip) continue;
      if (choice == 0) return kind;
      choice--;
    }
    return available.first;
  }

  double _gapFraction(World world) {
    final scaled =
        _curve.gapFractionAt(world.elapsed) * world.hazard.gapScale;
    final floor = _minGap(world) / world.fieldWidth;
    return scaled < floor ? floor : scaled;
  }
}
