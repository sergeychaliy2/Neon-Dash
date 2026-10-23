import 'dart:typed_data';

import '../config/game_config.dart';
import 'package:playable_kit/playable_kit.dart';

class Route {
  const Route._({
    required this.stage,
    required this.length,
    required this.segmentStart,
    required this.segmentClassIndex,
    required this.checkpointDistance,
  });

  factory Route.forStage(
    int stage, {
    RouteConfig config = RouteConfig.neonDash,
  }) {
    final safeStage = stage < 1 ? 1 : stage;
    final length = config.lengthForStage(safeStage);
    final random = DeterministicRandom(_seedBase + safeStage);
    final denseChance = config.denseChanceForStage(safeStage);

    final starts = <double>[0.0];
    final classes = <int>[HazardClass.moderate.index];

    var cursor = config.openingLength;
    var previous = HazardClass.moderate;
    while (cursor < length) {
      final next = _pickClass(random, previous, denseChance, config.calmChance);
      starts.add(cursor);
      classes.add(next.index);
      previous = next;
      cursor += random.nextRange(
        config.minSegmentLength,
        config.maxSegmentLength,
      );
    }

    final checkpoints = Float32List(config.checkpointCount);
    for (var i = 0; i < config.checkpointCount; i++) {
      checkpoints[i] = length * (i + 1) / (config.checkpointCount + 1);
    }

    return Route._(
      stage: safeStage,
      length: length,
      segmentStart: Float32List.fromList(starts),
      segmentClassIndex: Uint8List.fromList(classes),
      checkpointDistance: checkpoints,
    );
  }

  static const int _seedBase = 0x2F17;

  final int stage;

  final double length;

  final Float32List segmentStart;

  final Uint8List segmentClassIndex;

  final Float32List checkpointDistance;

  int get segmentCount => segmentStart.length;
  int get checkpointCount => checkpointDistance.length;

  HazardClass classOfSegment(int index) =>
      HazardClass.values[segmentClassIndex[index]];

  double segmentEnd(int index) =>
      index + 1 < segmentCount ? segmentStart[index + 1] : length;

  int segmentAt(double distance) {
    for (var i = segmentCount - 1; i > 0; i--) {
      if (distance >= segmentStart[i]) return i;
    }
    return 0;
  }

  double progressAt(double distance) {
    if (length <= 0.0) return 1.0;
    final fraction = distance / length;
    if (fraction < 0.0) return 0.0;
    return fraction > 1.0 ? 1.0 : fraction;
  }

  static HazardClass _pickClass(
    DeterministicRandom random,
    HazardClass previous,
    double denseChance,
    double calmChance,
  ) {
    if (previous == HazardClass.dense) return HazardClass.calm;
    if (random.chance(denseChance)) return HazardClass.dense;
    return random.chance(calmChance) ? HazardClass.calm : HazardClass.moderate;
  }
}
