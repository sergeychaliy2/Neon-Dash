import 'package:playable_kit/playable_kit.dart';
import 'package:test/test.dart';

void main() {
  group('DeterministicRandom', () {
    test('same seed produces the same sequence', () {
      final first = DeterministicRandom(12345);
      final second = DeterministicRandom(12345);

      for (var i = 0; i < 1000; i++) {
        expect(second.nextUint32(), first.nextUint32());
      }
    });

    test('different seeds diverge', () {
      final first = DeterministicRandom(1);
      final second = DeterministicRandom(2);

      var identical = 0;
      for (var i = 0; i < 100; i++) {
        if (first.nextUint32() == second.nextUint32()) identical++;
      }

      expect(identical, lessThan(5));
    });

    test('seed zero still advances', () {
      final random = DeterministicRandom(0);

      final values = {for (var i = 0; i < 10; i++) random.nextUint32()};

      expect(values.length, 10);
    });

    test('nextDouble stays within [0, 1)', () {
      final random = DeterministicRandom(7);

      for (var i = 0; i < 10000; i++) {
        final value = random.nextDouble();
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThan(1.0));
      }
    });

    test('nextRange stays within its bounds', () {
      final random = DeterministicRandom(99);

      for (var i = 0; i < 10000; i++) {
        final value = random.nextRange(-3.5, 8.25);
        expect(value, greaterThanOrEqualTo(-3.5));
        expect(value, lessThan(8.25));
      }
    });

    test('nextRange returns the lower bound for an empty range', () {
      final random = DeterministicRandom(4);

      expect(random.nextRange(5.0, 5.0), 5.0);
      expect(random.nextRange(5.0, 1.0), 5.0);
    });

    test('nextInt stays below its bound and handles a non-positive bound', () {
      final random = DeterministicRandom(21);

      for (var i = 0; i < 1000; i++) {
        final value = random.nextInt(7);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(7));
      }
      expect(random.nextInt(0), 0);
      expect(random.nextInt(-3), 0);
    });

    test('restore replays the sequence from a captured position', () {
      final random = DeterministicRandom(555);
      for (var i = 0; i < 50; i++) {
        random.nextUint32();
      }

      final captured = random.position;
      final expected = [for (var i = 0; i < 20; i++) random.nextUint32()];

      random.restore(captured);
      final replayed = [for (var i = 0; i < 20; i++) random.nextUint32()];

      expect(replayed, expected);
    });

    test('reseed restarts the sequence exactly as the constructor would', () {
      final fresh = DeterministicRandom(31337);
      final reused = DeterministicRandom(1)..reseed(31337);

      for (var i = 0; i < 100; i++) {
        expect(reused.nextUint32(), fresh.nextUint32());
      }
    });

    test('small seeds produce well-spread first values', () {
      final firstValues = [
        for (var seed = 1; seed <= 64; seed++)
          DeterministicRandom(seed).nextDouble(),
      ];

      expect(
        firstValues.toSet().length,
        firstValues.length,
        reason: 'no two seeds may open with the same value',
      );
      expect(
        firstValues.where((value) => value < 0.05).length,
        lessThan(8),
        reason: 'first values must not cluster near zero',
      );

      final mean = firstValues.reduce((a, b) => a + b) / firstValues.length;
      expect(mean, closeTo(0.5, 0.12));
    });
  });
}
