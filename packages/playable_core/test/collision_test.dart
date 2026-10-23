import 'package:playable_core/playable_core.dart';
import 'package:test/test.dart';

void main() {
  group('squaredDistanceToBox', () {
    test('is zero for a point inside the box', () {
      expect(squaredDistanceToBox(10.0, 10.0, 10.0, 10.0, 4.0, 2.0), 0.0);
      expect(squaredDistanceToBox(13.0, 11.0, 10.0, 10.0, 4.0, 2.0), 0.0);
    });

    test('is zero exactly on the edge', () {
      expect(squaredDistanceToBox(14.0, 10.0, 10.0, 10.0, 4.0, 2.0), 0.0);
    });

    test('measures the perpendicular gap beside a face', () {
      expect(squaredDistanceToBox(17.0, 10.0, 10.0, 10.0, 4.0, 2.0), 9.0);
    });

    test('measures the diagonal gap off a corner', () {
      final squared =
          squaredDistanceToBox(17.0, 16.0, 10.0, 10.0, 4.0, 2.0);

      expect(squared, closeTo(25.0, 1e-9));
    });

    test('is symmetric about the box centre', () {
      final right = squaredDistanceToBox(20.0, 10.0, 10.0, 10.0, 3.0, 3.0);
      final left = squaredDistanceToBox(0.0, 10.0, 10.0, 10.0, 3.0, 3.0);

      expect(left, right);
    });
  });

  group('circleOverlapsBox', () {
    test('overlaps when the gap is smaller than the radius', () {
      expect(
        circleOverlapsBox(16.0, 10.0, 2.5, 10.0, 10.0, 4.0, 2.0),
        isTrue,
      );
    });

    test('does not overlap when the gap exceeds the radius', () {
      expect(
        circleOverlapsBox(17.0, 10.0, 2.5, 10.0, 10.0, 4.0, 2.0),
        isFalse,
      );
    });

    test('touching counts as overlapping', () {
      expect(
        circleOverlapsBox(16.5, 10.0, 2.5, 10.0, 10.0, 4.0, 2.0),
        isTrue,
      );
    });
  });

  group('squaredDistanceToSegment', () {
    test('is zero on the segment', () {
      expect(squaredDistanceToSegment(5.0, 0.0, 0.0, 0.0, 10.0, 0.0), 0.0);
    });

    test('measures perpendicular distance beside the segment', () {
      expect(
        squaredDistanceToSegment(5.0, 3.0, 0.0, 0.0, 10.0, 0.0),
        closeTo(9.0, 1e-9),
      );
    });

    test('measures to the nearer end beyond the segment', () {
      expect(
        squaredDistanceToSegment(14.0, 3.0, 0.0, 0.0, 10.0, 0.0),
        closeTo(25.0, 1e-9),
      );
    });

    test('a degenerate segment behaves as a point', () {
      expect(
        squaredDistanceToSegment(3.0, 4.0, 1.0, 1.0, 1.0, 1.0),
        closeTo(13.0, 1e-9),
      );
    });
  });

  group('squaredDistanceToTriangle', () {
    const aX = -1.0, aY = -1.0;
    const bX = 1.0, bY = -1.0;
    const cX = 0.0, cY = 1.0;

    double distanceTo(double x, double y) =>
        squaredDistanceToTriangle(x, y, aX, aY, bX, bY, cX, cY);

    test('is zero inside and on the vertices', () {
      expect(distanceTo(0.0, 0.0), 0.0);
      expect(distanceTo(0.0, -0.9), 0.0);
      expect(distanceTo(0.0, 1.0), 0.0);
      expect(distanceTo(-1.0, -1.0), 0.0);
    });

    test('measures to the base from above it', () {
      expect(distanceTo(0.0, -3.0), closeTo(4.0, 1e-9));
    });

    test('the empty corner beside the point is genuinely empty', () {
      final squared = distanceTo(0.9, 0.9);

      expect(squared, greaterThan(0.5));
      expect(squared, closeTo(0.578, 0.01));
    });

    test('is symmetric about the spike centreline', () {
      expect(distanceTo(-0.9, 0.9), closeTo(distanceTo(0.9, 0.9), 1e-9));
    });
  });

  group('circleOverlapsTriangle', () {
    const aX = -2.0, aY = -2.0;
    const bX = 2.0, bY = -2.0;
    const cX = 0.0, cY = 2.0;

    test('overlaps when the circle reaches the sloping edge', () {
      expect(
        circleOverlapsTriangle(2.4, 1.6, 2.1, aX, aY, bX, bY, cX, cY),
        isTrue,
      );
    });

    test('clears the empty corner when the circle is smaller', () {
      expect(
        circleOverlapsTriangle(2.4, 1.6, 1.8, aX, aY, bX, bY, cX, cY),
        isFalse,
      );
    });

    test('a circle centred inside always overlaps', () {
      expect(
        circleOverlapsTriangle(0.0, -1.0, 0.1, aX, aY, bX, bY, cX, cY),
        isTrue,
      );
    });
  });

  group('circlesOverlap', () {
    test('overlaps when centres are closer than the summed radii', () {
      expect(circlesOverlap(0.0, 0.0, 2.0, 3.0, 0.0, 2.0), isTrue);
    });

    test('does not overlap when centres are further than the summed radii', () {
      expect(circlesOverlap(0.0, 0.0, 2.0, 5.0, 0.0, 2.0), isFalse);
    });

    test('touching counts as overlapping', () {
      expect(circlesOverlap(0.0, 0.0, 2.0, 4.0, 0.0, 2.0), isTrue);
    });
  });
}
