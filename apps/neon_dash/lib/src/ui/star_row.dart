library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../render/palette.dart';

class StarRow extends StatefulWidget {
  const StarRow({
    required this.earned,
    this.total = 3,
    this.alreadyHeld = 0,
    this.size = 44.0,
    this.animate = true,
    super.key,
  });

  final int earned;
  final int total;

  final int alreadyHeld;

  final double size;

  final bool animate;

  @override
  State<StarRow> createState() => _StarRowState();
}

class _StarRowState extends State<StarRow>
    with SingleTickerProviderStateMixin {
  static const Duration _perStar = Duration(milliseconds: 420);
  static const Duration _stagger = Duration(milliseconds: 230);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );
    if (widget.animate && widget.earned > widget.alreadyHeld) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(StarRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.earned == widget.earned &&
        oldWidget.alreadyHeld == widget.alreadyHeld) {
      return;
    }
    _controller
      ..duration = _totalDuration
      ..forward(from: 0.0);
  }

  Duration get _totalDuration {
    final animated = math.max(0, widget.earned - widget.alreadyHeld);
    if (animated == 0) return _perStar;
    return _stagger * (animated - 1) + _perStar;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _progressFor(int index, double elapsedMs) {
    if (index >= widget.earned) return 0.0;
    if (index < widget.alreadyHeld) return 1.0;

    final slot = index - widget.alreadyHeld;
    final start = _stagger.inMilliseconds * slot;
    final fraction = (elapsedMs - start) / _perStar.inMilliseconds;
    if (fraction <= 0.0) return 0.0;
    return fraction >= 1.0 ? 1.0 : fraction;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final elapsedMs = _controller.value * _totalDuration.inMilliseconds;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < widget.total; i++) ...<Widget>[
                if (i > 0) SizedBox(width: widget.size * 0.22),
                CustomPaint(
                  size: Size.square(widget.size),
                  painter: _StarPainter(
                    progress: Curves.easeOutBack.transform(
                      _progressFor(i, elapsedMs),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      );
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.progress});

  final double progress;

  static const int _points = 5;
  static const double _innerRatio = 0.44;
  static const double _tau = 6.283185307179586;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide * 0.5;
    final lit = progress.clamp(0.0, 1.0);

    final outline = _starPath(centre, radius * 0.82);

    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, radius * 0.08)
        ..strokeJoin = StrokeJoin.round
        ..color = Palette.starEmpty
        ..isAntiAlias = true,
    );

    if (lit <= 0.0) return;

    final filled = _starPath(centre, radius * 0.82 * progress);

    canvas
      ..drawPath(
        filled,
        Paint()
          ..color = Palette.star.withValues(alpha: 0.26 * lit)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45)
          ..isAntiAlias = true,
      )
      ..drawPath(
        filled,
        Paint()
          ..color = Palette.star.withValues(alpha: lit)
          ..isAntiAlias = true,
      )
      ..drawPath(
        _starPath(centre, radius * 0.82 * progress * _innerRatio * 1.6),
        Paint()
          ..color = const Color(0xFFFFFDF2).withValues(alpha: 0.85 * lit)
          ..isAntiAlias = true,
      );
  }

  Path _starPath(Offset centre, double radius) {
    final path = Path();
    final inner = radius * _innerRatio;

    for (var i = 0; i < _points * 2; i++) {
      final isOuter = i.isEven;
      final angle = -math.pi * 0.5 + i * _tau / (_points * 2);
      final reach = isOuter ? radius : inner;
      final point = Offset(
        centre.dx + math.cos(angle) * reach,
        centre.dy + math.sin(angle) * reach,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    return path..close();
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
