import 'dart:math' as math;
import 'dart:ui';

class ViewportLayout {
  const ViewportLayout._({
    required this.fieldRect,
    required this.scale,
    required this.worldWidth,
    required this.slotCount,
  });

  factory ViewportLayout.fit(
    Size size,
    double worldWidth,
    double worldHeight, {
    int slotCount = 3,
  }) {
    final scale = math.min(size.width / worldWidth, size.height / worldHeight);
    final pixelWidth = worldWidth * scale;
    final pixelHeight = worldHeight * scale;

    return ViewportLayout._(
      fieldRect: Rect.fromLTWH(
        (size.width - pixelWidth) * 0.5,
        (size.height - pixelHeight) * 0.5,
        pixelWidth,
        pixelHeight,
      ),
      scale: scale,
      worldWidth: worldWidth,
      slotCount: slotCount,
    );
  }

  static const double zoneWidthFraction = 0.30;

  static const double _zoneInsetWorld = 1.4;

  static const double _zoneTopFraction = 0.09;
  static const double _zoneBottomFraction = 0.155;

  static const double _slotSideWorld = 8.6;
  static const double _slotGapWorld = 1.5;
  static const double _slotBottomWorld = 2.6;

  final Rect fieldRect;

  final double scale;

  final double worldWidth;

  final int slotCount;

  double get _zoneWidth => worldWidth * zoneWidthFraction * scale;
  double get _inset => _zoneInsetWorld * scale;
  double get _zoneTop => fieldRect.top + fieldRect.height * _zoneTopFraction;
  double get _zoneBottom =>
      fieldRect.bottom - fieldRect.height * _zoneBottomFraction;

  Rect get leftZone => Rect.fromLTRB(
        fieldRect.left + _inset,
        _zoneTop,
        fieldRect.left + _inset + _zoneWidth,
        _zoneBottom,
      );

  Rect get rightZone => Rect.fromLTRB(
        fieldRect.right - _inset - _zoneWidth,
        _zoneTop,
        fieldRect.right - _inset,
        _zoneBottom,
      );

  int steerDirectionAt(Offset point) {
    if (slotIndexAt(point) >= 0) return 0;
    if (leftZone.contains(point)) return -1;
    if (rightZone.contains(point)) return 1;
    return 0;
  }

  double get _slotSide {
    final asked = _slotSideWorld * slotCount + _slotGapWorld * (slotCount - 1);
    final room = worldWidth - _slotGapWorld * 2.0;
    final side = asked <= room
        ? _slotSideWorld
        : (room - _slotGapWorld * (slotCount - 1)) / slotCount;
    return side * scale;
  }

  Rect slotRect(int index) {
    if (index < 0 || index >= slotCount) return Rect.zero;

    final side = _slotSide;
    final gap = _slotGapWorld * scale;
    final rowWidth = side * slotCount + gap * (slotCount - 1);
    final left = fieldRect.center.dx - rowWidth * 0.5 + index * (side + gap);
    final bottom = fieldRect.bottom - _slotBottomWorld * scale;

    return Rect.fromLTWH(left, bottom - side, side, side);
  }

  Rect get slotRow => slotCount <= 0
      ? Rect.zero
      : slotRect(0).expandToInclude(slotRect(slotCount - 1));

  int slotIndexAt(Offset point) {
    for (var i = 0; i < slotCount; i++) {
      final rect = slotRect(i);
      if (rect.isEmpty) continue;
      if (point.dx >= rect.left &&
          point.dx <= rect.right &&
          point.dy >= rect.top - rect.height * 0.25 &&
          point.dy <= rect.bottom + rect.height * 0.45) {
        return i;
      }
    }
    return -1;
  }

  double toWorldUnits(double pixels) => scale <= 0.0 ? pixels : pixels / scale;
}
