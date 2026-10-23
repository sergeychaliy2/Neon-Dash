library;

double squaredDistanceToBox(
  double pointX,
  double pointY,
  double boxX,
  double boxY,
  double boxHalfWidth,
  double boxHalfHeight,
) {
  var dx = pointX - boxX;
  if (dx < 0.0) dx = -dx;
  dx -= boxHalfWidth;
  if (dx < 0.0) dx = 0.0;

  var dy = pointY - boxY;
  if (dy < 0.0) dy = -dy;
  dy -= boxHalfHeight;
  if (dy < 0.0) dy = 0.0;

  return dx * dx + dy * dy;
}

bool circleOverlapsBox(
  double circleX,
  double circleY,
  double radius,
  double boxX,
  double boxY,
  double boxHalfWidth,
  double boxHalfHeight,
) {
  final squared = squaredDistanceToBox(
    circleX,
    circleY,
    boxX,
    boxY,
    boxHalfWidth,
    boxHalfHeight,
  );
  return squared <= radius * radius;
}

double squaredDistanceToSegment(
  double pointX,
  double pointY,
  double aX,
  double aY,
  double bX,
  double bY,
) {
  final edgeX = bX - aX;
  final edgeY = bY - aY;
  final toPointX = pointX - aX;
  final toPointY = pointY - aY;

  final edgeLengthSquared = edgeX * edgeX + edgeY * edgeY;
  if (edgeLengthSquared <= 0.0) {
    return toPointX * toPointX + toPointY * toPointY;
  }

  var along = (toPointX * edgeX + toPointY * edgeY) / edgeLengthSquared;
  if (along < 0.0) {
    along = 0.0;
  } else if (along > 1.0) {
    along = 1.0;
  }

  final dx = toPointX - edgeX * along;
  final dy = toPointY - edgeY * along;
  return dx * dx + dy * dy;
}

double squaredDistanceToTriangle(
  double pointX,
  double pointY,
  double aX,
  double aY,
  double bX,
  double bY,
  double cX,
  double cY,
) {
  if (_pointInTriangle(pointX, pointY, aX, aY, bX, bY, cX, cY)) return 0.0;

  var nearest = squaredDistanceToSegment(pointX, pointY, aX, aY, bX, bY);

  final toSecond = squaredDistanceToSegment(pointX, pointY, bX, bY, cX, cY);
  if (toSecond < nearest) nearest = toSecond;

  final toThird = squaredDistanceToSegment(pointX, pointY, cX, cY, aX, aY);
  if (toThird < nearest) nearest = toThird;

  return nearest;
}

bool circleOverlapsTriangle(
  double circleX,
  double circleY,
  double radius,
  double aX,
  double aY,
  double bX,
  double bY,
  double cX,
  double cY,
) =>
    squaredDistanceToTriangle(circleX, circleY, aX, aY, bX, bY, cX, cY) <=
    radius * radius;

bool _pointInTriangle(
  double pointX,
  double pointY,
  double aX,
  double aY,
  double bX,
  double bY,
  double cX,
  double cY,
) {
  final first = _edgeSign(pointX, pointY, aX, aY, bX, bY);
  final second = _edgeSign(pointX, pointY, bX, bY, cX, cY);
  final third = _edgeSign(pointX, pointY, cX, cY, aX, aY);

  final anyNegative = first < 0.0 || second < 0.0 || third < 0.0;
  final anyPositive = first > 0.0 || second > 0.0 || third > 0.0;
  return !(anyNegative && anyPositive);
}

double _edgeSign(
  double pointX,
  double pointY,
  double aX,
  double aY,
  double bX,
  double bY,
) =>
    (pointX - bX) * (aY - bY) - (aX - bX) * (pointY - bY);

bool circlesOverlap(
  double aX,
  double aY,
  double aRadius,
  double bX,
  double bY,
  double bRadius,
) {
  final dx = aX - bX;
  final dy = aY - bY;
  final reach = aRadius + bRadius;
  return dx * dx + dy * dy <= reach * reach;
}
