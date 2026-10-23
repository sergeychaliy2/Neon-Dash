import 'package:playable_kit/playable_kit.dart';
import 'package:test/test.dart';

void main() {
  FixedStepClock clockAt120() =>
      FixedStepClock(stepSeconds: 1.0 / 120.0, maxStepsPerFrame: 4);

  group('FixedStepClock', () {
    test('a frame shorter than a step yields nothing and keeps the time', () {
      final clock = clockAt120();

      expect(clock.consume(1.0 / 400.0), 0);
      expect(clock.pending, closeTo(1.0 / 400.0, 1e-12));
    });

    test('two short frames add up to one step', () {
      final clock = clockAt120();

      expect(clock.consume(1.0 / 240.0), 0);
      expect(clock.consume(1.0 / 240.0), 1);
      expect(clock.pending, closeTo(0.0, 1e-12));
    });

    test('a 60 Hz frame is exactly two steps at 120 Hz', () {
      expect(clockAt120().consume(1.0 / 60.0), 2);
    });

    test('nothing is lost across a long uneven run', () {
      final clock = clockAt120();
      final frames = <double>[
        1 / 61, 1 / 59, 1 / 144, 1 / 30, 1 / 120, 1 / 240, 1 / 90,
      ];

      var steps = 0;
      var seconds = 0.0;
      for (var round = 0; round < 500; round++) {
        final frame = frames[round % frames.length];
        seconds += frame;
        steps += clock.consume(frame);
      }

      expect(steps, (seconds * 120.0).floor());
      expect(clock.pending, lessThan(1.0 / 120.0));
    });

    test('a stall is discarded rather than queued', () {
      final clock = clockAt120();

      expect(clock.consume(2.0), 4);
      expect(clock.consume(1.0 / 120.0), 1);
    });

    test('time at the ceiling leaves no remainder behind', () {
      final clock = clockAt120();

      clock.consume(5.0);
      expect(clock.pending, closeTo(0.0, 1e-12));
    });

    test('zero and negative frames do nothing', () {
      final clock = clockAt120();

      expect(clock.consume(0.0), 0);
      expect(clock.consume(-1.0), 0);
      expect(clock.pending, 0.0);
    });

    test('reset drops the carried remainder', () {
      final clock = clockAt120()..consume(1.0 / 240.0);
      expect(clock.pending, greaterThan(0.0));

      clock.reset();

      expect(clock.pending, 0.0);
      expect(clock.consume(1.0 / 240.0), 0);
    });

    test('interpolation reports how far into the next step the clock is', () {
      final clock = clockAt120()..consume(1.0 / 240.0);

      expect(clock.interpolation, closeTo(0.5, 1e-9));
      expect(clock.interpolation, lessThan(1.0));
    });

    test('interpolation stays inside the unit interval, always', () {
      final clock = clockAt120();

      for (var i = 1; i <= 400; i++) {
        clock.consume(i / 1000.0);
        expect(clock.interpolation, inInclusiveRange(0.0, 1.0));
        expect(clock.interpolation, lessThan(1.0));
      }
    });

    test('a step of zero is refused rather than looping forever', () {
      expect(
        () => FixedStepClock(stepSeconds: 0.0, maxStepsPerFrame: 4),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => FixedStepClock(stepSeconds: 1 / 120, maxStepsPerFrame: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
