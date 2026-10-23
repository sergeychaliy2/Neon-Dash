import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class FrameStatsReporter {
  FrameStatsReporter({this.windowSeconds = 3.0});

  final double windowSeconds;

  static const int _capacity = 1024;

  final List<double> _buildMillis = <double>[];
  final List<double> _rasterMillis = <double>[];

  Stopwatch? _sinceReport;
  bool _listening = false;

  void start() {
    if (!kProfileMode || _listening) return;
    _listening = true;
    _sinceReport = Stopwatch()..start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_listening) return;
    _listening = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      if (_buildMillis.length >= _capacity) break;
      _buildMillis.add(timing.buildDuration.inMicroseconds / 1000.0);
      _rasterMillis.add(timing.rasterDuration.inMicroseconds / 1000.0);
    }

    final elapsed = _sinceReport;
    if (elapsed == null || elapsed.elapsedMilliseconds < windowSeconds * 1000) {
      return;
    }
    _report();
    elapsed.reset();
  }

  void _report() {
    if (_buildMillis.isEmpty) return;

    final frames = _buildMillis.length;
    final build = _percentiles(_buildMillis);
    final raster = _percentiles(_rasterMillis);

    var late60 = 0;
    var late120 = 0;
    for (var i = 0; i < frames; i++) {
      final total = math.max(_buildMillis[i], _rasterMillis[i]);
      if (total > 16.67) late60++;
      if (total > 8.33) late120++;
    }

    debugPrint(
      'FRAMESTATS frames=$frames '
      'build p50=${build.p50.toStringAsFixed(2)} '
      'p95=${build.p95.toStringAsFixed(2)} '
      'max=${build.max.toStringAsFixed(2)} | '
      'raster p50=${raster.p50.toStringAsFixed(2)} '
      'p95=${raster.p95.toStringAsFixed(2)} '
      'max=${raster.max.toStringAsFixed(2)} | '
      'late60=$late60 late120=$late120',
    );

    _buildMillis.clear();
    _rasterMillis.clear();
  }

  static _Percentiles _percentiles(List<double> samples) {
    final sorted = List<double>.of(samples)..sort();
    return _Percentiles(
      p50: sorted[sorted.length ~/ 2],
      p95: sorted[math.min(sorted.length - 1, (sorted.length * 95) ~/ 100)],
      max: sorted.last,
    );
  }
}

class _Percentiles {
  const _Percentiles({required this.p50, required this.p95, required this.max});

  final double p50;
  final double p95;
  final double max;
}
